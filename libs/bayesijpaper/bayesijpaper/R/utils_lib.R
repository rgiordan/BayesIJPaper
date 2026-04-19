
# Use pop_w for weights if specfied, otherwise use 
# a vector of ones as long as pop_df.
GetPopulationWeights <- function(pop_df, pop_w=NULL) {
    if (is.null(pop_w)) {
        pop_w <- rep(1, nrow(pop_df)) / nrow(pop_df)
    }

    weight_sum <- sum(pop_w)
    if (abs(weight_sum - 1) > 1e-6) {
        warning(sprintf("The population weights do not sum to one: %f", weight_sum))
    }
    return(pop_w)
}




CheckLogitFamily <- function(logit_fit) {
    logit_family <- family(logit_fit)
    if (!(logit_family$family %in% c("binomial", "bernoulli"))) {
      warning(sprintf("Family is not binomial or bernoulli (%s)", logit_family$family))
    }
    if (logit_family$link != "logit") {
      warning(sprintf("Link is not logit (%s)", logit_family$link))
    }
}






#' Get the response variable (y) from the posterior.
#' I don't see this use clearly documented, so I want to factor it out
#' for testing.
#' @param post A brms posterior
#'
#' @return The numeric response variable used for the posterior fitting
#' @importFrom brms standata
#'@export
GetResponse <- function(post) {
    return(as.numeric(brms::standata(post)$Y))
}


