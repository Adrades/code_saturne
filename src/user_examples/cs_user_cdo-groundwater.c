/*============================================================================
 * Set main parameters for the current simulation when the CDO kernel is used
 *============================================================================*/

/* VERS */

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2016 EDF S.A.

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

#include <errno.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <float.h>

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include <bft_mem.h>
#include <bft_printf.h>

#include "cs_mesh_location.h"
#include "cs_cdo_toolbox.h"
#include "cs_property.h"
#include "cs_advection_field.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_prototypes.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Additional doxygen documentation
 *============================================================================*/

/*!
  \file cs_user_cdo.c

  \brief  Set main parameters for the current simulation when the CDO kernel
          is used

*/

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*! \endcond (end ignore by Doxygen) */

/*============================================================================
 * Private function prototypes
 *============================================================================*/

static const double  one6 = 1/6.;
static const double  L = 200;

/* Solution of the TRACY 1D verification testcase
   F.T. Tracy, "1D, 2D, 3D analytical solutions of unsaturated flow in
   groundwater", Journal of Hydrology, 170, pp. 199--214 (1995)
*/
static void
get_sol(cs_real_t           time,
        const cs_real_3_t   xyz,
        cs_get_t           *get)
{
  /* Physical parameters */
  const double  ks = 1.15741e-4;
  const double  theta_r = 0.15, theta_s = 0.45, dtheta = theta_s - theta_r;
  const double  hr = -100;
  const double  td = -5*L*L*dtheta/(6*hr*ks);

  /* Space-dependent part */
  const double  xll = (xyz[0] - L)/L, beta = xll*xll;
  /* Time-dependent part */
  const double  alpha = 6 - 5*time/td;

  (*get).val = hr*(1 - beta/alpha);
}

/* Same as get_sol but optimize for time=0 */
static void
get_ic(cs_real_t           time,
       const cs_real_3_t   xyz,
       cs_get_t           *get)
{
  const double  x = xyz[0], xll = (x - L)/L;
  const double  hr = -100;

  (*get).val = 1-one6*xll*xll;
  (*get).val *= hr;
}

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Activate or not the CDO module
 */
/*----------------------------------------------------------------------------*/

bool
cs_user_cdo_activated(void)
{
  return  true;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Specify additional mesh locations
 */
/*----------------------------------------------------------------------------*/

void
cs_user_cdo_add_mesh_locations(void)
{
  return; /* REMOVE_LINE_FOR_USE_OF_SUBROUTINE */

  /* ===========================
     Define mesh locations
     ===========================

     By default several mesh locations are predefined
     >> "cells"
     >> "interior_faces"
     >> "boundary_faces"
     >> "vertices"

 */

  cs_mesh_location_add("left", CS_MESH_LOCATION_BOUNDARY_FACES, "x < 1e-3");

  char cmd[20];
  const double  tol = 1e-5;

  sprintf(cmd, "x > %10.7e", L-tol);
  cs_mesh_location_add("right", CS_MESH_LOCATION_BOUNDARY_FACES, cmd);

  return;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Specify for the computational domain:
 *         -- which type of boundaries closed the computational domain
 *         -- the settings for the time step
 *         -- activate predefined equations or modules
 *         -- add user-defined properties and/or advection fields
 *         -- add user-defined equations
 *
 * \param[in, out]   domain    pointer to a cs_domain_t structure
 */
/*----------------------------------------------------------------------------*/

void
cs_user_cdo_init_domain(cs_domain_t   *domain)
{
  return; /* REMOVE_LINE_FOR_USE_OF_SUBROUTINE */

  /* ======================
     Boundary of the domain
     ====================== */

  /* Choose a boundary by default.
     >> cs_domain_set_param(domain, "default_boundary", keyval);

     keyval is one of the following keyword: wall or symmetry
  */

  cs_domain_set_param(domain, "default_boundary", "symmetry");

  /* Add a boundary
     >> cs_domain_add_boundary(domain,
                               mesh location name,
                               boundary keyword)

     mesh location name is either a predefined mesh location or one defined
     by user

     boundary keyword is one of the following keyword
     >> wall, inlet, outlet, symmetry
  */

  cs_domain_add_boundary(domain, "left", "inlet");
  cs_domain_add_boundary(domain, "right", "outlet");

  /* ====================
     Time step management
     ==================== */

  /* Set the final time
     >> cs_domain_set_param(domain, "time_max", keyval);

     keyval is for instance "10."

     Set the max. number of time steps
     >> cs_domain_set_param(domain, "nt_max", keyval);

     keyval is for instance "100"

     If there is an inconsistency between the max. number of iteration in
     time and the final physical time, the first condition encountered stops
     the calculation.
  */

  cs_domain_set_param(domain, "time_max", "864000.");
  cs_domain_set_param(domain, "nt_max", "200");

  /* Define the value of the time step
     >> cs_domain_def_time_step_by_value(domain, dt_val);
     >> cs_domain_def_time_step_by_func(domain, dt_func);

     The second way to define the time step enable complex definitions.
     dt_func must have the following prototype:

     double dt_func(int  nt_cur, double  time_cur)
  */

  cs_domain_def_time_step_by_value(domain, 4320);

  /* Rk: Final time is 10 days = 864000 and dt = 0.05 day i.e 20 iters
     for one day */

  /* ================================
     Activate groundwater flow module
     ================================

     For the groundwater flow module:
     >> cs_domain_activate_groundwater(domain,
                                       permeability_type,
                                       Richards_time,
                                       n_soils,
                                       n_tracers);

     * permeability_type is one of the following keywords:
       "isotropic", "orthotropic" or "anisotropic"
     * Richards_time is one of the following keywords:
       "steady" or "unsteady"
     * n_soils should be at least equal to 1.

     * Consequences of the activation of the groundwater flow module are:
     - add a new equation named "Richards" along with an associated field named
       "hydraulic_head". Default boundary condition is set to "zero_flux".
     - define a new advection field named "darcian_flux"
     - define a new property called "permeability".
     - define a new property called "soil_capacity" if "unsteady" is chosen
  */

  cs_domain_activate_groundwater(domain,
                                 "isotropic", // type of permeability
                                 "unsteady",  // steady or unsteady
                                 1,           // number of soils
                                 0);          // number of tracers

  /* Retrieve the groundwater flow module */
  cs_groundwater_t  *gw = cs_domain_get_groundwater(domain);

  /* Set additional parameters related to the groundwater flow module
     >> cs_groundwater_set_param(gw, keyword, keyval);

     If keyword = "post_freq"
     - Frequency used to postprocess specific quantities related to the
       groundwater flow module
       Ex: keyval = "10" means every 10 iterations postprocessing is done.
     If keyword = "output_moisture"
       Ex: keyval = "true" means that the moisture field is postprocessed.

   */

  cs_groundwater_set_param(gw, "post_freq", "10");
  cs_groundwater_set_param(gw, "output_moisture", "true");

  /* =========
     Add soils
     =========

     >> cs_groundwater_add_soil_by_value(gw,
                                         mesh_location_name,
                                         model_keyword,
                                         saturated_permeability);

     - mesh_location_name is the name of the mesh location where this soil is
     defined. The mesh location is related to cells. By default, "cells"
     corresponds to all the cells of the mesh. Otherwise, one needs to define
     new mesh locations.
     - model_keyword is one of the following choices:
       "saturated", "tracy" or "genutchen"
     - saturated_permeability depends on the type of permeability chosen.
       1 value if isotropic, 3 values if orthtropic or 9 values if anisotropic.

  */

  cs_groundwater_add_soil_by_value(gw,
                                   "cells",       /* mesh location name */
                                   "tracy",       /* soil model */
                                   "1.15741e-4"); /* saturated permeability */

  /* Set additional parameters defining this soil
     >> cs_groundwater_set_soil_param(gw,
                                      mesh_location_name,
                                      keyword,
                                      keyval);

     If mesh_location_name is set to NULL, all soils are set.

     Available keywords are:
     - "saturated_moisture",
     - "residual_moisture",
     - "tracy_hr"  (only useful is Tracy model is used)

  */

  cs_groundwater_set_soil_param(gw, "cells", "tracy_hr", "-100");
  cs_groundwater_set_soil_param(gw, NULL, "saturated_moisture", "0.45");
  cs_groundwater_set_soil_param(gw, NULL, "residual_moisture", "0.15");

  /* ====================
     Add tracer equations
     ====================

     Add a tracer equation which is unsteady and convected by the darcean flux
     >> cs_domain_add_groundwater_tracer(domain,
                                         eqname,
                                         varname);

     This implies the creation of a new equation called eqname and a new
     field called varname.
  */

  /* Set parameters related to each tracer equation in each soil
     >> cs_domain_set_groundwater_tracer(domain,
                                         eqname,
                                         mesh_location_name,
                                         water_diff,
                                         alpha_l,
                                         alpha_t,
                                         rho,
                                         kd,
                                         lambda);

     According to the setting, additional properties can be created which are
     associated to the diffusion and/or reaction terms.

     If mesh_location_name is set to NULL, all soils are set.
   */

}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  - Specify the elements such as properties, advection fields,
 *           user-defined equations and modules which have been previously
 *           added.
 *
 * \param[in, out]   domain    pointer to a cs_domain_t structure
*/
/*----------------------------------------------------------------------------*/

void
cs_user_cdo_set_domain(cs_domain_t   *domain)
{
  /* Retrieve the equation to set
     cs_equation_t  *eq = cs_domain_get_equation(domain, "eq_name");
  */

  cs_equation_t  *eq = NULL;

  /* =================
     Richards equation
     ================= */

  eq = cs_domain_get_equation(domain, "Richards");

  /* Define the boundary conditions
     >> cs_equation_add_bc(eq,
                           "mesh_location_name",
                           "bc_type_keyword",
                           "definition_type_keyword",
                           pointer to the definition);

     -- eq is the structure related to the equation to set
     -- Keyword related to the boundary condition type is a choice among:
        >> "dirichlet", "neumann" or "robin"
     -- Keyword related to the type of definition is a choice among:
        >> "value", "analytic"

  */

  cs_equation_add_bc(eq,           // equation
                     "left",       // name of the mesh location
                     "dirichlet",  // BC type
                     "analytic",   // type of definition
                     get_sol);     // pointer to the analytic function

  cs_equation_add_bc(eq,           // equation
                     "right",      // name of the mesh location
                     "dirichlet",  // BC type
                     "value",      // type of definition
                     "-100");      // value to set

  /* Define the initial condition (By default: zero is set) */
  cs_equation_set_ic(eq,         // equation
                     "analytic", // type of definition
                     get_ic);    // pointer to the analytic function

}

/*----------------------------------------------------------------------------*/

END_C_DECLS
