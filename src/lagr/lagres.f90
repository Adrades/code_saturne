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

subroutine lagres &
!================

 ( nvar   , nscal  ,                                              &
   nbpmax , nvp    , nvp1   , nvep   , nivep  ,                   &
   ntersl , nvlsta , nvisbr ,                                     &
   itepa  ,                                                       &
   dt     , rtpa   , rtp    , propce , propfa , propfb ,          &
   ettp   , tepa   )

!===============================================================================

! Purpose:
! ----------

!   Subroutine of the Lagrangian particle-tracking module:
!   ------------------------------------------------------


!   Calculation of the particle resuspension
!
!
!
!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
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

integer          nvar   , nscal
integer          nbpmax , nvp    , nvp1   , nvep  , nivep
integer          ntersl , nvlsta , nvisbr
integer          itepa(nbpmax,nivep)

double precision dt(ncelet) , rtp(ncelet,*) , rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*) , propfb(nfabor,*)
double precision ettp(nbpmax,nvp) , tepa(nbpmax,nvep)

! Local variables

integer ip, ii, ndiam, test_colli
double precision kinetic_energy
double precision  adhesion_energ
double precision norm_velocity, norm_face

! ==========================================================================
! 0.    initialization
! ==========================================================================


do ip = 1, nbpart

   test_colli = 0

   if (itepa(ip,jdepo).eq.1) then

      ! The particle has just deposited
      ! The adhesion force is calculated

      call lagadh                                                     &
           ( ip   , nvar   , nscal  ,                                 &
           nbpmax , nvp    , nvp1   , nvep   , nivep  ,               &
           ntersl , nvlsta , nvisbr ,                                 &
           itepa  ,                                                   &
           dt     , rtpa   , rtp    , propce , propfa , propfb ,      &
           ettp   , tepa   , adhesion_energ)

   elseif (itepa(ip,jdepo).eq.2) then

      ! The particle is rolling
      ! if the number of great asperities
      ! is null it is marked for a possible collision

      if (itepa(ip,jnbasg).eq.0) then
         test_colli = 1
      endif

      if (tepa(ip,jndisp).gt.ettp(ip,jdp).and. &
           tepa(ip,jndisp).lt. 2.d0 * ettp(ip,jdp)) then

         ! If the particle has a displacement approximately
         ! equal to a diameter, recalculation of the adhesion force

         call lagadh                                                     &
              ( ip   , nvar   , nscal  ,                                 &
              nbpmax , nvp    , nvp1   , nvep   , nivep  ,               &
              ntersl , nvlsta , nvisbr ,                                 &
              itepa  ,                                                   &
              dt     , rtpa   , rtp    , propce , propfa , propfb ,      &
              ettp   , tepa   , adhesion_energ)

            if ((test_colli.eq.1) .and. (itepa(ip,jnbasg).gt.0)) then

               kinetic_energy = 0.5d0 * ettp(ip,jmp) * (ettp(ip,jup)**2      &
                                                  +    ettp(ip,jvp)**2       &
                                                  +    ettp(ip,jwp)**2)

               if (kinetic_energy.gt.adhesion_energ) then

                  ! The particle is resuspended
                  ! and its kinetic energy is totally converted
                  ! along the wall-normal distance

                  itepa(ip,jdepo) = 0

                  tepa(ip,jfadh) = 0.d0
                  tepa(ip,jmfadh) = 0.d0

                  itepa(ip,jnbasg) = 0
                  itepa(ip,jnbasp) = 0

                  tepa(ip,jndisp) = 0.d0

                  norm_face = surfbn(itepa(ip,jdfac))

                  norm_velocity = sqrt(ettp(ip,jup)**2 + ettp(ip,jvp)**2 + ettp(ip,jwp)**2)

                  ettp(ip,jup) = - norm_velocity / norm_face * surfbo(1, itepa(ip,jdfac))
                  ettp(ip,jvp) = - norm_velocity / norm_face * surfbo(2, itepa(ip,jdfac))
                  ettp(ip,jwp) = - norm_velocity / norm_face * surfbo(3, itepa(ip,jdfac))

               endif

            endif

      elseif (tepa(ip,jndisp).ge. 2d0 * ettp(ip,jdp)) then

         ndiam = floor(tepa(ip,jndisp) / ettp(ip,jdp))

         ii = 1

         do while ((ii.le.ndiam).and.(itepa(ip,jdepo).ne.0))

            call lagadh                                                     &
                 ( ip   , nvar   , nscal  ,                                 &
                 nbpmax , nvp    , nvp1   , nvep   , nivep  ,               &
                 ntersl , nvlsta , nvisbr ,                                 &
                 itepa  ,                                                   &
                 dt     , rtpa   , rtp    , propce , propfa , propfb ,      &
                 ettp   , tepa   , adhesion_energ)

            if ((test_colli.eq.1) .and. (itepa(ip,jnbasg).gt.0)) then

               kinetic_energy = 0.5d0 * ettp(ip,jmp) * (ettp(ip,jup)**2      &
                                                  +    ettp(ip,jvp)**2       &
                                                  +    ettp(ip,jwp)**2)


              if (kinetic_energy.gt.adhesion_energ) then

                  ! The particle is resuspended
                  ! and its kinetic energy is totally converted
                  ! along the wall-normal distance

                  itepa(ip,jdepo) = 0

                  tepa(ip,jfadh) = 0.d0
                  tepa(ip,jmfadh) = 0.d0

                  itepa(ip,jnbasg) = 0
                  itepa(ip,jnbasp) = 0

                  tepa(ip,jndisp) = 0.d0

                  norm_face = surfbn(itepa(ip,jdfac))

                  norm_velocity = sqrt(ettp(ip,jup)**2 + ettp(ip,jvp)**2 + ettp(ip,jwp)**2)

                  ettp(ip,jup) = - norm_velocity / norm_face * surfbo(1, itepa(ip,jdfac))
                  ettp(ip,jvp) = - norm_velocity / norm_face * surfbo(2, itepa(ip,jdfac))
                  ettp(ip,jwp) = - norm_velocity / norm_face * surfbo(3, itepa(ip,jdfac))


               endif

            endif ! if test_colli

            ii = ii + 1

         enddo ! do while ..

      endif ! if tepa(ip,jndisp)


   endif  ! if jdepo = ...

enddo

end subroutine lagres
