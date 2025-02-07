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

!> \file caltri.f90
!> \brief Main time loop.
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!______________________________________________________________________________

subroutine caltri

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use pointe
use optcal
use numvar
use cstphy
use cstnum, only: epzero
use entsor
use albase
use parall
use period
use ppppar
use ppthch
use ppincl
use coincl
use cpincl
use lagran
use radiat
use cplsat
use atincl
use ctincl
use cfpoin
use mesh
use field
use post
use atchem
use atimbr
use ptrglo
use turbomachinery
use cs_c_bindings
use cs_f_interfaces
use cdomod

use, intrinsic :: iso_c_binding

use cs_tagms
use cs_nz_condensation
use cs_nz_tagmr

!===============================================================================

implicit none

! Arguments


! Local variables

logical(kind=c_bool) :: mesh_modified, log_active, post_active
integer(c_int) :: ierr

integer          modhis, iappel, iisuit
integer          iel
integer          inod   , idim, ifac
integer          itrale , ntmsav
integer          iterns
integer          stats_id, restart_stats_id, lagr_stats_id, post_stats_id

double precision titer1, titer2

integer          ivoid(1)

double precision, save :: ttchis

double precision, pointer, dimension(:)   :: dt => null()
double precision, pointer, dimension(:)   :: porosi => null()
double precision, pointer, dimension(:,:) :: disale => null()
double precision, dimension(:,:), pointer :: xyzno0 => null()

integer, allocatable, dimension(:) :: isostd
integer, pointer, dimension(:,:) :: icodcl
double precision, pointer, dimension(:,:,:) :: rcodcl

!===============================================================================
! Interfaces
!===============================================================================

interface

  subroutine condli_ini(nvar, nscal, itrale, icodcl, isostd, dt, rcodcl)

    use mesh, only: nfac, nfabor

    implicit none

    integer          nvar, nscal, itrale

    double precision, pointer, dimension(:) :: xprale
    integer, pointer, dimension(:,:) :: icodcl
    integer, dimension(nfabor+1) :: isostd
    double precision, pointer, dimension(:) :: dt
    double precision, pointer, dimension(:,:,:) :: rcodcl

  end subroutine condli_ini

  !=============================================================================

  subroutine tridim(itrale, nvar, nscal, dt)

    implicit none

    integer                                   :: itrale, nvar, nscal
    double precision, pointer, dimension(:)   :: dt

  end subroutine tridim

  !=============================================================================

  subroutine turbulence_bc_free_pointers()  &
    bind(C, name='cs_turbulence_bc_free_pointers')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine turbulence_bc_free_pointers

  !=============================================================================

   subroutine post_activate_by_time_step()             &
     bind(C, name='cs_f_post_activate_by_time_step')
     use, intrinsic :: iso_c_binding
     implicit none
   end subroutine post_activate_by_time_step

  !=============================================================================

  subroutine cs_post_activate_writer(writer_id, activate)   &
    bind(C, name='cs_post_activate_writer')
    use, intrinsic :: iso_c_binding
    implicit none
    integer(c_int), value  :: writer_id
    logical(c_bool), value :: activate
  end subroutine cs_post_activate_writer

  !=============================================================================

  subroutine cs_post_default_write_variables()  &
    bind(C, name='cs_post_default_write_variables')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_post_default_write_variables

  !=============================================================================

  subroutine cs_user_postprocess_activate(nt_max_abs, nt_cur_abs, t_cur_abs) &
    bind(C, name='cs_user_postprocess_activate')
    use, intrinsic :: iso_c_binding
    implicit none
    integer(c_int), value :: nt_max_abs, nt_cur_abs
    real(c_double), value :: t_cur_abs
  end subroutine cs_user_postprocess_activate

  !=============================================================================

  subroutine cs_time_step_increment(dt) &
    bind(C, name='cs_time_step_increment')
    use, intrinsic :: iso_c_binding
    implicit none
    real(kind=c_double), value :: dt
  end subroutine cs_time_step_increment

  !=============================================================================

  subroutine cs_les_inflow_initialize()  &
    bind(C, name='cs_les_inflow_initialize')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_les_inflow_initialize

  !=============================================================================

  subroutine cs_meg_post_activate()  &
    bind(C, name='cs_meg_post_activate')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_meg_post_activate

  !=============================================================================

  subroutine cs_restart_map_build()  &
    bind(C, name='cs_restart_map_build')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_restart_map_build

  !=============================================================================

  subroutine cs_restart_map_free()  &
    bind(C, name='cs_restart_map_free')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_restart_map_free

  !=============================================================================

  subroutine cs_restart_lagrangian_checkpoint_read()  &
    bind(C, name='cs_restart_lagrangian_checkpoint_read')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_restart_lagrangian_checkpoint_read

  !=============================================================================

  subroutine cs_restart_lagrangian_checkpoint_write()  &
    bind(C, name='cs_restart_lagrangian_checkpoint_write')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_restart_lagrangian_checkpoint_write

  !=============================================================================

  subroutine cs_les_synthetic_eddy_restart_read()  &
    bind(C, name='cs_les_synthetic_eddy_restart_read')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_les_synthetic_eddy_restart_read

  !=============================================================================

  subroutine cs_les_synthetic_eddy_restart_write()  &
    bind(C, name='cs_les_synthetic_eddy_restart_write')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_les_synthetic_eddy_restart_write

  !=============================================================================

  subroutine cs_volume_mass_injection_build_lists(ncetsm, icetsm, izctsm) &
    bind(C, name='cs_volume_mass_injection_build_lists')
    use, intrinsic :: iso_c_binding
    implicit none
    integer(kind=c_int), value :: ncetsm
    integer(kind=c_int), dimension(*), intent(out) :: icetsm, izctsm
  end subroutine cs_volume_mass_injection_build_lists

  !=============================================================================

  function cs_runaway_check() result(ierr) &
    bind(C, name='cs_runaway_check')
    use, intrinsic :: iso_c_binding
    implicit none
    integer(c_int) :: ierr
  end function cs_runaway_check

  !=============================================================================

end interface

!===============================================================================
! Initialization
!===============================================================================

!--> Probes output tracking
ttchis = -1.d0

! Test presence of control_file to modify ntmabs if required

ntmsav = ntmabs

call cs_control_check_file

if (idtvar.eq.1 .and. ntmsav.gt.ntmabs .and. ntmabs.eq.ntcabs) then
  call cplact(ivoid(1))
  if (ivoid(1).gt.0) ntmabs = ntmabs+1
endif

! Define timer stats based on options

if (iilagr.gt.0) then
  lagr_stats_id = timer_stats_create("stages", &
                                     "lagrangian_stage", &
                                     "Lagrangian Module")
  stats_id = timer_stats_create("lagrangian_stage", &
                                "particle_displacement_stage", &
                                "particle displacement")
endif

!===============================================================================
! End of modules initialization
!===============================================================================

call initi2

! First pass for every subroutine requiring pass count
iappel = 1

!===============================================================================
! Zone definition for head-loss, mass sources term,
!   condensation sources term and 1D-wall module
!===============================================================================

! Allocate temporary arrays for zones definition
allocate(izctsm(ncel))

! -----------------
! Mass source terms
! -----------------

! Total number of cells with mass source term
ncetsm = volume_zone_n_type_cells(VOLUME_ZONE_MASS_SOURCE_TERM)
nctsmt = ncetsm
if (irangp.ge.0) then
  call parcpt(nctsmt)
endif

if (nctsmt.gt.0) then
  write(nfecra,2002) nctsmt
  write(nfecra,3000)
endif

! Condensation mass source terms
! ------------------------------

call cs_user_wall_condensation(nvar, nscal, iappel)

! Total number of cells with condensation source term
nftcdt = nfbpcd
if (irangp.ge.0) then
  call parcpt(nftcdt)
endif

if (nftcdt.gt.0) then
  write(nfecra,2003) nftcdt
  write(nfecra,3000)
endif

! --------------
! 1D-wall module
! --------------

call init_1d_wall_thermal

call cs_user_1d_wall_thermal(iappel, isuit1)

nfpt1t = nfpt1d
if (irangp.ge.0) then
  call parcpt(nfpt1t)
endif

if (nfpt1t.gt.0) then
  write(nfecra,2004) nfpt1t, nfpt1d
  write(nfecra,3000)
endif

call cs_1d_wall_thermal_check(iappel, isuit1)

! Free memory if relevant
if (nctsmt.eq.0) deallocate(izctsm)
if (nfpt1t.eq.0) call cs_1d_wall_thermal_finalize

! Formats
 2002 format(                                    &
 /,/,'MASS SOURCE TERMS TREATMENT ACTIVATED ',/, &
   '                 ON A TOTAL OF ',I10,' CELLS')
 2003 format(                                            &
 /,/,'CONDENSATION SOURCE TERMS TREATMENT ACTIVATED ',/, &
   '                 ON A TOTAL OF ',I10,' CELLS')
 2004 format(                                               &
 /,'1D-WALL THERMAL MODULE ACTIVATED ',/,     &
   '   ON A TOTAL OF ',I10,' BOUNDARY FACES',/,             &
   '   (',I10,' LOCAL BOUNDARY FACES)',/)

!===============================================================================
! Memory management
!===============================================================================

call boundary_conditions_init

call init_aux_arrays(ncelet, nfabor)

call turbomachinery_init

if (ippmod(iatmos).ge.0) then
  call init_atmo_autom(nfabor)

  if (ifilechemistry.ge.1) then
    call init_chemistry_reacnum
  endif
endif

if (ippmod(icompf).ge.0) then
  call init_compf (nfabor)
endif

if (iale.ge.1) then
  call init_ale (nfabor, nnod)
endif

if (iflow.eq.1) ncpdct = ncpdct + 1

if (ncpdct.gt.0) then
  if (iflow .eq.1) then
    ncepdc = ncel
  else
    ncepdc = volume_zone_n_type_cells(VOLUME_ZONE_HEAD_LOSS)
  endif
  call init_kpdc
  if (iflow .eq.1) then
    do iel = 1, ncepdc
      icepdc(iel) = iel
    enddo
  else
    call volume_zone_select_type_cells(VOLUME_ZONE_HEAD_LOSS, icepdc)
  endif
endif

if (nctsmt.gt.0) then
  call init_tsma (nvar)
endif

if (nftcdt.gt.0) then
  call init_nz_pcond(nvar)
endif

if (icondv.eq.0) then
  call init_vcond ( nvar, ncelet )
endif

if (nfpt1t.gt.0) then
  call init_1d_wall_thermal_local_models
endif

! Map arrays from Lagrangian module
if (iilagr.gt.0) then
  call init_lagr_arrays(tslagr)
endif

if (i_les_balance.gt.0) then
  call les_balance_create
endif

!===============================================================================
! Default initializations
!===============================================================================

call fldtri

call field_allocate_or_map_all

call field_get_val_s_by_name('dt', dt)

call iniva0(nscal)

! Compute the porosity if needed
if (iporos.ge.1) then

  ! Make fluid surfaces of mesh quantity point to the created fields
  call cs_porous_model_set_has_disable_flag(1)

  call cs_porous_model_init_fluid_quantities()

  ! Compute porosity from scan
  if (compute_porosity_from_scan) then
    write(nfecra, *) " Compute porosity field from scan"
    write(nfecra, *) " WARNING: user porosity will be ignored"
    write(nfecra, *) " (GUI, usporo.f90, cs_user_porosity.c)"
    call cs_compute_porosity_from_scan()

    ! Note using porosity from scan: give the hand to the user
  else

    call uiporo
    call usporo

    ! C version
    call user_porosity

    call field_get_val_s(ipori, porosi)

    if (irangp.ge.0.or.iperio.eq.1) then
      call synsca(porosi)
    endif

    do iel = 1, ncelet
      ! Penalisation of solid cells
      if (porosi(iel).lt.epzero) then
        porosi  (iel) = 0.d0
        isolid_0(iel) = 1
      endif
      cell_f_vol(iel) = volume(iel) * porosi(iel)
    enddo

    ! For integral formulation, in case of 0 fluid volume, clip fluid faces
    if (iporos.eq.3) then
      do ifac = 1, nfac
        !TODO compute i_f_face_factor with porosi AND fluid surface and surface:
        ! epsilon_i*surface/f_surface
        if (isolid_0(ifacel(1, ifac)) .eq. 1) then
          suffac(1, ifac) = 0.d0
          suffac(2, ifac) = 0.d0
          suffac(3, ifac) = 0.d0
          suffan(ifac) = 0.d0
        else if (isolid_0(ifacel(2, ifac)).eq.1) then
          suffac(1, ifac) = 0.d0
          suffac(2, ifac) = 0.d0
          suffac(3, ifac) = 0.d0
          suffan(ifac) = 0.d0
        endif
      enddo

      do ifac = 1, nfabor
        !TODO compute i_f_face_factor with porosi AND fluid surface and surface:
        ! epsilon_i*surface/f_surface
        if (isolid_0(ifabor(ifac)) .eq. 1) then
          suffbo(1, ifac) = 0.d0
          suffbo(2, ifac) = 0.d0
          suffbo(3, ifac) = 0.d0
          suffbn(ifac) = 0.d0
        endif
      enddo
    endif

  endif

  if (iporos.eq.3) then
    ! Compute solid quantities and update fluid volume and porosity
    call cs_f_mesh_quantities_solid_compute()
  endif

  call cs_f_mesh_quantities_fluid_vol_reductions()

endif

!==============================================================================
! On appelle cs_user_wall_condensation lorqu'il y a sur un processeur
! au moins des cellules avec terme source de condensation.
! On ne fait que remplir le tableau d'indirection des cellules
! On appelle cependant cs_user_condensation avec tous les processeurs,
! au cas ou l'utilisateur aurait mis en oeuvre des operations globales.
!==============================================================================

if (nftcdt.gt.0) then

  iappel = 2

  call init_nz_tagmr

  call cs_user_wall_condensation(nvar, nscal, iappel)

  call cs_wall_condensation_set_model(icondb_model)

  call cs_user_wall_condensation(nvar, nscal, iappel)

  call init_nz_mesh_tagmr

  ! the Condensation model coupled with a 0-D thermal model
  ! to take into account the metal mass structures effects.
  if (itagms.eq.1) then
    call init_tagms
  endif

endif

!===============================================================================
! Initialization for the Synthetic turbulence Inlets
!===============================================================================

call cs_les_inflow_initialize

!===============================================================================
! Possible restart
!===============================================================================

! Timer statistics

restart_stats_id = timer_stats_id_by_name("checkpoint_restart_stage")
post_stats_id = timer_stats_id_by_name("postprocessing_stage")

if (isuite.eq.1) then

  call timer_stats_start(restart_stats_id)

  call cs_restart_map_build

  call lecamo

  ! Using ALE, geometric parameters must be recalculated
  if (iale.ge.1) then

    call field_get_val_v(fdiale, disale)
    call field_get_val_v_by_name("vtx_coord0", xyzno0)

    do inod = 1, nnod
      do idim = 1, ndim
        xyznod(idim,inod) = xyzno0(idim,inod) + disale(idim,inod)
      enddo
    enddo

    call cs_ale_update_mesh_quantities(volmin, volmax, voltot)

    ! Abort at the end of the current time-step if there is a negative volume
    if (volmin.le.0.d0) ntmabs = ntcabs

  endif

  ! Radiative module restart */
  if (iirayo.gt.0) then
    call cs_rad_transfer_read
  endif

  ! Lagrangian module restart (particles) */
  if (iilagr.gt.0) then
    call cs_restart_lagrangian_checkpoint_read()
  endif

  call cs_les_synthetic_eddy_restart_read

  ! TODO
  ! cs_restart_map_free may not be called yet, because
  ! cs_lagr_solve_initialize and the first call of cs_lagr_solve_time_step
  ! may also need restart data for particles and statistics respectively.
  ! This should be solved by moving the corresponding stages at least to
  ! cs_lagr_solve_initialize sor as to free mapping data before the time loop.

  if (iilagr.lt.1) then
    call cs_restart_map_free
  endif

  call timer_stats_stop(restart_stats_id)

endif

!===============================================================================
! Initializations (user and additional)
!    dt rom romb viscl visct viscls (tpucou with periodicity)
!===============================================================================

call inivar(nvar, nscal)

if (icdo.ge.1) then ! CDO mode
  call cs_f_domain_initialize_cdo_systems
endif

iterns = -1
call phyvar(nvar, nscal, iterns, dt)

!===============================================================================
! Initialization for the atmospheric soil model
!===============================================================================

if (ippmod(iatmos).ge.2) then
  call atmsol()
endif

!===============================================================================
! Initializations for the 1D thermal wall module
!===============================================================================

! On suppose que toutes les phases voient la meme temperature de paroi
! USPT1D a un fonctionnement similaire a USKPDC et USTSMA, mais comme
! on ecrit des infos dans un fichier suite, on a besoin d'une partie de
! la memoire meme apres la boucle en temps -> IFPT1D et TPPT1D
!                                            (IFNIA1 et IFNRA1)

! On appelle uspt1d lorqu'il y a sur un processeur au moins des faces de
!     bord avec module thermique 1D.

if (nfpt1t.gt.0) then
! Deuxieme appel : remplissage des tableaux de definition de la geometrie
!            et de l'initialisation (IFPT1D,NPPT1D,EPPT1D,RGPT1D,TPPT1D)
  iappel = 2
  call cs_user_1d_wall_thermal(iappel, isuit1)

  iappel = 2
  call cs_1d_wall_thermal_check(iappel, isuit1)

  if (isuit1.eq.1) then

    call cs_1d_wall_thermal_read

  else

    ! Create mesh, initialize temperature.
    call cs_1d_wall_thermal_mesh_create

  endif

endif

! First pass for the BCs:
! - initilalize itypfb, reference pressure point...
!--------------------------------------------------

! Deprecated, only for compatibility reason
nvarcl = nvar

call field_build_bc_codes_all(icodcl, rcodcl)
allocate(isostd(nfabor+1))

! First pass for initialization BC types
! -- Couplage code_saturne/code_saturne

call cscini(nvar)
call condli_ini(nvar, nscal, itrale, icodcl, isostd, dt, rcodcl)

deallocate(isostd)
call field_free_bc_codes_all(icodcl, rcodcl)

!===============================================================================
! Arrays for time block, to discard afterwards
!===============================================================================

!===============================================================================
! Arrays for time block, to discard afterwards
!===============================================================================

! Build volume mass injection cell lists when present on at least one rank.
! This is a collective call for consistency and in case the user requires it.

if (nctsmt.gt.0) then
  call cs_volume_mass_injection_build_lists(ncetsm, icetsm, izctsm)
endif

! -- Structures mobiles en ALE

if (iale.ge.1) then
  call strini(dt)
endif

! -- Fin de zone Structures mobiles en ALE

! Lagrangian initialization

if (iilagr.gt.0) then

  call timer_stats_start(lagr_stats_id)

  call cs_lagr_solve_initialize(dt)

  call timer_stats_stop(lagr_stats_id)

endif

! Solve CDO module(s) or user-defined equations using CDO schemes
!================================================================

if (icdo.eq.1) then
   ! FV and CDO activated
   call cs_f_cdo_solve_steady_state_domain
endif

! Logging of initial values

call log_iteration

!===============================================================================
! Start of time loop
!===============================================================================

write(nfecra,2000)

ntcabs = ntpabs
ttcabs = ttpabs

if (iturbo.eq.2)  ttcmob = ttpmob

write(nfecra,3000)

!     Nb d'iter ALE (nb relatif a l'execution en cours)
!     Si ITALIN=1, on fait une iteration d'initialisation
!     (si ITALIN=-999, c'est qu'on a fait une suite de calculs
!      sans relire lecamx -> comme si on faisait une suite
!      d'un calcul sans ALE)
if (italin.eq.-999) italin = 1
itrale = 1
if (italin.eq.1) then
  itrale = 0
  write(nfecra,3002) ttcabs
endif

! In case of code coupling, sync status with other codes.

if (itrale.gt.0) then

  if (idtvar.eq.0) then
    call cplsyn (ntmabs, ntcabs, dt(1))
  else if (idtvar.ne.1) then ! synchronization in dttvar if idtvar = 1
    call cplsyn (ntmabs, ntcabs, dtref)
  endif

  if (ntmabs .eq. ntcabs .and. ntmabs.gt.ntpabs) then
    call csexit(1)
  endif

endif

! Possible postprocessing of initialization values

call timer_stats_start(post_stats_id)

call post_activate_by_time_step
call cs_user_postprocess_activate(ntmabs, ntcabs, ttcabs)

call cs_post_default_write_variables

call timer_stats_stop(post_stats_id)

! Start time loop

 100  continue

if (ttmabs.gt.0 .and. ttmabs.gt.ttcabs) then
  ntmabs = ntcabs + int((ttmabs-ttcabs)/dtref)
  if (ntmabs.le.ntcabs) ntmabs = ntcabs + 1
endif

if (itrale.gt.0 .and. ntmabs.gt.ntpabs) then
  call timer_stats_increment_time_step
  if (idtvar.eq.0.or.idtvar.eq.1) then
    call cs_time_step_increment(dt(1))
  else
    call cs_time_step_increment(dtref)
  endif
  if (iturbo.eq.2) then
    if(idtvar.eq.0.or.idtvar.eq.1) then
      ttcmob = ttcmob + dt(1)
    else
      ttcmob = ttcmob + dtref
    endif
  endif
endif

!===============================================================================
! Step forward in time
!===============================================================================

! Test presence of control_file to modify ntmabs if required
call cs_control_check_file

if ((idtvar.eq.0 .or. idtvar.eq.1) .and. (ttmabs.gt.0)) then
  if (ttcabs.ge.ttmabs) then
    ntmabs = ntcabs
  else if (ntmabs.lt.0) then  ! Changed by control_file
    ntmabs = ntcabs + 1
  endif
endif

! Check for runaway (diverging) computation
ierr = cs_runaway_check()

! Set default logging (always log 10 first iterations and last one=)
log_active = .false.
if (ntcabs - ntpabs.le.10 .or. ntcabs.eq.ntmabs) then
  log_active = .true.
else if (ntlist.gt.0) then
  if (mod(ntcabs,ntlist) .eq. 0) log_active = .true.
endif
call cs_log_default_activate(log_active)

if (ntmabs.gt.ntpabs .and. itrale.gt.0) then
  if (log_active) then
    write(nfecra,3001) ttcabs, ntcabs
  endif
endif

mesh_modified = .false.
call cs_volume_zone_build_all(mesh_modified)
call cs_boundary_zone_build_all(mesh_modified)

call dmtmps(titer1)

call cs_log_iteration_prepare

call tridim(itrale, nvar, nscal, dt)

if ((nfpt1d > 0).AND.(mod(ntcabs,ntlist).eq.0)) call cs_1d_wall_thermal_log()

if (ntmabs.gt.ntpabs .and. itrale.gt.0) then

  ! Solve CDO module(s) or user-defined equations using CDO schemes
  !================================================================

  if (icdo.eq.1) then
     ! FV and CDO activated
     call cs_f_cdo_solve_unsteady_state_domain
  endif

  ! Lagrangian module
  !==================

  if (iilagr.gt.0) then

    call timer_stats_start(lagr_stats_id)

    call cs_lagr_solve_time_step(itypfb, dt)

    call timer_stats_stop(lagr_stats_id)

  endif

  ! Update gradients needed in LES balance computation
  !=============================================================================

  if (i_les_balance.gt.0) then
    call les_balance_update_gradients
  endif

  ! Compute temporal means (accumulation)
  !=============================================================================

  call time_moment_update_all

endif

!===============================================================================
! Update mesh (ALE)
!===============================================================================

if (iale.ge.1 .and. ntmabs.gt.ntpabs) then

  if (itrale.eq.0 .or. itrale.gt.nalinf) then
    call cs_ale_update_mesh(itrale)
  endif

endif

!===============================================================================
! Optional processing by user
!===============================================================================

if (itrale.gt.0) then

  call timer_stats_start(post_stats_id)

  ! 1D profiles postprocessing output

  call uiexop()

  call cs_f_user_extra_operations(nvar, nscal, dt)

  call user_extra_operations()

  if (i_les_balance.gt.0) then
    call les_balance_compute
  endif

  call timer_stats_stop(post_stats_id)

endif

!===============================================================================
! Stop tests
!===============================================================================

! Test for lack of remaining time

call armtps(ntcabs,ntmabs)

! Stop test for couplings

if (idtvar.eq.0) then
  call cplsyn (ntmabs, ntcabs, dt(1))
else if (idtvar.ne.1) then ! synchronization in dttvar if idtvar = 1
  call cplsyn (ntmabs, ntcabs, dtref)
endif

!===============================================================================
! Possible output of checkpoint files
!===============================================================================

call reqsui(iisuit)

if (ntcabs.lt.ntmabs .and.itrale.eq.0) iisuit = 0

if (iisuit.eq.1) then

  call timer_stats_start(restart_stats_id)

  if(ntcabs.lt.ntmabs) then
    write(nfecra,3020) ntcabs, ttcabs
  else if(ntcabs.eq.ntmabs) then
    write(nfecra,3021) ntcabs,ttcabs
  endif

  call ecrava

  if (iturbo.eq.2 .and. iecaux.eq.1) then
    call trbsui
  endif

  if (nfpt1t.gt.0) then
    call cs_1d_wall_thermal_write
  endif

  call cs_les_synthetic_eddy_restart_write

  if (iilagr.gt.0) then
    call cs_restart_lagrangian_checkpoint_write()
  endif

  if (iirayo.gt.0) then
    call cs_rad_transfer_write
  endif

  if (i_les_balance.gt.0) then
    call les_balance_write_restart
  endif

  call stusui

  ! Remove all unnecessary previous dumps of checkpoint files
  call restart_clean_multiwriters_history

  call timer_stats_stop(restart_stats_id)

endif ! iisuit = 1

!===============================================================================
! Test to determine if a visualization output is generated
!===============================================================================

call timer_stats_start(post_stats_id)

call post_activate_by_time_step

call cs_meg_post_activate;
call cs_user_postprocess_activate(ntmabs, ntcabs, ttcabs)

! If ITRALE=0, deactivate all writers, as geometry has not been output yet.
if (itrale.eq.0) then
  post_active = .false.
  call cs_post_activate_writer(0, post_active)
endif

!===============================================================================
! Standard visualization output
!===============================================================================

call cs_post_default_write_variables

! CDO module (user-defined equations)
!====================================

if (icdo.eq.1) then
  ! FV and CDO activated
  call cs_f_cdo_post_domain
endif

!===============================================================================
! Structures
!===============================================================================

if ((nthist.gt.0 .or.frhist.gt.0.d0) .and. itrale.gt.0) then

  modhis = -1
  if (frhist.gt.0.d0) then
    if ((ttcabs - ttchis) .gt. frhist*(1-1.0d-6)) then
      modhis = 1
    endif
  else if (nthist.gt.0 .and. mod(ntcabs, nthist).eq.0) then
    modhis = 1
  endif

  if (modhis.eq.1) then

    ttchis = ttcabs
    if (ihistr.eq.1) then
      call strhis(modhis)
    endif

  endif

endif

!===============================================================================
! Write to "run_solver.log" every ntlist iterations
!===============================================================================

if (log_active) then

  call ecrlis(ncelet, ncel, dt, cell_f_vol)

  call log_iteration

  call log_l2residual

endif

call timer_stats_stop(post_stats_id)

call dmtmps(titer2)

if (itrale.le.0) then
  write(nfecra,3012)titer2-titer1
endif

!===============================================================================
! End of time loop
!===============================================================================

itrale = itrale + 1

if (ntcabs.lt.ntmabs) goto 100

! Final synchronization for variable time step

if (idtvar.eq.1) then
  call cplsyn (ntmabs, ntcabs, dtref)
endif

! LIBERATION DES TABLEAUX INTERMEDIAIRES (PDC+TSM)

if (isuite.eq.1.and.iilagr.gt.0) then
  call timer_stats_start(restart_stats_id)
  call cs_restart_map_free
  call timer_stats_stop(restart_stats_id)
endif

!===============================================================================
! Finalize probes
!===============================================================================

write(nfecra,4000)

call timer_stats_start(post_stats_id)

modhis = 2

if (ihistr.eq.1) then
  call strhis(modhis)
endif

call timer_stats_stop(post_stats_id)

if (nfpt1d.gt.0) then
  call cs_1d_wall_thermal_free
endif

! Free main arrays

call turbomachinery_finalize

call radiat_finalize

call turbulence_bc_free_pointers
call boundary_conditions_finalize

call finalize_aux_arrays

call finalize_meteo

if (ippmod(iatmos).ge.0) then

  if(imbrication_flag)then
    call finalize_imbrication
  endif

  call cs_at_data_assim_finalize

  if (ifilechemistry.ge.1) then
    call finalize_chemistry
  endif

endif

if (ippmod(icompf).ge.0) then
  call finalize_compf
endif

if (ippmod(islfm).ge.0) then
  call finalize_steady_laminar_flamelet_library
endif

if (ippmod(igmix).ge.0) then
  call finalize_gas_mix
endif

if (iale.ge.1) then
  call finalize_ale
endif

if (ncpdct.gt.0) then
  call finalize_kpdc
endif

if (nctsmt.gt.0) then
  call finalize_tsma
endif

if(nftcdt.gt.0) then
  call finalize_nz_pcond
  if (nztag1d.eq.1) then
    call finalize_nz_mesh_tagmr
    call finalize_nz_tagmr
  endif
endif

if (icondv.eq.0) then
  call finalize_vcond
  if (itagms.eq.1) then
    call finalize_tagms
  endif
endif

if (nfpt1d.gt.0) then
  call cs_1d_wall_thermal_finalize
endif

if (i_les_balance.gt.0) then
  call les_balance_finalize
endif

write(nfecra,7000)

!----
! Formats
!----

 2000 format(/,/,                                                 &
'===============================================================',&
                                                              /,/,&
                                                                /,&
                                                                /,&
'                       MAIN CALCULATION'                      ,/,&
'                       ================'                      ,/,&
                                                                /,&
                                                                /,&
'===============================================================',&
                                                              /,/,&
                                                                /)
 3000 format(/,                                                   &
'===============================================================',&
 /)
 3001 format(/,' INSTANT ',E18.9,        '   TIME STEP NUMBER ' ,I15,/,  &
' =============================================================' ,&
 /,/)
 3002 format(/,' INSTANT ',E18.9,        '   ALE INITIALIZATION' ,/,    &
' =============================================================' ,&
 /,/)
 3012 format(/,' TIME FOR ALE INITIALIZATION:        ',E14.5,/,/, &
'===============================================================',&
 /)
 3020 format(/,/,                                                 &
 ' Write intermediate restart files',/,                           &
 '   checkpoint at iteration ',    I10,  ', Physical time ',E14.5,/,/)
 3021 format(/,/,                                                 &
 ' Write final restart files',/,                                  &
 '   checkpoint at iteration ',    I10,  ', Physical time ',E14.5,/,/)

 4000 format(/,/,                                                 &
'===============================================================',&
                                                              /,/,&
                                                                /,&
                                                                /,&
'                 FINAL STAGE OF THE CALCULATION'              ,/,&
'                 =============================='              ,/,&
                                                                /,&
                                                                /,&
' =========================================================== ',/,&
                                                                /,&
                                                                /)
 7000 format(/,/,                                                 &
' ===========================================================' ,/,&
                                                              /,/,&
                                                                /,&
                                                                /,&
'                      END OF CALCULATION'                     ,/,&
'                      =================='                     ,/,&
                                                                /,&
                                                                /,&
'===============================================================')

!----
! End
!----

return
end subroutine
