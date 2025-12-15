library(rstanarm)
library(tidyverse)
library(rstansensitivity)

opt <- list()
opt$num_cores <- 4
opt$num_mcmc_chains <- 4

base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
source(file.path(base_dir, "rstanarm_lib.R"))
stan_examples_dir <- file.path(base_dir, "example-models")

# The random effects will be distributed according to a bimodal distribution.
set.seed(42)

rstan_fits <- list()

mean1 <- 2.0
var1 <- 1^2
mean2 <- 8.0
var2 <- 1.5^2
beta_true <- 0.5
offset_true <- 0.1

if (FALSE) {
    num_sims <- 20
    num_re <- 200
    obs_per_re <- 100  # 100 works for a kernel estimator
}
if (TRUE) {
    num_sims <- 30
    obs_per_re <- 25 
    num_re <- 800
}

for (sim in 1:num_sims) {
    cat("===========\nSimulation ", sim, "\n")
    lambda1 <- rnorm(num_re, mean=mean1, sd=sqrt(var1))
    lambda2 <- rnorm(num_re, mean=mean2, sd=sqrt(var2))
    
    lambda_z <- runif(num_re) < 0.5
    lambda <- lambda_z * lambda1 + (1 - lambda_z) * lambda2
    
    # Rescale
    lambda <- lambda - mean(lambda)
    lambda <- lambda / sd(lambda)
    lambda <- lambda * 1.0
    
    if (FALSE) {
        hist(lambda, 100)
    }
    
    z <- rep(1:num_re, each=obs_per_re)
    num_obs <- length(z)
    x <- rnorm(num_obs)
    
    y_latent <- offset_true + beta_true * x + lambda[z]
    y_p <- exp(y_latent) / (1 + exp(y_latent))
    summary(y_p)
    y <- as.integer(runif(num_obs) > y_p)
    
    if (FALSE) {
        hist(y_latent, 100)
        plot(-0.1 + beta_true * x + lambda[z], y_p)
    }
    
    model_config <- list(
        model_name="kernel_simulation",
        subdir="kernel",
        formula_str="y ~ 1 + x + (1|z)",
        rstan_fun="stan_glmer",
        family="binomial(link=\"logit\")",
        num_obs_var="N",
        prior="student_t(df=7)",
        prior_intercept="student_t(df=7)",
        num_samples=1000,
        num_boots=1000,
        exchangeable_col="z",
        num_obs=num_obs,
        keep_pars=c("(Intercept)", "x", "z"),
        num_exchangeable_obs=num_re,
        desc="kernel"
    )
    
    
    df <- data.frame(y=y, x=x, z=z)
    out_filename <- file.path(stan_examples_dir,
                              model_config$subdir,
                              sprintf("%s.data.R", model_config$model_name))
    SaveDataFrameToFile(df, model_config, out_filename)
    
    fit_time <- Sys.time()
    rstan_fit <- RunRstanArm(model_config, df, chains=opt$num_mcmc_chains)
    fit_time <- Sys.time() - fit_time
    print(fit_time)
    
    summary(rstan_fit)

    #######################
    # Loglik mat
    
    loglik_mat_time <- Sys.time()
    full_loglik_mat <- log_lik(rstan_fit)
    loglik_mat_time <- Sys.time() - loglik_mat_time
    print(loglik_mat_time)
    
    GetGroupedLoglikMat <- function(rstan_fit, rstanarm_ij_config, df, full_loglik_mat) {
        if (rstanarm_ij_config$exchangeable_col != "") {
            stopifnot(rstanarm_ij_config$exchangeable_col %in% names(df))
            exch_col <- df[[rstanarm_ij_config$exchangeable_col]]
            loglik_mat <-
                lapply(unique(exch_col),
                       function(group_id) {
                           full_loglik_mat[, exch_col == group_id, drop=FALSE ]
                       }) %>%
                lapply(function(x) { apply(x, MARGIN=1, FUN=sum) }) %>%
                reduce(cbind)
        }
        return (loglik_mat)
    }
    
    loglik_mat <- GetGroupedLoglikMat(rstan_fit,
                                      rstanarm_ij_config=model_config,
                                      df=df,
                                      full_loglik_mat=full_loglik_mat)
    dim(loglik_mat)
    
    result <- list(loglik_mat=loglik_mat,
                   rstan_fit=rstan_fit,
                   loglik_mat_time=loglik_mat_time,
                   fit_time=fit_time,
                   lambda=lambda)
    rstan_fits[[sim]] <- result
}

save(rstan_fits, num_re,
     file=file.path(stan_examples_dir, "kernel",
                    sprintf("kernel_fit_obs_per_re%d.Rdata", obs_per_re)))

