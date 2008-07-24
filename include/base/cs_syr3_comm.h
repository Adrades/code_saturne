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

#ifndef __CS_SYR3_COMM_H__
#define __CS_SYR3_COMM_H__

/*============================================================================
 *  Communications avec d'autres codes (Syrthes)
 *============================================================================*/

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


/*----------------------------------------------------------------------------
 *  Fichiers `include' librairie standard C
 *----------------------------------------------------------------------------*/


/*----------------------------------------------------------------------------
 *  Fichiers `include' locaux
 *----------------------------------------------------------------------------*/

#include "cs_base.h"


/*============================================================================
 *  Definitions d'enumerations
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Type de message
 *----------------------------------------------------------------------------*/

typedef enum {

  CS_SYR3_COMM_TYPE_BINAIRE,     /* Messages par fichiers binaires            */
  CS_SYR3_COMM_TYPE_MPI,         /* Messages MPI                              */
  CS_SYR3_COMM_TYPE_SOCKET       /* Messages par sockets IP                   */

} cs_syr3_comm_type_t;


/*----------------------------------------------------------------------------
 *  Emission ou reception de message
 *----------------------------------------------------------------------------*/

typedef enum {

  CS_SYR3_COMM_MODE_RECEPTION,   /* Communication en reception                */
  CS_SYR3_COMM_MODE_EMISSION     /* Communication en emission                 */

} cs_syr3_comm_mode_t;


/*============================================================================
 *  Definition de macros
 *============================================================================*/

#define CS_SYR3_COMM_FIN_FICHIER                           "EOF"
#define CS_SYR3_COMM_CMD_ARRET                        "cmd:stop"
#define CS_SYR3_COMM_CMD_ITER_DEB                 "cmd:iter:deb"
#define CS_SYR3_COMM_CMD_ITER_DEB_FIN         "cmd:iter:deb:fin"

#define CS_SYR3_COMM_LNG_NOM_RUB       32   /* Longueur du nom d'une rubrique */

/*
 * Communications par socket : on prevoit pour l'instant 8 codes couples
                               au maximum ; cette valeur peut etre modifiee
                               par la variable d'environnement
                               CS_SYR3_COMM_SOCKET_NBR_MAX
*/


/*============================================================================
 *  Declaration de structures
 *============================================================================*/

/*
  Pointeur associe a un communicateur. La structure elle-meme est declaree
  dans le fichier "cs_comm.c", car elle n'est pas necessaire ailleurs.
*/

typedef struct _cs_syr3_comm_t cs_syr3_comm_t;


/*
  Structure de sauvegarde des donnees d'une entete de message, permettant de
  simplifier le passage de ces donnees a differentes fonctions de traitement.
*/

typedef struct {

  cs_int_t   num_rub;                          /* Numero de rubrique associee */
  char       nom_rub[CS_SYR3_COMM_LNG_NOM_RUB + 1]; /* Nom si num_rub = 0     */
  cs_int_t   nbr_elt;                          /* Nombre d'elements           */
  cs_type_t  typ_elt;                          /* Type si nbr_elt > 0         */

} cs_syr3_comm_msg_entete_t;


/*=============================================================================
 * Definitions de variables globales
 *============================================================================*/


/*============================================================================
 *  Prototypes de fonctions publiques
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Fonction qui initialise une communication
 *----------------------------------------------------------------------------*/

cs_syr3_comm_t * cs_syr3_comm_initialise
(
 const char          *const nom_emetteur,   /* --> partie "emetteur" du nom   */
 const char          *const nom_recepteur,  /* --> partie "recepteur du nom   */
 const char          *const chaine_magique, /* --> Cha^ine de verif. de type   */
 const cs_int_t             numero,         /* --> Complete le nom si non nul */
#if defined(_CS_HAVE_MPI)
 const cs_int_t             rang_proc,      /* --> Rang processus en comm
                                                    (< 0 si comm par fichier) */
#endif
 const cs_syr3_comm_mode_t       mode,      /* --> emission ou reception      */
 const cs_syr3_comm_type_t       type,      /* --> Type de communication      */
 const cs_int_t             echo            /* --> echo sur sortie principale
                                                    (< 0 si aucun, entete si 0,
                                                    n premiers et derniers
                                                    elements si n)            */
);


/*----------------------------------------------------------------------------
 *  Fonction qui termine une communication
 *----------------------------------------------------------------------------*/

cs_syr3_comm_t * cs_syr3_comm_termine
(
 cs_syr3_comm_t *comm
);


/*----------------------------------------------------------------------------
 *  Fonction qui renvoie un pointeur sur le nom d'une communication
 *----------------------------------------------------------------------------*/

const char * cs_syr3_comm_ret_nom
(
 const cs_syr3_comm_t  *const comm
);


/*----------------------------------------------------------------------------
 *  Envoi d'un message
 *----------------------------------------------------------------------------*/

void cs_syr3_comm_envoie_message
(
 const cs_int_t          num_rub,           /* --> Num. rubrique associee     */
 const char              nom_rub[CS_SYR3_COMM_LNG_NOM_RUB], /* Si num_rub = 0 */
 const cs_int_t          nbr_elt,           /* --> Nombre d'elements          */
 const cs_type_t         typ_elt,           /* --> Type si nbr_elt > 0        */
       void       *const elt,               /* --> elements si nbr_elt > 0    */
 const cs_syr3_comm_t  *const comm
);


/*----------------------------------------------------------------------------
 *  Reception de l'entete d'un message ; renvoie le nombre d'elements du
 *  corps du message.
 *----------------------------------------------------------------------------*/

cs_int_t cs_syr3_comm_recoit_entete
(
       cs_syr3_comm_msg_entete_t  *const entete,  /* entete du message        */
 const cs_syr3_comm_t             *const comm
);


/*----------------------------------------------------------------------------
 *  Reception du corps d'un message.
 *
 *  Si la zone memoire destinee a recevoir les donnees existe deja, on
 *  fournit un pointeur "elt" sur cette zone ; la fonction renvoie alors
 *  ce meme pointeur. Sinon (si "elt" est a NULL), la memoire est allouee
 *  ici, et la fonction renvoie un pointeur sur cette zone.
 *----------------------------------------------------------------------------*/

void * cs_syr3_comm_recoit_corps
(
 const cs_syr3_comm_msg_entete_t  *const entete, /* entete du message         */
       void                       *const elt,    /* Pointeur sur les elements */
 const cs_syr3_comm_t             *const comm
);


#if defined(_CS_HAVE_SOCKET)

/*----------------------------------------------------------------------------
 *  Fonction qui ouvre un "socket" IP pour preparer ce mode de communication
 *----------------------------------------------------------------------------*/

void cs_syr3_comm_init_socket
(
 void
);

/*----------------------------------------------------------------------------
 *  Fonction qui ferme le "socket" IP avec ce mode de communication
 *----------------------------------------------------------------------------*/

void cs_syr3_comm_termine_socket
(
 void
);

#endif /* _CS_HAVE_SOCKET */

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __CS_SYR3_COMM_H__ */
