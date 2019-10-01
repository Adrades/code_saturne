#ifndef __CS_CDO_FIELD_INTERPOLATION_H__
#define __CS_CDO_FIELD_INTERPOLATION_H__

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

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_mesh.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Macro definitions
 *============================================================================*/

#define CS_CDO_FIELD_INTERPOL_SCALAR_CELL_TO_VERTICES    (1 << 0)

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief  Interpolate an array defined at vertices from an array defined at
 *         cells
 *
 * \param[in]     mode      activate which kind of interpolation operation
 */
/*----------------------------------------------------------------------------*/

void
cs_cdo_field_interpolation_activate(cs_flag_t     mode);

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
                                            cs_real_t          *vtx_values);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_CDO_FIELD_INTERPOLATION_H__ */
