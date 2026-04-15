library(rstan)
library(doParallel)
library(numDeriv)
library(mvtnorm)
library(lme4)


##############################################
# Everything below is specific to the paper.

LoadStanData <- function(model_loc, model_name, num_obs_var, weight_var) {
    stan_data <- new.env()
    source(file.path(model_loc, paste(model_name, "data.R", sep=".")),
           local=stan_data)
    stan_data <- as.list(stan_data)

    num_obs <- stan_data[[num_obs_var]]
    stan_data[[weight_var]] <- rep(1, num_obs)

    return(stan_data)
}


SetConfigDefaults <- function(model_config,
                              default_num_samples,
                              default_num_boots) {
  if (is.na(model_config$num_samples)) {
    model_config$num_samples <- default_num_samples
  }
  if (is.na(model_config$num_boots)) {
    model_config$num_boots <- default_num_boots
  }
  return(model_config)
}


RunSingleBootstrap <- function(model_ij,
                               stan_data,
                               num_obs_var,
                               weight_var,
                               keep_pars,
                               num_boots,
                               stan_args,
                               num_cores=1) {
    # Run the bootstraps.
    num_obs <- stan_data[[num_obs_var]]
    w_boot <- rmultinom(1, num_obs, rep(1 / num_obs, num_obs))[, 1]
    boot_stan_data <- stan_data
    boot_stan_data[[weight_var]] <- w_boot
    sampling_time <- Sys.time()
    # modelfit_boot <- sampling(model_ij,
    #                           data=boot_stan_data,
    #                           chains=num_mcmc_chains,
    #                           iter=num_mcmc_samples,
    #                           refresh=0)
    modelfit_boot <- do.call(sampling,
      c(list(object=model_ij, data=boot_stan_data, refresh=0), stan_args))
    sampling_time <- Sys.time() - sampling_time
    par_draws_boot <- OrderedExtract(modelfit_boot, keep_pars)
    boot_means <- colMeans(par_draws_boot)
    diagnostics <- rstan::summary(
      modelfit_boot, pars=keep_pars)$summary[, c("mean", "n_eff", "Rhat")]
    return(list(
         boot_means=boot_means,
         par_draws_boot=par_draws_boot,
         w_boot=w_boot,
         diagnostics=diagnostics,
         sampling_time=sampling_time))
}

