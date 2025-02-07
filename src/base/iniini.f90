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

!> \file iniini.f90
!> \brief Commons default initialization before handing over the user.
!>
!------------------------------------------------------------------------------

subroutine iniini

!===============================================================================
! Module files
!===============================================================================

use atincl
use paramx
use cstnum
use dimens
use numvar
use optcal
use cstphy
use rotation
use entsor
use pointe
use albase
use alstru
use alaste
use parall
use period
use cplsat
use ppincl
use ppcpfu
use mesh
use field
use vof
use cavitation
use darcy_module
use radiat
use turbomachinery
use cs_nz_condensation, only: nzones, init_sizes_pcond
use ctincl
use cfpoin
use vof
use cs_c_bindings

!===============================================================================

implicit none

! Local variables

integer          ii, jj, iscal, iest
integer          istr

!===============================================================================

!===============================================================================
! 0. STOCKAGE DES ARGUMENTS ET IMPRESSIONS INITIALES
!===============================================================================

write(nfecra, 900)

 900  format(/,                                                   &
'===============================================================',&
/,/,                                                        &
'                   CALCULATION PREPARATION'                   ,/,&
'                   ======================='                   ,/,&
                                                                /,&
                                                                /,&
' ===========================================================' ,/,&
                                                                /,&
                                                                /)

!===============================================================================
! 0. Global field keys
!===============================================================================

call field_get_key_id("label", keylbl)
call field_get_key_id('log', keylog)
call field_get_key_id('post_vis', keyvis)

call field_get_key_id("inner_mass_flux_id", kimasf)
call field_get_key_id("boundary_mass_flux_id", kbmasf)

call field_get_key_id("diffusivity_id", kivisl)
call field_get_key_id("diffusivity_ref", kvisl0)

call field_get_key_id("is_temperature", kscacp)

call field_get_key_id("density_id", kromsl)

call field_get_key_id("gradient_weighting_id", kwgrec)

call field_get_key_id("source_term_prev_id", kstprv)
call field_get_key_id("source_term_id", kst)

call field_get_key_id("turbulent_schmidt", ksigmas)

call field_get_key_id("turbulent_flux_ctheta", kctheta)

icrom = -1
ibrom = -1

ipori = -1
iporf = -1

!===============================================================================
! 1. Map Fortran pointers to C global data
!===============================================================================

call atmo_init
call time_step_init
call time_step_options_init
call thermal_model_init
call turb_model_init
call turb_rans_model_init
call turb_les_model_init
call turb_model_constants_init
call wall_functions_init
call physical_constants_init
call porosity_from_scan_init
call fluid_properties_init
call space_disc_options_init
call time_scheme_options_init
call velocity_pressure_options_init
call restart_auxiliary_options_init
call turb_reference_values_init
call listing_writing_period_init
call radiat_init
call gas_mix_options_init
call ctwr_properties_init
call map_ale
call cf_model_init
call vof_model_init
call cavitation_model_init

call map_turbomachinery_model(iturbo, ityint)
call init_sizes_pcond()

!===============================================================================
! 2. ENTREES SORTIES entsor.f90
!===============================================================================

! ---> NFECRA vaut 6 par defaut ou 9 en parallele (CSINIT)

! ---> Fichier aval

!     NTSUIT : Periode de sauvegarde du fichier suite
!            (il est de toutes facons ecrit en fin de calcul)
!              -1   : a la fin seulement
!              0    : par defaut (4 fois par calcul)
!              > 0  : periode

ntsuit = 0

! ---> Fichier thermochinie
!        FPP : utilisateur
!        JNF : Janaf
!        Les deux fichiers peuvent partager la meme unite
!          puisqu'ils sont lus l'un a pres l'autre.
!      En prime, INDJON (janaf=1 ou non=0)

impfpp = 25
ficfpp = 'define_ficfpp_in_usppmo'

indjon = 1

! ---> Fichiers module atmospherique
call atmo_set_meteo_file_name('meteo')

! ---> Fichiers historiques

!     EMPHIS : EMPlacement
!     PREHIS : PREfixe
!     EXTHIS : EXTension
!     IMPSTH : fichier stock + unite d'ecriture des variables
!              des structures mobiles

impsth(1) = 30
impsth(2) = 31

emphis = 'monitoring/'
prehis = 'probes_'

! tplfmt : time plot format (1: .dat, 2: .csv, 3: both)
! nthist : periode de sortie (> 0 ou -1 (jamais))
! frhist : frequence de sortie, en secondes (prioritaire sur nthist si > 0)
! ihistr : indicateur d'ecriture des historiques des structures
!          mobiles internes (=0 ou 1)

tplfmt = 1

nthist = 1
frhist = -1.d0

ihistr = 0

! ---> Fichiers utilisateurs

do ii = 1, nusrmx
  impusr(ii) = 69+ii
enddo

! ---> Sorties log

ntlist = 1

! Ici entsor.f90 est completement initialise

!===============================================================================
! 3. DIMENSIONS DE dimens.f90 (GEOMETRIE, sauf NCELBR)
!===============================================================================

! Geometry

ncel   = 0
ncelet = 0
nfac   = 0
nfabor = 0
nnod   = 0
lndfac = 0
lndfbr = 0

ncelgb = 0
nfacgb = 0
nfbrgb = 0
nsomgb = 0

! By default, assume no periodicity
iperio = 0
iperot = 0

! Get mesh metadata.

call ledevi(iperio, iperot)
!==========

call tstjpe(iperio, iperot)
!==========

!===============================================================================
! 4. DIMENSIONS de dimens.f90 (PHYSIQUE)
!===============================================================================

! --- Nombre de scalaires, de scalaires a diffusivite
!            variable, de variables, de proprietes

nscal  = 0
nscaus = 0
nscapp = 0
nvar   = 0

!===============================================================================
! 5. POSITION DES VARIABLES DE numvar.f90
!===============================================================================

! --- Initialize mappings of field ids

do ii = 1, nvarmx
  ivarfl(ii) = -1
enddo

idtten = -1

! Solved varible ids (for Fortran boundary conditions access)

ipr    = 0
iu     = 0
iv     = 0
iw     = 0
ik     = 0
iep    = 0
ir11   = 0
ir22   = 0
ir33   = 0
ir12   = 0
ir13   = 0
ir23   = 0
irij   = 0
iphi   = 0
ifb    = 0
ial    = 0
inusa  = 0

iuma = 0
ivma = 0
iwma = 0

do iscal = 1, nscamx
  isca  (iscal) = 0
  iscapp(iscal) = 0
  iscasp(iscal) = 0
enddo

! --- Initialisation par defaut des commons pour la physique particuliere

call ppinii
!==========

! --- Proprietes physiques au sens large
irom   = -1
iviscl = -1
ivisct = -1
icour  = -1
ifour  = -1
icp    = -1
iprtot = -1

itemp  = -1
ibeta  = -1

iforbr = -1
iyplbr = -1
itempb = -1

! --- Ici tout numvar est initialise.

!===============================================================================
! 6. OPTIONS DU CALCUL : TABLEAUX DE optcal.f90
!===============================================================================

! --- Schema en temps

!     NOTER BIEN que les valeurs de THETA pour
!       rho, visc, cp, flux de masse, termes sources
!       sont renseignees a partir des indicateurs I..EXT et ISTMPF
!       Elles ne sont pas completees directement par l'utilisateur
!       Les tests dans l'algo portent sur ces indicateurs


!   -- Flux de masse (-999 = non initialise)
!     = 1 Standard d'ordre 1
!     = 0 Explicite
!     = 2 Ordre deux
istmpf = -999


!   -- Termes sources Navier Stokes
!     Pour les termes sources explicites en std, I..EXT definit
!       l'extrapolation -theta ancien + (1+theta) nouveau
!     = 0 explicite
!     = 1 extrapolation avec theta = 1/2
!     = 2 extrapolation avec theta = 1
!       0 implique pas de reservation de tableaux
!       1 et 2 sont deux options equivalentes, la difference etant faite
!       uniquement au moment de fixer theta
!     Pour les termes sources implicites en std, I..EXT definit
!       la mise a l'ordre 2 ou non avec le thetav de la variable associee
!     = 0 implicite (std)
!     > 0 utilisation du thetav
!     Noter cpdt que le TS d'acc. masse n'est pas regi par I..EXT
!       (il suit bilsc2)
isno2t = -999
thetsn =-999.d0

!    -- Proprietes physiques
!     I..EXT definit l'extrapolation -theta ancien + (1+theta) nouveau
!     = 0 explicite
!     = 1 extrapolation avec theta = 1/2
!     = 2 extrapolation avec theta = 1
!       0 implique pas de reservation de tableaux
!       1 et 2 sont deux options equivalentes, la difference etant faite
!       uniquement au moment de fixer theta
!     INIT.. =1 indique que la variable a ete proprement initialisee (dans un
!       fichier suite portant les valeurs adaptees)

!     Masse volumique
initro = 0
!     Viscosite totale
thetvi = -999.d0
initvi = 0
!     Chaleur specifique
thetcp = -999.d0
initcp = 0

!   -- Convergence point fixe vitesse pression
epsup  = 1.d-5

!   -- Tab de travail pour normes de navsto
xnrmu0 = 0.d0
xnrmu  = 0.d0

do iscal = 1, nscamx

!   -- Termes sources des scalaires
!     Pour les termes sources explicites en std, I..EXT definit
!       l'extrapolation -theta ancien + (1+theta) nouveau
!     = 0 explicite
!     = 1 extrapolation avec theta = 1/2
!     = 2 extrapolation avec theta = 1
!       0 implique pas de reservation de tableaux
!       1 et 2 sont deux options equivalentes, la difference etant faite
!       uniquement au moment de fixer theta
!     Pour les termes sources implicites en std, I..EXT definit
!       la mise a l'ordre 2 ou non avec le thetav de la variable associee
!     = 0 implicite (std)
!     > 0 utilisation du thetav
!     Noter cpdt que le TS d'acc. masse n'est pas regi par I..EXT
!       (il suit bilsc2)
  isso2t(iscal) = -999
  thetss(iscal) =-999.d0

!    -- Proprietes physiques
!     I..EXT definit l'extrapolation -theta ancien + (1+theta) nouveau
!     = 0 explicite
!     = 1 extrapolation avec theta = 1/2
!     = 2 extrapolation avec theta = 1
!       0 implique pas de reservation de tableaux
!       1 et 2 sont deux options equivalentes, la difference etant faite
!       uniquement au moment de fixer theta
!     INIT.. =1 indique que la variable a ete proprement initialisee (dans un
!       fichier suite portant les valeurs adaptees)

  thetvs(iscal) = -999.d0
  initvs(iscal) = 0

enddo

! Method to compute interior mass flux due to ALE mesh velocity
! default: based on cell center mesh velocity
iflxmw = 0

! Restarted calculation
!   The restart indicator of the 1D wall thermal model is initialized by default
!   to -1, to force the user to set it in uspt1d.
!   The same goes for the synthetic turbulence method restart indicator.

isuite = 0
isuit1 = -1

! Time stepping (value not already in C)

ttpmob = 0.d0
ttcmob = ttpmob

do ii = 1, nvarmx
  cdtvar(ii) = 1.d0
enddo

! Thermal model

! No thermal scalar by default
itherm = 0
itpscl = 0
iscalt =-1

! No enthalpy for the gas (combustion) by default
ihgas = -1

! --- Turbulence
!     Le modele de turbulence devra etre choisi par l'utilisateur
!     En fait on n'a pas besoin d'initialiser ITYTUR (cf. varpos)
!     On suppose qu'il n'y a pas de temperature

iturb  =-999
itytur =-999
hybrid_turb  = 0

! Parfois, IGRHOK=1 donne des vecteurs non physiques en paroi
!        IGRHOK = 1
igrhok = 0
igrake = 1
iclkep = 0
irijnu = 0
irijrb = 0
irijec = 0
igrari = 1
idifre = 1
iclsyr = 1
iclptr = 0
idries =-1
ikwcln = 1

! --- Rotation/curvature correction of turbulence models
!     Unactivated by default
!     Correction type (itycor) is set in fldvar
irccor = 0
itycor = -999

! --- Algorithm to take into account the thermodynamic pressure variation in time
!     (not used by default except if idilat = 3)

ipthrm = 0

! Call predfl subroutine?
ipredfl = 0

!     by default:
!     ----------
!      - the thermodynamic pressure (pther) is initialized with p0 = p_atmos
!      - the maximum thermodynamic pressure (pthermax) is initialized with -1
!        (no maximum by default, this term is used to model a venting effect when
!         a positive value is given by the user)
!      - a global leak can be set through a leakage surface sleak with a head
!      loss kleak of 2.9 (Idelcick)

pther  = -1.d0
pthermax= -1.d0

sleak = 0.d0
kleak = 2.9d0

! --- Radiative Transfert (not activated by default)
iirayo = 0

! --- Initialize the zones number for the condensation modelling
nzones = -1

! ---  Choice the way to compute to compute the wall temperature at
!      the solid/fluid interface coupled with condensation to the
!      metalli mass strucutres wall
!      ( not activated by default itagms =0)

itagms = 0

! --- Type des CL, tables de tri
!       Sera calcule apres cs_user_boundary_conditions.

do ii = 1, ntypmx
  idebty(ii) = 0
  ifinty(ii) = 0
enddo

ifrslb = 0
itbslb = 0

! --- Estimateurs d'erreur pour Navier-Stokes
!       En attendant un retour d'experience et pour l'avoir,
!       on active les estimateurs par defaut.

!     Le numero d'estimateur IEST prend les valeurs suivantes
!        IESPRE : prediction
!                 L'estimateur est base sur la grandeur
!                 I = rho_n (u*-u_n)/dt + rho_n u_n grad u*
!                   - rho_n div (mu+mu_t)_n grad u* + grad P_n
!                   - reste du smb(u_n, P_n, autres variables_n)
!                 Idealement nul quand les methodes de reconstruction
!                   sont parfaites et le systeme est resolu exactement
!        IESDER : derive
!                 L'estimateur est base sur la grandeur
!                 I = div (flux de masse corrige apres etape pression)
!                 Idealement nul quand l'equation de Poisson est resolue
!                   exactement
!        IESCOR : correction
!                 L'estimateur est base sur la grandeur
!                 I = div (rho_n u_(n+1))
!                 Idealement nul quand IESDER est nul et que le passage
!                   des flux de masse aux faces vers les vitesses au centre
!                   se fait dans un espace de fonctions a divergence nulle.
!        IESTOT : total
!                 L'estimateur est base sur la grandeur
!                 I = rho_n (u_(n+1)-u_n)/dt + rho_n u_(n+1) grad u_(n+1)
!                   - rho_n div (mu+mu_t)_n grad u_(n+1) + gradP_(n_+1)
!                   - reste du smb(u_(n+1), P_(n+1), autres variables_n)
!                 Le flux du terme convectif est calcule a partir de u_(n+1)
!                   pris au centre des cellules (et non pas a partir du flux
!                   de masse aux faces actualise)

!     On evalue l'estimateur IEST selon les valeurs de IESCAL

!        iescal(iest) = 0 : l'estimateur IEST n'est pas calcule
!        iescal(iest) = 1 : l'estimateur IEST   est     calcule,
!                         sans contribution du volume  (on prend abs(I))
!        iescal(iest) = 2 : l'estimateur IEST   est     calcule,
!                         avec contribution du volume ("norme L2")
!                         soit abs(I)*SQRT(Volume_cellule),
!                         sauf pour IESCOR : on calcule abs(I)*Volume_cellule
!                         pour mesurer l'ecart en kg/s


do iest = 1, nestmx
  iescal(iest) = 0
enddo

! --- Somme de NCEPDC (pour les calculs paralleles)

ncpdct = 0

! --- Somme de NCETSM (pour les calculs paralleles)

nctsmt = 0

! --- Somme de nfbpcd (pour les calculs paralleles)

nftcdt= 0

!     Non utilisateur

! --- Calcul de la distance a la paroi
!     Seules variables utilisateur : ICDPAR

ineedy = 0
imajdy = 0
icdpar = -999

! --- LES balance
i_les_balance = 0

! --- Ici tout optcal.f90 est initialise

!===============================================================================
! TABLEAUX DE cstphy.f90
!===============================================================================

! --- Gravite

gx = 0.d0
gy = 0.d0
gz = 0.d0

! --- Vecteur rotation

icorio = 0

! --- Physical constants initialized in C (cs_physical_constants.c)

! Reset pther to p0
pther = p0

! --- Turbulence
!     YPLULI est mis a -GRAND*10. Si l'utilisateur ne l'a pas specifie dans usipsu, on
!     modifie sa valeur dans modini (10.88 avec les lois de paroi invariantes,
!     1/kappa sinon)
ypluli = -grand*10.d0
xkappa  = 0.42d0
cstlog  = 5.2d0

apow    = 8.3d0
bpow    = 1.d0/7.d0
cpow    = apow**(2.d0/(1.d0-bpow))
dpow    = 1.d0/(1.d0+bpow)

!   pour le k-epsilon
ce4     = 1.20d0

!   pour le k-epsilon quadratic (Baglietto)
cnl1  = 0.8d0
cnl2  = 11.d0
cnl3  = 4.5d0
cnl4  = 1.d3
cnl5  = 1.d0

!   pour le Rij-epsilon LRR (et SSG pour crij3)
crij1  = 1.80d0
crij2  = 0.60d0
crij3  = 0.55d0
crijp1 = 0.50d0
crijp2 = 0.30d0

!   pour le Rij-epsilon SSG
cssgs1  = 1.70d0
cssgs2  =-1.05d0
cssgr1  = 0.90d0
cssgr2  = 0.80d0
cssgr3  = 0.65d0
cssgr4  = 0.625d0
cssgr5  = 0.20d0
cssge2  = 1.83d0

!   Rij EB-RSM
cebms1  = 1.70d0
cebms2  = 0.d0
cebmr1  = 0.90d0
cebmr2  = 0.80d0
cebmr3  = 0.65d0
cebmr4  = 0.625d0
cebmr5  = 0.20d0
cebme2  = 1.83d0
cebmmu  = 0.22d0
xcl     = 0.122d0
xa1     = 0.1d0
xceta   = 80.d0
xct     = 6.d0

!   pour le v2f phi-model
cv2fa1 = 0.05d0
cv2fe2 = 1.85d0
cv2fc1 = 1.4d0
cv2fc2 = 0.3d0
cv2fct = 6.d0
cv2fcl = 0.25d0
cv2fet = 110.d0

!   pour le v2f BL-v2/k (previously known as v2-f phi-alpha, hence the cpal**)
cpale1 = 1.44d0
cpale2 = 1.83d0
cpale3 = 2.3d0
cpale4 = 0.4d0
cpalct = 4.d0
cpalcl = 0.164d0
cpalet = 75.d0
cpalc1 = 1.7d0
cpalc2 = 0.9d0

!   pour le modele k-omega sst
ckwsk1 = 1.d0/0.85d0
ckwsk2 = 1.d0
ckwsw1 = 2.d0
ckwsw2 = 1.d0/0.856d0
ckwbt1 = 0.075d0
ckwbt2 = 0.0828d0
ckwgm1 = ckwbt1/cmu - xkappa**2/(ckwsw1*sqrt(cmu))
ckwgm2 = ckwbt2/cmu - xkappa**2/(ckwsw2*sqrt(cmu))
ckwa1  = 0.31d0
ckwc1  = 10.d0

! pour la ddes
cddes = 0.65d0

! pour le sas
csas  = 0.11d0
csas_eta2 = 3.51d0

!   pour le modele de Spalart Allmaras
csab1    = 0.1355d0
csab2    = 0.622d0
csav1    = 7.1d0
csasig   = 2.d0/3.d0
csaw1    = csab1/xkappa**2 + 1.d0/csasig*(1.d0 + csab2)
csaw2    = 0.3d0
csaw3    = 2.d0

! for the Spalart-Shur rotation/curvature correction
cssr1 = 1.d0
cssr2 = 2.d0
cssr3 = 1.d0

! Scalars
!  Set default values.
!  Especially, assume there is no variance
!    (field first_moment_id < 0) and that variances are clipped to 0 only.

do iscal = 1, nscamx
  rvarfl(iscal) = 0.8d0
enddo

! For the AFM model (Algebraic flux model)
xiafm  = 0.7d0
etaafm = 0.4d0
cthafm = 0.236d0

! For the DFM (tranport equation on the turbulent flux)
cthdfm = 0.31d0
! For the EB-DFM model (0.122*2.5d0, See F. Dehoux thesis)
cthebdfm = 0.22d0
xclt   = 0.305d0
rhebdfm = 0.5d0

! --- Ici tout cstphy a ete initialise

!===============================================================================
! INITIALISATION DES PARAMETRES ALE de albase.f90 et alstru.f90
!===============================================================================

! --- Iterations d'initialisation fluide seul
nalinf = 0

! --- Nombre de structures internes
!     (sera relu ou recalcule)
nbstru = -999

! --- Nombre de structures externes
!     (sera relu ou recalcule)
nbaste = -999

! --- Numero d'iteration de couplage externe
ntcast = 0

! --- Parametres du couplage implicite
nalimx = 1
epalim = 1.d-5

! --- Iteration d'initialisation de l'ALE
italin = -999

! --- Tableaux des structures
do istr = 1, nstrmx
  dtstr(istr) = dtref
  do ii = 1, 3
    xstr(ii,istr)   = 0.d0
    xpstr(ii,istr)  = 0.d0
    xppstr(ii,istr) = 0.d0
    xsta(ii,istr)   = 0.d0
    xpsta(ii,istr)  = 0.d0
    xppsta(ii,istr) = 0.d0
    xstp(ii,istr)   = 0.d0
    forstr(ii,istr) = 0.d0
    forsta(ii,istr) = 0.d0
    forstp(ii,istr) = 0.d0
    xstreq(ii,istr) = 0.d0
    do jj = 1, 3
      xmstru(ii,jj,istr) = 0.d0
      xcstru(ii,jj,istr) = 0.d0
      xkstru(ii,jj,istr) = 0.d0
    enddo
  enddo
enddo

! --- Schema de couplage des structures
aexxst = -grand
bexxst = -grand
cfopre = -grand

! --- Methode de Newmark HHT
alpnmk = 0.d0
betnmk = -grand
gamnmk = -grand

!===============================================================================
! INITIALISATION DES PARAMETRES DE COUPLAGE CS/CS
!===============================================================================

! --- Nombre de couplage
nbrcpl = 0

! --- Couplage uniquement par les faces
ifaccp = 0

!===============================================================================
! Lagrangian arrays
!===============================================================================

tslagr => rvoid2

return
end subroutine
