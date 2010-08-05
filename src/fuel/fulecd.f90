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

subroutine fulecd
!================

!===============================================================================
!  FONCTION  :
!  ---------

! LECTURE DU FICHIER DE DONNEES PHYSIQUE PARTICULIERE
!      RELATIF A LA COMBUSTION FUEL

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
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
use entsor
use cstnum
use cstphy
use ppppar
use ppthch
use coincl
use cpincl
use fuincl
use ppincl
use ppcpfu

!===============================================================================

implicit none

! Arguments

! Local variables

character *150 chain1,chain2
character *12   nomcoe(ngazem)

integer          it     , ice    , iat    , ios
integer          ncoel  , inicoe
integer          icla
integer          idebch , ifinch , lonch  , ichai  , ichcoe
integer          atcoel(ngazem,natom), inicha

double precision tmin   , tmax
double precision wmolce(ngazem), ehcoel(ngazem,npot)
double precision cpcoel(ngazem,npot)
double precision ncfov,nhfov,nofov,nsfov
double precision mhsfov,mcofov,mchfov,mtofov
double precision nhsfov,ncofov,ncmv,nhmv
double precision ch2fv,ch4fv,h02fov,yo2ox

!===============================================================================
!==================================================
! 1. LECTURE DU FICHIER DONNEES SPECIFIQUES
!==================================================

! --> Ouverture du fichier

open ( unit=impfpp, file=ficfpp,                                  &
        STATUS='OLD', FORM='FORMATTED', ACCESS='SEQUENTIAL',      &
                                        iostat=ios, err=99 )
rewind (unit=impfpp,err=99 )

! --> Lecture thermochimie

read (impfpp,*,err=999,end=999 )

! ---- Nb de constituants elementaires (gazeux,liquide et solide)

read ( impfpp,*,err=999,end=999 ) ncoel
if ( ncoel.gt.ngazgm ) then
  write(nfecra,9991) ngazgm,ncoel
  call csexit (1)
endif

! ---- Nb de points de tabulation ENTH-TEMP

read ( impfpp,*,err=999,end=999 ) npo
if ( npo.gt.npot ) then
  write(nfecra,9992) npot,npo
  call csexit (1)
endif

! --- Lecture des noms des constituants elementaires

do ice=1,ncoel
  do inicoe=1,len(nomcoe(ice))
    NOMCOE(ICE)(INICOE:INICOE)=' '
  enddo
enddo

do inicha=1,len(chain1)
  CHAIN1(INICHA:INICHA)=' '
enddo

do inicha=1,len(chain2)
  CHAIN2(INICHA:INICHA)=' '
enddo

read (impfpp,*,err=999,end=999)
!     READ (IMPFPP,*,ERR=999,END=999) CHAIN2
read (impfpp,1010,err=999,end=999 ) chain1
call verlon (chain1, idebch, ifinch, lonch)
chain2(1:lonch)=chain1(idebch:ifinch)

ice=1
ichcoe=0
do ichai = 1, lonch
  IF (CHAIN2(ICHAI:ICHAI).NE.' ') THEN
    ichcoe=ichcoe+1
    nomcoe(ice)(ichcoe:ichcoe) =chain2(ichai:ichai)
  else
    if (ichcoe.ne.0) then
      ice=ice+1
      ichcoe=0
    endif
  endif
enddo

 1010 format(a150)

! --- Temperature Min et Max

read (impfpp,*,err=999,end=999) tmin
read (impfpp,*,err=999,end=999) tmax


! ---- Nb especes atomiques (C, H, O, N, ...)

read (impfpp,*,err=999,end=999 ) nato
if ( nato.gt.natom ) then
  write(nfecra,9993) natom,nato
  call csexit (1)
  !==========
endif

! ---- Masse molaire especes atomiques
!      Composition des constituants elementaires en fonction
!        des especes elementaires

do iat = 1, nato
  read (impfpp,*,err=999,end=999 ) wmolat(iat),                   &
                      ( atcoel(ice,iat),ice=1,ncoel )
enddo

! ---- Calcul des masses molaires des constituants elementaires

do ice = 1, ncoel
  wmolce(ice) = 0.d0
  do iat = 1, nato
    wmolce(ice)= wmolce(ice) + atcoel(ice,iat)*wmolat(iat)
  enddo
enddo


! --> Lecture rayonnement

read (impfpp,*,err=999,end=999 )

! ---- Coefficient d'absorption du melange gazeux

read (impfpp,*,err=999,end=999 ) ckabs1


! --> Lecture caracteristiques fuel

read (impfpp,*,err=999,end=999 )

! ---- Nb de classes de fuel

read (impfpp,*,err=999,end=999 ) nclafu

! --> Diametre initial  (mm)

read (impfpp,*,err=999,end=999 ) ( dinifl(icla),icla=1,nclafu )

! --> Composition elementaire en C, H, O, S, In (% en masse)
!     In d�signe les inertes (m�taux, etc.) qui resteront
!        dans le r�sidu solide

read (impfpp,*,err=999,end=999 ) cfol
read (impfpp,*,err=999,end=999 ) hfol
read (impfpp,*,err=999,end=999 ) ofol
read (impfpp,*,err=999,end=999 ) sfol

cfol = 1.d-2 * cfol
hfol = 1.d-2 * hfol
ofol = 1.d-2 * ofol
sfol = 1.d-2 * sfol
xinfol = 1.d0-cfol-hfol-ofol-sfol
if (xinfol .lt. zero) then
   WRITE(NFECRA,*)'Erreur dans les fractions massiques du FOL'
!         STOP
endif
WRITE (NFECRA,*) 'Fractions massiques elementaires / FOL  '
WRITE (NFECRA,*) ' C = ',CFOL
WRITE (NFECRA,*) ' H = ',HFOL
WRITE (NFECRA,*) ' O = ',OFOL
WRITE (NFECRA,*) ' S = ',SFOL
WRITE (NFECRA,*) ' In= ',XINFOL


! --> PCI

read (impfpp,*,err=999,end=999 ) pcifol

! --> CP moyen du fuel sec (J/kg/K)

read (impfpp,*,err=999,end=999 ) cp2fol

! --> Masse volumique initiale (kg/m3)

read (impfpp,*,err=999,end=999 ) rho0fl

! --> Caracteristiques du coke

read (impfpp,*,err=999,end=999)

! ------- Composition elementaire en C, H, O, S (% / pur)

read (impfpp,*,err=999,end=999 ) ckf
read (impfpp,*,err=999,end=999 ) hkf
read (impfpp,*,err=999,end=999 ) okf
read (impfpp,*,err=999,end=999 ) skf

ckf = 1.d-2 * ckf
hkf = 1.d-2 * hkf
okf = 1.d-2 * okf
skf = 1.d-2 * skf

if ( abs(ckf+hkf+okf+skf-1.d0) .gt. 1.d-15 ) then
  write(nfecra,9990) ckf+hkf+okf+skf
  call csexit(1)
endif

! ------ PCI

read (impfpp,*,err=999,end=999 ) pcikf

! ---- Fraction de coke dans le fuel

read (impfpp,*,err=999,end=999) fkc
WRITE (NFECRA,*)' Fraction massique de coke / FOL'
write (nfecra,*) fkc

!     Les inertes restent dans le coke
xinkf = zero
if ( fkc .gt. zero) xinkf = xinfol/fkc
if ( (ckf+hkf+okf+skf) .gt. 1.d0) then
   WRITE(NFECRA,*)'Erreur dans les fractions massiques du KF'
!         STOP
endif

WRITE (NFECRA,*) 'Fractions massiques elementaires / coke '
WRITE (NFECRA,*) ' C = ',CKF*(1.D0-XINKF)
WRITE (NFECRA,*) ' H = ',HKF*(1.D0-XINKF)
WRITE (NFECRA,*) ' O = ',OKF*(1.D0-XINKF)
WRITE (NFECRA,*) ' S = ',SKF*(1.D0-XINKF)
WRITE (NFECRA,*) ' In= ',XInKF

!     Compatibilite des fractions massiques et des formules mol�culaires
!     masses �l�mentaires dans le fuel, le coke, les vapeurs
!        F      K        MV
!   C    CFOL   CKF*FKC  CFOL-CKF*FKC
!   H    HFOL   HKF*FKC  HFOL-HKF*FKC
!   O    OFOL   OKF*FKC  OFOL-OKF*FKC
!   S    SFOL   SKF*FKC  SFOL-SKF*FKC
!   In   XInFOL  XInFOL    0
!      elements dans les vapeurs
ncfov  = (cfol-ckf*fkc*(1.d0-xinkf))/wmolat(iatc)/(1.d0-fkc)
nhfov  = (hfol-hkf*fkc*(1.d0-xinkf))/wmolat(iath)/(1.d0-fkc)
nofov  = (ofol-okf*fkc*(1.d0-xinkf))/wmolat(iato)/(1.d0-fkc)
nsfov  = (sfol-skf*fkc*(1.d0-xinkf))/wmolat(iats)/(1.d0-fkc)
!       on consid�re que S se d�gage sous forme H2S
!                    que O                      CO
nhsfov = nsfov
ncofov = nofov
ncmv   = ncfov - ncofov
nhmv   = nhfov - 2.d0*nhsfov

!   Les vapeurs sont alors constitu�es de nHSFOV moles de H2S
!                                         nCOFOV          CO
!                                         nCMV            CHn
!   o� CHn est un hydrocarbure mod�le de formule moyenne avec
nhcfov  = nhmv/ncmv
WRITE(NFECRA,*) ' nHCFOV = ',NHCFOV ,NHMV,NCMV

!   Les masses dans les vapeurs sont
mhsfov = (wmolat(iats)+2.d0*wmolat(iath))*nhsfov
mcofov = (wmolat(iatc)+wmolat(iato))*ncofov
mchfov = wmolat(iatc)*ncmv+wmolat(iath)*nhmv
mtofov = mhsfov+mcofov+mchfov

WRITE(NFECRA,*) ' mtoFOV = ',MTOFOV

!   Les fractions massiques dans les vapeurs sont
hsfov = mhsfov / mtofov
cofov = mcofov / mtofov
chfov = mchfov / mtofov
WRITE (NFECRA,*) 'Fractions massiques sp�cifiques / FOV '
WRITE (NFECRA,*) ' H2S = ',HSFOV
WRITE (NFECRA,*) ' CO  = ',COFOV
WRITE (NFECRA,*) ' CHn = ',CHFOV
WRITE (NFECRA,*) ' ..n = ',nHCFOV
ch4fv = zero
ch2fv = chfov
if ( nhcfov.ge.2.d0 .and. nhcfov.le.4.d0 ) then
  WRITE(NFECRA,*) 'Le FOV est equivalent a un melange '
  ch2fv = 2.d0-0.5d0*nhcfov
   ch4fv = (1-ch2fv)*16.d0/(12.d0+nhcfov)
   ch2fv = ch2fv*14.d0/(12.d0+nhcfov)
   ch4fv = ch4fv * chfov
   ch2fv = ch2fv * chfov
   WRITE (NFECRA,*) ' H2S = ',HSFOV
   WRITE (NFECRA,*) ' CO  = ',COFOV
   WRITE (NFECRA,*) ' CH4 = ',CH4FV
   WRITE (NFECRA,*) 'C2H4 = ',CH2FV
endif
WRITE(NFECRA,*) ' nHCFOV 2 = ',NHCFOV

! ---- Parametre d'evaporation

 read (impfpp,*,err=999,end=999) tevap1
 read (impfpp,*,err=999,end=999) tevap2

! ---- Parametres combustion heterogene (modele a sphere retrecissante)

read (impfpp,*,err=999,end=999 )

read (impfpp,*,err=999,end=999 ) ahetfl
read (impfpp,*,err=999,end=999 ) ehetfl
read (impfpp,*,err=999,end=999 ) iofhet

! --> Fermeture du fichier (ne pas oublier, car l'unite sert pour janaf)

close(impfpp)

!==============================================
! 2.
!==============================================


! --> Discretisation de la temperature

do it = 1, npo
  th(it) = dble(it-1)*(tmax-tmin)/dble(npo-1) + tmin
enddo

! --> Calcul des enthalpies pour les differentes especes courantes

call pptbht                                                       &
!==========
 ( ncoel  ,                                                       &
   nomcoe , ehcoel , cpcoel , wmolce )

! --> Calcul tabulation enthalpie - temperature pour le melange gazeux

! ---- Nb de constituants gazeux
!     ATTENTION ON COMPTE EGALEMENT H2S et le monomere SO2

ngaze = 8

! ---- Definition des pointeurs pour les tableaux WMOLE et EHGAZE
!      REMARQUE : Cette position de pointeurs va egalement servir
!                 pour le tableau de pointeurs IYM1 relatif aux
!                 tableaux PROPCE et PROPFB
!                 ON BALAYE JUSTE DE 1 A NGAZE

!     ATTENTION : ordre des esp�ces dans EHCOEL, WMOLCE
!                 vient du fichier data_FUE
!     Actuellement 1   CH4
!                  2   C2H4
!                  3   CO
!                  4   O2
!                  5   CO2
!                  6   H2O
!                  7   N2
!                  8   C (solide)
!                  9   H2S
!                 10   SO2
ifov = 1
ico  = 2
ih2s = 3
ih2o = 4
ico2 = 5
iso2 = 6
io2  = 7
in2  = 8

! ---- Remplissage de EHGAZE et WMOLE
!         a partir de EHCOEL et WMOLCE

do it = 1, npo
  ehgaze(ifov ,it) = ( ch4fv*ehcoel(1,it) + ch2fv*ehcoel(2,it) )
  ehgaze(ico  ,it) = ehcoel( 3,it)
  ehgaze(io2  ,it) = ehcoel( 4,it)
  ehgaze(ico2 ,it) = ehcoel( 5,it)
  ehgaze(ih2o ,it) = ehcoel( 6,it)
  ehgaze(in2  ,it) = ehcoel( 7,it)
  ehgaze(ih2s ,it) = ehcoel( 9,it)
  ehgaze(iso2 ,it) = ehcoel(10,it)
enddo
wmole(ifov ) = (ch4fv+ch2fv)/(ch4fv/wmolce(1)+ch2fv/wmolce(2))

wmole(ifov ) = (1.d0*0.012d0 + nhcfov *0.001d0 )
WRITE(NFECRA,*) ' Wmole IFOV = ',WMOLE(IFOV ),CH4FV,CH2FV
wmole(ico  ) = wmolce( 3)
wmole(io2  ) = wmolce( 4)
wmole(ico2 ) = wmolce( 5)
wmole(ih2o ) = wmolce( 6)
wmole(in2  ) = wmolce( 7)
wmole(ih2s ) = wmolce( 9)
wmole(iso2 ) = wmolce(10)

!     Concentrations dans les vapeurs
afovf1 = chfov / wmole(ifov)
acof1  = cofov / wmole(ico)
ah2sf1  = hsfov / wmole(ih2s)
!      Caract�risation de l'oxydant
yo2ox = wmole(io2) / (wmole(io2)+xsi*wmole(in2))
!     Caract�ristion des gaz issus de la combustion h�t�rog�ne
!      Max est le point o� F3 est maximal ; il correspond � un
!      m�lange stoechiometrique de coke et d'oxydant
!      On suppose, pour l'instant, que l'oxydant est un melange O2, N2
!      � modifier si recyclage de fum�es
!      FF3MAX(CKF*C+OKF*O+SKF*S+HKF*H) + (1-F3max)*(YO2Ox*O2+(1-YO2Ox)*N2) =>
!            CO + H2O + H2S + N2
!      On suppose que S est prioritaire pour H
!      Masse de C dans les r�actants FF3MAX*CKF
!      Masse de O                    FF3MAX*OKF + (1-F3max)*YO2Ox
!      Masse de S                    FF3MAX*SKF
!      Masse de H                    FF3MAX*HKF
!      Masse de N                    (1-FF3MAX)*(1-YO2Ox)
!      Nombre de C                   FF3MAX*CKF / WMOLAT(IATC)
!      Nombre de O                   (FF3MAX*OKF+(1-F3max*YO2Ox)/WMOLAT(IATO)
!      Nombre de S                   FF3MAX*SKF / WMOLAT(IATS)
!      Nombre de H                   FF3MAX*HKF / WMOLAT(IATH)
!      Nombre de moles de H2S dans les produits = nombre de moles de S
!      Nombre de moles de H2O dans les produits = 1/2 nombre H-nb moles H2S
!      Nombre de moles de CO = nombre de moles de C
!      Nombre de moles de O dans les produits = nb moles CO + H2O
!      Et il vient :
!      FF3MAX * ( CKF/WMOLAT(IATC) + 0.5*HKF/WOLAT(IATH) - SKF/WMOLAT(IATS)
!                -OKF/WMOALT(IATO) - YO2Ox/WOLAT(IATO) )
!      =     YO2Ox/WMOLAT(IATO)

!      FF3MAX = YO2Ox /(0.016*(CKF/.012 + 0.5*HKF/.001 -SKF/.032)-OKF+YO2Ox)

 ff3max = yo2ox/(wmolat(iato)*(ckf/wmolat(iatc)                   &
                       +0.5d0*hkf/wmolat(iath)                    &
                             -skf/wmolat(iats))                   &
                -okf + yo2ox)

!      AXXF3 nb de moles de l'esp�ce XX en kilog de F3 calcules en FF3MAX
 ah2sf3 = ff3max*skf/wmolat(iats)
 ah2of3 = 0.5d0*ff3max*hkf/wmolat(iath)-ah2sf3
 acof3  = ff3max*ckf/wmolat(iatc)

!       AO2F3  = 0.5d0*FF3MAX*(     OKF/WMOLAT(IATO)-CKF/WMOLAT(IATC)
!     &                       -0.5*HKF/WMOLAT(IATH)+SKF/WMOLAT(IATS))
 ao2f3  = 0.d0

 an2f3  = (1.d0-yo2ox)/wmole(in2) * (1.d0-ff3max)

 ao2f4 = yo2ox/wmole(io2)
 an2f4 = (1.d0-yo2ox)/wmole(in2)

!      Avec cette convention la concentration en O2 est n�gative en FF3MAX
!      ceci correspond � l'oxyg�ne absorb� par la r�action h�t�rog�ne.

! --> Calcul tabulation enthalpie - temperature pour la phase dispersee
!     Fuel Oil Liquid et  Coke

! ---- Nb de constituants solide

nsolid = 2

! ---- Definition des pointeurs IFOL et IKF

ifol = 1
ikf = 2

! ------ Calcul de H02FOL

!       H0, EH & PCI en J/kg
!       CFOL, HFOL sont des fractions massiques �l�mentaires
!       rapports des masses molaires des produits aux �l�ments du
!                combustible (le comburant est dans l'�tat de r�f.)

! ------ Calcul de HRFVAP

!  L'enthalpie de formation du fuel gazeux est connue (m�lange CH4, C2H4),
!  Le PCI du fuel liquide est connu , on peut donc reconstituer son
!   enthalpie de formation (on n�glige l'effet de H2S => SO2)
!   on introduit les enthalpies de formation massique du CO2 et de H2O

  h02fol = pcifol                                                 &
         + cfol * 44.d0/12.d0 * ehcoel(5,1)                       &
         + hfol * 18.d0/2.d0  * ehcoel(6,1)
!       H02FOL en J/kg (de fol)
!       L'enthalpie de formation de la vapeur de fuel
!       est suppos�e etre des celle des seuls hydrocarbures
!       (i.e. on n�glige, pour l'instant, CO et H2S)
  h02fov = ch4fv * ehcoel(1,1) + ch2fv * ehcoel(2,1)
!  L'enthalpie de formation du coke peut-�tre consid�r�e nulle
!  (pas loin du graphite)

!  L'enthalpie de changement de phase est donc celle de la r�action
!  Fuel_Liquide => FKC*Coke + (1-FKC)*Fuel_Vapeur
  hrfvap =  (1.d0-fkc)*h02fov-h02fol

  WRITE(NFECRA,*) 'Donnees thermo pour le fuel'
  WRITE(NFECRA,*) 'PCIFOL ',PCIFOL
  WRITE(NFECRA,*) 'H02FOL ',H02FOL
  WRITE(NFECRA,*) 'CP2FOL ',CP2FOL
  WRITE(NFECRA,*) 'HRFVAP ',HRFVAP
  WRITE(NFECRA,*) 'H02FOV ',H02FOV

!  L'enthalpie de la r�action h�t�rog�ne est directement celle de la
!  formation d'une  mole de CO � partir de carbone � l'�tat de r�f�rence
!  il est d'usage d'ajouter cette enthalpie � celle de la phase
!  dispers�e

! ------ Calcul de EHSOLI pour le fuel
!        Si CP2FOL > 0 : HFOL = H02FOL + CP2FOL(T2-TREFTH)

    do it = 1, npo
      ehsoli(ifol,it) = h02fol                                    &
                            + cp2fol * ( th(it) - trefth )
    enddo

! ---- Calcul relatif au coke

! ------ Coke = CH(GAMMA)O(DELTA)

!        On considere le PCI constant qqs T

!          Soit le PCI est connu et fourni dans le fichier
!          soit on consid�re qu'il est entierement fourni
!          par la combustion de la fraction carbone
!          suppos�e � l'�tat de r�f�rence
 do it = 1, npo
    ehsoli(ikf,it) = cp2fol * ( th(it) - trefth )
 enddo

WRITE(NFECRA,*) ' Verification des enthalpies de formation'
WRITE(NFECRA,*) ' CH4  ',EHCOEL(1,1)
WRITE(NFECRA,*) ' C2H4 ',EHCOEL(2,1)
WRITE(NFECRA,*) ' FOV  ',EHGAZE(IFOV,1)
WRITE(NFECRA,*) ' FOL  ',EHSOLI(IFOL,1)
WRITE(NFECRA,*) ' KF   ',EHSOLI(IKF,1)

!     Masse Vol + Diametre (en milimetres)
!        on suppose que les masse vol sont les memes
!        pour le fuel, coke et residu

rhokf  = rho0fl
do icla = 1, nclafu
  dinikf(icla) = dinifl(icla)*(fkc*rho0fl/rhokf)**(1.d0/3.d0)
  diniin(icla) = dinifl(icla)*(xinfol*rho0fl/rho0fl)**(1.d0/3.d0)
  WRITE(NFECRA,*) ' Classe D = ',ICLA,DINIFL(ICLA),DINIKF(ICLA),  &
                                      diniin(icla)
enddo

return


!============================
! 3. SORTIE EN ERREUR
!============================

  99  continue
write ( nfecra,9998 )
call csexit (1)
!==========

  999 continue
write ( nfecra,9999 )
call csexit (1)
!==========
!--------
! FORMATS
!--------


 9990 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES (FULECD)      ',/,&
'@    =========                                               ',/,&
'@      PHYSIQUE PARTICULIERE (FUEL)                          ',/,&
'@                                                            ',/,&
'@  Erreur sur la composition du Coke :                       ',/,&
'@   la somme des compositions elementaires doit etre egal    ',/,&
'@   a 1, elle vaut ici : ',G15.7,'                           ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier le fichier parametrique.                         ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 9991 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES (FULECD)      ',/,&
'@    =========                                               ',/,&
'@      PHYSIQUE PARTICULIERE (FUEL)                          ',/,&
'@                                                            ',/,&
'@  Le nombre d''especes courantes doit etre inferieur        ',/,&
'@                                  ou egal a',I10             ,/,&
'@   Il vaut ',I10   ,' dans le fichier parametrique          ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier le fichier parametrique.                         ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 9992 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES (FULECD)      ',/,&
'@    =========                                               ',/,&
'@      PHYSIQUE PARTICULIERE (FUEL)                          ',/,&
'@                                                            ',/,&
'@  Le nombre de points de tabulation est limite a ',I10       ,/,&
'@   Il vaut ',I10   ,' dans le fichier parametrique          ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier le fichier parametrique.                         ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 9993 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES (FULECD)      ',/,&
'@    =========                                               ',/,&
'@      PHYSIQUE PARTICULIERE (FUEL)                          ',/,&
'@                                                            ',/,&
'@  Le nombre d''especes elementaires est limite a ',I10       ,/,&
'@   Il vaut ',I10   ,' dans le fichier parametrique          ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier le fichier parametrique.                         ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 9998 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES (FULECD)      ',/,&
'@    =========                                               ',/,&
'@      PHYSIQUE PARTICULIERE (FUEL)                          ',/,&
'@                                                            ',/,&
'@  Erreur a l''ouverture du fichier parametrique.            ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 9999 format(                                                           &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES (FULECD)      ',/,&
'@    =========                                               ',/,&
'@      PHYSIQUE PARTICULIERE (FUEL)                          ',/,&
'@                                                            ',/,&
'@  Erreur a la lecture du fichier parametrique.              ',/,&
'@    Le fichier a ete ouvert mais est peut etre incomplet    ',/,&
'@    ou son format inadapte.                                 ',/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

end subroutine


