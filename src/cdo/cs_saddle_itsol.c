/*============================================================================
 * In-house iterative solvers defined by blocks and associated to CDO
 * discretizations
 *============================================================================*/

/*
  This file is part of Code_Saturne, a general-purpose CFD tool.

  Copyright (C) 1998-2021 EDF S.A.

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

#include "cs_defs.h"

/*----------------------------------------------------------------------------
 * Standard C library headers
 *----------------------------------------------------------------------------*/

#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(HAVE_OPENMP)
#include <omp.h>
#endif

/*----------------------------------------------------------------------------
 *  BFT headers
 *----------------------------------------------------------------------------*/

#include <bft_mem.h>

/*----------------------------------------------------------------------------
 *  Local headers
 *----------------------------------------------------------------------------*/

#include "cs_blas.h"
#include "cs_parall.h"

/*----------------------------------------------------------------------------
 *  Header for the current file
 *----------------------------------------------------------------------------*/

#include "cs_saddle_itsol.h"

/*----------------------------------------------------------------------------*/

BEGIN_C_DECLS

/*=============================================================================
 * Additional doxygen documentation
 *============================================================================*/

/*!
 * \file cs_saddle_itsol.c
 *
 * \brief  In-house iterative solvers defined by blocks and associated to CDO
 *         discretizations
 */

/*! \cond DOXYGEN_SHOULD_SKIP_THIS */

/*=============================================================================
 * Local Macro definitions and structure definitions
 *============================================================================*/

/*============================================================================
 * Private variables
 *============================================================================*/

/*============================================================================
 * Private function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Test if one needs one more iteration. The residual criterion is
 *        computed inside the main algorithm.
 *
 * \param[in, out] info     pointer to a Uzawa builder structure
 *
 * \return true (one moe iteration) otherwise false
 */
/*----------------------------------------------------------------------------*/

static bool
_cvg_test(cs_iter_algo_info_t       *info)
{
  /* Increment the number of algo. iterations */
  info->n_algo_iter += 1;

  const cs_real_t  prev_res = info->res;
  const double  epsilon = fmax(info->rtol*info->res0, info->atol);

  /* Set the convergence status */
  if (info->res < epsilon)
    info->cvg = CS_SLES_CONVERGED;

  else if (info->n_algo_iter >= info->n_max_algo_iter)
    info->cvg = CS_SLES_MAX_ITERATION;

  else if (info->res > info->dtol * prev_res)
    info->cvg = CS_SLES_DIVERGED;

  else
    info->cvg = CS_SLES_ITERATING;

  if (info->verbosity > 0)
    cs_log_printf(CS_LOG_DEFAULT,
                  "<Krylov.It%02d> res %5.3e | %4d %6d cvg%d | fit.eps %5.3e\n",
                  info->n_algo_iter, info->res, info->last_inner_iter,
                  info->n_inner_iter, info->cvg, epsilon);

  if (info->cvg == CS_SLES_ITERATING)
    return true;
  else
    return false;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the scalar multiplication of a vector split into the x1 and
 *        x2 part
 *
 * \param[in]     ssys      pointer to a cs_saddle_system_t structure
 * \param[in]     x       vector used for the norm computation
 *
 * \return the norm
 */
/*----------------------------------------------------------------------------*/

static void
_scalar_scaling(cs_saddle_system_t   *ssys,
                cs_real_t             scalar,
                cs_real_t            *x)
{
  assert(x != NULL);
  cs_real_t  *x1 = x, *x2 = x + ssys->max_x1_size;

# pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
  for (cs_lnum_t i = 0; i < ssys->x1_size; i++)
    x1[i] *= scalar;

# pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
  for (cs_lnum_t i = 0; i < ssys->x2_size; i++)
    x2[i] *= scalar;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the canonical dot product between the vectors x and y
 *        The synchronization is performed during the process.
 *
 * \param[in]     ssys    pointer to a cs_saddle_system_t structure
 * \param[in]     x       first vector
 * \param[in]     y       second vector
 *
 * \return the value of the canonical dot product (x,y)
 */
/*----------------------------------------------------------------------------*/

static double
_dot_product(cs_saddle_system_t   *ssys,
             cs_real_t            *x,
             cs_real_t            *y)
{
  double  dp_value = 0.;

  if (x == NULL || y== NULL)
    return dp_value;

  const cs_range_set_t  *rset = ssys->rset;

  cs_real_t  *x1 = x, *x2 = x + ssys->max_x1_size;
  cs_real_t  *y1 = y, *y2 = y + ssys->max_x1_size;

  /* First part x1 and y1 whose DoFs are shared among processes */
  if (rset != NULL) {

    cs_range_set_gather(rset,
                        CS_REAL_TYPE,/* type */
                        1,           /* stride (treated as scalar up to now) */
                        x1,          /* in: size = n_sles_scatter_elts */
                        x1);         /* out: size = n_sles_gather_elts */
    cs_range_set_gather(rset,
                        CS_REAL_TYPE,/* type */
                        1,           /* stride (treated as scalar up to now) */
                        y1,          /* in: size = n_sles_scatter_elts */
                        y1);         /* out: size = n_sles_gather_elts */

    dp_value = cs_dot(rset->n_elts[0], x1, y1);

    /* Move back to a scatter view */
    cs_range_set_scatter(rset,
                         CS_REAL_TYPE,
                         1,
                         x1,
                         x1);
    cs_range_set_scatter(rset,
                         CS_REAL_TYPE,
                         1,
                         y1,
                         y1);
  }

  dp_value += cs_dot(ssys->x2_size, x2, y2);

  cs_parall_sum(1, CS_DOUBLE, &dp_value);

  return dp_value;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the norm of a vector split into the x1 and x2 part
 *        The synchronization is performed during the process.
 *
 * \param[in]     ssys      pointer to a cs_saddle_system_t structure
 * \param[in]     x       vector used for the norm computation
 *
 * \return the value of the euclidean norm of x
 */
/*----------------------------------------------------------------------------*/

static double
_norm(cs_saddle_system_t   *ssys,
      cs_real_t            *x)
{
  double  n_square_value = 0;

  if (x == NULL)
    return n_square_value;
  assert(ssys != NULL);

  cs_real_t  *x1 = x, *x2 = x + ssys->max_x1_size;
  const cs_range_set_t  *rset = ssys->rset;

  /* Norm for the x1 DoFs (those shared among processes) */
  double  _nx1_square = 0;

  if (rset != NULL) {
    cs_range_set_gather(rset,
                        CS_REAL_TYPE,/* type */
                        1,           /* stride (treated as scalar up to now) */
                        x1,          /* in: size = n_sles_scatter_elts */
                        x1);         /* out: size = n_sles_gather_elts */

    /* n_elts[0] corresponds to the number of element in the gather view */
    _nx1_square = cs_dot_xx(rset->n_elts[0], x1);

    cs_range_set_scatter(rset,
                         CS_REAL_TYPE,
                         1,
                         x1,
                         x1);
  }

  /* Norm for the x2 DoFs (not shared so that there is no need to
     synchronize) */
  double  _nx2_square = cs_dot_xx(ssys->x2_size, x2);

  n_square_value = _nx1_square + _nx2_square;
  cs_parall_sum(1, CS_DOUBLE, &n_square_value);
  assert(n_square_value > -DBL_MIN);

  return sqrt(n_square_value);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the residual divided into two parts
 *        res1 = rhs1 - M11.x1 - M12.x2
 *        res2 = rhs2 - M21.x1
 *
 *        The matrix m11 is represented with 1 block.
 *        The stride is equal to 3 for the operator m21_unassembled
 *
 * \param[in]      ssys      pointer to a cs_saddle_system_t structure
 * \param[in, out] x1        array for the first part
 * \param[in, out] x2        array for the second part
 * \param[out]     res       resulting residual vector
 */
/*----------------------------------------------------------------------------*/

static void
_compute_residual_3(cs_saddle_system_t   *ssys,
                    cs_real_t            *x1,
                    cs_real_t            *x2,
                    cs_real_t            *res)
{
  assert(res != NULL && x1 != NULL && x2 != NULL && ssys != NULL);
  assert(ssys->m21_stride == 3);
  assert(ssys->n_m11_matrices == 1);

  const cs_range_set_t  *rset = ssys->rset;

  cs_real_t  *res1 = res, *res2 = res + ssys->max_x1_size;

  /* Two parts:
   * a) rhs1 - M11.x1 -M12.x2
   * b) rhs2 - M21.x1
   */
  cs_real_t  *m12x2 = NULL;
  BFT_MALLOC(m12x2, ssys->x1_size, cs_real_t);
  memset(m12x2, 0, ssys->x1_size*sizeof(cs_real_t));

  const cs_adjacency_t  *adj = ssys->m21_adjacency;

  assert(ssys->x2_size == adj->n_elts);
# pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
  for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++) {

    const cs_real_t  _x2 = x2[i2];
    cs_real_t  _m21x1 = 0.;
    for (cs_lnum_t j = adj->idx[i2]; j < adj->idx[i2+1]; j++) {

      const cs_lnum_t  shift = 3*adj->ids[j];
      assert(shift < ssys->x1_size);
      const cs_real_t  *m21_vals = ssys->m21_unassembled + 3*j;
      cs_real_t  *_m12x2 = m12x2 + shift;

      _m21x1 += cs_math_3_dot_product(m21_vals, x1 + shift);

#     pragma omp critical
      {
        _m12x2[0] += m21_vals[0] * _x2;
        _m12x2[1] += m21_vals[1] * _x2;
        _m12x2[2] += m21_vals[2] * _x2;
      }

    } /* Loop on x1 elements associated to a given x2 element */

    res2[i2] = ssys->rhs2[i2] - _m21x1;

  } /* Loop on x2 elements */

  const cs_matrix_t  *m11 = ssys->m11_matrices[0];
  cs_matrix_vector_multiply_gs_allocated(rset, m11, x1, res1);

# pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
  for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
    res1[i1] = ssys->rhs1[i1] - res1[i1] - m12x2[i1];

  /* Free memory */
  BFT_FREE(m12x2);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Compute the matrix-vector operation divided into two parts
 *        matvec1 = M11.vec1 + M12.vec2
 *        matvec2 = M21.vec1
 *
 *        The stride is equal to 3 for the operator m21_unassembled
 *
 * \param[in]      ssys      pointer to a cs_saddle_system_t structure
 * \param[in, out] vec       array to multiply
 * \param[out]     matvec    resulting vector
 */
/*----------------------------------------------------------------------------*/

static void
_matvec_product(cs_saddle_system_t   *ssys,
                cs_real_t            *vec,
                cs_real_t            *matvec)
{
  /* Sanity checks */
  assert(vec != NULL && matvec != NULL && ssys != NULL);
  assert(ssys->m21_stride == 3);
  assert(ssys->n_m11_matrices == 1);

  const cs_range_set_t  *rset = ssys->rset;

  cs_real_t  *v1 = vec, *v2 = vec + ssys->max_x1_size;
  cs_real_t  *mv1 = matvec, *mv2 = matvec + ssys->max_x1_size;

  /* Two parts:
   * a) mv1 = M11.v1 + M12.v2
   * b) mv2 = M21.v1
   */
  const cs_matrix_t  *m11 = ssys->m11_matrices[0];
  cs_matrix_vector_multiply_gs_allocated(rset, m11, v1, mv1);

  /* 1) M12.v2 and M21.v1 */
  const cs_adjacency_t  *adj = ssys->m21_adjacency;

  cs_real_t  *m12v2 = NULL;
  BFT_MALLOC(m12v2, ssys->x1_size, cs_real_t);
  memset(m12v2, 0, ssys->x1_size*sizeof(cs_real_t));

  assert(ssys->x2_size == adj->n_elts);
# pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
  for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++) {

    const cs_real_t  _v2 = v2[i2];
    cs_real_t  _m21v1 = 0.;
    for (cs_lnum_t j = adj->idx[i2]; j < adj->idx[i2+1]; j++) {

      const cs_lnum_t  shift = 3*adj->ids[j];
      const cs_real_t  *m21_vals = ssys->m21_unassembled + 3*j;
      cs_real_t  *_m12v2 = m12v2 + shift;

      _m21v1 += cs_math_3_dot_product(m21_vals, v1 + shift);

#     pragma omp critical
      {
        _m12v2[0] += m21_vals[0] * _v2;
        _m12v2[1] += m21_vals[1] * _v2;
        _m12v2[2] += m21_vals[2] * _v2;
      }

    } /* Loop on x1 elements associated to a given x2 element */

    mv2[i2] = _m21v1;

  } /* Loop on x2 elements */

  if (rset->ifs != NULL)
    cs_interface_set_sum(rset->ifs,
                         ssys->x1_size,
                         1, false, CS_REAL_TYPE, /* stride, interlaced */
                         mv1);

# pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
  for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
    mv1[i1] += m12v2[i1];

  /* Free temporary memory */
  BFT_FREE(m12v2);
}

#if 0 /* WIP */
/*----------------------------------------------------------------------------*/
/*!
 * \brief Set the block preconditioners
 *
 * \param[in, out] slesp_a      settings for the A block
 * \param[in, out] slesp_schur  settings for the Schur complement approx.
 */
/*----------------------------------------------------------------------------*/

static void
_set_preconditioners(cs_param_sles_t  *slesp_a,
                     cs_param_sles_t  *slesp_schur)
{
  slesp_a->setup_done = true;
  slesp_a->verbosity = 3;
  slesp_a->field_id = -1;
  slesp_a->solver_class = CS_PARAM_SLES_CLASS_CS;
  slesp_a->precond = CS_PARAM_PRECOND_AMG;
  slesp_a->solver = CS_PARAM_ITSOL_CG;
  slesp_a->amg_type = CS_PARAM_AMG_HOUSE_K;
  slesp_a->eps = 1e-1; /* Only a coarse approximation is needed */
  slesp_a->n_max_iter = 50;

  slesp_schur->setup_done = true;
  slesp_schur->verbosity = 3;
  slesp_schur->field_id = -1;
  slesp_schur->solver_class = CS_PARAM_SLES_CLASS_CS;
  slesp_schur->precond = CS_PARAM_PRECOND_AMG;
  slesp_schur->solver = CS_PARAM_ITSOL_CG;
  slesp_schur->amg_type = CS_PARAM_AMG_HOUSE_K;
  slesp_schur->eps = 1e-3; /* Only a coarse approximation is needed */
  slesp_schur->n_max_iter = 50;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Apply diagonal preconditioning: Compute z s.t. P_d z = r
 *
 * \param[in]      slesp_a      settings for the A block
 * \param[in]      slesp_schur  settings for the Schur complement approx.
 * \param[in]      ssys         pointer to a cs_saddle_system_t structure
 * \param[in, out] z            array to evaluate
 * \param[out]     r            rhs of the preconditioning system
 */
/*----------------------------------------------------------------------------*/

static void
_diag_pc_apply(const cs_param_sles_t  *slesp_a,
               const cs_param_sles_t  *slesp_schur,
               cs_saddle_system_t     *ssys,
               cs_real_t              *z,
               cs_real_t              *r,
               double                  r_norm)
{

  /* Prepare solving (handle parallelism)
   * stride = 1 for scalar-valued */
  cs_equation_prepare_system(1, n_scatter_dofs, matrix, rset, rhs_redux,
                             xsol, b);

  /* Solve the linear solver */
  cs_solving_info_t  a_info = {.n_it = 0,
                               .res_norm = DBL_MAX,
                               .rhs_norm = r_norm};

  cs_sles_convergence_state_t  code = cs_sles_solve(sles,
                                                    matrix,
                                                    CS_HALO_ROTATION_IGNORE,
                                                    slesp_a->eps,
                                                    a_info.rhs_norm,
                                                    &(a_info.n_it),
                                                    &(a_info.res_norm),
                                                    b,
                                                    xsol,
                                                    0,      /* aux. size */
                                                    NULL);  /* aux. buffers */

  cs_equation_solve_scalar_system(uza->n_u_dofs,
                                  slesp0,
                                  a,
                                  cs_shared_range_set,
                                  1,     /* no normalization */
                                  false, /* rhs_redux --> already done */
                                  msles->sles,
                                  invA_lumped,
                                  uza->rhs));
}
#endif

/*============================================================================
 * Public function prototypes
 *============================================================================*/

/*----------------------------------------------------------------------------*/
/*!
 * \brief Perform a matrix-vector multiplication in case of scatter-view array
 *        as input parameter.  Thus, one performs a scatter --> gather (before
 *        the multiplication) and a gather --> scatter operation after the
 *        multiplication.  One assumes that matvec is allocated to the right
 *        size. No check is done.
 *
 *        The stride is equal to 1 for the matrix (db_size[3] = 1) and the
 *        vector
 *
 * \param[in]      rset      pointer to a cs_range_set_t structure
 * \param[in]      mat       matrix
 * \param[in, out] vec       vector
 * \param[in, out] matvec    resulting vector for the matrix-vector product
 */
/*----------------------------------------------------------------------------*/

void
cs_matrix_vector_multiply_gs_allocated(const cs_range_set_t      *rset,
                                       const cs_matrix_t         *mat,
                                       cs_real_t                 *vec,
                                       cs_real_t                 *matvec)
{
  if (mat == NULL || vec == NULL)
    return;

  /* Handle the input array
   * n_rows = n_gather_elts <= n_scatter_elts = n_dofs (mesh view) <= n_cols
   */

  /* scatter view to gather view for the input vector */
  if (rset != NULL)
    cs_range_set_gather(rset,
                        CS_REAL_TYPE,  /* type */
                        1,             /* stride */
                        vec,           /* in:  size=n_sles_scatter_elts */
                        vec);          /* out: size=n_sles_gather_elts */

  cs_matrix_vector_multiply(CS_HALO_ROTATION_IGNORE, mat, vec, matvec);

  /* gather view to scatter view (i.e. algebraic to mesh view) */
  if (rset != NULL) {
    cs_range_set_scatter(rset,
                         CS_REAL_TYPE, 1, /* type and stride */
                         vec, vec);
    cs_range_set_scatter(rset,
                         CS_REAL_TYPE, 1, /* type and stride */
                         matvec, matvec);
  }
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Perform a matrix-vector multiplication in case of scatter-view array
 *        as input parameter.  Thus, one performs a scatter --> gather (before
 *        the multiplication) and a gather --> scatter operation after the
 *        multiplication.  The output parameter matvec is not allocated. A
 *        check on the size is done for the input array.
 *
 *        The stride is equal to 1 for the matrix (db_size[3] = 1) and the
 *        vector
 *
 * \param[in]      rset      pointer to a cs_range_set_t structure
 * \param[in]      mat       matrix
 * \param[in]      vec_len   size of vec
 * \param[in, out] vec       vector of real numbers
 * \param[out]     matvec    resulting vector for the matrix-vector product
 */
/*----------------------------------------------------------------------------*/

void
cs_matrix_vector_multiply_gs(const cs_range_set_t      *rset,
                             const cs_matrix_t         *mat,
                             cs_lnum_t                  vec_len,
                             cs_real_t                 *vec,
                             cs_real_t                **p_matvec)
{
  if (mat == NULL || vec == NULL)
    return;

  const cs_lnum_t  n_cols = cs_matrix_get_n_columns(mat);

  /* Handle the input array
   * n_rows = n_gather_elts <= n_scatter_elts = n_dofs (mesh view) <= n_cols
   */
  cs_real_t  *vecx = NULL;
  if (n_cols > vec_len) {
    BFT_MALLOC(vecx, n_cols, cs_real_t);
    memcpy(vecx, vec, sizeof(cs_real_t)*vec_len);
  }
  else
    vecx = vec;

  /* scatter view to gather view */
  if (rset != NULL)
    cs_range_set_gather(rset,
                        CS_REAL_TYPE,  /* type */
                        1,             /* stride */
                        vecx,          /* in:  size=n_sles_scatter_elts */
                        vecx);         /* out: size=n_sles_gather_elts */

  /* Handle the output array */
  cs_real_t  *matvec = NULL;
  BFT_MALLOC(matvec, n_cols, cs_real_t);

  cs_matrix_vector_multiply(CS_HALO_ROTATION_IGNORE, mat, vecx, matvec);

  /* gather to scatter view (i.e. algebraic to mesh view) */
  if (rset != NULL) {
    cs_range_set_scatter(rset,
                         CS_REAL_TYPE, 1, /* type and stride */
                         vecx, vec);
    cs_range_set_scatter(rset,
                         CS_REAL_TYPE, 1, /* type and stride */
                         matvec, matvec);
  }

  /* Free allocated memory if needed */
  if (vecx != vec) {
    assert(n_cols > vec_len);
    BFT_FREE(vecx);
  }

  /* return the resulting array */
  *p_matvec = matvec;
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Apply the MINRES algorithm to a saddle point problem (the system is
 *        stored in a hybrid way). Please refer to cs_saddle_system_t structure
 *        definition.
 *        The stride is equal to 1 for the matrix (db_size[3] = 1) and the
 *        vector.
 *
 * \param[in]      ssys      pointer to a cs_saddle_system_t structure
 * \param[in, out] x1        array for the first part
 * \param[in, out] x2        array for the second part
 * \param[in, out] info      pointer to a cs_iter_algo_info_t structure
 */
/*----------------------------------------------------------------------------*/

void
cs_saddle_minres(cs_saddle_system_t    *ssys,
                 cs_real_t             *x1,
                 cs_real_t             *x2,
                 cs_iter_algo_info_t   *info)
{
  /* Workspace */
  const cs_lnum_t  ssys_size = ssys->max_x1_size + ssys->x2_size;
  const size_t  n_bytes = sizeof(cs_real_t)*ssys_size;
  cs_lnum_t  wsp_size = 10*ssys_size;
  cs_real_t  *wsp = NULL;

  BFT_MALLOC(wsp, wsp_size, cs_real_t);
  memset(wsp, 0, wsp_size*sizeof(cs_real_t));

  /* Set pointers */
  cs_real_t  *v     = wsp;
  cs_real_t  *vold  = wsp + ssys_size;
  cs_real_t  *mv    = wsp + 2*ssys_size;
  cs_real_t  *w     = wsp + 3*ssys_size;
  cs_real_t  *wold  = wsp + 4*ssys_size;
  cs_real_t  *woold = wsp + 5*ssys_size;
  cs_real_t  *r     = wsp + 6*ssys_size;
  cs_real_t  *z     = wsp + 7*ssys_size;
  cs_real_t  *u     = wsp + 8*ssys_size;
  cs_real_t  *uold  = wsp + 9*ssys_size;

#if 0
  /* Create and set preconditioners */
  cs_param_sles_t  *slesp_a = cs_param_sles_create(-1, "precond_A_block");
  cs_param_sles_t  *slesp_schur =  cs_param_sles_create(-1, "precond_S_block");

  _set_preconditioners(slesp_a, slesp_schur);
#endif

  /* Compute the first residual */
  _compute_residual_3(ssys, x1, x2, r);

#if 0
  /* Apply preconditioning */
  _diag_pc_apply(slesp_a, slesp_schur, ssys, r, z);
#endif

  double  beta = _norm(ssys, r);
  info->res0 = beta;
  info->res = beta;
  memcpy(v, r, n_bytes);

  /* Initialization */
  double  coold, soold;
  double  eta = beta;
  double  c=1.0, cold=1.0, s=0.0, sold=0.0;

  while (info->cvg == CS_SLES_ITERATING) {

    assert(fabs(beta) > 0.);
    _scalar_scaling(ssys, 1./beta, v);

    /* Compute the matrix-vector product M.v */
    _matvec_product(ssys, v, r);

    double  alpha = _dot_product(ssys, r, v);

    /* r(k+1) = r(k) - alpha*v(k) - beta v(k-1) */
#   pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
    for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
      r[i1] = r[i1] - alpha*v[i1] - beta*vold[i1];

    cs_real_t  *r2 = r + ssys->max_x1_size;
    const cs_real_t  *v2 = v + ssys->max_x1_size;
    const cs_real_t  *v2old = vold + ssys->max_x1_size;

#   pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
    for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++)
      r2[i2] = r2[i2] - alpha*v2[i2] - beta*v2old[i2];

    /* New value for beta */
    double  betaold = beta;
    beta = _norm(ssys, r);

    coold = cold; cold = c; soold = sold; sold = s;

    /* QR factorization */
    double rho0 = cold*alpha - coold*sold*betaold;
    double rho1 = sqrt(rho0*rho0 + beta*beta);
    double rho2 = sold*alpha + coold*cold*betaold;
    double rho3 = soold*betaold;

    /* Givens rotation */
    assert(fabs(rho1) > DBL_MIN);
    const double  irho1 = 1./rho1;
    c = rho0*irho1;
    s = beta*irho1;

    /* w(k+1) = 1/a0 * ( v(k) - alp3*w(k-1) - alp2 w(k) )*/
    memcpy(woold, wold, n_bytes);
    memcpy(wold, w, n_bytes);

#   pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
    for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
      w[i1] = irho1 * (v[i1] - rho2*wold[i1] - rho3*woold[i1]);

    cs_real_t  *w2 = w + ssys->max_x1_size;
    const cs_real_t  *w2old = wold + ssys->max_x1_size;
    const cs_real_t  *w2oold = woold + ssys->max_x1_size;

#   pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
    for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++)
      w2[i2] = irho1 * (v2[i2] - rho2*w2old[i2] - rho3*w2oold[i2]);

    /* Update the solution vector */
    /* x1(k+1) = x1(k) + c1*eta*w(k+1) */
    const double  ceta = c*eta;

#   pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
    for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
      x1[i1] = x1[i1] + ceta*w[i1];

#   pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
    for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++)
      x2[i2] = x2[i2] + ceta*w2[i2];

    /* Compute the current residual */
    // _compute_residual_3(ssys, x1, x2, res);
    info->res *= s;

    /* Last updates */
    eta = -s*eta;

    /* v(k-1) <-- v(k); v(k) <-- v(k+1); */
    memcpy(vold, v, n_bytes);
    memcpy(v, r, n_bytes);

    /* Check the convergence criteria */
    _cvg_test(info);

  } /* main loop */

  /* Free temporary workspace */
#if 0
  cs_param_sles_free(&slesp_a);
  cs_param_sles_free(&slesp_schur);
#endif
  BFT_FREE(wsp);
}

/*----------------------------------------------------------------------------*/
/*!
 * \brief Perform elementary tests to assess this module
 *
 * \param[in]      ssys      pointer to a cs_saddle_system_t structure
 * \param[in, out] x1        array for the first part
 * \param[in, out] x2        array for the second part
 */
/*----------------------------------------------------------------------------*/

void
cs_saddle_test(cs_saddle_system_t   *ssys,
               cs_real_t            *x1,
               cs_real_t            *x2)
{
  /* Workspace */
  const cs_lnum_t  ssys_size = ssys->max_x1_size + ssys->x2_size;
  const size_t  n_bytes = sizeof(cs_real_t)*ssys_size;
  cs_lnum_t  wsp_size = 3*ssys_size;
  cs_real_t  *wsp = NULL;

  BFT_MALLOC(wsp, wsp_size, cs_real_t);
  memset(wsp, 0, wsp_size*sizeof(cs_real_t));

  /* Set pointers */
  cs_real_t  *v = wsp;
  cs_real_t  *mv = wsp + ssys_size;
  cs_real_t  *res = wsp + 2*ssys_size;

# pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
  for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
    v[i1] = ssys->rhs1[i1];
  cs_real_t  *v2 = v + ssys->max_x1_size;
# pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
  for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++)
    v2[i2] = ssys->rhs2[i2];

  double  res_norm = _norm(ssys, v);

  printf("\n >>>> RHSNORM= %6.4e", res_norm);

  memset(v, 0, n_bytes);
  _compute_residual_3(ssys, v, v2, res);

  res_norm = _norm(ssys, res);
  printf(" Vs NORM= %6.4e\n", res_norm);

# pragma omp parallel for if (ssys->x1_size > CS_THR_MIN)
  for (cs_lnum_t i1 = 0; i1 < ssys->x1_size; i1++)
    v[i1] = x1[i1];
# pragma omp parallel for if (ssys->x2_size > CS_THR_MIN)
  for (cs_lnum_t i2 = 0; i2 < ssys->x2_size; i2++)
    v2[i2] = x2[i2];

  /* Compute the matrix-vector product M.v_k */
  _matvec_product(ssys, v, mv);

  ssys->rhs1 = mv;
  ssys->rhs2 = mv + ssys->max_x1_size;

  /* Compute the first residual */
  _compute_residual_3(ssys, v, v2, res);

  res_norm = _norm(ssys, res);

  printf("\n >>>> RESNORM= %6.4e\n", res_norm);

  /* Free temporary workspace */
  BFT_FREE(wsp);
}

/*----------------------------------------------------------------------------*/

END_C_DECLS
