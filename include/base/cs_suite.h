/*============================================================================
 *
 *     This file is part of the Code_Saturne Kernel, element of the
 *     Code_Saturne CFD tool.
 *
 *     Copyright (C) 1998-2008 EDF S.A., France
 *
 *     contact: saturne-support@edf.fr
 *
 *     The Code_Saturne Kernel is free software; you can redistribute it
 *     and/or modify it under the terms of the GNU General Public License
 *     as published by the Free Software Foundation; either version 2 of
 *     the License, or (at your option) any later version.
 *
 *     The Code_Saturne Kernel is distributed in the hope that it will be
 *     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
 *     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with the Code_Saturne Kernel; if not, write to the
 *     Free Software Foundation, Inc.,
 *     51 Franklin St, Fifth Floor,
 *     Boston, MA  02110-1301  USA
 *
 *============================================================================*/

#ifndef __CS_SUITE_H__
#define __CS_SUITE_H__

/*============================================================================
 *  Gestion des fichiers suite
 *============================================================================*/

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


/*----------------------------------------------------------------------------
 *  Fichiers `include' librairie standard C
 *----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
 *  Fichiers `include` librairies BFT et FVM
 *----------------------------------------------------------------------------*/

#include <fvm_defs.h>

/*----------------------------------------------------------------------------
 *  Fichiers `include' locaux
 *----------------------------------------------------------------------------*/

#include "cs_base.h"


/*============================================================================
 *  D�finitions d'�numerations
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Fichier en lecture ou �criture
 *----------------------------------------------------------------------------*/

typedef enum {

  CS_SUITE_MODE_LECTURE,         /* Communication en r�ception                */
  CS_SUITE_MODE_ECRITURE         /* Communication en �mission                 */

} cs_suite_mode_t;


/*----------------------------------------------------------------------------
 *  Type de support de maillage associ� � une rubrique
 *----------------------------------------------------------------------------*/

typedef enum {

  CS_SUITE_SUPPORT_SCAL,         /* Scalaire (sans support)                   */
  CS_SUITE_SUPPORT_CEL,          /* Valeurs associ�es aux cellules            */
  CS_SUITE_SUPPORT_FAC_INT,      /* Valeurs associ�es aux faces internes      */
  CS_SUITE_SUPPORT_FAC_BRD,      /* Valeurs associ�es aux faces de bord       */
  CS_SUITE_SUPPORT_SOM           /* Valeurs associ�es aux sommets             */

} cs_suite_support_t;


/*============================================================================
 *  D�finition de macros
 *============================================================================*/

/* Codes d'erreur */

#define CS_SUITE_SUCCES          0 /* R�ussite */
#define CS_SUITE_ERR_NUM_FIC    -1 /* Pas de suite du num�ro indiqu� */
#define CS_SUITE_ERR_TYPE_FIC   -2 /* Type de fichier incorrect */
#define CS_SUITE_ERR_SUPPORT    -3 /* Support ind�fini/dimension incorrecte */
#define CS_SUITE_ERR_TYPE_VAL   -4 /* Type de valeur inconnu ou impr�vu */
#define CS_SUITE_ERR_NBR_VAL    -5 /* Nombre de valeurs ne correspond pas */
#define CS_SUITE_ERR_MODE       -6 /* Mode d'ouverture incompatible */
#define CS_SUITE_ERR_EXISTE     -7 /* Enregistrement non disponible */


/*============================================================================
 *  D�claration de structures
 *============================================================================*/

/*
  Pointeur associ� � un fichier suite. La structure elle-m�me est d�clar�e
  dans le fichier "cs_suite.c", car elle n'est pas n�cessaire ailleurs.
*/

typedef struct _cs_suite_t cs_suite_t;


/*=============================================================================
 * D�finitions de variables globales
 *============================================================================*/


/*============================================================================
 *  Fonctions publiques pour API Fortran
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Ouverture d'un fichier suite
 *
 * Interface Fortran :
 *
 * SUBROUTINE OPNSUI (NOMSUI, LNGNOM, IREAWR, NUMSUI, IERROR)
 * *****************
 *
 * CHARACTER*       NOMSUI      : --> : Nom du fichier suite
 * INTEGER          LNGNOM      : --> : Longueur du nom du fichier suite
 * INTEGER          IREAWR      : --> : 1 pour lecture, 2 pour �criture
 * INTEGER          NUMSUI      : <-- : Num�ro du fichier suite ouvert
 * INTEGER          IERROR      : <-- : 0 pour succ�s, < 0 pour erreur
 *----------------------------------------------------------------------------*/

void CS_PROCF (opnsui, OPNSUI)
(
 const char       *const nomsui,  /* --> Nom du fichier                       */
 const cs_int_t   *const lngnom,  /* --> Longueur du nom                      */
 const cs_int_t   *const ireawr,  /* --> 1 pour lecture, 2 pour �criture      */
       cs_int_t   *const numsui,  /* <-- Num�ro du ficher suite ouvert        */
       cs_int_t   *const ierror   /* <-- 0 pour succ�s, < 0 pour erreur       */
                                  /*     (> 0, ou < 0 en cas d'erreur)        */
 CS_ARGF_SUPP_CHAINE              /*     (arguments 'longueur' �ventuels F77, */
                                  /*     inutilis�s lors de l'appel mais      */
                                  /*     plac�s par de nombreux compilateurs) */
);


/*----------------------------------------------------------------------------
 * Fermeture d'un fichier suite
 *
 * Interface Fortran :
 *
 * SUBROUTINE CLSSUI (NUMSUI)
 * *****************
 *
 * INTEGER          NUMSUI      : <-> : num�ro du fichier suite � fermer
 * INTEGER          IERROR      : <-- : 0 pour succ�s, < 0 pour erreur
 *----------------------------------------------------------------------------*/

void CS_PROCF (clssui, CLSSUI)
(
 const cs_int_t   *const numsui,  /* <-> Num�ro du ficher suite � fermer      */
       cs_int_t   *const ierror   /* <-- Num�ro du ficher suite ouvert        */
);


/*----------------------------------------------------------------------------
 *  V�rification du support associ� � un fichier suite ;
 *  On renvoie pour chaque type d'entit� 1 si le nombre d'entit�s associ�es
 *  au fichier suite correspond au nombre d'entit�s en cours (et donc que
 *  l'on consid�re que le support est bien le m�me), 0 sinon.
 *
 * Interface Fortran :
 *
 * SUBROUTINE TSTSUI (NUMSUI, INDCEL, INDFAC, INDFBR, INDSOM)
 * *****************
 *
 * INTEGER          NUMSUI      : --> : Num�ro du fichier suite
 * INTEGER          INDCEL      : <-- : Indicateur corresp. cellules
 * INTEGER          INDFAC      : <-- : Indicateur corresp. faces internes
 * INTEGER          INDFBR      : <-- : Indicateur corresp. faces de bord
 * INTEGER          INDSOM      : <-- : Indicateur corresp. sommets
 *----------------------------------------------------------------------------*/

void CS_PROCF (tstsui, TSTSUI)
(
 const cs_int_t  *const numsui,   /* --> Num�ro du fichier suite              */
       cs_int_t  *const indcel,   /* <-- Indicateur corresp. cellules         */
       cs_int_t  *const indfac,   /* <-- Indicateur corresp. faces internes   */
       cs_int_t  *const indfbr,   /* <-- Indicateur corresp. faces de bord    */
       cs_int_t  *const indsom    /* <-- Indicateur corresp. sommets          */
);


/*----------------------------------------------------------------------------
 *  Affichage de l'index associ� � un fichier suite
 *
 * Interface Fortran :
 *
 * SUBROUTINE INFSUI (NUMSUI)
 * *****************
 *
 * INTEGER          NUMSUI      : --> : Num�ro du fichier suite
 *----------------------------------------------------------------------------*/

void CS_PROCF (infsui, INFSUI)
(
 const cs_int_t  *const numsui    /* --> Num�ro du fichier suite              */
);


/*----------------------------------------------------------------------------
 * Lecture d'une rubrique sur fichier suite
 *
 * Interface Fortran :
 *
 * SUBROUTINE LECSUI (NUMSUI, NOMRUB, LNGNOM, ITYSUP, NBVENT, IRTYPE, TABVAR)
 * *****************
 *
 * INTEGER          NUMSUI      : --> : Num�ro du fichier suite
 * CHARACTER*       NOMRUB      : --> : Nom de la rubrique
 * INTEGER          LNGNOM      : --> : Longueur du nom de la rubrique
 * INTEGER          ITYSUP      : --> : Type de support :
 *                              :     :  0 : scalaire (pas de support)
 *                              :     :  1 : cellules
 *                              :     :  2 : faces internes
 *                              :     :  3 : faces de bord
 *                              :     :  4 : sommets (si disponibles)
 * INTEGER          NBVENT      : --> : Nb. valeurs par entit� de support
 * INTEGER          IRTYPE      : --> : 1 pour entiers, 2 pour double pr�cision
 * (?)              TABVAR      : <-> : Tableau des valeurs � lire
 * INTEGER          IERROR      : <-- : 0 pour succ�s, < 0 pour erreur
 *----------------------------------------------------------------------------*/

void CS_PROCF (lecsui, LECSUI)
(
 const cs_int_t   *const numsui,  /* --> Num�ro du fichier suite              */
 const char       *const nomrub,  /* --> Nom de la rubrique                   */
 const cs_int_t   *const lngnom,  /* --> Longueur du nom de la rubrique       */
 const cs_int_t   *const itysup,  /* --> Type de support (voir ci-dessus)     */
 const cs_int_t   *const nbvent,  /* --> Nb. valeurs par entit� du support    */
 const cs_int_t   *const irtype,  /* --> 1 pour entiers, 2 pour double pr�c.  */
       void       *const tabvar,  /* <-- Tableur des valeurs � lire           */
       cs_int_t   *const ierror   /* <-- 0 pour succ�s, < 0 pour erreur       */
 CS_ARGF_SUPP_CHAINE              /*     (arguments 'longueur' �ventuels F77, */
                                  /*     inutilis�s lors de l'appel mais      */
                                  /*     plac�s par de nombreux compilateurs) */
);


/*----------------------------------------------------------------------------
 * �criture d'une rubrique sur fichier suite
 *
 * Interface Fortran :
 *
 * SUBROUTINE ECRSUI (NUMSUI, NOMRUB, LNGNOM, ITYSUP, NBVENT, IRTYPE, TABVAR)
 * *****************
 *
 * INTEGER          NUMSUI      : --> : Num�ro du fichier suite
 * CHARACTER*       NOMRUB      : --> : Nom de la rubrique
 * INTEGER          LNGNOM      : --> : Longueur du nom de la rubrique
 * INTEGER          ITYSUP      : --> : Type de support :
 *                              :     :  0 : scalaire (pas de support)
 *                              :     :  1 : cellules
 *                              :     :  2 : faces internes
 *                              :     :  3 : faces de bord
 *                              :     :  4 : sommets (si disponibles)
 * INTEGER          NBVENT      : --> : Nb. valeurs par entit� de support
 * INTEGER          IRTYPE      : --> : 1 pour entiers, 2 pour double pr�cision
 * (?)              TABVAR      : --> : Tableau des valeurs fournies
 * INTEGER          IERROR      : <-- : 0 pour succ�s, < 0 pour erreur
 *----------------------------------------------------------------------------*/

void CS_PROCF (ecrsui, ECRSUI)
(
 const cs_int_t   *const numsui,  /* --> Num�ro du fichier suite              */
 const char       *const nomrub,  /* --> Nom de la rubrique                   */
 const cs_int_t   *const lngnom,  /* --> Longueur du nom de la rubrique       */
 const cs_int_t   *const itysup,  /* --> Type de support (voir ci-dessus)     */
 const cs_int_t   *const nbvent,  /* --> Nb. valeurs par entit� du support    */
 const cs_int_t   *const irtype,  /* --> 1 pour entiers, 2 pour double pr�c.  */
 const void       *const tabvar,  /* --> Tableur des valeurs fournies         */
       cs_int_t   *const ierror   /* <-- 0 pour succ�s, < 0 pour erreur       */
 CS_ARGF_SUPP_CHAINE              /*     (arguments 'longueur' �ventuels F77, */
                                  /*     inutilis�s lors de l'appel mais      */
                                  /*     plac�s par de nombreux compilateurs) */
);


/*============================================================================
 *  Prototypes de fonctions publiques
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Fonction qui initialise un fichier suite
 *----------------------------------------------------------------------------*/

cs_suite_t * cs_suite_cree
(
 const char             *const nom,         /* --> nom de base du fichier     */
 const cs_suite_mode_t         mode         /* --> Lecture ou �criture        */
);


/*----------------------------------------------------------------------------
 *  Fonction qui d�truit la structure associ�e � un fichier suite (et ferme
 *  le fichier associ�) ; elle renvoie un pointeur NULL.
 *----------------------------------------------------------------------------*/

cs_suite_t * cs_suite_detruit
(
 cs_suite_t * suite                         /* --> Fichier suite              */
);


/*----------------------------------------------------------------------------
 *  Fonction qui v�rifie les supports de base associ� � un fichier suite ;
 *  On renvoie pour chaque type d'entit� true si le nombre d'entit�s
 *  associ�es au fichier suite correspond au nombre d'entit�s en cours (et
 *  donc que l'on consid�re que le support est bien le m�me), false sinon.
 *----------------------------------------------------------------------------*/

void cs_suite_verif_support_base
(
 const cs_suite_t  *const suite,            /* --> Fichier suite              */
       cs_bool_t   *const corresp_cel,      /* <-- Corresp. cellules          */
       cs_bool_t   *const corresp_fac,      /* <-- Corresp. faces internes    */
       cs_bool_t   *const corresp_fbr,      /* <-- Corresp. faces de bord     */
       cs_bool_t   *const corresp_som       /* <-- Corresp. sommets           */
);


/*----------------------------------------------------------------------------
 * Add a location definition.
 *
 * parameters:
 *   suite           <-- associated restart file pointer
 *   location_name   <-- name associated with the location
 *   n_glob_ents     <-- global number of entities
 *   n_ents          <-- local number of entities
 *   ent_global_num  <-- global entity numbers, or NULL
 *
 * returns:
 *   the location id assigned to the location, or -1 in case of error
 *----------------------------------------------------------------------------*/

int
cs_suite_ajoute_support(cs_suite_t        *suite,
                        const char        *location_name,
                        fvm_gnum_t         n_glob_ents,
                        fvm_lnum_t         n_ents,
                        const fvm_gnum_t  *ent_global_num);

/*----------------------------------------------------------------------------
 *  Fonction qui affiche l'index g�n�r� lors de l'analyse du fichier
 *----------------------------------------------------------------------------*/

void cs_suite_affiche_index
(
 const cs_suite_t  *const  suite          /* --> Structure suite              */
);


/*----------------------------------------------------------------------------
 *  Fonction qui lit un enregistrement sur fichier suite ; On renvoie 0
 *  (CS_SUITE_SUCCES) en cas de succ�s, une valeur n�gative (de type
 *  CS_SUITE_ERR_xxx) en cas d'�chec.
 *----------------------------------------------------------------------------*/

cs_int_t cs_suite_lit_rub
(
       cs_suite_t  *suite,                     /* --> Ptr. structure suite    */
 const char        *nom_rub,                   /* --> Nom de la rubrique      */
       int          ind_support,               /* --> Support de la variable  */
       cs_int_t     nbr_val_ent,               /* --> Nb. val/point support   */
       cs_type_t    typ_val,                   /* --> Type de valeurs         */
       void        *val                        /* <-- Valeurs � lire          */
);


/*----------------------------------------------------------------------------
 *  Fonction qui ecrit un enregistrement sur fichier suite
 *----------------------------------------------------------------------------*/

void cs_suite_ecr_rub
(
       cs_suite_t  *suite,                     /* --> Ptr. structure suite    */
 const char        *nom_rub,                   /* --> Nom de la rubrique      */
       int          ind_support,               /* --> Support de la variable  */
       cs_int_t     nbr_val_ent,               /* --> Nb. val/point support   */
       cs_type_t    typ_val,                   /* --> Type de valeurs         */
 const void        *val                        /* <-- Valeurs � lire          */
);


/*----------------------------------------------------------------------------
 *  Fonction qui initialise l'API Fortran
 *----------------------------------------------------------------------------*/

void cs_suite_f77_api_init
(
 void
);


/*----------------------------------------------------------------------------
 *  Fonction qui termine l'API Fortran
 *----------------------------------------------------------------------------*/

void cs_suite_f77_api_finalize
(
 void
);


#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __CS_SUITE_H__ */
