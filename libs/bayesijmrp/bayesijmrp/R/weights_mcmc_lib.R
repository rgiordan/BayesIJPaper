library(tidyverse)
library(brms)


##############################################
# MCMC


#' Get MrPaw weights for the logistic MCMC estimator.
#' @param logit_post The output of `brm(..., survey_df, family=binomial(link="logit"))`
#' @param survey_df The survey dataframe
#' @param pop_df The population dataframe
#' @param pop_w Optional.  The weight given to each row of pop_df.  Defaults to ones.
#' @param save_preds Optional.  If true, save the posterior predictions for re-use.
#' @param re_formula Optional.  Formula containing group-level effects to be considered in the prediction. If `NULL` (default), include all group-level effects; if `NA`, include no group-level effects.
#' @param allow_new_levels Optional.  If true, allow new levels of group-level effects in prediction stage.
#'
#' @return Draws from the MrP estimate, and the weight vector
#' whose n-th entry is d E[MrP | X, Y] / d y_n.
#'
#' @importFrom brms posterior_epred
#' @importFrom brms posterior_linpred
#'@export
GetLogitMCMCWeights <- function(logit_post, survey_df, pop_df, pop_w=NULL, 
                                save_preds=FALSE, re_formula=NULL,
                                allow_new_levels=FALSE) {
    stopifnot(class(logit_post) == "brmsfit")

    CheckLogitFamily(logit_post)

    pop_w <- GetPopulationWeights(pop_df, pop_w)

    # posterior_epred should be yhat.
    # posterior_linpred should be theta^T x_n.  
    # Draws are in rows and observations in columns.
    yhat_pop <- posterior_epred(logit_post, newdata=pop_df,
                                re_formula=re_formula,
                                allow_new_levels=allow_new_levels)
    mrp_draws_logit <- yhat_pop %*% pop_w

    # Get the influence scores for the logit model
    # The log likelihood derivative for the n^th datapoint is just the theta^T x_n
    # TODO: optionally return the linpred for further diagnostics
    ll_grad_draws_logit <- posterior_linpred(logit_post, newdata=survey_df)
    # w_logit <- cov(mrp_draws_logit, ll_grad_draws_logit)[1,]

    result_list <- list(
        mrp_draws=mrp_draws_logit,
    )

    if (save_preds) {
        yhat_draws <- posterior_epred(logit_post, newdata=survey_df)
        eta_draws <- posterior_linpred(logit_post, newdata=survey_df)

        result_list$yhat_pop <- yhat_pop
        result_list$yhat_draws <- yhat_draws
        result_list$eta_draws <- eta_draws
    }
    return(result_list)
}



###################################################
# Evaluate influence functions using MrP weights


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
