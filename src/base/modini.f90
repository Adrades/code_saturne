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

!> \file modini.f90
!> \brief Modify calculation parameters after user changes (module variables)
!>
!------------------------------------------------------------------------------

subroutine modini

!===============================================================================
! Module files
!===============================================================================

use paramx
use cstnum
use dimens
use field
use numvar
use optcal
use cstphy
use entsor
use albase
use alstru
use cplsat
use post
use ppincl
use rotation
use darcy_module
use turbomachinery
use vof
use cs_c_bindings

!===============================================================================

implicit none

! Arguments


! Local variables

integer          f_id
integer          ii, jj, iok, ikw
integer          nbccou
integer          nscacp, iscal, ivar
integer          imrgrp, iclvfl, kclvfl
integer          iscacp, kcpsyr, icpsyr
integer          nfld, f_type
integer          key_t_ext_id, icpext, kscmin, kscmax
integer          iviext
integer          kturt, turb_flux_model, turb_flux_model_type

double precision relxsp, clvfmn, clvfmx, visls_0, visls_cmp
double precision scminp

character(len=80) :: name

type(var_cal_opt) :: vcopt , vcopt1

!===============================================================================

! Indicateur erreur (0 : pas d'erreur)
iok = 0

call field_get_key_id("syrthes_coupling", kcpsyr)

call field_get_key_id("time_extrapolated", key_t_ext_id)

call field_get_key_id("min_scalar_clipping", kscmin)
call field_get_key_id("max_scalar_clipping", kscmax)
call field_get_key_id('turbulent_flux_model', kturt)

call field_get_key_id("variance_clipping", kclvfl)

!===============================================================================
! 1. ENTREES SORTIES entsor
!===============================================================================

!---> sorties chrono?

if (idtvar.lt.0) then
  call hide_property(icour)
  call hide_property(ifour)
endif

!---> sorties historiques ?
!      Si une valeur non modifiee par l'utilisateur (=-999)
!        on la met a sa valeur par defaut
!      On sort toutes les variables a tous les pas de temps par defaut
!      NTHIST = -1 : on ne sort pas d'historiques
!      NTHIST =  n : on sort des historiques tous les n pas de temps

! Adapt the output frequency parameters according to the time scheme.
if (idtvar.lt.0.or.idtvar.eq.2) then
  frhist = -1.d0
else
  if (frhist > 0.d0) then
    nthist = -1
  endif
endif

! Logging and postprocessing output

if (irovar.eq.0) then
  call hide_property(icrom)
  call hide_property(ibrom)
endif

if (ivivar.eq.0) then
  call hide_property(iviscl)
endif

if (idtvar.lt.0) then
  call hide_property(icour)
  call hide_property(ifour)
endif

!===============================================================================
! 2. POSITION DES VARIABLES DE numvar
!===============================================================================

! ---> Reperage des variables qui disposeront de deux types de CL

!     Fait dans varpos.
!     Si l'utilisateur y a touche ensuite, on risque l'incident.

!===============================================================================
! 3. OPTIONS DU CALCUL : TABLEAUX DE optcal
!===============================================================================

! time scheme

if (ntmabs.eq.-1 .and. ttmabs.lt.-0.5) then
  ntmabs = 10
endif

! restart

call indsui(isuite)

if (isuit1.eq.-1) isuit1 = isuite

!    -- Proprietes physiques
call field_get_key_int(iviscl, key_t_ext_id, iviext)
if (abs(thetvi+999.d0).gt.epzero) then
  write(nfecra,1011) 'IVIEXT',iviext,'THETVI'
  iok = iok + 1
elseif (iviext.eq.0) then
  thetvi = 0.0d0
elseif (iviext.eq.1) then
  thetvi = 0.5d0
elseif (iviext.eq.2) then
  thetvi = 1.d0
endif

if (icp.ge.0) then
  call field_get_key_int(icp, key_t_ext_id, icpext)
  if (abs(thetcp+999.d0).gt.epzero) then
    write(nfecra,1011) 'ICPEXT',icpext,'THETCP'
    iok = iok + 1
  elseif (icpext.eq.0) then
    thetcp = 0.0d0
  elseif (icpext.eq.1) then
    thetcp = 0.5d0
  elseif (icpext.eq.2) then
    thetcp = 1.d0
  endif
endif

!    -- Termes sources NS
if (abs(thetsn+999.d0).gt.epzero) then
  write(nfecra,1011) 'ISNO2T',isno2t,'THETSN'
  iok = iok + 1
elseif (isno2t.eq.1) then
  thetsn = 0.5d0
elseif (isno2t.eq.2) then
  thetsn = 1.d0
elseif (isno2t.eq.0) then
  thetsn = 0.d0
endif

!    -- Termes sources grandeurs turbulentes
if (abs(thetst+999.d0).gt.epzero) then
  write(nfecra,1011) 'ISTO2T',isto2t,'THETST'
  iok = iok + 1
elseif (isto2t.eq.1) then
  thetst = 0.5d0
elseif (isto2t.eq.2) then
  thetst = 1.d0
elseif (isto2t.eq.0) then
  thetst = 0.d0
endif

do iscal = 1, nscal
!    -- Termes sources des scalaires
  if (abs(thetss(iscal)+999.d0).gt.epzero) then
    write(nfecra,1021) iscal,'ISSO2T',isso2t(iscal),'THETSS'
    iok = iok + 1
  elseif (isso2t(iscal).eq.1) then
    thetss(iscal) = 0.5d0
  elseif (isso2t(iscal).eq.2) then
    thetss(iscal) = 1.d0
  elseif (isso2t(iscal).eq.0) then
    thetss(iscal) = 0.d0
  endif
  ! Scalars diffusivity
  call field_get_key_int(ivarfl(isca(iscal)), kivisl, f_id)
  if (f_id.ge.0) then
    call field_get_key_int(f_id, key_t_ext_id, iviext)
  else
    iviext = 0
  endif
  if (abs(thetvs(iscal)+999.d0).gt.epzero) then
    write(nfecra,1021) iscal,'IVSEXT',iviext,'THETVS'
    iok = iok + 1
  elseif (iviext.eq.0) then
    thetvs(iscal) = 0.d0
  elseif (iviext.eq.1) then
    thetvs(iscal) = 0.5d0
  elseif (iviext.eq.2) then
    thetvs(iscal) = 1.d0
  endif
enddo

! Loop on on field variables
call field_get_n_fields(nfld)

do f_id = 0, nfld - 1
  call field_get_type(f_id, f_type)
  ! Is the field of type FIELD_VARIABLE?
  if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
    call field_get_key_struct_var_cal_opt(f_id, vcopt)
    if (abs(vcopt%thetav+1.d0).gt.epzero) then
      call field_get_name(f_id, name)
      write(nfecra,1131) trim(name),'THETAV'
    else
      if (vcopt%istat.eq.0) then
        vcopt%thetav = 1.d0
      else if (ischtp.eq.1) then
        vcopt%thetav = 1.d0
      else if (ischtp.eq.2) then
        vcopt%thetav = 0.5d0
      endif
    endif
    call field_set_key_struct_var_cal_opt(f_id, vcopt)
  endif
enddo

! Diffusivity model:
! Daly Harlow (GGDH) on Rij and epsilon by default
if (itytur.eq.3) then

  call field_get_key_struct_var_cal_opt(ivarfl(irij), vcopt1)
  call field_get_key_struct_var_cal_opt(ivarfl(iep), vcopt)

  ! Diffusivity model:
  ! Daly Harlow (GGDH) on Rij and epsilon by default
  if (idirsm.ne.0) then
     vcopt1%idften = ANISOTROPIC_RIGHT_DIFFUSION
     vcopt%idften  = ANISOTROPIC_RIGHT_DIFFUSION
     ! Scalar diffusivity (Shir model) elswhere (idirsm = 0)
  else
     vcopt1%idften = ISOTROPIC_DIFFUSION
     vcopt%idften  = ISOTROPIC_DIFFUSION
  endif

  call field_set_key_struct_var_cal_opt(ivarfl(irij), vcopt1)
  call field_set_key_struct_var_cal_opt(ivarfl(iep), vcopt)
endif

! ---> ISSTPC
!        Si l'utilisateur n'a rien specifie pour le test de pente (=-1),
!        On impose 1 (ie sans) pour la vitesse en LES
!                  0 (ie avec) sinon

if (itytur.eq.4) then
  ii = iu
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (vcopt%isstpc.eq.-999) then
    vcopt%isstpc = 1
    call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  endif
  do jj = 1, nscal
    ii = isca(jj)
    call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
    if (vcopt%isstpc.eq.-999) then
      vcopt%isstpc = 0
      call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
    endif
 enddo
endif

do f_id = 0, nfld - 1
  call field_get_type(f_id, f_type)
  ! Is the field of type FIELD_VARIABLE?
  if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
    call field_get_key_struct_var_cal_opt(f_id, vcopt)
    if (vcopt%isstpc.eq.-999) then
      vcopt%isstpc = 0
      call field_set_key_struct_var_cal_opt(f_id, vcopt)
    endif
  endif
enddo

! ---> BLENCV
!        Si l'utilisateur n'a rien specifie pour le schema convectif
!                  1 (ie centre) pour les vitesses
!                                     les scalaires utilisateurs
!                                     le scalaire thermique
!                  0 (ie upwind pur) pour le reste
!   (en particulier, en L.E.S. toutes les variables sont donc en centre)

!  Pour le modele de cavitation on force dans tous les cas le taux de vide en
!  upwind et on affiche un message si l'utilisateur avait specifie autre chose

ii = iu
call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
if (abs(vcopt%blencv+1.d0).lt.epzero) then
  vcopt%blencv = 1.d0
  call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
endif

if (iand(ivofmt,VOF_MERKLE_MASS_TRANSFER).ne.0) then
  ii = ivolf2
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (abs(vcopt%blencv+1.d0).lt.epzero) then
    if (abs(vcopt%blencv+1.d0).gt.epzero) &
         write(nfecra,3000) 0.d0, vcopt%blencv
    vcopt%blencv = 0.d0
    call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  endif
else if (ivofmt.gt.0) then
  ii = ivolf2
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (abs(vcopt%blencv+1.d0).lt.epzero) then
    vcopt%blencv = 1.d0
    call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  endif
endif

do jj = 1, nscaus
  ii = isca(jj)
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (abs(vcopt%blencv+1.d0).lt.epzero) then
    vcopt%blencv = 1.d0
    call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  endif
enddo

if (iscalt.gt.0) then
  ii = isca(iscalt)
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (abs(vcopt%blencv+1.d0).lt.epzero) then
    vcopt%blencv = 1.d0
    call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  endif
endif

do f_id = 0, nfld - 1
  call field_get_type(f_id, f_type)
  ! Is the field of type FIELD_VARIABLE?
  if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
    call field_get_key_struct_var_cal_opt(f_id, vcopt)
    if (abs(vcopt%blencv+1.d0).lt.epzero) then
      vcopt%blencv = 0.d0
      call field_set_key_struct_var_cal_opt(f_id, vcopt)
    endif
  endif
enddo

! ---> NSWRSM, EPSRSM ET EPSILO
!        Si l'utilisateur n'a rien specifie  (NSWRSM=-1),
!        On impose
!           a l'ordre 1 :
!                  2  pour la pression
!                  1  pour les autres variables
!                  on initialise EPSILO a 1.d-8
!                     pour la pression
!                  on initialise EPSILO a 1.d-5
!                     pour les autres variables
!                  on initialise EPSRSM a 10*EPSILO
!           a l'ordre 2 :
!                  5  pour la pression
!                  10 pour les autres variables
!                  on initialise EPSILO a 1.D-5
!                  on initialise EPSRSM a 10*EPSILO
!     Attention aux tests dans verini

if (ischtp.eq.2) then
  ii = ipr
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (vcopt%nswrsm.eq.-1) vcopt%nswrsm = 5
  if (abs(vcopt%epsilo+1.d0).lt.epzero) vcopt%epsilo = 1.d-5
  if (abs(vcopt%epsrsm+1.d0).lt.epzero) vcopt%epsrsm = 10.d0*vcopt%epsilo
  call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  ii = iu
  call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  if (vcopt%nswrsm.eq.-1) vcopt%nswrsm = 10
  if (abs(vcopt%epsilo+1.d0).lt.epzero) vcopt%epsilo = 1.d-5
  if (abs(vcopt%epsrsm+1.d0).lt.epzero) vcopt%epsrsm = 10.d0*vcopt%epsilo
  call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  do jj = 1, nscal
    ii = isca(jj)
    call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
    if (vcopt%nswrsm.eq.-1) vcopt%nswrsm = 10
    if (abs(vcopt%epsilo+1.d0).lt.epzero) vcopt%epsilo = 1.d-5
    if (abs(vcopt%epsrsm+1.d0).lt.epzero) vcopt%epsrsm = 10.d0*vcopt%epsilo
    call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)
  enddo
endif

! For the pressure, default solver precision 1e-8
! because the mass conservation is up to this precision
ii = ipr
call field_get_key_struct_var_cal_opt(ivarfl(ii), vcopt)
if (vcopt%nswrsm.eq.-1) vcopt%nswrsm = 2
if (abs(vcopt%epsilo+1.d0).lt.epzero) vcopt%epsilo = 1.d-8
call field_set_key_struct_var_cal_opt(ivarfl(ii), vcopt)

do f_id = 0, nfld - 1
  call field_get_type(f_id, f_type)
  ! Is the field of type FIELD_VARIABLE?
  if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
    call field_get_key_struct_var_cal_opt(f_id, vcopt)
    if (vcopt%nswrsm.eq.-1) vcopt%nswrsm = 1
    if (abs(vcopt%epsilo+1.d0).lt.epzero) vcopt%epsilo = 1.d-5
    if (abs(vcopt%epsrsm+1.d0).lt.epzero) vcopt%epsrsm = 10.d0*vcopt%epsilo
    call field_set_key_struct_var_cal_opt(f_id, vcopt)
  endif
enddo

! ---> IMLIGR
!        Si l'utilisateur n'a rien specifie pour la limitation des
!          gradients (=-999),
!        On impose -1 avec gradrc (pas de limitation)
!               et  1 avec gradmc (limitation)
imrgrp = abs(imrgra)
if (imrgrp.ge.10) imrgrp = imrgrp - 10

if (imrgrp.eq.0.or.imrgrp.ge.4) then
  do f_id = 0, nfld - 1
    call field_get_type(f_id, f_type)
    ! Is the field of type FIELD_VARIABLE?
    if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
      call field_get_key_struct_var_cal_opt(f_id, vcopt)
      if (vcopt%imligr.eq.-999) then
        vcopt%imligr = -1
        call field_set_key_struct_var_cal_opt(f_id, vcopt)
      endif
    endif
  enddo
else
  do f_id = 0, nfld - 1
    call field_get_type(f_id, f_type)
    ! Is the field of type FIELD_VARIABLE?
    if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
      call field_get_key_struct_var_cal_opt(f_id, vcopt)
      if (vcopt%imligr.eq.-999) then
        vcopt%imligr = 1
        call field_set_key_struct_var_cal_opt(f_id, vcopt)
      endif
    endif
  enddo
endif

! ---> DTMIN DTMAX CDTVAR

if (dtmin.le.-grand) then
  dtmin = 0.1d0*dtref
endif
if (dtmax.le.-grand) then
  dtmax = 1.0d3*dtref
endif

! Init. of time step factor for velocity, pressure and turbulent variables
! FIXME time step factor is used ONLY for additional variables (user or model)

cdtvar(iv ) = cdtvar(iu)
cdtvar(iw ) = cdtvar(iu)
cdtvar(ipr) = cdtvar(iu)

if (itytur.eq.2) then
  cdtvar(iep ) = cdtvar(ik  )
elseif (itytur.eq.3) then
  cdtvar(ir22) = cdtvar(ir11)
  cdtvar(ir33) = cdtvar(ir11)
  cdtvar(ir12) = cdtvar(ir11)
  cdtvar(ir13) = cdtvar(ir11)
  cdtvar(ir23) = cdtvar(ir11)
  cdtvar(iep ) = cdtvar(ir11)
  ! cdtvar(ial) is useless because no time dependance in the equation of alpha.
  if (iturb.eq.32) then
    cdtvar(ial) = cdtvar(ir11)
  endif
elseif (itytur.eq.5) then
  cdtvar(iep ) = cdtvar(ik  )
  cdtvar(iphi) = cdtvar(ik  )
!     CDTVAR(IFB/IAL) est en fait inutile car pas de temps dans
!     l'eq de f_barre/alpha
  if (iturb.eq.50) then
    cdtvar(ifb ) = cdtvar(ik  )
  elseif (iturb.eq.51) then
    cdtvar(ial ) = cdtvar(ik  )
  endif
elseif (iturb.eq.60) then
  cdtvar(iomg) = cdtvar(ik  )
elseif (iturb.eq.70) then
  ! cdtvar est a 1.0 par defaut dans iniini.f90
  cdtvar(inusa)= cdtvar(inusa)
endif

! ---> IWALLF
! For laminar cases or when using low Reynolds model: no wall function.
! When using mixing length, Spalart-Allmaras or LES: one scale log law.
! When using EB-RSM : all y+ wall functions
! In all other cases: 2 scales log law.
! Here iwallf is set automatically only if it wasn't set in the gui or
! in a user subroutine.

if (iwallf.eq.-999) then
  if (    iturb.eq.10.or.iturb.eq.70 &
      .or.itytur.eq.4) then
    iwallf = 2
  elseif (iturb.eq.0.or.itytur.eq.5) then
    iwallf = 0
  elseif (iturb.eq.32) then
    iwallf = 7
  else
    iwallf = 3
  endif
endif

! ---> IWALFS
! If the wall function for the velocity is the two scales wall function using
! Van Driest mixing length (iwallf=5), then the corresponding wall function for
! scalar should be used (iwalfs=1).
! For atmospheric Flows, it is by default Louis, or Monin-Obukhov
! Here iwalfs is set automatically only if it wasn't set in a user subroutine.

if (iwalfs.eq.-999) then
  if (ippmod(iatmos).ge.0) then
    iwalfs = 2
  else if (iwallf.eq.5) then
    iwalfs = 1
  else
    iwalfs = 0
  endif
endif

! ---> YPLULI
! 1/XKAPPA est la valeur qui assure la continuite de la derivee
! entre la zone lineaire et la zone logarithmique.

! Dans le cas des lois de paroi invariantes, on utilise la valeur de
! continuite du profil de vitesse, 10.88.

! Pour la LES, on remet 10.88, afin d'eviter des clic/clac quand on est a
! la limite (en modele a une echelle en effet, YPLULI=1/XKAPPA ne permet pas
! forcement de calculer u* de maniere totalement satisfaisante).
! Idem en Spalart-Allmaras.

if (ypluli.lt.-grand) then
  if (iwallf.eq.4 .or. itytur.eq.4 .or. iturb.eq.70.or.iwallf.eq.6.or.iturb.eq.60 &
      .or. iturb.eq.22 ) then
    ypluli = 10.88d0
  else
    ypluli = 1.d0/xkappa
  endif
endif

! ---> ICPSYR
!      Si l'utilisateur n'a pas modifie ICPSYR, on prend par defaut :
!        s'il n y a pas de couplage
!          0 pour tous les scalaires
!        sinon
!          1 pour le scalaire ISCALT s'il existe
!          0 pour les autres
!      Les modifs adequates devront etre ajoutees pour les physiques
!        particulieres
!      Les tests de coherence seront faits dans verini.

if (nscal.gt.0) then

!     On regarde s'il y a du couplage

  nbccou = cs_syr_coupling_n_couplings()

!     S'il y a du couplage
  if (nbccou .ne. 0) then

!       On compte le nombre de scalaires couples
    nscacp = 0
    do iscal = 1, nscal
      call field_get_key_int(ivarfl(isca(iscal)), kcpsyr, icpsyr)
      if (icpsyr.eq.1) then
        nscacp = nscacp + 1
      endif
    enddo

!       Si l'utilisateur n'a pas couple de scalaire,
    if (nscacp.eq.0) then

!         On couple le scalaire temperature de la phase
      if (iscalt.gt.0.and.iscalt.le.nscal) then
        icpsyr = 1
        call field_set_key_int(ivarfl(isca(iscalt)), kcpsyr, icpsyr)
        goto 100
      endif
 100        continue

    endif

  endif

endif

! Temperature scale

if (itherm.ge.1 .and. itpscl.le.0) then
  itpscl = 1
endif

! ---> "is_temperature"
!      If the user has not modified "is_temperature", we take by default:
!        passive scalar of scalars other than iscalt
!         = 0 : passive, enthalpy, or energy
!         = 1 : temperature

if (nscal.gt.0) then
  do ii = 1, nscal
    call field_get_key_int(ivarfl(isca(ii)), kscacp, iscacp)
    if (iscacp.eq.-1) then
      if (ii.eq.iscalt .and. itherm.eq.1) then
        iscacp = 1
      else
        iscacp = 0
      endif
      call field_set_key_int(ivarfl(isca(ii)), kscacp, iscacp)
    endif
  enddo
endif

! ---> ICALHY
!      Calcul de la pression hydrostatique en sortie pour les conditions de
!        Dirichlet sur la pression. Se deduit de IPHYDR et de la valeur de
!        la gravite (test assez arbitraire sur la norme).
!      ICALHY est initialise a -1 (l'utilisateur peut avoir force
!        0 ou 1 et dans ce cas, on ne retouche pas)

if (icalhy.ne.-1.and.icalhy.ne.0.and.icalhy.ne.1) then
  write(nfecra,1061)icalhy
  iok = iok + 1
endif


! ---> ICDPAR
!      Calcul de la distance a la paroi. En standard, on met ICDPAR a -1, au cas
!      ou les faces de bord auraient change de type d'un calcul a l'autre. En k-omega,
!      il faut la distance a la paroi pour une suite propre, donc on initialise a 1 et
!      on avertit (dans verini).
ikw = 0
if (iturb.eq.60) ikw = 1
if (icdpar.eq.-999) then
  icdpar = -1
  if (ikw.eq.1) icdpar = 1
  if (isuite.eq.1 .and. ikw.eq.1) write(nfecra,2000)
endif
if (icdpar.eq.-1 .and. ikw.eq.1 .and. isuite.eq.1)                &
     write(nfecra,2001)

! ---> IKECOU
!      If the fluid_solid option is enabled, we force ikecou to 0.
if (fluid_solid) then
  if(ikecou .eq. 1) then
    ikecou = 0
    write(nfecra,5000)
  endif
endif


! ---> RELAXV
if (idtvar.lt.0) then
  relxsp = 1.d0-relxst
  if (relxsp.le.epzero) relxsp = relxst
  call field_get_key_struct_var_cal_opt(ivarfl(ipr), vcopt)
  if (abs(vcopt%relaxv+1.d0).le.epzero) then
    vcopt%relaxv = relxsp
    call field_set_key_struct_var_cal_opt(ivarfl(ipr), vcopt)
  endif
  do f_id = 0, nfld - 1
    call field_get_type(f_id, f_type)
    ! Is the field of type FIELD_VARIABLE?
    if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
      call field_get_key_struct_var_cal_opt(f_id, vcopt)
      if (abs(vcopt%relaxv+1.d0).le.epzero) then
        vcopt%relaxv = relxst
        call field_set_key_struct_var_cal_opt(f_id, vcopt)
      endif
    endif
  enddo
else

  do f_id = 0, nfld - 1
    call field_get_type(f_id, f_type)
    ! Is the field of type FIELD_VARIABLE?
    if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
      call field_get_key_struct_var_cal_opt(f_id, vcopt)
      if (abs(vcopt%relaxv+1.d0).le.epzero) then
        vcopt%relaxv = 1.d0
        call field_set_key_struct_var_cal_opt(f_id, vcopt)
      endif
    endif
  enddo
endif

! Options specific to steady case
if (idtvar.lt.0) then
  ipucou = 0
  dtref = 1.d0
  dtmin = 1.d0
  dtmax = 1.d0
  do f_id = 0, nfld - 1
    call field_get_type(f_id, f_type)
    ! Is the field of type FIELD_VARIABLE?
    if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
      call field_get_key_struct_var_cal_opt(f_id, vcopt)
      vcopt%istat = 0
      call field_set_key_struct_var_cal_opt(f_id, vcopt)
    endif
  enddo
  call field_get_key_struct_var_cal_opt(ivarfl(iu), vcopt)
  arak = arak/max(vcopt%relaxv,epzero)
endif

! With a staggered approach no Rhie and Chow correction is needed
if (staggered.eq.1) then
  arak = 0.d0
endif

!===============================================================================
! 4. TABLEAUX DE cstphy
!===============================================================================

! ---> Constantes
!    Ca fait un calcul en double, mais si qqn a bouge cmu, apow, bpow,
!     ca servira.

cpow    = apow**(2.d0/(1.d0-bpow))
dpow    = 1.d0/(1.d0+bpow)

! Modified value of Cmu for V2f and Bl-v2k
if (iturb.eq.50.or.iturb.eq.51) cmu = 0.22d0

cmu025 = cmu**0.25d0

if (idirsm.eq.0) then
  csrij = 0.11d0
else
  if (iturb.eq.32) then
    csrij = 0.21d0
  else
    csrij = 0.22d0
  endif
endif

! Constant for the Buoyant production term of Rij
! EBRSM
if (iturb.eq.32) then
  crij3 = 0.6d0
else
  crij3 = 0.55d0
endif

if (iturb.eq.60) then !sst-ddes
  ! SST DDES
  if (hybrid_turb.eq.2) then
    cddes = 0.65d0
  else if (hybrid_turb.eq.1) then
    cddes = 0.61d0
  endif
  ! SST SAS
  csas  = 0.11d0
  csas_eta2 = 3.51d0
elseif (iturb.eq.51) then !phif-ddes
  cddes = 0.60d0
endif

! ---> ICLVFL
!      Si l'utilisateur n'a pas modifie ICLVFL, on prend par defaut :
!        0 pour les variances
!      Les modifs adequates devront etre ajoutees pour les physiques
!        particulieres
!      If the user gives a value we put iclcfl to 2.

do iscal = 1, nscal
  if (iscavr(iscal).gt.0) then
    call field_get_key_int(ivarfl(isca(iscal)), kclvfl, iclvfl)
    ! Get the min clipping
    call field_get_key_double(ivarfl(isca(iscal)), kscmin, scminp)
    ! If modified put 2
    if (iclvfl.eq.-1 .and. abs(scminp+grand).ge.epzero) then
      call field_set_key_int(ivarfl(isca(iscal)), kclvfl, 2)

    else if (iclvfl.eq.-1) then
      call field_set_key_int(ivarfl(isca(iscal)), kclvfl, 0)
    endif

    ! Min for variances is 0 or greater
    call field_get_key_double(ivarfl(isca(iscal)), kscmin, scminp)
    ! set min clipping to 0
    scminp = max(0.d0, scminp)
    call field_set_key_double(ivarfl(isca(iscal)), kscmin, scminp)
  endif
enddo

do ii = 1, nscal
  f_id = ivarfl(isca(ii))
  call field_get_key_double(f_id, kvisl0, visls_0)

  ! For scalars which are not variances, define the reference diffusivity
  if (iscavr(ii).le.0 .and. visls_0.lt.-grand) then
    call field_get_key_int(f_id, kscacp, iscacp)
    if (iscacp.gt.0) then
      ! For temperature, the diffusivity factor is directly the thermal conductivity
      ! lambda = Cp * mu / Pr
      ! where Pr is the (molecular) Prandtl number
      visls_0 = viscl0 * cp0
    else
      visls_0 = viscl0
    endif
    call field_set_key_double(f_id, kvisl0, visls_0)
  endif

  ! For fluctuation variances, the diffusivity is that of the associated scalar.
  iscal = iscavr(ii)
  if (iscal.gt.0.and.iscal.le.nscal)then
    call field_get_key_double(ivarfl(isca(iscal)), kvisl0, visls_0)
    call field_get_key_double(f_id, kvisl0, visls_cmp)
    call field_set_key_double(f_id, kvisl0, visls_0)
    if (visls_cmp.gt.-grand) then
      write(nfecra,1071) ii, iscal, ii, iscal, visls_0
    endif
  endif
enddo

! xyzp0 : reference point for hydrostatic pressure
! The user should specify the 3 coordinates, otherwise
! it is set to (0.,0.,0.).

if (xyzp0(1).gt.-0.5d0*rinfin.and. &
    xyzp0(2).gt.-0.5d0*rinfin.and. &
    xyzp0(3).gt.-0.5d0*rinfin       ) then
  ixyzp0 = 1
else
  do ii = 1, 3
    xyzp0(ii) = 0.d0
  enddo
endif

! Turbulent fluxes constant for GGDH, AFM and DFM
if (nscal.gt.0) then
  do iscal = 1, nscal

    call field_get_key_int(ivarfl(isca(iscal)), kturt, turb_flux_model)
    turb_flux_model_type = turb_flux_model / 10

    ! AFM and GGDH on the scalar
    if (turb_flux_model_type.eq.1.or.turb_flux_model_type.eq.2) then
      call field_get_key_struct_var_cal_opt(ivarfl(isca(iscal)), vcopt)
      vcopt%idften = ANISOTROPIC_RIGHT_DIFFUSION
      call field_set_key_double(ivarfl(isca(iscal)), kctheta, cthafm)
      call field_set_key_struct_var_cal_opt(ivarfl(isca(iscal)), vcopt)
    ! DFM on the scalar
    elseif (turb_flux_model_type.eq.3) then
      call field_get_key_struct_var_cal_opt(ivarfl(isca(iscal)), vcopt)
      vcopt%idifft = 0
      vcopt%idften = ISOTROPIC_DIFFUSION
      if (turb_flux_model.eq.31) then
        call field_set_key_double(ivarfl(isca(iscal)), kctheta, cthebdfm)
        c2trit = 0.3d0
      else
        call field_set_key_double(ivarfl(isca(iscal)), kctheta, cthdfm)
      end if
      call field_set_key_struct_var_cal_opt(ivarfl(isca(iscal)), vcopt)
      ! GGDH on the thermal fluxes is automatically done

      ! GGDH on the variance of the thermal scalar
      do ii = 1, nscal
        if (iscavr(ii).eq.iscal) then
          call field_get_key_struct_var_cal_opt(ivarfl(isca(ii)), vcopt)
          vcopt%idften = ANISOTROPIC_RIGHT_DIFFUSION
          call field_set_key_double(ivarfl(isca(ii)), kctheta, csrij)
          call field_set_key_struct_var_cal_opt(ivarfl(isca(ii)), vcopt)
        endif
      enddo
    else
      call field_set_key_double(ivarfl(isca(iscal)), kctheta, csrij)
    endif
  enddo
endif

! harmonic face viscosity interpolation
if (imvisf.eq.1) then
  do ivar = 1, nvar
    call field_get_key_struct_var_cal_opt(ivarfl(ivar), vcopt)
    vcopt%imvisf = 1
    call field_set_key_struct_var_cal_opt(ivarfl(ivar), vcopt)
  enddo
endif

! VoF model enabled
if (ivofmt.gt.0) then
  ro0    = rho2
  viscl0 = mu2

  ! VOF algorithm: continuity of the flux across internal faces
  call field_get_key_struct_var_cal_opt(ivarfl(ipr), vcopt)
  vcopt%imvisf = 1
  call field_set_key_struct_var_cal_opt(ivarfl(ipr), vcopt)
endif

! Anisotropic diffusion/permeability for Darcy module
if (ippmod(idarcy).eq.1) then

  if (darcy_anisotropic_permeability.eq.1) then
    call field_get_key_struct_var_cal_opt(ivarfl(ipr), vcopt)
    vcopt%idften = ANISOTROPIC_LEFT_DIFFUSION
    call field_set_key_struct_var_cal_opt(ivarfl(ipr), vcopt)
 endif

  if (darcy_anisotropic_dispersion.eq.1) then
    do iscal = 1, nscal
      call field_get_key_struct_var_cal_opt(ivarfl(isca(iscal)), vcopt)
      vcopt%idften = ANISOTROPIC_LEFT_DIFFUSION
      call field_set_key_struct_var_cal_opt(ivarfl(isca(iscal)), vcopt)
    enddo
  endif

  ! csrij = 1 and ctheta(iscal) = 1 for Darcy module
  csrij = 1.d0
  do iscal = 1, nscal
    call field_set_key_double(ivarfl(isca(iscal)), kctheta, 1.d0)
  enddo

  ! reference values for pressure and density
  p0 = 0.d0
  ro0 = 1.d0

  ! be careful: if iturb was not initialized iturb is set to 0 to pass verini
  if (iturb.eq.-999) iturb = 0
  if (iturb.gt.0) then
    write(nfecra,4001)
    call csexit (1)
  endif

endif

! Set iswdyn to 2 by default if not modified for pure diffusion equations
do f_id = 0, nfld - 1
  call field_get_type(f_id, f_type)
  ! Is the field of type FIELD_VARIABLE?
  if (iand(f_type, FIELD_VARIABLE).eq.FIELD_VARIABLE) then
    call field_get_key_struct_var_cal_opt(f_id, vcopt)
    if (vcopt%iswdyn.eq.-1.and. vcopt%iconv.eq.0) then
      vcopt%iswdyn = 2
      call field_set_key_struct_var_cal_opt(f_id, vcopt)
    endif
  endif
enddo

!===============================================================================
! 5. ELEMENTS DE albase
!===============================================================================

if (iale.ge.1) then
  if (isuite.eq.0 .and. italin.eq.-999 ) italin = 1
else
  italin = 0
endif

!===============================================================================
! 6. COEFFICIENTS DE alstru
!===============================================================================

if (betnmk.lt.-0.5d0*grand) betnmk = (1.d0-alpnmk)**2/4.d0
if (gamnmk.lt.-0.5d0*grand) gamnmk = (1.d0-2.d0*alpnmk)/2.d0
if (aexxst.lt.-0.5d0*grand) aexxst = 0.5d0
if (bexxst.lt.-0.5d0*grand) bexxst = 0.0d0
if (cfopre.lt.-0.5d0*grand) cfopre = 2.0d0

!===============================================================================
! 7. PARAMETRES DE cplsat
!===============================================================================

! Get number of couplings

call nbccpl(nbrcpl)
!==========

if (nbrcpl.ge.1.and.iturbo.ne.0) then
  ifaccp = 1
endif

!===============================================================================
! 8. Define Min/Max clipping values of void fraction of VOF model
!===============================================================================

if (ivofmt.gt.0) then
  call field_get_key_double(ivarfl(ivolf2), kscmin, clvfmn)
  call field_get_key_double(ivarfl(ivolf2), kscmax, clvfmx)

  if (clvfmn.lt.-0.5d0*grand) then
    clvfmn = 0.d0
    if (iand(ivofmt,VOF_MERKLE_MASS_TRANSFER).ne.0) clvfmn = epzero
  endif
  if (clvfmx.gt.0.5d0*grand) then
    clvfmx = 1.d0
    if (iand(ivofmt,VOF_MERKLE_MASS_TRANSFER).ne.0) clvfmx = 1.d0-epzero
  endif

  call field_set_key_double(ivarfl(ivolf2), kscmin, clvfmn)
  call field_set_key_double(ivarfl(ivolf2), kscmax, clvfmx)
endif

!===============================================================================
! 9. STOP SI PB
!===============================================================================

if (iok.ne.0) then
  call csexit (1)
endif

 1011 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@    ',a6,' = ',   i10,                                        /,&
'@    ',a6,' WILL BE INITIALIZED AUTOMATICALLY',                /,&
'@    DO NOT MODIFY IT.,'                                       /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  Check cs_user_parameters.f90',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 1021 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@    SCALAR ',   i10,' ',a6,' = ',   i10,                      /,&
'@    ',a6,' WILL BE INITIALIZED AUTOMATICALLY',                /,&
'@    DO NOT MODIFY IT.,'                                       /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  Check cs_user_parameters.f90',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 1131 format( &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ADVANCED MODIFICATION FOR',                      /,&
'@    ========,'                                                /,&
'@    ',a17,' OF THE VARIABLE'                                  /,&
'@    ',a6,'.'                                                  /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)

 1061 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING: ABORT IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@    ICALHY must be an integer equal to 0 or 1',               /,&
'@',                                                            /,&
'@  Its value is ',i10,                                         /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@  Check cs_user_parameters.f90',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 1071 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING:       IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@',                                                            /,&
'@  The scalar ',i10,   ' is the fluctuations variance',        /,&
'@    of the scalar ',i10,                                      /,&
'@',                                                            /,&
'@  The diffusivity_ref value of the scalar ', i10,             /,&
'@    must not be set:',                                        /,&
'@    it is automatically set equal to the scalar',             /,&
'@    diffusivity ', i10,   ' i.e. ',e14.5,                     /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 2000 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING:       IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@',                                                            /,&
'@  The k-omega turbulence model has been chosen. In order to', /,&
'@    have a correct calculation restart, the ICDPAR indicator',/,&
'@    has been set to 1 (read the wall distance in the restart',/,&
'@    file).',                                                  /,&
'@  If this initialization raises any issue (modification of,'  /,&
'@    the number and position of the wall faces since the',     /,&
'@    previous calcuation), force ICDPAR=1 (there might be,'    /,&
'@    a small shift in the turbulent viscosity at the,'         /,&
'@    first time-step).,'                                       /,&
'@',                                                            /,&
'@  The calculation will be run.',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 2001 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING:       IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@',                                                            /,&
'@  The k-omega turbulence model has been chosen, with the,'    /,&
'@    option for a re-calculation of the wall distance',        /,&
'@    (ICDPAR=-1). There might be a small shift in the',        /,&
'@    turbulent viscosity at the first time-step.',             /,&
'@',                                                            /,&
'@  The calculation will be run.',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 3000 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING:       IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@',                                                            /,&
'@  The cavitation model requires an upwind convection scheme' ,/,&
'@    for the void fraction (BLENCV(IVOLF2)=',e14.5,').',       /,&
'@  The user has set BLENCV(IVOLF2)=',e14.5,                    /,&
'@',                                                            /,&
'@  The upwind scheme for the void fraction is forced.',        /,&
'@',                                                            /,&
'@  The calculation will be run.',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 4001 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING:       IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@',                                                            /,&
'@  A turbulence model can not be used with the'                /,&
'@    gound water flows modeling.',                             /,&
'@',                                                            /,&
'@  The calculation will not be run.',                          /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
 5000 format(                                                     &
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /,&
'@ @@ WARNING:       IN THE DATA SPECIFICATION',                /,&
'@    ========',                                                /,&
'@',                                                            /,&
'@  The pseudo coupling of turbulent dissipation and turbulent',/,&
'@  kinetic energy (ikecou = 1) is not compatible with the use',/,&
'@  of fluid/solid option to disable the dynamic in the solid ',/,&
'@  cells (fluid_solid =1). ',                                  /,&
'@',                                                            /,&
'@  The parameter ikecou is forced to 0 (no coupling)',         /,&
'@',                                                            /,&
'@  The calculation will be run.',                              /,&
'@',                                                            /,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@',                                                            /)
return
end subroutine
