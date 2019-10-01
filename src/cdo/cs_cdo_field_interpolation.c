/*============================================================================
 * Routines to handle field interpolation with CDO schemes
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2019 EDF S.A.

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

#include <assert.h>

#if defined(HAVE_MPI)
#include <mpi.h>
#endif

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include <bft_mem.h>

#include "cs_cdovcb_scaleq.h"
#include "cs_equation.h"
#include "cs_equation_priv.h"
#include "cs_timer_stats.h"

/*----------------------------------------------------------------------------
 * Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_cdo_field_interpolation.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Local Macro definitions
 *============================================================================*/

#define CS_CDO_FIELD_INTERPOLATION_DBG   0

/*============================================================================
 * Type definitions
 *============================================================================*/

/*============================================================================
 * Local variables
 *============================================================================*/

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

cs_flag_t       _field_interpolation_flag = 0;
cs_equation_t  *_field_interpolation_eq_cell2vertices = NULL;

/*============================================================================
 * Private variables
 *============================================================================*/

/*! (DOXYGEN_SHOULD_SKIP_THIS) \endcond */

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Interpolate an array defined at vertices from an array defined at
 *         cells
 *
 * \param[in]      cell_values     values at cells
 * \param[in, out] vtx_values      interpolated values at vertices
 */
/*----------------------------------------------------------------------------*/

void
cs_cdo_field_interpolation_activate(cs_flag_t     mode)
{
  _field_interpolation_flag = mode;

  if (mode & CS_CDO_FIELD_INTERPOL_SCALAR_CELL_TO_VERTICES) {

    _field_interpolation_eq_cell2vertices
      = cs_equation_add("Interpolation_Cell2Vertices",
                        "Interpolation_at_vertices",
                        CS_EQUATION_TYPE_PREDEFINED,
                        1,
                        CS_PARAM_BC_HMG_NEUMANN);

    cs_equation_param_t  *eqp
      = cs_equation_get_param(_field_interpolation_eq_cell2vertices);

    cs_equation_set_param(eqp, CS_EQKEY_SPACE_SCHEME, "cdo_vcb");
    cs_equation_set_param(eqp, CS_EQKEY_PRECOND, "amg");
    cs_equation_set_param(eqp, CS_EQKEY_AMG_TYPE, "k_cycle");
    cs_equation_set_param(eqp, CS_EQKEY_ITSOL, "cg");
    cs_equation_set_param(eqp, CS_EQKEY_ITSOL_EPS, "1e-4");


    cs_equation_add_diffusion(eqp, cs_property_by_name("unity"));

  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Interpolate an array defined at vertices from an array defined at
 *         cells
 *
 * \param[in]      mesh            pointer to a mesh structure
 * \param[in]      cell_values     values at cells
 * \param[in, out] vtx_values      interpolated values at vertices
 */
/*----------------------------------------------------------------------------*/

void
cs_cdo_field_interpolation_cell_to_vertices(const cs_mesh_t    *mesh,
                                            const cs_real_t    *cell_values,
                                            cs_real_t          *vtx_values)
{
  if (vtx_values == NULL)
    return; /* Should be allocated */

  if (_field_interpolation_eq_cell2vertices == NULL)
    bft_error(__FILE__, __LINE__, 0,
              " %s: Equation related to the interpolation of cell array to"
              " vertices is not allocated.", __func__);
  cs_equation_t  *eq = _field_interpolation_eq_cell2vertices;

  if (eq->main_ts_id > -1)
    cs_timer_stats_start(eq->main_ts_id);

  /* Allocate, build and solve the algebraic system:
   * The linear solver is called inside and the field value is updated inside
   */
  cs_cdovcb_scaleq_interpolate(mesh,
                               cell_values,
                               eq->field_id,
                               eq->param,
                               eq->builder,
                               eq->scheme_context);

  /* Copy the computed solution into the given array at vertices */
  cs_field_t  *f = cs_field_by_id(eq->field_id);
  memcpy(vtx_values, f->val, mesh->n_vertices*sizeof(cs_real_t));

  if (eq->main_ts_id > -1)
    cs_timer_stats_stop(eq->main_ts_id);
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
