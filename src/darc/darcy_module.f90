!-------------------------------------------------------------------------------

! This file is part of code_saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2022 EDF S.A.
!
! This program is free software; you can redistribute it and/or modify it under
! the terms of the GNU General Public License as published by the Free Software
! Foundation; either version 2 of the License, or (at your option) any later
! version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
! FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
! details.
!
! You should have received a copy of the GNU General Public License along with
! this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
! Street, Fifth Floor, Boston, MA 02110-1301, USA.

!-------------------------------------------------------------------------------

!> \file darcy_module.f90
!> \brief Module for Darcy calculation options

module darcy_module

  !=============================================================================

  use, intrinsic :: iso_c_binding

  use paramx

  implicit none

  !=============================================================================

  !> \defgroup darcy_module Module for variable numbering

  !> \addtogroup darcy_module
  !> \{

  !-----------------------------------------------------------------------------
  ! Darcy module variables
  !-----------------------------------------------------------------------------

  !> \anchor darcy_anisotropic_permeability
  !> Set permeability to isotropic (0) or anisotropic (1) for all soils
  integer :: darcy_anisotropic_permeability

  !> \anchor darcy_anisotropic_dispersion
  !> Set dispersion to isotropic (0) or anisotropic (1) for all solutes
  integer :: darcy_anisotropic_dispersion

  !> \anchor darcy_unsteady
  !> Set if the transport part is based on a steady (0) or unsteady (1)
  !> flow field
  integer :: darcy_unsteady

  !> \anchor darcy_convergence_criterion
  !> Set convergence criteron of the Newton scheme
  !> - 0: over pressure (recommanded)
  !> - 1: over velocity
  integer :: darcy_convergence_criterion

  !> \anchor darcy_unsaturated
  !> Take into account unsaturated zone (1) or not (0).
  integer :: darcy_unsaturated

  !> \}

end module darcy_module
