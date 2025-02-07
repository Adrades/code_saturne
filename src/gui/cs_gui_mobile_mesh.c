/*============================================================================
 * Management of the GUI parameters file: mobile mesh
 *============================================================================*/

/*
  This file is part of code_saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2022 EDF S.A.

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

/*----------------------------------------------------------------------------*/

#include "cs_defs.h"

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>

/*----------------------------------------------------------------------------
 * Local headers
 *----------------------------------------------------------------------------*/

#include "bft_mem.h"
#include "bft_error.h"
#include "bft_printf.h"

#include "cs_ale.h"
#include "cs_base.h"
#include "cs_boundary.h"
#include "cs_boundary_zone.h"
#include "cs_convection_diffusion.h"
#include "cs_field_pointer.h"
#include "cs_gui.h"
#include "cs_gui_util.h"
#include "cs_gui_boundary_conditions.h"
#include "cs_mesh.h"
#include "cs_prototypes.h"
#include "cs_timer.h"
#include "cs_time_step.h"
#include "cs_volume_zone.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_gui_mobile_mesh.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Local Macro Definitions
 *============================================================================*/

/* debugging switch */
#define _XML_DEBUG_ 0

/*============================================================================
 * Static variables
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Possible values for boundary nature
 *----------------------------------------------------------------------------*/

enum ale_boundary_nature
{
  ale_boundary_nature_none,
  ale_boundary_nature_fixed_wall,
  ale_boundary_nature_sliding_wall,
  ale_boundary_nature_internal_coupling,
  ale_boundary_nature_external_coupling,
  ale_boundary_nature_fixed_velocity,
  ale_boundary_nature_fixed_displacement,
  ale_boundary_nature_free_surface
};

/*============================================================================
 * Private function definitions
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Return value for ALE method
 *
 * parameters:
 *   tn_ale    <-- tree node associated with ALE
 *
 * return:
 *   0 for isotropic, 1 for orthotropic
 *----------------------------------------------------------------------------*/

static int
_ale_visc_type(cs_tree_node_t  *tn_ale)
{
  int mvisc_type = 0;

  cs_tree_node_t *tn_mv = cs_tree_get_node(tn_ale, "mesh_viscosity");

  const char *type = cs_tree_node_get_tag(tn_mv, "type");
  if (type != NULL) {
    if (strcmp(type, "isotrop") != 0) {
      if (strcmp(type, "orthotrop") == 0)
        mvisc_type = 1;
      else
        bft_error(__FILE__, __LINE__, 0,
                  "invalid mesh viscosity type: %s", type);
    }
  }

  return mvisc_type;
}

/*-----------------------------------------------------------------------------
 * Get the ale boundary formula
 *
 * parameters:
 *   tn_w    <-- pointer to tree node for a given BC
 *   choice  <-- nature: "fixed_velocity" or "fixed_displacement"
 *----------------------------------------------------------------------------*/

static const char*
_get_ale_boundary_formula(cs_tree_node_t  *tn_w,
                          const char      *choice)
{
  cs_tree_node_t *tn = cs_tree_get_node(tn_w, "ale");
  tn = cs_tree_node_get_sibling_with_tag(tn, "choice", choice);

  const char *formula = cs_tree_node_get_child_value_str(tn, "formula");

  return formula;
}

/*-----------------------------------------------------------------------------
 * Get uialcl data for fixed displacement
 *
 * parameters:
 *   tn_w           <-- pointer to tree node for a given mobile_boundary BC
 *   z              <-- selected boundary zone
 *   impale         --> impale
 *   disale         --> disale
 *----------------------------------------------------------------------------*/

static void
_uialcl_fixed_displacement(cs_tree_node_t   *tn_w,
                           const cs_zone_t  *z,
                           int              *impale,
                           cs_real_t         disale[][3])
{

  const cs_mesh_t *m = cs_glob_mesh;

  /* Get formula */
  const char *formula = _get_ale_boundary_formula(tn_w, "fixed_displacement");

  if (!formula)
    bft_error(__FILE__, __LINE__, 0,
              _("Boundary nature formula is null for %s."),
              cs_gui_node_get_tag(tn_w, "label"));

  /* Evaluate formula using meg */
  cs_real_t *bc_vals = cs_meg_boundary_function(z,
                                                "mesh_velocity",
                                                "fixed_displacement");

  /* Loop over boundary faces */
  for (cs_lnum_t elt_id = 0; elt_id < z->n_elts; elt_id++) {
    const cs_lnum_t face_id = z->elt_ids[elt_id];

    /* ALE BC on vertices */
    const cs_lnum_t s = m->b_face_vtx_idx[face_id];
    const cs_lnum_t e = m->b_face_vtx_idx[face_id+1];

    /* Compute the portion of surface associated to v_id_1 */
    for (cs_lnum_t k = s; k < e; k++) {

      const cs_lnum_t v_id = m->b_face_vtx_lst[k];
      cs_real_t *_val = disale[v_id];

      impale[v_id] = 1;
      //FIXME prorata
      for (int d = 0; d < 3; d++)
        _val[d] = bc_vals[elt_id + d * z->n_elts];

    }
  }
}

/*-----------------------------------------------------------------------------
 * Get uialcl data for fixed velocity
 *
 * parameters:
 *   tn_w         <-- pointer to tree node for a given mobile_boundary BC
 *   iuma         <-- iuma
 *   ivma         <-- ivma
 *   iwma         <-- iwma
 *   nfabor       <-- Number of boundary faces
 *   z            <-- selected boundary zone
 *   rcodcl       --> rcodcl
 *----------------------------------------------------------------------------*/

static void
_uialcl_fixed_velocity(cs_tree_node_t  *tn_w,
                       int              iuma,
                       int              ivma,
                       int              iwma,
                       int              ivimpo,
                       cs_lnum_t        nfabor,
                       const cs_zone_t *z,
                       int              ialtyb[],
                       double          *rcodcl)
{
  /* Get formula */
  const char *formula = _get_ale_boundary_formula(tn_w, "fixed_velocity");

  if (!formula)
    bft_error(__FILE__, __LINE__, 0,
              _("Boundary nature formula is null for %s."),
              cs_gui_node_get_tag(tn_w, "label"));

  /* Evaluate formula using meg */
  cs_real_t *bc_vals = cs_meg_boundary_function(z,
                                                "mesh_velocity",
                                                "fixed_velocity");

  /* Loop over boundary faces */
  for (cs_lnum_t elt_id = 0; elt_id < z->n_elts; elt_id++) {
    const cs_lnum_t face_id = z->elt_ids[elt_id];


    /* Fill  rcodcl */
    rcodcl[(iuma-1) * nfabor + face_id] = bc_vals[elt_id + 0 * z->n_elts];
    rcodcl[(ivma-1) * nfabor + face_id] = bc_vals[elt_id + 1 * z->n_elts];
    rcodcl[(iwma-1) * nfabor + face_id] = bc_vals[elt_id + 2 * z->n_elts];

    ialtyb[face_id]  = ivimpo;

  }

  /* Free memory */
  BFT_FREE(bc_vals);

}

/*-----------------------------------------------------------------------------
 * Return the ale boundary nature of a given boundary condition
 *
 * parameters:
 *   tn <-> pointer to tree node for a given mobile_boundary BC
 *
 * return:
 *   associated nature
 *----------------------------------------------------------------------------*/

static enum  ale_boundary_nature
_get_ale_boundary_nature(cs_tree_node_t  *tn)
{
  const char *nat_bndy = cs_tree_node_get_tag(tn, "nature");

  if (cs_gui_strcmp(nat_bndy, "free_surface"))
    return ale_boundary_nature_free_surface;

  else {

    const char *label = cs_tree_node_get_tag(tn, "label");

    /* get the matching BC node */
    tn = cs_tree_node_get_child(tn->parent, nat_bndy);

    /* Now searh from siblings */
    tn = cs_tree_node_get_sibling_with_tag(tn, "label", label);

    /* Finaly get child node ALE */
    cs_tree_node_t *tn_ale = cs_tree_get_node(tn, "ale/choice");
    const char *nat_ale = cs_tree_node_get_value_str(tn_ale);

    if (cs_gui_strcmp(nat_ale, "fixed_boundary"))
      return ale_boundary_nature_fixed_wall;
    if (cs_gui_strcmp(nat_ale, "sliding_boundary"))
      return ale_boundary_nature_sliding_wall;
    else if (cs_gui_strcmp(nat_ale, "internal_coupling"))
      return ale_boundary_nature_internal_coupling;
    else if (cs_gui_strcmp(nat_ale, "external_coupling"))
      return ale_boundary_nature_external_coupling;
    else if (cs_gui_strcmp(nat_ale, "fixed_velocity"))
      return ale_boundary_nature_fixed_velocity;
    else if (cs_gui_strcmp(nat_ale, "fixed_displacement"))
      return ale_boundary_nature_fixed_displacement;
    else
      return ale_boundary_nature_none;
  }
}

/*-----------------------------------------------------------------------------
 * Return the ale boundary type of a given boundary condition
 *
 * parameters:
 *   tn_bndy <-- pointer to tree node for a given BC
 *
 * return:
 *   associated boundary type
 *----------------------------------------------------------------------------*/

static cs_boundary_type_t
_get_ale_boundary_type(cs_tree_node_t  *tn_bndy)
{
  const char *nat_bndy = cs_tree_node_get_tag(tn_bndy, "nature");

  if (cs_gui_strcmp(nat_bndy, "free_surface"))
    return CS_BOUNDARY_ALE_FREE_SURFACE;

  else {

    const char *label = cs_tree_node_get_tag(tn_bndy, "label");

    /* get the matching BC node */
    cs_tree_node_t *tn = cs_tree_node_get_child(tn_bndy->parent, nat_bndy);

    /* Now search from siblings */
    tn = cs_tree_node_get_sibling_with_tag(tn, "label", label);

    /* Finally get child node ALE */
    tn = cs_tree_get_node(tn, "ale/choice");
    const char *nat = cs_tree_node_get_value_str(tn);

    if (cs_gui_strcmp(nat, "fixed_boundary"))
      return CS_BOUNDARY_ALE_FIXED;
    else if (cs_gui_strcmp(nat, "sliding_boundary"))
      return CS_BOUNDARY_ALE_SLIDING;
    else if (cs_gui_strcmp(nat, "internal_coupling"))
      return CS_BOUNDARY_ALE_INTERNAL_COUPLING;
    else if (cs_gui_strcmp(nat, "external_coupling"))
      return CS_BOUNDARY_ALE_EXTERNAL_COUPLING;
    else if (cs_gui_strcmp(nat, "fixed_velocity"))
      return CS_BOUNDARY_ALE_IMPOSED_VEL;
    else if (cs_gui_strcmp(nat, "fixed_displacement"))
      return CS_BOUNDARY_ALE_IMPOSED_DISP;
    else if (cs_gui_strcmp(nat, "free_surface"))
      return CS_BOUNDARY_ALE_FREE_SURFACE;
    else
      return CS_BOUNDARY_UNDEFINED;
  }
}

/*-----------------------------------------------------------------------------
 * Retrieve internal coupling x, y and z values
 *
 * parameters:
 *   tn_ic <-- tree node for a given BC's internal coupling definitions
 *   name  <-- node name
 *   xyz   --> result matrix
 *----------------------------------------------------------------------------*/

static void
_get_internal_coupling_xyz_values(cs_tree_node_t  *tn_ic,
                                  const char      *name,
                                  double           xyz[3])
{
  cs_tree_node_t *tn = cs_tree_node_get_child(tn_ic, name);

  cs_gui_node_get_child_real(tn, "X", xyz);
  cs_gui_node_get_child_real(tn, "Y", xyz+1);
  cs_gui_node_get_child_real(tn, "Z", xyz+2);
}

/*-----------------------------------------------------------------------------
 * Retrieve data for internal coupling for a specific boundary
 *
 * parameters:
 *   label    <-- boundary label
 *   xmstru   --> Mass matrix
 *   xcstr    --> Damping matrix
 *   xkstru   --> Stiffness matrix
 *   forstr   --> Fluid force matrix
 *   istruc   <-- internal coupling boundary index
 *----------------------------------------------------------------------------*/

static void
_get_uistr2_data(const char      *label,
                 double          *xmstru,
                 double          *xcstru,
                 double          *xkstru,
                 double          *forstr,
                 int              istruc)
{
  /* Get mass matrix, damping matrix and stiffness matrix */

  cs_meg_fsi_struct("mass_matrix", label, NULL,
                    &xmstru[istruc * 9]);
  cs_meg_fsi_struct("damping_matrix", label, NULL,
                    &xcstru[istruc * 9]);
  cs_meg_fsi_struct("stiffness_matrix", label, NULL,
                    &xkstru[istruc * 9]);

  /* Set variable for fluid force vector */
  const cs_real_t fluid_f[3] = {forstr[istruc*3],
                                forstr[istruc*3 + 1],
                                forstr[istruc*3 + 2]};

  /* Get fluid force matrix */
  cs_meg_fsi_struct("fluid_force", label, fluid_f,
                    &forstr[istruc * 3]);
}

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public Fortran function definitions
 *============================================================================*/

/*----------------------------------------------------------------------------
 * ALE related keywords
 *
 * Fortran Interface:
 *
 * SUBROUTINE UIALIN
 * *****************
 *
 * nalinf  <->  number of sub iteration of initialization
 *              of fluid
 * nalimx  <->  max number of iterations of implicitation of
 *              the displacement of the structures
 * epalim  <->  relative precision of implicitation of
 *              the displacement of the structures
 *
 *----------------------------------------------------------------------------*/

void CS_PROCF (uialin, UIALIN) (int     *nalinf,
                                int     *nalimx,
                                double  *epalim)
{
  cs_tree_node_t *tn
    = cs_tree_get_node(cs_glob_tree, "thermophysical_models/ale_method");

  cs_gui_node_get_status_int(tn, &cs_glob_ale);

  if (cs_glob_ale) {
    cs_gui_node_get_child_int(tn, "fluid_initialization_sub_iterations",
                              nalinf);
    cs_gui_node_get_child_int(tn, "max_iterations_implicitation",
                              nalimx);
    cs_gui_node_get_child_real(tn, "implicitation_precision",
                               epalim);
  }

#if _XML_DEBUG_
  bft_printf("==> %s\n", __func__);
  bft_printf("--cs_glob_ale = %i\n", cs_glob_ale);
  if (cs_glob_ale > 0) {
    bft_printf("--nalinf = %i\n", *nalinf);
    bft_printf("--nalimx = %i\n", *nalimx);
    bft_printf("--epalim = %g\n", *epalim);
  }
#endif
}

/*----------------------------------------------------------------------------
 * ALE diffusion type
 *
 * Fortran Interface:
 *
 * SUBROUTINE UIALVM
 * *****************
 *----------------------------------------------------------------------------*/

void CS_PROCF (uialvm, UIALVM) ()
{
  cs_tree_node_t *tn
    = cs_tree_get_node(cs_glob_tree, "thermophysical_models/ale_method");

  int iortvm = _ale_visc_type(tn);

  cs_var_cal_opt_t vcopt;
  int key_cal_opt_id = cs_field_key_id("var_cal_opt");
  cs_field_t *f_mesh_u = cs_field_by_name("mesh_velocity");
  cs_field_get_key_struct(f_mesh_u, key_cal_opt_id, &vcopt);

  if (iortvm == 1) { /* orthotropic viscosity */
    vcopt.idften = CS_ANISOTROPIC_LEFT_DIFFUSION;
  } else { /* isotropic viscosity */
    vcopt.idften = CS_ISOTROPIC_DIFFUSION;
  }
  cs_field_set_key_struct(f_mesh_u, key_cal_opt_id, &vcopt);

#if _XML_DEBUG_
  bft_printf("==> %s\n", __func__);
  bft_printf("--iortvm = %i\n",  iortvm);
  }
#endif
}

/*-----------------------------------------------------------------------------
 * uialcl
 *
 * parameters:
 *   ialtyb       <-- ialtyb
 *   impale       <-- uialcl_fixed_displacement
 *   disale       <-- See uialcl_fixed_displacement
 *   iuma         <-- See uialcl_fixed_velocity
 *   ivma         <-- See uialcl_fixed_velocity
 *   iwma         <-- See uialcl_fixed_velocity
 *   rcodcl       <-- See uialcl_fixed_velocity
 *----------------------------------------------------------------------------*/

void CS_PROCF (uialcl, UIALCL) (const int *const    ibfixe,
                                const int *const    igliss,
                                const int *const    ivimpo,
                                const int *const    ifresf,
                                int       *const    ialtyb,
                                int       *const    impale,
                                cs_real_3_t        *disale,
                                const int *const    iuma,
                                const int *const    ivma,
                                const int *const    iwma,
                                double    *const    rcodcl)
{
  const cs_mesh_t *m = cs_glob_mesh;

  cs_tree_node_t *tn_b0 = cs_tree_get_node(cs_glob_tree, "boundary_conditions");

  /* Loop on boundary zones */

  for (cs_tree_node_t *tn_bndy = cs_tree_node_get_child(tn_b0, "boundary");
       tn_bndy != NULL;
       tn_bndy = cs_tree_node_get_next_of_name(tn_bndy)) {

    const char *label = cs_tree_node_get_tag(tn_bndy, "label");

    const cs_zone_t *z = cs_boundary_zone_by_name_try(label);
    if (z == NULL)  /* possible in case of old XML file with "dead" nodes */
      continue;

    cs_lnum_t n_faces = z->n_elts;
    const cs_lnum_t *faces_list = z->elt_ids;

    /* Get ALE nature and get sibling tn */
    enum ale_boundary_nature nature = _get_ale_boundary_nature(tn_bndy);

    if (nature == ale_boundary_nature_none)
      continue;

    /* get the matching BC node */
    const char *nat_bndy = cs_tree_node_get_tag(tn_bndy, "nature");
    cs_tree_node_t *tn_bc = cs_tree_node_get_child(tn_bndy->parent, nat_bndy);
    tn_bc = cs_tree_node_get_sibling_with_tag(tn_bc, "label", label);

    if (nature ==  ale_boundary_nature_fixed_wall) {
      for (cs_lnum_t ifac = 0; ifac < n_faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        ialtyb[ifbr] = *ibfixe;
      }
    }
    else if (nature ==  ale_boundary_nature_sliding_wall) {
      for (cs_lnum_t ifac = 0; ifac < n_faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        ialtyb[ifbr] = *igliss;
      }
    }
    else if (nature ==  ale_boundary_nature_free_surface) {
      for (cs_lnum_t ifac = 0; ifac < n_faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        ialtyb[ifbr] = *ifresf;
      }
    }
    else if (nature == ale_boundary_nature_fixed_displacement) {
      _uialcl_fixed_displacement(tn_bc,
                                 z,
                                 impale,
                                 disale);
    }
    else if (nature == ale_boundary_nature_fixed_velocity) {
      _uialcl_fixed_velocity(tn_bc, *iuma, *ivma, *iwma, *ivimpo,
                             m->n_b_faces,
                             z,
                             ialtyb, rcodcl);
    }
  }
}

/*-----------------------------------------------------------------------------
 * Retrieve data for internal coupling. Called once at initialization
 *
 * parameters:
 *   idfstr   --> Structure definition
 *   mbstru   <-- number of previous structures (-999 or by restart)
 *   aexxst   --> Displacement prediction alpha
 *   bexxst   --> Displacement prediction beta
 *   cfopre   --> Stress prediction alpha
 *   ihistr   --> Monitor point synchronisation
 *   xstr0    <-> Values of the initial displacement
 *   xstreq   <-> Values of the equilibrium displacement
 *   vstr0    <-> Values of the initial velocity
 *----------------------------------------------------------------------------*/

void CS_PROCF (uistr1, UISTR1) (cs_lnum_t        *idfstr,
                                const int        *mbstru,
                                double           *aexxst,
                                double           *bexxst,
                                double           *cfopre,
                                int              *ihistr,
                                double           *xstr0,
                                double           *xstreq,
                                double           *vstr0)
{
  int  istruct = 0;

  cs_tree_node_t *tn0
    = cs_tree_get_node(cs_glob_tree, "thermophysical_models/ale_method");

  /* Get advanced data */
  cs_gui_node_get_child_real(tn0, "displacement_prediction_alpha", aexxst);
  cs_gui_node_get_child_real(tn0, "displacement_prediction_beta", bexxst);
  cs_gui_node_get_child_real(tn0, "stress_prediction_alpha", cfopre);
  cs_gui_node_get_child_status_int(tn0, "monitor_point_synchronisation", ihistr);

  cs_tree_node_t *tn = cs_tree_get_node(cs_glob_tree, "boundary_conditions");

  cs_tree_node_t *tn_b0 = cs_tree_node_get_child(tn, "boundary");
  cs_tree_node_t *tn_w0 = cs_tree_node_get_child(tn, "boundary");//FIXME

  /* At each time-step, loop on boundary faces */

  int izone = 0;

  for (tn = tn_b0;
       tn != NULL;
       tn = cs_tree_node_get_next_of_name(tn), izone++) {

    const char *label = cs_tree_node_get_tag(tn, "label");

    cs_tree_node_t *tn_w
      = cs_tree_node_get_sibling_with_tag(tn_w0, "label", label);

    /* Keep only internal coupling */
    if (  _get_ale_boundary_nature(tn_w)
        == ale_boundary_nature_internal_coupling) {

      if (istruct+1 > *mbstru) { /* Do not overwrite restart data */
        /* Read initial_displacement, equilibrium_displacement
           and initial_velocity */
        cs_tree_node_t *tn_ic = cs_tree_get_node(tn_w, "ale");
        tn_ic = cs_tree_node_get_sibling_with_tag(tn_ic,
                                                  "choice",
                                                  "internal_coupling");
        _get_internal_coupling_xyz_values(tn_ic, "initial_displacement",
                                          &xstr0[3 * istruct]);
        _get_internal_coupling_xyz_values(tn_ic, "equilibrium_displacement",
                                          &xstreq[3 * istruct]);
        _get_internal_coupling_xyz_values(tn_ic, "initial_velocity",
                                          &vstr0[3 * istruct]);
      }

      const cs_zone_t *z = cs_boundary_zone_by_name_try(label);
      if (z == NULL)  /* possible in case of old XML file with "dead" nodes */
        continue;

      cs_lnum_t n_faces = z->n_elts;
      const cs_lnum_t *faces_list = z->elt_ids;

      /* Set idfstr to positive index starting at 1 */
      for (cs_lnum_t ifac = 0; ifac < n_faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        idfstr[ifbr] = istruct + 1;
      }
      ++istruct;
    }
  }
}

/*-----------------------------------------------------------------------------
 * Retrieve data for internal coupling. Called at each step
 *
 * parameters:
 *   xmstru       --> Mass matrix
 *   xcstr        --> Damping matrix
 *   xkstru       --> Stiffness matrix
 *   forstr       --> Fluid force matrix
 *----------------------------------------------------------------------------*/

void CS_PROCF (uistr2, UISTR2) (double *const  xmstru,
                                double *const  xcstru,
                                double *const  xkstru,
                                double *const  forstr)
{
  int istru = 0;

  cs_tree_node_t *tn_b0 = cs_tree_get_node(cs_glob_tree, "boundary_conditions");

  /* At each time-step, loop on boundary faces */

  for (cs_tree_node_t *tn_bndy = cs_tree_node_get_child(tn_b0, "boundary");
       tn_bndy != NULL;
       tn_bndy = cs_tree_node_get_next_of_name(tn_bndy)) {

    const char *label = cs_tree_node_get_tag(tn_bndy, "label");

    enum ale_boundary_nature nature =_get_ale_boundary_nature(tn_bndy);

    /* Keep only internal coupling */
    if (nature == ale_boundary_nature_internal_coupling) {

      /* get the matching BC node */
      const char *nat_bndy = cs_tree_node_get_tag(tn_bndy, "nature");
      cs_tree_node_t *tn_bc = cs_tree_node_get_child(tn_bndy->parent, nat_bndy);
      tn_bc = cs_tree_node_get_sibling_with_tag(tn_bc, "label", label);

      cs_tree_node_t *tn_ic = cs_tree_get_node(tn_bc, "ale");
      tn_ic = cs_tree_node_get_sibling_with_tag(tn_ic,
                                                "choice",
                                                "internal_coupling");

      _get_uistr2_data(label,
                       xmstru,
                       xcstru,
                       xkstru,
                       forstr,
                       istru);
      ++istru;
    }
  }
}

/*-----------------------------------------------------------------------------
 * Retrieve data for external coupling
 *
 * parameters:
 *   idfstr    <-- Structure definition
 *----------------------------------------------------------------------------*/

void
CS_PROCF(uiaste, UIASTE)(int  *idfstr)
{
  int istruct     = 0;

  cs_tree_node_t *tn = cs_tree_get_node(cs_glob_tree, "boundary_conditions");

  cs_tree_node_t *tn_b0 = cs_tree_node_get_child(tn, "boundary");
  cs_tree_node_t *tn_w0 = cs_tree_node_get_child(tn, "boundary");//FIXME

  /* Loop on boundary faces */

  for (tn = tn_b0; tn != NULL; tn = cs_tree_node_get_next_of_name(tn)) {

    const char *label = cs_tree_node_get_tag(tn, "label");

    cs_tree_node_t *tn_w
      = cs_tree_node_get_sibling_with_tag(tn_w0, "label", label);

    enum ale_boundary_nature nature =_get_ale_boundary_nature(tn_w);

    if (nature == ale_boundary_nature_external_coupling) {

      const cs_zone_t *z = cs_boundary_zone_by_name_try(label);
      if (z == NULL)  /* possible in case of old XML file with "dead" nodes */
        continue;

      cs_lnum_t n_faces = z->n_elts;
      const cs_lnum_t *faces_list = z->elt_ids;

      cs_tree_node_t *tn_ec = cs_tree_get_node(tn_w, "ale");
      tn_ec = cs_tree_node_get_sibling_with_tag(tn_ec,
                                                "choice",
                                                "external_coupling");

      /* Set idfstr with negative value starting from -1 */
      for (cs_lnum_t ifac = 0; ifac < n_faces; ifac++) {
        cs_lnum_t ifbr = faces_list[ifac];
        idfstr[ifbr]  = -istruct - 1;
      }
      istruct++;
    }

  }
}

/*============================================================================
 * Public function definitions
 *============================================================================*/

/*-----------------------------------------------------------------------------
 * Return the viscosity's type of ALE method
 *
 * parameters:
 *   type --> type of viscosity's type
 *----------------------------------------------------------------------------*/

void
cs_gui_get_ale_viscosity_type(int  *type)
{
  cs_tree_node_t *tn
    = cs_tree_get_node(cs_glob_tree,
                       "thermophysical_models/ale_method");

  *type = _ale_visc_type(tn);
}

/*----------------------------------------------------------------------------
 * Mesh viscosity setting.
 *----------------------------------------------------------------------------*/

void
cs_gui_mesh_viscosity(void)
{
  cs_tree_node_t *tn0
    = cs_tree_get_node(cs_glob_tree, "thermophysical_models/ale_method");

  /* Get formula */
  const char *mvisc_expr = cs_tree_node_get_child_value_str(tn0, "formula");

  if (mvisc_expr == NULL)
    return;

  /* Compute mesh viscosity using the MEG function.
   * The function accepts a field of arbitrary dimension, hence no need to
   * check here. The formula is generated by the code.
   */
  const cs_zone_t *z_all = cs_volume_zone_by_name("all_cells");
  cs_field_t *fmeg[1] = {CS_F_(vism)};
  cs_meg_volume_function(z_all, fmeg);

}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Translate the user settings for the domain boundaries into a
 *         structure storing the ALE boundaries (New mechanism used in CDO)
 *
 * \param[in, out]  domain   pointer to a \ref cs_domain_t structure
 */
/*----------------------------------------------------------------------------*/

void
cs_gui_mobile_mesh_get_boundaries(cs_domain_t  *domain)
{
  assert(domain != NULL);

  cs_tree_node_t *tn_b0 = cs_tree_get_node(cs_glob_tree, "boundary_conditions");

  /* Loop on boundary zones */

  for (cs_tree_node_t *tn_bndy = cs_tree_node_get_child(tn_b0, "boundary");
       tn_bndy != NULL;
       tn_bndy = cs_tree_node_get_next_of_name(tn_bndy)) {

    const char *label = cs_tree_node_get_tag(tn_bndy, "label");
    const cs_zone_t *z = cs_boundary_zone_by_name_try(label);
    if (z == NULL)  /* possible in case of old XML file with "dead" nodes */
      continue;

    cs_boundary_type_t ale_bdy = _get_ale_boundary_type(tn_bndy);

    if (ale_bdy == CS_BOUNDARY_UNDEFINED)
      continue;

    cs_boundary_add(domain->ale_boundaries,
                    ale_bdy,
                    z->name);

  } /* Loop on mobile_boundary zones */

    /* TODO */
    /* else if (nature == ale_boundary_nature_fixed_displacement) { */
    /*   _uialcl_fixed_displacement(tn_bndy, z, */
    /*                              impale, disale); */
    /* } */
    /* else if (nature == ale_boundary_nature_fixed_velocity) { */
    /*   _uialcl_fixed_velocity(tn_bndy, *iuma, *ivma, *iwma, *ivimpo, */
    /*                          m->n_b_faces, z, */
    /*                          ialtyb, rcodcl); */
    /* } */

}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Return the fixed velocity for a boundary
 *
 * \param[in]  label boundary condition label
 *
 * \return a pointer to an array of cs_real_t values
 */
/*----------------------------------------------------------------------------*/

cs_real_t *
cs_gui_mobile_mesh_get_fixed_velocity(const char    *label)
{
  cs_tree_node_t *tn_b0 = cs_tree_get_node(cs_glob_tree, "boundary_conditions");

  /* Loop on boundary zones */

  for (cs_tree_node_t *tn_bndy = cs_tree_node_get_child(tn_b0, "boundary");
       tn_bndy != NULL;
       tn_bndy = cs_tree_node_get_next_of_name(tn_bndy)) {

    const char *nat_bndy = cs_tree_node_get_tag(tn_bndy, "nature");
    const char *label_bndy = cs_tree_node_get_tag(tn_bndy, "label");

    /* get the matching BC node */
    cs_tree_node_t *tn = cs_tree_node_get_child(tn_bndy->parent, nat_bndy);

    /* Now searh from siblings */
    tn = cs_tree_node_get_sibling_with_tag(tn, "label", label_bndy);

    if (strcmp(label_bndy, label) == 0) {

      /* Get formula */
      const char *formula = _get_ale_boundary_formula(tn, "fixed_velocity");

      if (!formula)
        bft_error(__FILE__, __LINE__, 0,
                  _("Boundary nature formula is null for %s."),
                  cs_gui_node_get_tag(tn, "label"));

      const cs_zone_t *bz = cs_boundary_zone_by_name(label);

      /* Evaluate formula using meg */
      return cs_meg_boundary_function(bz,
                                      "mesh_velocity",
                                      "fixed_velocity");

    }
  }

  return NULL; /* avoid a compilation warning */
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
