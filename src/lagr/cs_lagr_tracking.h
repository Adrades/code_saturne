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

#ifndef __CS_LAGR_TRACKING_H__
#define __CS_LAGR_TRACKING_H__

/*============================================================================
 * Functions and types for the Lagrangian module
 *============================================================================*/

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_defs.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*============================================================================
 * Type definitions
 *============================================================================*/

typedef enum {

  CS_LAGR_CUR_CELL_NUM,     /* current local cell number */
  CS_LAGR_LAST_FACE_NUM,

  CS_LAGR_SWITCH_ORDER_1,
  CS_LAGR_STATE,            /* < 0 : - number of the boundary face where
                                      the particle is kept
                                 0   : particle has to be destroyed
                                 1   : particle has to be synchronized
                                 2   : particle treated. End of displacement */

  CS_LAGR_PREV_ID,          /* id in particle set of the previous particle */
  CS_LAGR_NEXT_ID,          /* id in particle set of the next particle */

  CS_LAGR_RANDOM_VALUE,     /* random value associated with the particle */

  CS_LAGR_STAT_WEIGHT,
  CS_LAGR_RESIDENCE_TIME,
  CS_LAGR_MASS,
  CS_LAGR_DIAMETER,
  CS_LAGR_TAUP_AUX,
  CS_LAGR_COORDS,
  CS_LAGR_VELOCITY,
  CS_LAGR_VELOCITY_SEEN,

  /* Deposition submodel additional parameters */

  CS_LAGR_YPLUS,
  CS_LAGR_INTERF,
  CS_LAGR_NEIGHBOR_FACE_ID,
  CS_LAGR_MARKO_VALUE,
  CS_LAGR_DEPOSITION_FLAG,

  /* Resuspension model additional parameters */

  CS_LAGR_N_LARGE_ASPERITIES,
  CS_LAGR_N_SMALL_ASPERITIES,
  CS_LAGR_ADHESION_FORCE,
  CS_LAGR_ADHESION_TORQUE,
  CS_LAGR_DISPLACEMENT_NORM,

  /* Thermal model additional parameters */

  CS_LAGR_TEMPERATURE,
  CS_LAGR_FLUID_TEMPERATURE,
  CS_LAGR_CP,

  /* Coal combustion additional parameters */

  CS_LAGR_COAL_MASS,
  CS_LAGR_COKE_MASS,

  CS_LAGR_SHRINKING_DIAMETER,
  CS_LAGR_INITIAL_DIAMETER,
  CS_LAGR_INITIAL_DENSITY,

  CS_LAGR_COAL_NUM,
  CS_LAGR_COAL_DENSITY,

  /* Radiative model additional parameters */

  CS_LAGR_EMISSIVITY,

  /* End of attributes */

  CS_LAGR_N_ATTRIBUTES

} cs_lagr_attribute_t;

/* Base particle description */
/* ------------------------- */

typedef struct {

  cs_lnum_t   cur_cell_num;   /* current local cell number */
  cs_lnum_t   last_face_num;

  int         switch_order_1;
  cs_lnum_t   state;         /* < 0 : - number of the boundary face where
                                      the particle is kept
                                0   : particle has to be destroyed
                                1   : particle has to be synchronized
                                2   : particle treated. End of displacement */

  cs_lnum_t   prev_id;  /* id in particle set of the previous particle */
  cs_lnum_t   next_id;  /* id in particle set of the next particle */

  cs_real_t   random_value;   /* random value associated with the particle */

  cs_real_t   stat_weight;
  cs_real_t   residence_time;
  cs_real_t   mass;
  cs_real_t   diameter;
  cs_real_t   taup_aux;
  cs_real_t   coord[3];
  cs_real_t   velocity[3];
  cs_real_t   velocity_seen[3];

  /* Deposition submodel additional parameters */

  cs_real_t   yplus;
  cs_real_t   interf;
  cs_lnum_t   close_face_id;
  cs_lnum_t   marko_val;
  cs_lnum_t   depo;                  /* jdepo   */

  /* Resuspension model additional parameters */

  cs_lnum_t   nb_large_asperities;   /* jnbasg  */
  cs_lnum_t   nb_small_asperities;   /* jnbasg  */
  cs_real_t   adhesion_force;        /* jfadh   */
  cs_real_t   adhesion_torque;       /* jmfadh  */
  cs_real_t   displacement_norm;     /* jndisp  */

  /* Thermal model additional parameters */

  cs_real_t   temp;            /* jhp */
  cs_real_t   fluid_temp;      /* jtf */
  cs_real_t   cp;              /* jcp */

  /* Coal combustion additional parameters */

  cs_real_t   coal_mass;       /* jmch */
  cs_real_t   coke_mass;       /* jmck */

  cs_real_t   shrinking_diam;  /* jrdck */
  cs_real_t   initial_diam;    /* jrd0p */
  cs_real_t   initial_density; /* jrr0p */

  cs_lnum_t   coal_number;     /* jinch */
  cs_real_t   coal_density;    /* jrhock */

  /* Radiative model additional parameters */

  cs_real_t   emissivity;      /* jreps */

} cs_lagr_particle_t;

/* Particle description for user-defined variables */
/* ----------------------------------------------- */

typedef struct { /* User-defined variables. Max. 10 */

  cs_lnum_t   stat_class;  /* Only if NBCLST > 0 */
  cs_real_t   aux[10];

} cs_lagr_aux_particle_t;

/* Particle set */
/* ------------ */

typedef struct {

  cs_lnum_t  n_particles;
  cs_lnum_t  n_part_out;
  cs_lnum_t  n_part_dep;
  cs_lnum_t  n_failed_part;

  cs_real_t  weight;
  cs_real_t  weight_out;
  cs_real_t  weight_dep;
  cs_real_t  weight_failed;

  cs_lnum_t  n_particles_max;

  cs_lnum_t  first_used_id;
  cs_lnum_t  first_free_id;

  cs_lagr_particle_t       *particles;  /* Main  particle description */

  cs_lagr_aux_particle_t   *aux_desc;   /* Additional description for study
                                           with user-defined variables */
} cs_lagr_particle_set_t;

/*=============================================================================
 * Global variables
 *============================================================================*/

extern const char *cs_lagr_attribute_name[];

/*============================================================================
 * Public function prototypes for Fortran API
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Allocate cs_lagr_particle_set_t structure and initialize useful buffers
 * and indexes
 *
 * parameters:
 *   n_particles_max <--  local max. number of particles
 *   iphyla          <--  kind of physics used for the lagrangian approach
 *   nvls            <--  number of user-defined variables
 *   nbclst          <--  number of stat. class to study sub-set of particles
 *   ...
 *----------------------------------------------------------------------------*/

void
CS_PROCF (lagbeg, LAGBEG)(const cs_int_t    *n_particles_max,
                          const cs_int_t    *iphyla,
                          const cs_int_t    *idepst,
                          const cs_int_t    *ireent,
                          const cs_int_t    *nvls,
                          const cs_int_t    *nbclst,
                          cs_lnum_t          icocel[],
                          cs_lnum_t          itycel[],
                          const cs_lnum_t   *jisor,
                          const cs_lnum_t   *jrval,
                          const cs_lnum_t   *jrpoi,
                          const cs_lnum_t   *jrtsp,
                          const cs_lnum_t   *jdp,
                          const cs_lnum_t   *jmp,
                          const cs_lnum_t   *jxp,
                          const cs_lnum_t   *jyp,
                          const cs_lnum_t   *jzp,
                          const cs_lnum_t   *jup,
                          const cs_lnum_t   *jvp,
                          const cs_lnum_t   *jwp,
                          const cs_lnum_t   *juf,
                          const cs_lnum_t   *jvf,
                          const cs_lnum_t   *jwf,
                          const cs_lnum_t   *jtaux,
                          const cs_lnum_t   *jryplu,
                          const cs_lnum_t   *jrinpf,
                          const cs_lnum_t   *jdfac,
                          const cs_lnum_t   *jimark,
                          const cs_lnum_t   *jtp,
                          const cs_lnum_t   *jhp,
                          const cs_lnum_t   *jtf,
                          const cs_lnum_t   *jmch,
                          const cs_lnum_t   *jmck,
                          const cs_lnum_t   *jcp,
                          const cs_lnum_t   *jrdck,
                          const cs_lnum_t   *jrd0p,
                          const cs_lnum_t   *jrr0p,
                          const cs_lnum_t   *jinch,
                          const cs_lnum_t   *jrhock,
                          const cs_lnum_t   *jreps,
                          const cs_lnum_t   *jdepo,
                          const cs_lnum_t   *jnbasg,
                          const cs_lnum_t   *jnbasp,
                          const cs_lnum_t   *jfadh,
                          const cs_lnum_t   *jmfadh,
                          const cs_lnum_t   *jndisp);

/*----------------------------------------------------------------------------
 * Get variables and parameters associated to each particles and keep it in
 * a new structure
 *
 * parameters:
 *   nbpmax <-- n_particles max.
 *   nbpart --> number of current particles
 *   ...
 *----------------------------------------------------------------------------*/

void
CS_PROCF (prtget, PRTGET)(const cs_int_t   *nbpmax,
                          const cs_int_t   *nbpart,
                          const cs_real_t   ettp[],
                          const cs_real_t   ettpa[],
                          const cs_int_t    itepa[],
                          const cs_real_t   tepa[],
                          const cs_int_t    ibord[],
                          const cs_int_t    indep[]);

/*----------------------------------------------------------------------------
 * Put variables and parameters associated to each particles into FORTRAN
 * arrays.
 *
 * parameters:
 *   nbpmax <-- n_particles max.
 *   nbpart --> number of current particles
 *   dnbpar --> particle total weight
 *   nbpout --> number of outgoing particles
 *   dnbpou --> outgoing particle total weight
 *   nbperr --> number of failed particles
 *   dnbper --> failed particles total weight
 *   nbpdep --> number of depositing particles
 *   dnbdep --> depositing particles total weight
 *   ...
 *----------------------------------------------------------------------------*/

void
CS_PROCF (prtput, PRTPUT)(const cs_int_t   *nbpmax,
                          cs_int_t         *nbpart,
                          cs_real_t        *dnbpar,
                          cs_int_t         *nbpout,
                          cs_real_t        *dnbpou,
                          cs_int_t         *nbperr,
                          cs_real_t        *dnbper,
                          cs_int_t         *nbpdep,
                          cs_real_t        *dnbdep,
                          cs_real_t         ettp[],
                          cs_real_t         ettpa[],
                          cs_int_t          itepa[],
                          cs_real_t         tepa[],
                          cs_int_t          ibord[]);

/*----------------------------------------------------------------------------
 * Get variables and parameters associated to each particles and keep it in
 * a new structure
 *
 * parameters:
 *   ...
 *----------------------------------------------------------------------------*/

void
CS_PROCF (getbdy, GETBDY)(const cs_int_t    *nflagm,
                          const cs_int_t    *nfrlag,
                          const cs_int_t    *injcon,
                          const cs_int_t     ilflag[],
                          const cs_int_t     iusncl[],
                          const cs_int_t     iusclb[],
                          const cs_int_t     iusmoy[],
                          const cs_real_t    deblag[],
                          const cs_int_t     ifrlag[]);

/*----------------------------------------------------------------------------
 * Displacement of particles.
 *
 * parameters:
 *   p_n_particles <-> pointer to the number of particles
 *   scheme_order  <-- current order of the scheme used for Lagragian
 *----------------------------------------------------------------------------*/

void
CS_PROCF (dplprt, DPLPRT)(cs_int_t        *p_n_particles,
                          cs_real_t       *p_parts_weight,
                          cs_int_t        *p_scheme_order,
                          cs_real_t        boundary_stat[],
                          const cs_int_t  *iensi3,
                          const cs_int_t  *inbr,
                          const cs_int_t  *inbrbd,
                          const cs_int_t  *iflm,
                          const cs_int_t  *iflmbd,
                          const cs_int_t  *iang,
                          const cs_int_t  *iangbd,
                          const cs_int_t  *ivit,
                          const cs_int_t  *ivitbd,
                          const cs_int_t  *nusbor,
                          cs_int_t         iusb[],
                          cs_real_t        visc_length[],
                          cs_real_t        dlgeo[],
                          cs_real_t        rtp[],
                          const cs_int_t  *iu,
                          const cs_int_t  *iv,
                          const cs_int_t  *iw,
                          cs_real_t        energt[]);

/*----------------------------------------------------------------------------
 * Update C structures metadata after particle computations.
 *
 * This metadata is overwritten and rebuilt at each time step, so
 * it is useful only for a possible postprocessing step.
 *
 * The matching data is copied separately, as it may not need to be
 * updated at each time step.
 *
 * parameters:
 *   nbpmax <-- n_particles max.
 *   nbpart <-- number of current particles
 *   dnbpar <-- particle total weight
 *   nbpout <-- number of outgoing particles
 *   dnbpou <-- outgoing particle total weight
 *   nbperr <-- number of failed particles
 *   dnbper <-- failed particles total weight
 *   nbpdep <-- number of depositing particles
 *   dnbdep <-- depositing particles total weight
 *   ...
 *----------------------------------------------------------------------------*/

void
CS_PROCF (ucdprt, UCDPRT)(const cs_lnum_t   *nbpmax,
                          const cs_lnum_t   *nbpart,
                          const cs_real_t   *dnbpar,
                          const cs_int_t    *nbpout,
                          const cs_real_t   *dnbpou,
                          const cs_int_t    *nbperr,
                          const cs_real_t   *dnbper,
                          const cs_int_t    *nbpdep,
                          const cs_real_t   *dnbdep,
                          const cs_real_t    ettp[],
                          const cs_real_t    ettpa[],
                          const cs_lnum_t    itepa[],
                          const cs_real_t    tepa[],
                          const cs_lnum_t    ibord[],
                          const cs_lnum_t    indep[]);

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Get data access information for a given particle attribute.
 *
 * For attributes not currently present, the displacement and data
 * size should be -1 and 0 respectively.
 *
 * parameters:
 *   attr     <-- particle attribute
 *   extents  --> size (in bytes) of particle structure, or NULL
 *   size     --> size (in bytes) of attribute in particle structure, or NULL
 *   displ    --> displacement (in bytes) in particle structure, or NULL
 *   datatype --> associated datatype, or NULL
 *   count    --> associated elements count, or NULL
 *----------------------------------------------------------------------------*/

void
cs_lagr_get_attr_info(cs_lagr_attribute_t    attr,
                      size_t                *extents,
                      size_t                *size,
                      ptrdiff_t             *displ,
                      cs_datatype_t         *datatype,
                      int                   *count);

/*----------------------------------------------------------------------------
 * Return pointers to the main cs_lagr_particle_set_t structures.
 *
 * parameters:
 *   current_set  --> pointer to current particle set, or NULL
 *   previous_set --> pointer to previous particle set, or NULL
 *----------------------------------------------------------------------------*/

void
cs_lagr_get_particle_sets(cs_lagr_particle_set_t  **current_set,
                          cs_lagr_particle_set_t  **previous_set);

/*----------------------------------------------------------------------------
 * Delete cs_lagr_particle_set_t structure and delete other useful buffers.
 *----------------------------------------------------------------------------*/

void
cs_lagr_destroy(void);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_LAGR_TRACKING_H__ */
