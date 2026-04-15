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


GetDefaultDescription <- function(model_config) {
  return(with(model_config, paste(subdir, weight_var, model_name, sep="_")))
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


RunMAP <- function(model_ij,
                   stan_data,
                   num_draws,
                   num_obs_var,
                   weight_var,
                   keep_pars) {
    num_obs <- stan_data[[num_obs_var]]

    map_time <- Sys.time()
    map_fit <- rstan::optimizing(model_ij, data=stan_data, as_vector=FALSE)
    map_time <- Sys.time() - map_time

    # Get the optimal unconstrained parameters
    dummy_modelfit_ij <- GetDummyStanfitFromModel(model_ij, stan_data)
    par_names <- dummy_modelfit_ij@model_pars
    par_list <- get_inits(dummy_modelfit_ij)[[1]]
    for (par in par_names) {
        par_list[[par]] <- map_fit$par[[par]]
    }
    upars <- unconstrain_pars(dummy_modelfit_ij, par_list)

    # Get the Hessian numerically
    hess_upars <- numDeriv::jacobian(
      function(x) { grad_log_prob(dummy_modelfit_ij, x)}, upars)
    hess_upars <- 0.5 * (hess_upars + t(hess_upars))

    # This should match
    # hess_upars2 <- numDeriv::hessian(function(x) {
    #   log_prob(dummy_modelfit_ij, x)}, upars)

    # Get the variance of the score by evaluating the full score with
    # weightings on each individual datapoint.
    grad_log_prob_mat <- matrix(NA, nrow=num_obs, ncol=length(upars))
    pb <- txtProgressBar(min = 0, max = num_obs, style = 3)
    for (obs_n in 1:num_obs) {
        setTxtProgressBar(pb, obs_n)
        stan_data_w <- stan_data
        w_n <- rep(0, num_obs)
        w_n[obs_n] <- 1
        stan_data_w[[weight_var]] <- w_n
        n_modelfit_ij <- GetDummyStanfitFromModel(model_ij, stan_data_w)
        grad_log_prob_mat[obs_n, ] <- grad_log_prob(n_modelfit_ij, upars)
    }
    close(pb)
    score_cov <- cov(grad_log_prob_mat, grad_log_prob_mat)

    draw_example <- as.matrix(dummy_modelfit_ij, pars=keep_pars)
    hess_eig <- eigen(hess_upars)
    if (min(abs(hess_eig$values)) > 1e-8) {
        # Use Monte Carlo to get the covariance of the constrained pars.
        # Sadly I don't know how to safely convert from a parameter list to a
        # matrix except using a StanFit.
        sandwich_cov <- solve(hess_upars, t(solve(hess_upars, score_cov)))
        upar_draws <- rmvnorm(n=num_draws, mean=upars, sigma=sandwich_cov)
        const_par_draws <- matrix(NA, nrow(upar_draws), ncol(draw_example))
        pb <- txtProgressBar(min = 0, max = nrow(upar_draws), style = 3)
        for (b in 1:nrow(upar_draws)) {
            setTxtProgressBar(pb, b)
            par_draw <- constrain_pars(dummy_modelfit_ij, upar_draws[b, ])
            dummy_modelfit_ij <- GetDummyStanfitFromModel(
              model_ij, stan_data, init=list(par_draw))
            const_par_draws[b, ]  <- as.matrix(dummy_modelfit_ij, keep_pars)
        }
        close(pb)
        draw_map_cov <- cov(const_par_draws)
        colnames(draw_map_cov) <- colnames(draw_example)
        rownames(draw_map_cov) <- colnames(draw_example)
    } else {
        cat("The Hessian is singular.")
        print(hess_eig$values)
        sandwich_cov <- NULL
        const_par_draws <- NULL
        draw_map_cov <- NULL
    }
    return(environment())
}


RunBaseMCMC <- function(model,
                        model_ij,
                        stan_data,
                        num_obs_var,
                        weight_var,
                        lp_var,
                        keep_pars,
                        stan_args,
                        num_se_blocks=50,
                        num_se_draws=200,
                        num_cores=1) {
    ###########################
    # Sample

    options(mc.cores=num_cores)

    # Run the IJ sampler
    ij_fit_time <- Sys.time()
    # modelfit_ij <- sampling(
    #   model_ij, data=stan_data, iter=num_mcmc_samples, chains=num_mcmc_chains)
    modelfit_ij <- do.call(sampling,
      c(list(object=model_ij, data=stan_data), stan_args))
    ij_fit_time <- Sys.time() - ij_fit_time
    cat("IJ fit time: ", ij_fit_time, "\n")

    # Run the original sampler
    fit_time <- Sys.time()
    # modelfit <- sampling(
    #   model, data=stan_data, iter=num_mcmc_samples, chains=num_mcmc_chains)
    modelfit <- do.call(sampling,
      c(list(object=model, data=stan_data), stan_args))
    fit_time <- Sys.time() - fit_time
    cat("Original fit time: ", fit_time, "\n")

    modelfit_ij_summary <- summary(modelfit_ij, pars=keep_pars)
    modelfit_summary <- summary(modelfit, pars=keep_pars)

    #########################
    # Get the IJ esitmates.

    lp_draws <- OrderedExtract(modelfit_ij, lp_var)
    par_draws <- OrderedExtract(modelfit_ij, keep_pars)

    # IJ covariance
    ij_cov <- ComputeIJCovariance(lp_draws, par_draws)

    # Bayesian covariance.
    bayes_cov <- cov(par_draws, par_draws)

    ##############################
    # SEs

    se_results <- bayesijlib::ComputeIJStandardErrors(
      lp_draws, par_draws, num_se_blocks, num_se_draws)

    se_results_block_doubled <- bayesijlib::ComputeIJStandardErrors(
      lp_draws, par_draws, 2 * num_se_blocks, num_se_draws)

    return(environment())
}


RunMCMCBootstraps <- function(model_ij,
                              stan_data,
                              num_obs_var,
                              weight_var,
                              keep_pars,
                              stan_args,
                              num_boots=50,
                              num_cores=1) {
    #################################
    # Bootstrap

    options(mc.cores=1) # Cannot do parallel within parallel
    cat("Computing the bootstraps.\n")
    boot_results <- foreach(b=1:num_boots) %dopar% {
      RunSingleBootstrap(model_ij=model_ij,
                         stan_data=stan_data,
                         num_obs_var=num_obs_var,
                         weight_var=weight_var,
                         keep_pars=keep_pars,
                         num_boots=num_boots,
                         stan_args=stan_args,
                         num_cores=num_cores)
    }

    boot_time <- do.call(
      sum, lapply(boot_results, function(x) { x$sampling_time } ))
    cat("Bootstrap time: ", boot_time, "\n")

    boot_means <- do.call(
      bind_rows, lapply(boot_results, function(x) { x$boot_means } )) %>%
      as.matrix()
    draw_boot_cov <- cov(boot_means, boot_means)

    #################################
    # Standard errors

    # Note that the bootstrap samples alrady contain both Monte Carlo
    # and frequentist (bootstrapping) variability built in, since each
    # bootstrap is a new
    # Monte Carlo chain.  So we can treat each bootstrapped mean as an
    # independent random observation.
    draw_boot_cov_se <- GetCovarianceMatrixSE(
      boot_means, boot_means, correlated_samples=FALSE)

    return(environment())
}
