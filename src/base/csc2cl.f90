!-------------------------------------------------------------------------------

!     This file is part of the Code_Saturne Kernel, element of the
!     Code_Saturne CFD tool.

!     Copyright (C) 1998-2010 EDF S.A., France

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

subroutine csc2cl &
!================

 ( idbia0 , idbra0 ,                                              &
   nvar   , nscal  , nphas  ,                                     &
   nvcp   , nvcpto , nfbcpl , nfbncp ,                            &
   icodcl , itrifb , itypfb ,                                     &
   lfbcpl , lfbncp ,                                              &
   ia     ,                                                       &
   dt     , rtp    , rtpa   , propce , propfa , propfb ,          &
   coefa  , coefb  , rcodcl ,                                     &
   w1     , w2     , w3     , w4     , w5     , w6     , coefu  , &
   rvcpfb , pndcpl , dofcpl ,                                     &
   ra     )

!===============================================================================
! FONCTION :
! --------

!         TRADUCTION DE LA CONDITION ITYPFB(*,*) = ICSCPL

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! idbia0           ! i  ! <-- ! number of first free position in ia            !
! idbra0           ! i  ! <-- ! number of first free position in ra            !
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! nphas            ! i  ! <-- ! number of phases                               !
! icodcl           ! te ! --> ! code de condition limites aux faces            !
!  (nfabor,nvar    !    !     !  de bord                                       !
!                  !    !     ! = 1   -> dirichlet                             !
!                  !    !     ! = 3   -> densite de flux                       !
!                  !    !     ! = 4   -> glissemt et u.n=0 (vitesse)           !
!                  !    !     ! = 5   -> frottemt et u.n=0 (vitesse)           !
!                  !    !     ! = 9   -> entree/sortie libre (vitesse          !
!                  !    !     !  entrante eventuelle     bloquee               !
!                  !    !     ! = 10  -> entree/sortie libre (vitesse          !
!                  !    !     !  entrante eventuelle non bloquee :             !
!                  !    !     !  prescrire une valeur de dirichlet en          !
!                  !    !     !  prevision pour les scalaires k, eps,          !
!                  !    !     !  scal en plus du neumann usuel                 !
! itrifb           ! ia ! <-- ! indirection for boundary faces ordering        !
!  (nfabor, nphas) !    !     !                                                !
! itypfb           ! ia ! --> ! boundary face types                            !
!  (nfabor, nphas) !    !     !                                                !
! ia(*)            ! ia ! --- ! main integer work array                        !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfa(nfac, *)  ! ra ! <-- ! physical properties at interior face centers   !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! rcodcl           ! tr ! --> ! valeur des conditions aux limites              !
!  (nfabor,nvar    !    !     !  aux faces de bord                             !
!                  !    !     ! rcodcl(1) = valeur du dirichlet                !
!                  !    !     ! rcodcl(2) = valeur du coef. d'echange          !
!                  !    !     !  ext. (infinie si pas d'echange)               !
!                  !    !     ! rcodcl(3) = valeur de la densite de            !
!                  !    !     !  flux (negatif si gain) w/m2                   !
!                  !    !     ! pour les vitesses (vistl+visct)*gradu          !
!                  !    !     ! pour la pression             dt*gradp          !
!                  !    !     ! pour les scalaires                             !
!                  !    !     !        cp*(viscls+visct/sigmas)*gradt          !
! w1,2,3,4,5,6     ! ra ! --- ! work arrays                                    !
!  (ncelet)        !    !     !  (computation of pressure gradient)            !
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
use pointe
use numvar
use optcal
use cstphy
use cstnum
use entsor
use parall
use period
use cplsat
use mesh

!===============================================================================

implicit none

! Arguments

integer          idbia0 , idbra0
integer          nvar   , nscal  , nphas
integer          nvcp   , nvcpto
integer          nfbcpl , nfbncp

integer          icodcl(nfabor,nvar)
integer          lfbcpl(nfbcpl)  , lfbncp(nfbncp)
integer          itrifb(nfabor,nphas), itypfb(nfabor,nphas)
integer          ia(*)

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision rcodcl(nfabor,nvar,3)
double precision w1(ncelet),w2(ncelet),w3(ncelet)
double precision w4(ncelet),w5(ncelet),w6(ncelet)
double precision coefu(nfabor,ndim)
double precision rvcpfb(nfbcpl,nvcpto), pndcpl(nfbcpl)
double precision dofcpl(3,nfbcpl)
double precision ra(*)

! Local variables


integer          idebia, idebra
integer          ifac, iel,isou, iphas
integer          inc, iccocg, iphydp, iclvar, nswrgp, imligp
integer          iwarnp, ivar
integer          ipt
integer          iii

double precision epsrgp, climgp, extrap
double precision xp
double precision xip   , xiip  , yiip  , ziip
double precision xjp
double precision xipf, yipf, zipf, ipf

double precision xif, yif, zif, xopf, yopf, zopf
double precision gradi, pondj, flumab

!===============================================================================


idebia = idbia0
idebra = idbra0


!===============================================================================
! 1.  TRADUCTION DU COUPLAGE EN TERMES DE CONDITIONS AUX LIMITES
!===============================================================================

! On rappelle que les variables sont re�ues dans l'ordre de VARPOS ;
! il suffit dont de boucler sur les variables.

do ivar = 1, nvcp

!   --- Calcul du gradient de la variable si celle-ci est interpol�e
!         Les �changes pour le parall�lisme et la p�riodicit�
!         ont d�j� �t� fait dans CSCPFB. Inutile de les refaire.

  inc    = 1
  iccocg = 1
  iphydp = 0

  iclvar = iclrtp(ivar,icoef)
  nswrgp = nswrgr(ivar)
  imligp = imligr(ivar)
  iwarnp = iwarni(ivar)
  epsrgp = epsrgr(ivar)
  climgp = climgr(ivar)
  extrap = extrag(ivar)

  call grdcel                                                     &
  !==========
 ( idebia , idebra ,                                              &
   nphas  ,                                                       &
   ivar   , imrgra , inc    , iccocg , nswrgp , imligp , iphydp,  &
   iwarnp , nfecra ,                                              &
   epsrgp , climgp , extrap ,                                     &
   ia     ,                                                       &
   w4     , w4     , w4     ,                                     &
   rtp(1,ivar) , coefa(1,iclvar) , coefb(1,iclvar) ,              &
   w1     , w2     , w3     ,                                     &
!        ------   ------   ------
   w4     , w5     , w6     ,                                     &
   ra     )


  ! For a specific face to face coupling, geometric assumptions are made

  if (ifaccp.eq.1) then


    do ipt = 1, nfbcpl

      ifac = lfbcpl(ipt)
      iel  = ifabor(ifac)

!         Information de l'instance en cours interpol�e en I'
      iii = idiipb-1+3*(ifac-1)
      xiip = ra(iii+1)
      yiip = ra(iii+2)
      ziip = ra(iii+3)

      xif = cdgfbo(1,ifac) -xyzcen(1,iel)
      yif = cdgfbo(2,ifac) -xyzcen(2,iel)
      zif = cdgfbo(3,ifac) -xyzcen(3,iel)

      xipf = cdgfbo(1,ifac)-xiip - xyzcen(1,iel)
      yipf = cdgfbo(2,ifac)-yiip - xyzcen(2,iel)
      zipf = cdgfbo(3,ifac)-ziip - xyzcen(3,iel)

      ipf = sqrt(xipf**2+yipf**2+zipf**2)


      iii = idiipb-1+3*(ifac-1)
      xiip = ra(iii+1)
      yiip = ra(iii+2)
      ziip = ra(iii+3)

      xopf = dofcpl(1,ipt)
      yopf = dofcpl(2,ipt)
      zopf = dofcpl(3,ipt)

      if (ivar.eq.ipr(1)) then

! --- On veut imposer un dirichlet de pression de mani�re � conserver
!     le gradient de pression � la travers�e du couplage et �tre consistant
!     avec la r�solution du gradient de pression sur maillage orthogonal

        xip = rtp(iel,ivar) + (w1(iel)*xiip + w2(iel)*yiip + w3(iel)*ziip)

      else if (ivar.eq.iu(1).or.ivar.eq.iv(1).or.ivar.eq.iw(1)) then

! --- Pour toutes les autres variables, on veut imposer un dirichlet
!     en accord avec les flux convectifs au centre. On se laisse le choix
!     entre UPWIND, SOLU et CENTRE. Seul le centr� respecte la diffusion
!     des faces internes du somaine. Pour l'UPWIND et le SOLU, le d�centrement
!     est r�alis� ici et plus dans bilsc2.F pour les faces coupl�es.

! -- UPWIND

!        xip =  rtp(iel,ivar)

! -- SOLU

!        xip =  rtp(iel,ivar) + (w1(iel)*xif + w2(iel)*yif + w3(iel)*zif)

! -- CENTRE

        xip =  rtp(iel,ivar) + w1(iel)*xiip + w2(iel)*yiip + w3(iel)*ziip

      else

! -- UPWIND

!        xip =  rtp(iel,ivar)

! -- SOLU

!        xip =  rtp(iel,ivar) + (w1(iel)*xif + w2(iel)*yif + w3(iel)*zif)

! -- CENTRE

        xip =  rtp(iel,ivar) + (w1(iel)*xiip + w2(iel)*yiip + w3(iel)*ziip)

      endif

! -- on a besoin de alpha_ij pour interpolation centr�e et du flumab
!    pour le d�centrement

      pondj = pndcpl(ipt)
      flumab = propfb(ifac,ipprob(ifluma(iu(1))))

!         Informations recues de l'instance distante en J'/O'
      xjp = rvcpfb(ipt,ivar)


      do iphas = 1, nphas
        itypfb(ifac,iphas)  = icscpl
      enddo

      if (ivar.eq.ipr(1)) then

        icodcl(ifac,ivar  ) = 1
        rcodcl(ifac,ivar,1) = (1.d0-pondj)*xjp + pondj*xip + p0(1)

      else if (ivar.eq.iu(1).or.ivar.eq.iv(1).or.ivar.eq.iw(1)) then

        icodcl(ifac,ivar  ) = 1

! -- DECENTRE (SOLU ou UPWIND)

!        if (flumab.ge.0.d0) then
!          rcodcl(ifac,ivar,1) = xip
!        else
!          rcodcl(ifac,ivar,1) = xjp
!        endif

! -- CENTRE

        rcodcl(ifac,ivar,1) = (1.d0-pondj)*xjp + pondj*xip

      else

        icodcl(ifac,ivar  ) = 1

! -- DECENTRE (SOLU ou UPWIND)

!        if(flumab.ge.0.d0) then
!          rcodcl(ifac,ivar,1) = xip
!        else
!          rcodcl(ifac,ivar,1) = xjp
!        endif

! -- CENTRE

        rcodcl(ifac,ivar,1) = (1.d0-pondj)*xjp + pondj*xip

      endif

    enddo

  ! For a generic coupling, no assumption can be made

  else


!   --- Traduction en termes de condition limite pour les faces de bord localis�es
!         --> CL type Dirichlet

    do ipt = 1, nfbcpl

      ifac = lfbcpl(ipt)
      iel  = ifabor(ifac)

!         Information de l'instance en cours interpol�e en I'
      iii = idiipb-1+3*(ifac-1)
      xiip = ra(iii+1)
      yiip = ra(iii+2)
      ziip = ra(iii+3)

      xif = cdgfbo(1,ifac) -xyzcen(1,iel)
      yif = cdgfbo(2,ifac) -xyzcen(2,iel)
      zif = cdgfbo(3,ifac) -xyzcen(3,iel)

      xipf = cdgfbo(1,ifac)-xiip - xyzcen(1,iel)
      yipf = cdgfbo(2,ifac)-yiip - xyzcen(2,iel)
      zipf = cdgfbo(3,ifac)-ziip - xyzcen(3,iel)

      ipf = sqrt(xipf**2+yipf**2+zipf**2)


      iii = idiipb-1+3*(ifac-1)
      xiip = ra(iii+1)
      yiip = ra(iii+2)
      ziip = ra(iii+3)

      xopf = dofcpl(1,ipt)
      yopf = dofcpl(2,ipt)
      zopf = dofcpl(3,ipt)

!         Informations locales interpolees en I'/O'

      xip =  rtp(iel,ivar)                                          &
        + (w1(iel)*(xiip+xopf) + w2(iel)*(yiip+yopf) +              &
           w3(iel)*(ziip+zopf))

!         Informations recues de l'instance distante en J'/O'
      xjp = rvcpfb(ipt,ivar)


      gradi = (w1(iel)*xipf+w2(iel)*yipf+w3(iel)*zipf)/ipf

      do iphas = 1, nphas
        itypfb(ifac,iphas)  = icscpl
      enddo

      if(ivar.ne.ipr(1)) then
        icodcl(ifac,ivar  ) = 1
        rcodcl(ifac,ivar,1) = 0.5d0*(xip+xjp)
      else
        icodcl(ifac,ivar  ) = 3
        rcodcl(ifac,ivar,3) = -0.5d0*dt(iel)*(gradi+xjp)
      endif


    enddo

  endif

! --- Faces de bord non localis�es
!       --> CL type Neumann homog�ne

  do ipt = 1, nfbncp

    ifac = lfbncp(ipt)

    do iphas = 1, nphas
      itypfb(ifac,iphas)  = icscpl
    enddo

    icodcl(ifac,ivar  ) = 3
    rcodcl(ifac,ivar,3) = 0.d0

  enddo

enddo


!----
! FORMAT
!----

!----
! FIN
!----

return
end subroutine
