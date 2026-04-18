library(mcmcse)
library(reshape2)


# #' @export
StackChainArray <- function(draws_array) {
    num_chains <- dim(draws_array)[2]
    draws_mat <- do.call(
        rbind, lapply(1:num_chains,
                      function(chain) {
                            # Drop the chain dimension but not the parameter
                            # dimension in case the parmeters are one-dimensional.
                            return(array(
                                draws_array[, chain, ],
                                dim=dim(draws_array)[c(1, 3)]))
                          }))
    return(draws_mat)
}


#' @importFrom rstan extract
#' @export
OrderedExtract <- function(modelfit, pars) {
    return(StackChainArray(rstan::extract(modelfit, pars, permute=FALSE)))
}


#' @importFrom mcmcse mcse.multi
mcse.multi_safe <- function(arg_draws) {
    # Set a default to return if the method fails.
    output_list <- list(cov=matrix(NA, ncol(arg_draws), ncol(arg_draws)))
    tryCatch(output_list <- mcmcse::mcse.multi(arg_draws),
             error=function(e) { print(e) },
             warning=function(w) { print(w) }) # Should we suppress the warning?
    return(output_list$cov)
}

GetCovarianceSE <- function(x_draws, y_draws, correlated_samples) {
    # Get standard errors for a single scalar covariance under
    # random sampling of the rows of the draws.   This uses
    # the population moments and the delta method.

    # x_draws and y_draws should be vectors, not matrices.
    x_mean <- mean(x_draws)
    y_mean <- mean(y_draws)

    arg_draws <- cbind(x_draws * y_draws, x_draws, y_draws)
    if (correlated_samples) {
        # mcse may throw a warning about the covariance not being full rank, which is fine (I think)
        arg_cov_mat <- mcse.multi_safe(arg_draws)
        #suppressWarnings(arg_cov_mat <- mcmcse::mcse.multi(arg_draws)$cov)
    } else {
        arg_cov_mat <- cov(arg_draws, arg_draws)
    }
    grad_g <- c(1, -1 * y_mean, -1 * x_mean)
    g_se <- as.numeric(sqrt(t(grad_g) %*% arg_cov_mat %*% grad_g / nrow(arg_draws)))

    return(g_se)
}


GetCovarianceMatrixSE <- function(x_draws, y_draws, correlated_samples) {
    # Get standard errors for a covariance matrix under random sampling of
    # the rows of x_draws and y_draws.  x_draws and y_draws should
    # be matrices.
    stopifnot(nrow(x_draws) == nrow(y_draws))
    num_x_pars <- ncol(x_draws)
    num_y_pars <- ncol(y_draws)
    cov_se_mat <- matrix(NA, num_x_pars, num_y_pars)
    for (ix in 1:num_x_pars) {
        for (iy in 1:ix) {
            cov_se_mat[ix, iy] <- GetCovarianceSE(
                x_draws[, ix], y_draws[, iy],
                correlated_samples=correlated_samples)
            cov_se_mat[iy, ix] <- cov_se_mat[ix, iy]
        }
    }
    return(cov_se_mat)
}


#' Estimate Monte Carlo standard errors of sample covariances or
#' by block bootstrapping draws from an MCMC chain.
#'
#' @param draws1_mat One set of parameter draws.
#' @param draws2_mat Another set of parameter draws.
#' @param num_blocks The number of blocks in the block bootstrap.
#' @param num_draws The number of bootstrap draws.
#' @param show_progress_par.  Optional.  If TRUE, show a progress bar.
#' By default, FALSE.
#' @return A list containing the draws of the covariance cov_samples
#' and the estimated Monte Carlo sample errors in cov_se.
#' @export
GetBlockBootstrapCovarianceDraws <- function(draws1_mat, draws2_mat,
                                             num_blocks, num_draws,
                                             show_progress_bar=FALSE) {

  if (nrow(draws1_mat) != nrow(draws2_mat)) {
    stop("draws1_mat and draws2_mat must have the same number of rows.")
  }

  num_samples <- nrow(draws1_mat)

  block_size <- floor(num_samples / num_blocks)

  # Correction factor if the number of blocked observations is not the same
  # as the original.
  n_factor <- (block_size * num_blocks) / num_samples

  # The indices of each block into the MCMC samples.
  block_inds <- lapply(
    1:num_blocks,
    function(ind) { (ind - 1) * block_size + 1:block_size })

  base_cov <- cov(draws1_mat, draws2_mat)
  cov_samples <- array(NA, c(num_draws, ncol(draws1_mat), ncol(draws2_mat)))
  if (show_progress_bar) {
    pb <- txtProgressBar(min=1, max=num_draws, style=3)
  }

  # Pre-aggregate the sums required within each block.
  ComputeSums <- function(draws_mat) {
    lapply(block_inds, \(inds) colSums(draws_mat[inds, , drop=FALSE ]))
  }
  sums1 <- ComputeSums(draws1_mat)
  sums2 <- ComputeSums(draws2_mat)

  outers12 <- lapply(
    block_inds,
    \(inds) t(draws1_mat[inds, , drop=FALSE ]) %*% draws2_mat[inds, , drop=FALSE])

  ComputeCovariance <- function(block_ind_draws) {
    n_ind_draws <- length(block_ind_draws) * block_size
    AverageOverInds <- function(sim_list) {
      reduce(sim_list[block_ind_draws], \(x, y) x + y) / n_ind_draws
    }
    d1_bar <- AverageOverInds(sums1)
    d2_bar <- AverageOverInds(sums2)
    outer_bar <- AverageOverInds(outers12)
    return(outer_bar - d1_bar %*% t(d2_bar))
  }

  for (draw in 1:num_draws) {
    if (show_progress_bar) {
      setTxtProgressBar(pb, draw)
    }
    block_ind_draws <- sample(1:num_blocks, num_blocks, replace=TRUE)
    cov_samples[draw, , ] <- ComputeCovariance(block_ind_draws)
  }
  if (show_progress_bar) {
    close(pb)
  }

  cov_se <- sqrt(n_factor) * apply(cov_samples, MARGIN=c(2, 3), sd)
  rownames(cov_se) <- colnames(draws1_mat)
  colnames(cov_se) <- colnames(draws2_mat)

  return(list(cov_samples=cov_samples, cov_se=cov_se))
}


ComputeIJStandardErrors <- function(lp_draws, par_draws, num_blocks, num_draws) {
  # This way of doing it was based on an old version of
  # GetBlockBootstrapCovarianceDraws.  I include it only as a record
  # of what the function used to do.
  # ij_se_list <- GetBlockBootstrapCovarianceDraws(
  #     lp_draws, par_draws, num_blocks=num_blocks, num_draws=num_draws)
  # ij_cov_se <- ij_se_list$cov_se


  # Compute block bootstrap draws of the influence function
  ij_se_list <- GetBlockBootstrapCovarianceDraws(
    lp_draws, par_draws, num_blocks=100, num_draws=100)
  num_pars <- ncol(par_draws)
  num_samples <- dim(ij_se_list$cov_samples)[1]
  ij_cov_draws <- array(NA, dim=c(num_samples, num_pars, num_pars))
  for (draw in 1:num_samples) {
    # For each blocked draw, compute ij_cov
    infl_draws_mat <- num_exch_obs * ij_se_list$cov_samples[draw,,]
    colnames(infl_draws_mat) <- colnames(par_draws)
    ij_cov_draw <- bayesijlib::ComputeIJCovarianceFromInfluence(infl_draws_mat)
    ij_cov_draws[draw,,] <- ij_cov_draw
  }
  ij_cov_se <- apply(ij_cov_draws, FUN=sd, MARGIN=c(2,3))
  colnames(ij_cov_se) <- rownames(ij_cov_se) <- colnames(par_draws)

  num_obs <- ncol(lp_draws)
  bayes_se_list <- GetBlockBootstrapCovarianceDraws(
      par_draws, par_draws, num_blocks=num_blocks, num_draws=num_draws)
  bayes_cov_se <- bayes_se_list$cov_se

  # Sanity check that the Bayes covariance SEs match mcmcse and the delta method
  bayes_cov_se_delta_method <-
    GetCovarianceMatrixSE(par_draws, par_draws, correlated_samples=TRUE)

  return(environment())
}




# Convert the standard deviation of X to the standard deviation of
# sqrt(X / num_obs)
# using the delta method.  This is useful for converting standard errors
# of the covariance of sqrt{N} E[mu] (e.g. as computed by the IJ
# estimator) to standard errors for the
# standard deviation of E[mu].
#' @export
ConvertCovSEToSESE <- function(x_cov, x_cov_se, num_obs) {
    return(x_cov_se / (2 * sqrt(x_cov * num_obs)))
}
