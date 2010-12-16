!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2009 EDF S.A., France

!     contact: saturne-support@edf.fr

!     The Code_Saturne Kernel is free software; you can redistribute it
!     and/or modify it under the terms of the GNU General Public License
!     as published by the Free Software Foundation; either version 2 of
!     the License, or (at your option) any later version.

!     The Code_Saturne Kernel is distributed in the hope that it will be
!     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
!     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!     GNU General Public License for more details.

!     You should have received a copy of the GNU General Public License
!     along with the Code_Saturne Kernel; if not, write to the
!     Free Software Foundation, Inc.,
!     51 Franklin St, Fifth Floor,
!     Boston, MA  02110-1301  USA

!-------------------------------------------------------------------------------

subroutine cfphyv &
!================

 ( idbia0 , idbra0 ,                                              &
   nvar   , nscal  , nphas  ,                                     &
   nphmx  ,                                                       &
   ibrom  , izfppp ,                                              &
   ia     ,                                                       &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  ,                                              &
   w1     , w2     , w3     ,                                     &
   ra     )

!===============================================================================
! FONCTION :
! --------

! ROUTINE PHYSIQUE PARTICULIERE : COMPRESSIBLE SANS CHOC

! Calcul des proprietes physiques variables


! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! nphas            ! i  ! <-- ! number of phases                               !
! nphmx            ! e  ! <-- ! nphsmx                                         !
! ibrom            ! te ! <-- ! indicateur de remplissage de romb              !
!   (nphmx   )     !    !     !                                                !
! izfppp           ! te ! --> ! numero de zone de la face de bord              !
! (nfabor)         !    !     !  pour le module phys. part.                    !
! ia(*)            ! ia ! --- ! main integer work array                        !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! w1...3(ncelet    ! tr ! --- ! tableau de travail                             !
! ra(*)            ! ra ! --- ! main real work array                           !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use cstphy
use cstnum
use entsor
use ppppar
use ppthch
use ppincl
use mesh

!===============================================================================

implicit none

! Arguments

integer          idbia0 , idbra0
integer          nvar   , nscal  , nphas
integer          nphmx

integer          ibrom(nphmx)
integer          izfppp(nfabor)
integer          ia(*)

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision w1(ncelet), w2(ncelet), w3(ncelet)
double precision ra(*)

! Local variables

integer          idebia, idebra, ifinia
integer          iphas , iel
integer          ifac
integer          iirom , iiromb
integer          maxelt, ils

integer          ipass
data             ipass /0/
save             ipass

!===============================================================================
!===============================================================================
! 1. INITIALISATIONS A CONSERVER
!===============================================================================

! --- Initialisation memoire

idebia = idbia0
idebra = idbra0


!===============================================================================
! 2. ON DONNE LA MAIN A L'UTILISATEUR
!===============================================================================

maxelt = max(ncelet, nfac, nfabor)
ils    = idebia
ifinia = ils + maxelt
call iasize('cfphyv',ifinia)

iuscfp = 1
call uscfpv                                                       &
!==========
 ( ifinia , idebra ,                                              &
   nvar   , nscal  , nphas  ,                                     &
   nphmx  ,                                                       &
   maxelt , ia(ils),                                              &
   ia     ,                                                       &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  ,                                              &
   w1     , w2     , w3     ,                                     &
   ra     )

!     Si IUSCFP = 0, l'utilisateur n'a pas inclus le ss pgm uscfpv dans
!       ses sources. C'est une erreur si Cp, Cv ou Lambda est variable.
!     On se contente de faire le test au premier passage.
if(ipass.eq.0) then
  ipass = ipass + 1
  do iphas = 1, nphas
    if((ivisls(itempk(iphas)).gt.0.or.                            &
        icp(iphas).gt.0.or.icv(iphas).gt.0).and.iuscfp.eq.0) then
      write(nfecra,1000)                                          &
           ivisls(itempk(iphas)),icp(iphas),icv(iphas)
      call csexit (1)
      !==========
    endif
  enddo
endif

!===============================================================================
! 3. MISE A JOUR DE LAMBDA/CV
!===============================================================================

! On a v�rifi� auparavant que CV0 �tait non nul.
! Si CV variable est nul, c'est une erreur utilisateur. On fait
!     un test � tous les passages (pas optimal), sachant que pour
!     le moment, on est en gaz parfait avec CV constant : si quelqu'un
!     essaye du CV variable, ce serait dommage que cela lui explose � la
!     figure pour de mauvaises raisons.
! Si IVISLS(IENERG(IPHAS)).EQ.0, on a forcement IVISLS(ITEMPK(IPHAS)).EQ.0
!     et ICV(IPHAS).EQ.0, par construction de IVISLS(IENERG(IPHAS)) dans
!     le sous-programme cfvarp

do iphas = 1, nphas

  if(ivisls(ienerg(iphas)).gt.0) then

    if(ivisls(itempk(iphas)).gt.0) then

      do iel = 1, ncel
        propce(iel,ipproc(ivisls(ienerg(iphas)))) =               &
             propce(iel,ipproc(ivisls(itempk(iphas))))
      enddo

    else
      do iel = 1, ncel
        propce(iel,ipproc(ivisls(ienerg(iphas)))) =               &
             visls0(itempk(iphas))
      enddo

    endif

    if(icv(iphas).gt.0) then

      do iel = 1, ncel
        if(propce(iel,ipproc(icv(iphas))).le.0.d0) then
          write(nfecra,2000)iel,propce(iel,ipproc(icv(iphas)))
          call csexit (1)
          !==========
        endif
      enddo

      do iel = 1, ncel
        propce(iel,ipproc(ivisls(ienerg(iphas)))) =               &
             propce(iel,ipproc(ivisls(ienerg(iphas))))            &
             / propce(iel,ipproc(icv(iphas)))
      enddo

    else

      do iel = 1, ncel
        propce(iel,ipproc(ivisls(ienerg(iphas)))) =               &
             propce(iel,ipproc(ivisls(ienerg(iphas))))            &
             / cv0(iphas)
      enddo

    endif

  else

    visls0(ienerg(iphas)) = visls0(itempk(iphas))/cv0(iphas)

  endif


enddo


!===============================================================================
! 3. MISE A JOUR DE ROM et ROMB :
!     On ne s'en sert a priori pas, mais la variable existe
!     On a ici des valeurs issues du pas de temps pr�c�dent (y compris
!       pour les conditions aux limites) ou issues de valeurs initiales
!     L'�change p�rio/parall sera fait dans phyvar.
!===============================================================================

do iphas = 1, nphas

  iirom  = ipproc(irom  (iphas))
  iiromb = ipprob(irom  (iphas))

  do iel = 1, ncel
    propce(iel,iirom)  = rtpa(iel,isca(irho(iphas)))
  enddo

  do ifac = 1, nfabor
    iel = ifabor(ifac)
    propfb(ifac,iiromb) =                                         &
         coefa(ifac,iclrtp(isca(irho(iphas)),icoef))              &
         + coefb(ifac,iclrtp(isca(irho(iphas)),icoef))            &
         * rtpa(iel,isca(irho(iphas)))
  enddo

enddo


!--------
! FORMATS
!--------

 1000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION (MODULE COMPRESSIBLE)  ',/,&
'@    =========                                               ',/,&
'@                                                            ',/,&
'@  Une ou plusieurs des propri�t�s suivantes a �t� d�clar�e  ',/,&
'@    variable (rep�r�e ci-dessous par un indicateur non nul) ',/,&
'@    et une loi doit �tre fournie dans uscfpv.               ',/,&
'@         propri�t�                               indicateur ',/,&
'@     - conductivit� thermique                    ',I10       ,/,&
'@     - capacit� calorifique � pression constante ',I10       ,/,&
'@     - capacit� calorifique � volume constant    ',I10       ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Renseigner uscfpv ou d�clarer les propri�t�s constantes et',/,&
'@    uniformes (uscfx2 pour la conductivit� thermique,       ',/,&
'@    uscfth pour les capacit�s calorifiques).                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 2000 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''EXECUTION (MODULE COMPRESSIBLE)  ',/,&
'@    =========                                               ',/,&
'@                                                            ',/,&
'@  La capacit� calorifique � volume constant pr�sente (au    ',/,&
'@    moins) une valeur n�gative ou nulle :                   ',/,&
'@    cellule ',I10,   '  Cv = ',E18.9                         ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier uscfpv.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)


!----
! FIN
!----

return
end subroutine
