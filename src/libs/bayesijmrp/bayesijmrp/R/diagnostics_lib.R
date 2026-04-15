###################################################
# Evaluate influence functions using MrP weights

library(tidyverse)
library(brms)


#' @importFrom brms posterior_linpred
SafeGetEtaDraws <- function(mrpaw_list, post, survey_df) {
    if ("eta_draws" %in% names(mrpaw_list)) {
        eta_draws <- mrpaw_list$eta_draws
    } else {
        eta_draws <- posterior_linpred(post, newdata=survey_df)
    }
    return(eta_draws)
}


#' Evaluate the nonparametric influence function and IJ variance.
#' @param mrpaw_list The output of one of the Get*MCMCWeights functions
#' @param post The output of `brm(..., survey_df, family=binomial(link="logit"))`
#' @param survey_df The survey dataframe
#'
#' @export
EvalInfluenceFunction <- function(mrpaw_list, post, survey_df) {
    stopifnot(class(post) == "brmsfit")
    CheckLogitFamily(post)

    eta_draws <- SafeGetEtaDraws(mrpaw_list, post, survey_df)

    y <- GetResponse(post)
    lp_mat <- (y * t(eta_draws) - log(1 + exp(t(eta_draws)))) %>% t()
    lp_draws <- apply(lp_mat, FUN=sum, MARGIN=1)
    infl_vec <- cov(mrpaw_list$mrp_draws, lp_mat) %>% as.numeric()

    # With N datapoints, Var(N * infl) \approx Var(\sqrt{N} * MrP); the
    # factor of n_obs gives an estimate of Var(MrP).
    n_obs <- length(y)
    ij_var <- n_obs * var(infl_vec)

    return(list(infl_vec=infl_vec, ij_var=ij_var, lp_mat=lp_mat))
}
