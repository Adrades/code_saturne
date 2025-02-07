#ifndef __CS_ORDER_H__
#define __CS_ORDER_H__

/*============================================================================
 * Functions related to the ordering of local arrays.
 *============================================================================*/

/*
  This file is part of code_saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2022 EDF S.A.

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

/*----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_defs.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Macro definitions
 *============================================================================*/

/*============================================================================
 * Type definitions
 *============================================================================*/

/*=============================================================================
 * Static global variables
 *============================================================================*/

/*=============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------
 * Test if an array of global numbers is ordered.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (number of entity i
 *              given by number[i] or number[list[i]] if list exists
 *              (if NULL, a default 0 to n-1 numbering is considered)
 *   nb_ent <-- number of entities considered
 *
 * returns:
 *   1 if ordered, 0 otherwise.
 *----------------------------------------------------------------------------*/

int
cs_order_gnum_test(const cs_lnum_t   list[],
                   const cs_gnum_t   number[],
                   size_t            nb_ent);

/*----------------------------------------------------------------------------
 * Return an ordering table associated with an array of global numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (number of entity i
 *              given by number[i] or number[list[i]]) if list exists
 *              (if NULL, a default 0 to n-1 numbering is considered)
 *   nb_ent <-- number of entities considered
 *
 * returns:
 *   pointer to list of nb_ent entities (0 to n-1 numbering) ordered by
 *   increasing associated number. The calling code is responsible for
 *   freeing this array when it is not needed anymore
 *----------------------------------------------------------------------------*/

cs_lnum_t *
cs_order_gnum(const cs_lnum_t   list[],
              const cs_gnum_t   number[],
              size_t            nb_ent);

/*----------------------------------------------------------------------------
 * Return a lexicographical ordering table associated with a strided array
 * of global numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (number of entity i
 *              given by number[i] or number[list[i]]) if list exists
 *              (if NULL, a default 0 to n-1 numbering is considered)
 *   stride <-- stride of number array (number of values to compare)
 *   nb_ent <-- number of entities considered
 *
 * returns:
 *   pointer to list of nb_ent entities (0 to n-1 numbering) ordered by
 *   increasing associated number. The calling code is responsible for
 *   freeing this array when it is not needed anymore.
 *----------------------------------------------------------------------------*/

cs_lnum_t *
cs_order_gnum_s(const cs_lnum_t  list[],
                const cs_gnum_t  number[],
                size_t           stride,
                size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Return a lexicographical ordering table associated with an indexed array
 * of global numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (numbers of entity i start
 *              at index[i] or _index[i] (reduced index) if list exists).
 *              If list = NULL, a default 0 to n-1 numbering is considered)
 *   index  <-- number of values to compare for each entity
 *   nb_ent <-- number of entities considered
 *
 * returns:
 *   pointer to list of nb_ent entities (0 to n-1 numbering) ordered by
 *   increasing associated number. The calling code is responsible for
 *   freeing this array when it is not needed anymore.
 *----------------------------------------------------------------------------*/

cs_lnum_t *
cs_order_gnum_i(const cs_lnum_t  list[],
                const cs_gnum_t  number[],
                const cs_lnum_t  index[],
                size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Compute an ordering table associated with an array of global numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (number of entity i
 *              given by number[i] or number[list[i]]) if list exists
 *              (if NULL, a default 0 to n-1 numbering is considered)
 *   order  --> pointer to pre-allocated ordering table
 *   nb_ent <-- number of entities considered
 *----------------------------------------------------------------------------*/

void
cs_order_gnum_allocated(const cs_lnum_t  list[],
                        const cs_gnum_t  number[],
                        cs_lnum_t        order[],
                        size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Compute a lexicographical ordering table associated with an array of
 * strided global numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (numbers of entity i start
 *              at number[i*stride] or number[list[i]*stride]) if
 *              list exists (if NULL, a default 0 to n-1 numbering is
 *              considered)
 *   stride <-- stride of number array (number of values to compare)
 *   order  --> pointer to pre-allocated ordering table
 *   nb_ent <-- number of entities considered
 *----------------------------------------------------------------------------*/

void
cs_order_gnum_allocated_s(const cs_lnum_t  list[],
                          const cs_gnum_t  number[],
                          size_t           stride,
                          cs_lnum_t        order[],
                          size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Compute a lexicographical ordering table associated with an indexed array
 * of global numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (numbers of entity i start
 *              at index[i] or _index[i] (reduced index) if list exists).
 *              If list = NULL, a default 0 to n-1 numbering is considered)
 *   index  <-- number of values to compare for each entity (from 0)
 *   order  --> pointer to pre-allocated ordering table
 *   nb_ent <-- number of entities considered
 *----------------------------------------------------------------------------*/

void
cs_order_gnum_allocated_i(const cs_lnum_t  list[],
                          const cs_gnum_t  number[],
                          const cs_lnum_t  index[],
                          cs_lnum_t        order[],
                          size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Compute an ordering table associated with an array of local numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (number of entity i
 *              given by number[i] or number[list[i]]) if list exists
 *              (if NULL, a default 0 to n-1 numbering is considered)
 *   order  --> pointer to pre-allocated ordering table
 *   nb_ent <-- number of entities considered
 *----------------------------------------------------------------------------*/

void
cs_order_lnum_allocated(const cs_lnum_t  list[],
                        const cs_lnum_t  number[],
                        cs_lnum_t        order[],
                        size_t           nb_ent);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute an ordering table associated with an array of local values.
 *
 * \param[in]   list    optional list (0 to n-1 numbering) of selected entities
 *                      (or NULL if all nb_ent are selected). This list may
 *                      contain element numbers in any order
 * \param[in]   val     array of all entity values (value of entity i given
 *                      by value[i] or value[list[i]]) if list exists
 *                      (if NULL, a default 0 to n-1 numbering is considered)
 * \param[out]  order   pointer to pre-allocated ordering table
 * \param[in]   nb_ent  number of entities considered
 */
/*----------------------------------------------------------------------------*/

void
cs_order_real_allocated(const cs_lnum_t  list[],
                        const cs_real_t  val[],
                        cs_lnum_t        order[],
                        size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Compute a lexicographical ordering table associated with an array of
 * strided local numbers.
 *
 * parameters:
 *   list   <-- optional list (0 to n-1 numbering) of selected entities
 *              (or NULL if all nb_ent are selected). This list may
 *              contain element numbers in any order
 *   number <-- array of all entity numbers (numbers of entity i start
 *              at number[i*stride] or number[list[i]*stride]) if
 *              list exists (if NULL, a default 0 to n-1 numbering is
 *              considered)
 *   stride <-- stride of number array (number of values to compare)
 *   order  --> pointer to pre-allocated ordering table
 *   nb_ent <-- number of entities considered
 *----------------------------------------------------------------------------*/

void
cs_order_lnum_allocated_s(const cs_lnum_t  list[],
                          const cs_lnum_t  number[],
                          size_t           stride,
                          cs_lnum_t        order[],
                          size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Build local renumbering array based on ordering of entities.
 *
 * parameters:
 *   order  <-- 0 to n-1 ordering of entities by increasing attribute
 *   nb_ent <-- number of entities considered
 *
 * returns:
 *   pointer to renumbering array (0 to n-1 numbering) indicating the new
 *   index of renumbered entities; The calling code is responsible for
 *   freeing this array when it is not needed anymore
 *----------------------------------------------------------------------------*/

cs_lnum_t *
cs_order_renumbering(const cs_lnum_t  order[],
                     size_t           nb_ent);

/*----------------------------------------------------------------------------
 * Reorder data based on ordering array.
 *
 * parameters:
 *   n_elts   <-- number of elements
 *   elt_size <-- element size
 *   order    <-- reordering array
 *   data     <-> data
 *----------------------------------------------------------------------------*/

void
cs_order_reorder_data(cs_lnum_t         n_elts,
                      size_t            elt_size,
                      const cs_lnum_t   order[],
                      void             *data);

/*----------------------------------------------------------------------------*/
/*!
 * \brief Build a sorted array containing a single occurence of each global
 *        number in a given array.
 *
 * Global numbers under a given "base" value are extruded.
 *
 * The caller is responsible for freeing the returned array.
 *
 * \param[in]   n_ent     size of input array
 * \param[in]   base      base id; numbers lower than this are dropped
 * \param[in]   number    array containing of all referenced entity numbers
 * \param[out]  n_single  array number of single occurences >= base
 * \param[out]  single    sorted array of unique numbers >= base
 */
/*----------------------------------------------------------------------------*/

void
cs_order_single_gnum(size_t            n_ent,
                     const cs_gnum_t   base,
                     const cs_gnum_t   number[],
                     size_t           *n_single,
                     cs_gnum_t        *single[]);

/*----------------------------------------------------------------------------*/

END_C_DECLS

#endif /* __CS_ORDER_H__ */
