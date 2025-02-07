!-------------------------------------------------------------------------------

!VERS

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

!===============================================================================
! Purpose:
! -------

!> \file cs_user_atmospheric_model.f90
!>
!> \brief User subroutines dedicated to the atmospheric model.
!>
!> See \ref cs_user_atmospheric_model for examples.
!-------------------------------------------------------------------------------

!===============================================================================

!> \brief Atmospheric module subroutine

!> User definition of the vertical 1D arrays
!> User initialization of corresponding 1D ground model

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     imode        number of calls of usatdv
!______________________________________________________________________________!

subroutine usatdv &
  ( imode )

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use atincl
use atsoil
use mesh

implicit none

!===============================================================================

! Arguments

integer           imode

! Local variables

integer           ii,iiv
double precision :: zzmax,ztop
double precision, save :: zvmax

!==============================================================================

!< [imode_0]

if (imode.eq.0) then
  write(nfecra,*) 'defining the dimensions of the 1D vertical arrays'
else
  write(nfecra,*) 'defining the coordinates and levels of the 1D vertical arrays'
endif


! 1. Defining the max vertical level:
!====================================
! For the first call (imode = 0) the user should fill the maximum height of the
! 1D model (zvmax), the numbert of 1D verticals and the number of levels
! If the 1D radiative model, the profiles will be extended to 11000m (troposhere)

if (imode.eq.0) then

  nvert = 1
  kvert = 50
  kmx = kvert
  zvmax = 1975.d0 ! for Wangara

  ! If 1D radiative model: complete the vertical array up to 11000
  if (iatra1.gt.0) then
    ztop = 11000.d0
    zzmax = (int(zvmax)/1000)*1000.d0

    do while(zzmax.le.(ztop-1000.d0))
      zzmax = zzmax + 1000.d0
      kmx = kmx + 1
    enddo
  endif

!< [imode_0]

else

!< [imode_1]

  ! 2. Defining the  coordinates and levels of the vertical arrays:
  !===============================================================
  ! for the second call (after allocating the arrays)
  ! the user should fill the arrays

  ! Vertical levels:

  zvert(1) = 0.d0
  zvert(2)  = 5.d0
  zvert(3)  = 20.5d0
  zvert(4)  = 42.0d0
  zvert(5)  = 65.0d0
  zvert(6)  = 89.5d0
  zvert(7)  = 115.0d0
  zvert(8)  = 142.0d0
  zvert(9)  = 170.5d0
  zvert(10) = 199.5d0
  zvert(11) = 230.0d0
  zvert(12) = 262.0d0
  zvert(13) = 294.5d0
  zvert(14) = 328.5d0
  zvert(15) = 363.5d0
  zvert(16) = 399.0d0
  zvert(17) = 435.5d0
  zvert(18) = 473.5d0
  zvert(19) = 512.0d0
  zvert(20) = 551.0d0
  zvert(21) = 591.5d0
  zvert(22) = 632.5d0
  zvert(23) = 674.0d0
  zvert(24) = 716.0d0
  zvert(25) = 759.0d0
  zvert(26) = 802.5d0
  zvert(27) = 846.5d0
  zvert(28) = 891.5d0
  zvert(29) = 936.5d0
  zvert(30) = 982.0d0
  zvert(31) = 1028.0d0
  zvert(32) = 1074.5d0
  zvert(33) = 1122.0d0
  zvert(34) = 1169.5d0
  zvert(35) = 1217.0d0
  zvert(36) = 1265.5d0
  zvert(37) = 1314.5d0
  zvert(38) = 1363.5d0
  zvert(39) = 1413.0d0
  zvert(40) = 1462.5d0
  zvert(41) = 1512.5d0
  zvert(42) = 1563.0d0
  zvert(43) = 1613.5d0
  zvert(44) = 1664.5d0
  zvert(45) = 1715.5d0
  zvert(46) = 1767.0d0
  zvert(47) = 1818.5d0
  zvert(48) = 1870.0d0
  zvert(49) = 1922.5d0
  zvert(50) = 1975.0d0

  ! If 1D radiative model: complete the vertical array up to 11000 m
  if (iatra1.gt.0) then
    ztop = 11000.d0
    ii = kvert
    zzmax = (int(zvert(ii))/1000)*1000.d0

    do while(zzmax.le.(ztop-1000.d0))
      zzmax = zzmax+1000.d0
      ii = ii + 1
      zvert(ii) = zzmax
    enddo

  endif

  ! 3 - Initializing the position of each vertical
  !==============================================

  do iiv = 1, nvert

    ! xy coordinates of vertical iiv:
    xyvert(iiv,1) = 50.d0  !x coordinate
    xyvert(iiv,2) = 50.d0  !y coordinate
    xyvert(iiv,3) = 1.d0   !kmin (in case of relief)

    ! 4 - Initializing the soil table of each vertical grid
    !=====================================================

    soilvert(iiv)%albedo  = 0.25d0
    soilvert(iiv)%emissi  = 0.965d0
    soilvert(iiv)%ttsoil  = 14.77d0
    soilvert(iiv)%totwat  = 0.0043d0
    soilvert(iiv)%pressure = 1023.d0
    soilvert(iiv)%density = 1.23d0
    soilvert(iiv)%foir = 0.d0
    soilvert(iiv)%fos  = 0.d0

  enddo
endif

!< [imode_1]

return
end subroutine usatdv

!===============================================================================

!> \brief Fill in vertical profiles of atmospheric properties prior to solve
!> 1D radiative transfers. Altitudes (\ref zvert array) are defined in
!> \ref usatd.

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in,out] preray        pressure vertical profile
!> \param[in,out] temray        real temperature vertical profile
!> \param[in,out] romray        density vertical profile
!> \param[in,out] qvray         water vapor content vertical profile
!> \param[in,out] qlray         water liquid content vertical profile
!> \param[in,out] ncray         droplets density vertical profile
!> \param[in,out] aeroso        aerosol concentration vertical profile
!______________________________________________________________________________!

subroutine cs_user_atmo_1d_rad_prf &
     ( preray, temray, romray, qvray, qlray, ncray, aeroso )

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use atincl
use atsoil
use mesh

!===============================================================================

implicit none

! Arguments

double precision preray(kmx), temray(kmx), romray(kmx), qvray(kmx)
double precision qlray(kmx), ncray(kmx), aeroso(kmx)

! Local variables

integer k
double precision tmean, rhum, rap

!===============================================================================

!< [humid_aerosols_atmo]

aeroso(1) = 10.d0

do k = 2, kvert
  zray(k) = zvert(k)

  tmean = 0.5d0 * (temray(k-1) + temray(k)) + tkelvi
  rhum = rair * (1.d0 + (rvsra-1.d0)*qvray(k))
  rap = -abs(gz) * (zray(k)-zray(k-1)) / rhum / tmean
  preray(k) = preray(k-1) * exp(rap)

  ! analytical profile of aerosol concentration
  if (zray(k).lt.50.d0) then
    aeroso(k) = aeroso(1)
  else
    aeroso(k) = aeroso(1)*exp(-(zray(k)-50.d0) / 1.25d3)
    if (aeroso(k).lt.5.d0) then
      aeroso(k) = 5.d0
    endif
  endif
enddo

! Filling the additional levels above meshed domain
! (at these levels, pressure, temperature, density profiles have been
! initialized with standard atmosphere profiles)

do k = kvert+1, kmx
  zray(k) = zvert(k)

  ! read meteo data for temperature, water wapor and liquid content in
  ! upper layers for example to fill temray, qvray, qlray

  tmean = 0.5d0*(temray(k-1)+temray(k)) + tkelvi
  rhum = rair*(1.d0+(rvsra-1.d0)*qvray(k))
  rap = -abs(gz)*(zray(k)-zray(k-1)) / rhum / tmean
  preray(k) = preray(k-1)*exp(rap)
  romray(k) = preray(k) / (temray(k)+tkelvi) / rhum

  ! nc not known above the meshed domain
  ! droplets radius is assumed of mean volume radius = 5 microns
  ncray(k) = 1.d-6*(3.d0*romray(k)*qlray(k))                               &
                  /(4.d0*pi*1.d3*(5.d-6)**3.d0)

  ! similarly, aerosol concentration not known
  aeroso(k) = aeroso(1)*exp(-(zray(k)-50.d0) / 1.25d3)
  if (aeroso(k).lt.5.d0) then
    aeroso(k) = 5.d0
  endif
enddo

!< [humid_aerosols_atmo]

return
end subroutine cs_user_atmo_1d_rad_prf

!===============================================================================

!> \brief Overwrite soil variables.

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]
!______________________________________________________________________________!

subroutine cs_user_atmo_soil &
     (temp , qv ,rom , dt, rcodcl)

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use ppppar
use ppthch
use ppincl
use atincl
use atsoil
use mesh
use field

!===============================================================================

implicit none

! Arguments

double precision rcodcl(nfabor,nvar,3)

double precision temp(ncelet)
double precision qv(ncelet)
double precision rom(ncelet),dt(ncelet)

! Local variables

integer ifac, isol

double precision tetas, qvs

integer, dimension(:), pointer :: elt_ids

double precision, pointer, dimension(:)   :: bvar_temp_sol
double precision, pointer, dimension(:)   :: bvar_tempp
double precision, pointer, dimension(:)   :: bvar_total_water

!===============================================================================

!< [atmo_soil_temperature]
call field_get_val_s_by_name("soil_temperature", bvar_temp_sol)
call field_get_val_s_by_name("soil_pot_temperature", bvar_tempp)
call field_get_val_s_by_name("soil_total_water", bvar_total_water)

call atmo_get_soil_zone(nfmodsol, nbrsol, elt_ids)

do isol = 1, nfmodsol
  ifac = elt_ids(isol) + 1 ! C > Fortran

  ! read external data to set potential temperature and specific humidity
  tetas = 16.504682364d0
  qvs = 0.00583966915d0

  bvar_temp_sol   (isol) = tetas - tkelvi
  bvar_tempp      (isol) = tetas
  bvar_total_water(isol) = qvs
enddo

!< [atmo_soil_temperature]

return
end subroutine cs_user_atmo_soil
