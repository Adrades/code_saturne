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

subroutine lagadh &
!================

 ( ip     , nvar   , nscal  ,                                     &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   itepa  ,                                                       &
   dt     , rtpa   , rtp    , propce , propfa , propfb ,          &
   ettp   , tepa   , adhesion_energ)

!===============================================================================

! Purpose:
! ----------

!   Subroutine of the Lagrangian particle-tracking module:
!   ------------------------------------------------------


!   Calculation of the adhesion force and adhesion energy
!
!
!
!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! ip               ! i  ! <-- ! particle number                                !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! nbpmax           ! e  ! <-- ! nombre max de particulies autorise             !
! nvp              ! e  ! <-- ! nombre de variables particulaires              !
! nvp1             ! e  ! <-- ! nvp sans position, vfluide, vpart              !
! nvep             ! e  ! <-- ! nombre info particulaires (reels)              !
! nivep            ! e  ! <-- ! nombre info particulaires (entiers)            !
! ntersl           ! e  ! <-- ! nbr termes sources de couplage retour          !
! nvlsta           ! e  ! <-- ! nombre de var statistiques lagrangien          !
! nvisbr           ! e  ! <-- ! nombre de statistiques aux frontieres          !
! itepa            ! te ! <-- ! info particulaires (entiers)                   !
! (nbpmax,nivep    !    !     !   (cellule de la particule,...)                !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! ettp             ! tr ! <-- ! tableaux des variables liees                   !
!  (nbpmax,nvp)    !    !     !   aux particules etape courante                !
! tepa             ! tr ! <-- ! info particulaires (reels)                     !
! (nbpmax,nvep)    !    !     !   (poids statistiques,...)                     !
! adhesion_energ   ! r  ! --> ! particle adhesion energy                       !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================


!===============================================================================


!===============================================================================
! Module files
!===============================================================================

use paramx
use cstphy
use cstnum
use lagpar
use lagran
use ppthch
use entsor
use mesh

!===============================================================================

implicit none

! Arguments

integer          ip
integer          nvar   , nscal
integer          nbpmax , nvp    , nvp1   , nvep  , nivep
integer          ntersl , nvlsta , nvisbr
integer          itepa(nbpmax,nivep)

double precision dt(ncelet) , rtp(ncelet,*) , rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*) , propfb(nfabor,*)
double precision ettp(nbpmax,nvp) , tepa(nbpmax,nvep)
double precision adhesion_energ

! Local variables

integer nbasg, nbasp, np, ntmp(1)

double precision step, rpart, rtmp(1)
double precision paramh, nmoyap, nmoyag, scovag, scovap
double precision dismin, distcc, distp
double precision udlvor(2), uvdwsp, uvdwss, uedlsp, uedlss
double precision fadhes

! Variables for the adhesion moment
double precision dismom, rdismom, omsurf,reff,radh,gaus
double precision sig2, xmu

! ==========================================================================
! 0.    initialization
! ==========================================================================

!     step = step used to calculate the adhesion force following
!                         F = U(dcutof+step)-U(dcutof-step)/(2*step)

step = 1.0d-11

scovap = denasp * pi * rayasp**2
scovag = pi * rayasg**2 / espasg**2


! ==========================================================================
! 3.    calculation of the adhesion force
! ==========================================================================


!     determination of the number of contacts with asperities
!     =======================================================

! Number of large-scale asperities

rpart = 0.5d0 * ettp(ip,jdp)

nmoyag = (2.0d0 * rpart + rayasg) / rayasg * scovag

if (nmoyag.gt.600.d0) then
   itepa(ip,jnbasg) = ceiling(nmoyag)
else
   call fische(1, nmoyag, itepa(ip,jnbasg))
endif


if (itepa(ip,jnbasg).gt.1) then

   nmoyag = 1 + 2.0d0 * dcutof*(2.0d0*rpart + 2.0d0 * rayasg+4.0d0*dcutof)       &
        / rayasg**2 * scovag

   if (nmoyag.gt.600.d0) then
      nbasg = ceiling(nmoyag)
   else
     call fische(1, nmoyag, ntmp)
     nbasg = ntmp(1)
   endif

   nbasg = max(1,nbasg)

else
   nbasg = itepa(ip,jnbasg)
endif

! Nb of small-scale asperities : 1st case: no large-scale asperities

if (nbasg.eq.0) then

   nmoyap = (2.0d0 * rpart + rayasp) / rayasp * scovap

   if (nmoyap.gt.600.d0) then
      itepa(ip,jnbasp)   = ceiling(nmoyap)
   else
      call fische(1, nmoyap, itepa(ip,jnbasp))
   endif

   if (itepa(ip,jnbasp).gt.1) then

      nmoyap = 1 + 2.0d0*dcutof*(2.0d0*rpart+2.0d0*rayasp+4.0d0*dcutof)    &
           / rayasp**2 * scovap

      if (nmoyap.gt.600.d0) then
         nbasp = ceiling(nmoyap)
      else
         call fische(1, nmoyap, ntmp)
         nbasp = ntmp(1)
      endif
      nbasp = max(1,nbasp)

   else
      nbasp = itepa(ip,jnbasp)
   endif

   ! Determination of the minimal distance between the particle and the plate
   dismin = rayasp * min(1.0d0,itepa(ip,jnbasp)*1.0d0)

   ! 2nd case: contact with large-scale asperities

else

   paramh = 0.5d0*(2.0d0*rpart+rayasp)*rayasp / (rpart + rayasg)

   nmoyap = paramh*(2*rayasg-paramh) / rayasp**2 * scovap

   if (nmoyap.gt.600.d0) then
      itepa(ip,jnbasp)   = ceiling(nmoyap)
   else
      call fische(1, nmoyap, itepa(ip,jnbasp))
   endif


   if (itepa(ip,jnbasp).gt.1) then

      paramh = 0.5d0*(2.0d0*rpart+2*rayasp+4.0d0*dcutof)*2.0d0*dcutof     &
           / (rpart+rayasg+rayasp+dcutof)

      nmoyap = 1 + paramh*(2*rayasg-paramh) / rayasp**2 * scovap

      if (nmoyap.gt.600.d0) then
         nbasp = ceiling(nmoyap)
      else
         call fische(1, nmoyap, ntmp)
         nbasp = ntmp(1)
      endif
      nbasp = max(1,nbasp)
   else
      nbasp = itepa(ip,jnbasp)
   endif

   ! Mutliple contacts with large scale asperities?

   nbasp = nbasp * nbasg
   itepa(ip,jnbasp) = itepa(ip,jnbasp)*itepa(ip,jnbasg)

   ! Determination of the minimal distance between the particle and the plate
   dismin = rayasp * min(1.0d0,nbasp*1.0d0)                  &
        + rayasg * min(1.0d0,nbasg*1.0d0)

endif ! End of determination of itepa(ip,jnbasp) and itepa(ip,jnbasg)


! Sum of {particle-plane} and {particle-asperity} energies


! Interaction between the sphere and the plate
do np = 1,2
   udlvor(np) = 0.0d0
   distp = dismin + dcutof + step * (3-2*np)

   call vdwsp(distp, rpart, uvdwsp)

   udlvor(np) = uvdwsp
enddo

fadhes = (udlvor(2) - udlvor(1)) / (2.d0 * step)
adhesion_energ = udlvor(1)

! Interaction between the sphere and small-scale asperities

do np = 1,2

   udlvor(np) = 0.0d0
   distcc =  dcutof + step * (3-2*np) + rpart + rayasp

   call vdwsa(distcc, rpart, rayasp, uvdwss)
   udlvor(np) = uvdwss

enddo

fadhes = fadhes + (udlvor(2) - udlvor(1)) / (2.d0 * step)  * nbasp

adhesion_energ = adhesion_energ + udlvor(1)*nbasp

! Interaction between the sphere and large-scale asperities

do np = 1,2
   udlvor(np) = 0.0d0

   if (nbasp.eq.0) then
      distcc =  dcutof + step * (3-2*np) + rpart + rayasg
   elseif (nbasp.gt.0) then
      distcc =  dcutof + rayasp + step * (3-2*np) + rpart + rayasg
   endif

   call vdwsa(distcc, rpart, rayasg, uvdwss)

   udlvor(np) = uvdwss
enddo

fadhes = fadhes + (udlvor(2) - udlvor(1)) / (2.0d0 * step) * nbasg
adhesion_energ = adhesion_energ + udlvor(1) * nbasg

! The force is negative when it is attractive

if (fadhes.ge.0.0d0) then
   tepa(ip,jfadh) = 0.0d0
else
   tepa(ip,jfadh) = - fadhes
endif

! The interaction should be negative to prevent reentrainment (attraction)

if (adhesion_energ.ge.0.0d0) then
   adhesion_energ = 0.0d0
else
   adhesion_energ = abs(adhesion_energ)
endif

!
! Calculation of adhesion torques exerted on the particle

call zufall(1,rtmp)
dismom = rtmp(1)

if (nbasg.gt.0) then
   dismom = dismom * sqrt((2.0d0*rpart+rayasg)*rayasg)
elseif (nbasg.eq.0 .and. nbasp.gt.0) then
   dismom = dismom * sqrt((2.0d0*rpart+rayasp)*rayasp)
else

   !in the sphere-plate case, we use the deformation given by the DMT theory,
   !which is close to our approach

   omsurf = cstham / (24.0d0 * pi * dcutof**2)
   dismom = (12.0d0 * pi * omsurf * (rpart**2)/modyeq)**(1.0d0/3.0d0)

endif

tepa(ip,jmfadh) = tepa(ip,jfadh)*dismom


end subroutine lagadh



! =========================================================================
!     vdw interaction between a sphere and a plane
!     following formulas from Czarnecki (large distances)
!                           and Gregory (small distances)
! =========================================================================

subroutine vdwsp (distp,rpart,var)

use cstnum
use lagran

implicit none

double precision distp, rpart, var


if (distp.lt.lambwl/2/pi) then
   var = -cstham*rpart/(6*distp)*(1/                                &
        (1+14*distp/lambwl+5*pi/4.9d0*distp**3/lambwl/rpart**2))
else
   var = cstham*(2.45/60/pi*lambwl*((distp-rpart)/distp**2          &
            -(distp+3*rpart)/(distp+2*rpart)**2)                  &
            -2.17/720/pi**2*lambwl**2*((distp-2*rpart)            &
            /distp**3 -(distp+4*rpart)/(distp+2*rpart)**3)        &
            +0.59/5040/pi**3*lambwl**3*((distp-3*rpart)/          &
            distp**4 -(distp+5*rpart)/(distp+2*rpart)**4))
endif

end subroutine vdwsp


! =========================================================================
!     Vdw interaction between two spheres
!     following the formula from Gregory (1981a)
! =========================================================================

subroutine vdwsa (distcc,rpart1,rpart2,var)

use cstnum
use lagran

implicit none

double precision distcc, rpart1,rpart2, var

var = - cstham*rpart1*rpart2/(6*(distcc-rpart1-rpart2)              &
           *(rpart1+rpart2))*(1-5.32d0*(distcc-rpart1-rpart2)     &
           /lambwl*log(1+lambwl/(distcc-rpart1-rpart2)/5.32d0))

end subroutine vdwsa



