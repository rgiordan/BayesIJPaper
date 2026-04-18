
LoadIntoEnv <- function(full_path) {
    new_env <- new.env()
    load(full_path, envir=new_env)
    new_env <- as.list(new_env)
    return(new_env)
}


GetDummyStanfitFromModel <- function(model, data, init=NULL) {
    if (!is.null(init)) {
        suppressWarnings(
            dummy_stanfit <-
                sampling(model, data=data,
                        algorithm="Fixed_param", init=init,
                        iter=1, chains=1, refresh=0))
    } else {
        suppressWarnings(
            dummy_stanfit <-
                sampling(model, data=data,
                        algorithm="Fixed_param",
                        iter=1, chains=1, refresh=0))
    }
    return(dummy_stanfit)
}


# df: A dataframe
# ecol: A vector containing unique values picking out exchangable rows
# w: A "weight" vector giving weight to each of the unique values of ecol
# Returns: df with rows repeated according to the weighting.
#' @export
BootstrapByExchangableColumn <- function(df, ecol, w) {
    ecol_vals <- unique(ecol)
    ecol_n <- length(w)
    stopifnot(ecol_n == length(ecol_vals))
    stopifnot(length(ecol) == nrow(df))
    df_list <- lapply(ecol_vals, function(v) { df[ ecol == v, , drop=FALSE]})
    RepeatDF <- function(df_v, reps) {
        if (reps > 0) {
            return(do.call(bind_rows, lapply(1:reps, function(x) { df_v })))
        } else {
            return(data.frame())
        }
    }
    return(
        do.call(bind_rows,
                lapply(1:ecol_n,
                       function(i) {
                           RepeatDF(df_list[[i]], w[i])
                       })
                )
    )
}


ComputeInflDraws <- function (loglik_draws_mat, param_draws_mat) {
    if (nrow(loglik_draws_mat) != nrow(param_draws_mat)) {
        stop(paste0("loglik_draws_mat and param_draws_mat must have the ",
            "same number of rows."))
    }
    num_obs <- ncol(loglik_draws_mat)
    infl_draws_mat <- num_obs * cov(loglik_draws_mat, param_draws_mat)
    colnames(infl_draws_mat) <- colnames(param_draws_mat)
    return(infl_draws_mat)
}


ComputeIJFrequentistSe <- function (loglik_draws_mat, param_draws_mat) {
  infl_draws_mat <- ComputeInflDraws(loglik_draws_mat, param_draws_mat)
  return(GetCovarianceMatrixSE(
            infl_draws_mat, infl_draws_mat, correlated_samples=FALSE))
}



#' Return an estimate of the infinitesimal jackknife covariance estimate
#' of the frequentist variance of the posterior expectations of the parameters
#' in param_draws_mat.
#' @param loglik_draws_mat Draws of the log likelihood.
#' @param param_draws_mat Draws of the parameters of interest..
#' @return The IJ covariance matrix, which is an estimate of
#' N * Cov(E[params | x]), where N is the number of distinct exchangeable
#' observations.
#' @export
ComputeIJCovariance <- function(loglik_draws_mat, param_draws_mat,
                                exchangeable_col=NULL) {
  if (nrow(loglik_draws_mat) != nrow(param_draws_mat)) {
    stop(paste0("loglik_draws_mat and param_draws_mat must have the ",
                "same number of rows."))
  }
  num_obs <- ncol(loglik_draws_mat)
  infl_draws_mat <- num_obs * cov(loglik_draws_mat, param_draws_mat)
  colnames(infl_draws_mat) <- colnames(param_draws_mat)
  ij_cov <- ComputeIJCovarianceFromInfluence(infl_mat)
  return(ij_cov)
}


#' Return an estimate of the infinitesimal jackknife covariance estimate
#' of the frequentist variance of the posterior expectations of the parameters
#' in param_draws_mat.
#' @param infl_mat A matrix of n * cov(lp, par), with datapoints in rows and parameters
#'                 in columns.
#' @return The IJ covariance matrix, which is an estimate of
#' N * Cov(E[params | x]), where N is the number of distinct exchangeable
#' observations.
#' @export
ComputeIJCovarianceFromInfluence <- function(infl_mat) {
    ij_cov <- cov(infl_mat, infl_mat)
    colnames(ij_cov) <- rownames(ij_cov) <- colnames(infl_mat)
    return(ij_cov)
}

