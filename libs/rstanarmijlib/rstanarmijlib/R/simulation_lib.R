
# Just to keep this standardized.
SimulateRegressors <- function(num_obs) {
    df <- tibble(x=rnorm(num_obs), y=0)
    obs_per_re <- 5
    df$z <- rep(1:ceiling(num_obs / obs_per_re), each=obs_per_re)
    return(df)
}

# Simulate new y responses, keeping the regressors fixed.  Return a
# dataframe identical to df but with the response varaibles updated
# with new, simulated values.
#
# vcov_list should be a list, whose names are the random effect terms,
# whose entries are the random effect covariance matrix.
# For Gaussian models, it must also have the sc attribute set to the
# residual standard deviation.
SimulateDataset <- function(formula_str, df, beta, vcov_list, model_family) {
    formula_val <- formula(formula_str)

    if (!is.null(findbars(formula_val))) {
        # There are random effects
        glform <- glFormula(formula_val, df)

        # We will add the random effects to yfree_mean one by one in the loop
        # below.
        yfree_mean <- glform$X %*% beta

        # reTrms are the named random effect variables.
        reTrms <- glform$reTrms

        # rex_list will contain the random effect values for the rows of the
        # original dataframe.
        rex_list <- list()
        re_terms <- names(reTrms$flist)
        for (i in 1:length(re_terms)) {
            re_term <- re_terms[i]
            re_vals <- as.integer(as.factor(reTrms$flist[[re_term]]))
            re_num <- length(unique(re_vals))

            # Zt should be the sparse indicator matrix.
            # I hope these are stored in order.
            Zt <- reTrms$Ztlist[[i]]
            # Don't know what this was or why I neeeded it
            #cnms <- reTrms$cnms[[re_term]]

            vcov <- vcov_list[[re_term]]
            re_draws <- rmvnorm(re_num, sigma=vcov)
            re_draws_flat <- matrix(t(re_draws), nrow=1)
            re_draws_sp <- Matrix(re_draws_flat, sparse=TRUE)
            rex <- as.numeric(re_draws_sp %*% Zt)
            yfree_mean <- yfree_mean + rex
            rex_list[[i]] <- rex
        }
    } else {
        # There are no random effects to simulate.
        x_mat <- model.matrix(formula_val, df)
        yfree_mean <- x_mat %*% beta
    }

    # Draw new y values based on the mean computed above.
    # I feel like this should be done somewhere.
    n_obs <- length(yfree_mean)
    if (model_family$family == "gaussian") {
        fe_sd <- attr(vcov_list, "sc")
        y_sim <- rnorm(n_obs, mean=yfree_mean, sd=fe_sd)
    } else if (model_family$family == "binomial") {
        phat <- model_family$linkinv(yfree_mean)
        y_sim <- rbinom(n_obs, prob=phat, size=1)
    } else if (model_family$family == "poisson") {
        lamhat <- model_family$linkinv(yfree_mean)
        y_sim <- rpois(n_obs, lamhat)
    } else {
        stop(paste0("Family ", model_family$family, "not implemented."))
    }

    df_sim <- df
    response_name <- all.vars(formula_val)[1]
    df_sim[[response_name]] <- y_sim
    df_sim[[paste0(response_name, "_free_mean")]] <- yfree_mean
    return(df_sim)
}


SimulateDatasetFromFit <- function(rstan_fit, df, model_config) {
    if (!is.null(findbars(formula(model_config$formula_str)))) {
        # The model has random effects
        vcov_list <- VarCorr(rstan_fit)
    } else {
        # Mimick the structure for sigma
        vcov_list <- list()
        attr(vcov_list, "sc") <- sigma(rstan_fit)
    }
    SimulateDataset(
        formula_str=model_config$formula_str,
        df=df,
        beta=fixef(rstan_fit),
        vcov_list=vcov_list,
        model_family=eval(parse(text=model_config$family))
    )
}


SimulateDatasetFromGroundTruth <- function(ground_truth, df, model_config) {
    # If a generative_formula_str is in pars, use it.  Otherwise use the formula
    # from model_config.
    if (is.null(ground_truth$generative_formula_str)) {
        cat("\nUsing model formula.\n")
        generative_formula_str <- model_config$formula_str
    } else {
        cat("\nUsing ground truth formula:\n")
        cat(ground_truth$generative_formula_str , "\n\n")
        generative_formula_str <- ground_truth$generative_formula_str
    }

    # TODO: optionally re-generate regressors?
    df_sim <-
        SimulateDataset(
            formula_str=generative_formula_str,
            df=df,
            beta=ground_truth$beta,
            vcov_list=ground_truth$vcov_list,
            model_family=eval(parse(text=model_config$family)))
    return(df_sim)
}



RunRstanarmSimulations <- function(ground_truth,
                                   df,
                                   rstanarm_ij_config,
                                   stan_examples_dir,
                                   num_sims=200,
                                   num_mcmc_chains=4,
                                   num_cores=1,
                                   simulate_from_fit=TRUE,
                                   resample_regressors=TRUE) {
    # Use our multiple cores for the simulations, not the MCMC chains.
    registerDoParallel(cores=num_cores)

    stop("Needs updating")

    ###############################
    # Set defaults
    if (is.na(rstanarm_ij_config$num_samples)) {
        rstanarm_ij_config$num_samples <- default_num_mcmc_samples
    }

    ###############################
    # Run the simulations
    sim_results <- foreach(b=1:num_sims) %dopar% {
        options(mc.cores=1) # Don't do parallel within parallel

        # Use BootstrapByExchangableColumn
        if (resample_regressors) {
            df_sim <- BootstrapExchangeableRows(df, rstanarm_ij_config$exchangeable_col)
        } else {
            df_sim <- df
        }

        if (simulate_from_fit) {
            df_sim <- SimulateDatasetFromFit(ground_truth, df_sim, rstanarm_ij_config)
        } else {
            df_sim <- SimulateDatasetFromGroundTruth(ground_truth, df_sim, rstanarm_ij_config)
        }

        sampling_time <- Sys.time()
        sim_fit <- RunRstanArm(rstanarm_ij_config, df_sim, chains=num_mcmc_chains)
        sampling_time <- Sys.time() - sampling_time

        draws_mat_sim <- GetProcessedDrawsMat(sim_fit, rstanarm_ij_config)
        sim_means <- colMeans(draws_mat_sim)
        sim_bayes_cov <- cov(draws_mat_sim, draws_mat_sim)
        diagnostics <- summary(sim_fit)[, c("mean", "n_eff", "Rhat")]
        list(sim_means=sim_means,
             sim_bayes_cov=sim_bayes_cov,
             diagnostics=diagnostics,
             sampling_time=sampling_time)
    }


    ###############################
    # Compute the summary statistics

    sim_means <- as.matrix(do.call(bind_rows, lapply(sim_results, function(x) { x$sim_means } )))
    sim_cov <- cov(sim_means, sim_means)

    # Note that the simulation samples alrady contain both Monte Carlo
    # and frequentist variability built in, since each simulation is a new
    # Monte Carlo chain.  So we can treat each simulated posterior means as an independent
    # random observation.
    sim_cov_se <- GetCovarianceMatrixSE(sim_means, sim_means, correlated_samples=FALSE)

    return(environment())
}


################################################
# Save a dataframe in the Stan examples format
SaveDataFrameToFile <- function(df, rstanarm_ij_config, out_filename) {
    out_file <- file(out_filename, "w")
    CatVar <- function(varname, value) {
        cat(sprintf("%s <- c(%s)", varname,
                    paste(value, collapse=",\n")), "\n",
            file=out_file)
    }
    cat(sprintf("# Generated %s\n", Sys.time()), file=out_file)
    cat(rstanarm_ij_config$num_obs_var, " <-", nrow(df), "\n", file=out_file)
    for (par_name in names(df)) {
        CatVar(par_name, df[[par_name]])
    }
    close(out_file)
}
