!-------------------------------------------------------------------------------

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2013 EDF S.A.
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

subroutine lagbar &
!================

 ( rtp , energt )

!=================================================================
!===============================================================================
! Purpose:
! -------
!
!
!    Subroutine of the Lagrangian particle-tracking module
!    Calculation of the energy barrier for DLVO deposition conditions
!
!
!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________
! rtp        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)    !     !     !  (at current time step)
!energt
!  (nfabor)  ! tr ! --> ! energy barrier at boundary faces
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use mesh
use lagran
use lagpar
use ppthch
use optcal
use numvar
use cstphy
use cstnum

!===============================================================================

implicit none

! Arguments

double precision  energt(nfabor)
double precision  rtp (ncelet,*)

! Local variables

double precision ldebye, tempf, barr
double precision aux1  , aux2 , bg , bd , fc , fg , cc
integer          cpt
integer          ncmax
integer          ifac , iel , mode
parameter (ncmax=2000)

!===============================================================================

! Calculation of the criterion

! Determination of the temperature

do ifac = 1,nfabor
   iel = ifabor(ifac)
   if (iscalt.gt.0) then
      if (iscsth(iscalt).eq.-1) then
         tempf = rtp(iel,isca(iscalt)) + tkelvi
      else if (iscsth(iscalt).eq. 1) then
         tempf = rtp(iel,isca(iscalt))
      else if (iscsth(iscalt).eq.2) then
         mode = 1
         call usthht(mode,rtp(iel,isca(iscalt)),tempf)
      endif
   else
      tempf = t0
   endif


   !Calculation of the Debye length

   ldebye = ((2.d3 * cstfar**2 * fion) / (epseau * epsvid * rr * tempf))**(-0.5d0)


   !Height of the energy barrier

   aux1 = ldebye * exp(-1.d0) * phi1 * phi2
   aux2 = cstham / (6.d0 * epsvid * epseau * 4.d0 * pi)

   if (aux1.lt.aux2)  then
      barr = 0.d1
   else
      !Research for the maximum by dichotomy
      bg = 1.d-30
      bd = 2 * ldebye

      do cpt = 1,ncmax

         cc = (bg + bd) * 0.5d0

         fg =  cstham / (6.d0 * bg **2) - epsvid * epseau * 4.d0 &
              * pi * phi1 * phi2 * exp(-bg / ldebye) / ldebye

         fc =  cstham / (6.d0 * cc **2) -epsvid * epseau * 4.d0 &
              * pi * phi1 * phi2 * exp(-cc / ldebye) / ldebye

         if (fg * fc.lt.0d1) then
            bd = cc
         else
            bg = cc
         endif

      enddo

      barr =  -cstham / (6.d0 * cc) + epsvid * epseau * 4.d0 &
           * pi * phi1 * phi2 * exp(-cc / ldebye)

   endif
   energt (ifac) = barr


enddo

return
end subroutine lagbar
