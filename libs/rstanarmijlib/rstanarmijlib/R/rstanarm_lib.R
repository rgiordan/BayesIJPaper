

############################################
# This whole file is only for the paper.


GetRstanarmDataFrame <- function(stan_data, num_obs) {
    # Gather everything in stan_data with the right length.
    CheckValid <- function(par) {
        v <- stan_data[[par]]
        if (!is.numeric(v)) {
            return(FALSE)
        }
        if (length(v) != num_obs) {
            return(FALSE)
        }
        # if (par == stan_data$bayes_ij_config$w_var) {
        #     return(FALSE)
        # }
        return(TRUE)
    }
    df_list <- list()
    for (par in names(stan_data)) {
        if (CheckValid(par)) {
            df_list[[par]] <- stan_data[[par]]
        }
    }
    df <- (do.call(bind_cols, df_list))
    return(df)
}


LoadRstanarmDataframe <- function(rstanarm_ij_config, stan_examples_dir) {
    # Load the data
    full_filename <- with(rstanarm_ij_config,
                          file.path(stan_examples_dir, subdir,
                                    paste(model_name, "data.R", sep=".")))
    if (!file.exists(full_filename)) {
        stop(sprintf("File %s does not exist", full_filename))
    }
    stan_data <- new.env()
    source(full_filename, local=stan_data)
    stan_data <- as.list(stan_data)
    num_obs <- rstanarm_ij_config$num_obs
    df <- GetRstanarmDataFrame(stan_data, num_obs)
    return(df)
}


GetRstanarmFunction <- function(rstan_fun) {
    if (rstan_fun == "stan_glmer") {
        return(stan_glmer)
    } else if (rstan_fun == "stan_glm") {
        return(stan_glm)
    } else {
        stop("Unknown function.")
    }
}



# Generate a list suitable for use as a configuration file.
GenerateRstanarmConfig <- function(
    model_name,
    subdir,
    formula_str,
    rstan_fun,
    family,
    num_obs_var) {
    return(list(
        model_name = model_name,
        subdir = subdir,
        formula_str = formula_str,
        rstan_fun = rstan_fun,
        family = family,
        num_obs_var = num_obs_var
    ))
}

# Automatically process an rstanarm_config and dataset to get variables to save
# for computing the IJ.
GetIJConfig <- function(rstanarm_config, stan_examples_dir,
                        num_samples=NA, num_boots=NA,
                        exchangeable_col=c(), num_saved_re_pars=5) {
    # Append values to ij_config that will be saved in the configuration.
    ret_ij_config <- list()
    with(rstanarm_config, {
        ij_config <- list()
        ij_config$num_samples <- num_samples
        ij_config$num_boots <- num_boots
        ij_config$exchangeable_col <- exchangeable_col

        stan_data <- new.env()
        source(file.path(stan_examples_dir, subdir,
                         paste(model_name, "data.R", sep=".")), local=stan_data)
        stan_data <- as.list(stan_data)

        # Auto-generate the parameters to save
        num_obs <- stan_data[[num_obs_var]]
        ij_config$num_obs <- num_obs

        # Run the model to get the actual parameter names and levels.
        stopifnot(length(exchangeable_col) <= 1)

        df <- GetRstanarmDataFrame(stan_data, num_obs)
        stan_fun <- GetRstanarmFunction(rstan_fun)
        suppressWarnings(
            empty_fit <- stan_fun(formula(formula_str),
                                  data = df,
                                  family = eval(parse(text=family)),
                                  #prior = eval(parse(text=prior)),
                                  #prior_intercept = eval(parse(text=prior_intercept)),
                                  iter=1,
                                  chains=1,
                                  cores=1)
        )

        par_names <- colnames(as.matrix(empty_fit))
        re_inds <- grepl("^b\\[.*\\]", par_names)
        pars <- par_names[!re_inds]
        re_pars <- par_names[re_inds]

        if (is.na(num_saved_re_pars)) {
            num_saved_re_pars <- 5
        }

        # See this for documenation of flist:
        # https://www.rdocumentation.org/packages/lme4/versions/1.1-21/topics/mkReTrms
        keep_re_pars <- c()
        flist <- empty_fit$glmod$reTrms$flist
        for (re_level in names(flist)) {
            cat(re_level, levels(flist[[re_level]]), "\n")
            vals <- levels(flist[[re_level]])
            level_num_saved_re_pars <- min(num_saved_re_pars, length(vals))
            keep_vals <- sort(sample(vals, level_num_saved_re_pars, replace=FALSE))
            re_par_levels <- as.character(paste(re_level, keep_vals, sep=":"))
            for (re_par_level in re_par_levels) {
                keep_re_pars <- c(keep_re_pars,
                                  re_pars[str_detect(re_pars, paste0(re_par_level, "\\]"))])
            }
        }
        stopifnot(all(keep_re_pars %in% re_pars))
        keep_pars <- c(keep_re_pars, pars)
        ij_config$keep_pars <- keep_pars

        # TODO: exchangeable_col is "" when empty, not length zero.
        stopifnot(length(exchangeable_col) == 1)
        if (exchangeable_col == "") {
            exchangeable_col_name <- "independent"
        } else {
            exchangeable_col_name <- exchangeable_col
        }

        if (exchangeable_col == "") {
            ij_config$num_exchangeable_obs <- num_obs
        } else {
            ij_config$num_exchangeable_obs <- length(unique(df[[exchangeable_col]]))
        }

        ij_config$desc <-
            paste(str_replace(subdir, "\\/", "_"),
                  model_name,
                  exchangeable_col_name, sep="_")

        ret_ij_config <<- ij_config
    })
    return(ret_ij_config)
}


# Get the draws mat for selected parameters as well as some transformed values.
GetProcessedDrawsMat <- function(rstan_fit, rstanarm_ij_config) {
    draws_mat <- as.matrix(rstan_fit, pars=rstanarm_ij_config$keep_pars)

    AppendNamedColumn <- function(vec, vec_name) {
        new_draws_mat <- matrix(vec, nrow=nrow(draws_mat))
        colnames(new_draws_mat) <- vec_name
        draws_mat <<- cbind(draws_mat, new_draws_mat)
    }

    # Get patterns matching something like Sigma[z: x, x], which are random effect
    # variances.
    re_var_cols <-
        colnames(draws_mat)[grepl("Sigma\\[.+:(.*),\\1\\]", colnames(draws_mat))]

    if ("sigma" %in% colnames(draws_mat)) {
        AppendNamedColumn(log(draws_mat[, "sigma"]), "log_sigma")
    }
    for (re_var_col in re_var_cols) {
        AppendNamedColumn(log(draws_mat[, re_var_col]), paste("log", re_var_col, sep="_"))
    }
    return(draws_mat)
}



SetConfigDefaults <- function(rstanarm_ij_config,
                              default_num_samples=2000,
                              default_num_boots=200) {
    if (is.na(rstanarm_ij_config$num_samples)) {
        rstanarm_ij_config$num_samples <- default_num_samples
    }
    if (is.na(rstanarm_ij_config$num_boots)) {
        rstanarm_ij_config$num_boots <- default_num_boots
    }
    return(rstanarm_ij_config)
}


RunRstanArm <- function(rstanarm_ij_config, df, chains) {
    rstan_fit <- with(rstanarm_ij_config,
                      GetRstanarmFunction(rstan_fun)(
                          formula(formula_str),
                          data = df,
                          family = eval(parse(text=family)),
                          # prior = eval(parse(text=prior)),
                          # prior_intercept = eval(parse(text=prior_intercept)),
                          iter = num_samples,
                          chains = chains))
    return(rstan_fit)
}


#' Aggregate the draws of the log likelihood according to a grouping variable
#' where the observations are exchangeable within a group.
#' @param loglik_draws_mat Draws of the log likelihood.
#' @param exchangeable_col Optional, a vector of indices indicating the grouping
#' of exchangeable observations.
#' @return The log likelihood draws of aggregated by the given grouping.
#' @export
GroupLogLikelihoodDraws <- function(loglik_draws_mat, exchangeable_col) {
  if (length(exchangeable_col) != ncol(loglik_draws_mat)) {
    stop(paste0("exchangeable_col must be as long as the number of ",
                "columns in loglik_draws_mat."))
  }

  # Sum the log likelihood within exchangable observations, drop the
  # grouping column, and re-cast as a matrix.
  loglik_draws_mat <- aggregate(
      t(loglik_draws_mat),
      by=list(exchangeable_col=exchangeable_col), sum)[, -1] %>%
    t() %>%
    as.matrix()
  return(loglik_draws_mat)
}


#' @importFrom bayesijlib ComputeIJStandardErrors
# Run the base MCMC and compute the IJ for an rstanarm configuration.
RunRstanarmBaseMCMC <- function(rstanarm_ij_config,
                                stan_examples_dir,
                                num_se_blocks=50,
                                num_se_draws=200,
                                num_mcmc_chains=4,
                                num_cores=1) {

    #######################################
    # Load the data.
    options(mc.cores = num_cores)
    df <- LoadRstanarmDataframe(rstanarm_ij_config, stan_examples_dir)

    #######################################
    # Run MCMC.

    fit_time <- Sys.time()
    rstan_fit <- RunRstanArm(rstanarm_ij_config, df, chains=num_mcmc_chains)
    fit_time <- Sys.time() - fit_time

    ###############################
    # Get draws

    draws_mat <- GetProcessedDrawsMat(rstan_fit, rstanarm_ij_config)

    ########################################################################
    # Get the log likelihood grouped according to the exchangeable column.

    ij_time <- Sys.time()
    lp_mat <- log_lik(rstan_fit)
    if (rstanarm_ij_config$exchangeable_col != "") {
        stopifnot(rstanarm_ij_config$exchangeable_col %in% names(df))
        exch_col <- df[[rstanarm_ij_config$exchangeable_col]]
        lp_mat <- GroupLogLikelihoodDraws(lp_mat, exch_col)
    }

    ij_cov <- ComputeIJCovariance(lp_mat, draws_mat)
    ij_time <- Sys.time() - ij_time
    bayes_cov <- cov(draws_mat, draws_mat)

    ##############################
    # SEs

    se_results <- bayesijlib::ComputeIJStandardErrors(
      lp_mat, draws_mat, num_se_blocks, num_se_draws)

    se_results_block_doubled <- bayesijlib::ComputeIJStandardErrors(
      lp_mat, draws_mat, 2 * num_se_blocks, num_se_draws)

    return(environment())
}


GetExchangeableColumn <- function(exchangeable_col, df) {
  if (exchangeable_col == "") {
    ecol <- 1:nrow(df)
  } else {
    ecol <- df[[exchangeable_col]]
    stopifnot(length(ecol) == nrow(df))
  }
  return(ecol)
}


RunRstanarmBootstraps <- function(rstanarm_ij_config,
                                  stan_examples_dir,
                                  num_mcmc_chains=4,
                                  num_cores=1) {
    # Use our multiple cores for the bootstraps, not the MCMC chains.
    registerDoParallel(cores=num_cores)

    ###############################
    # Load the data
    df <- LoadRstanarmDataframe(rstanarm_ij_config, stan_examples_dir)

    ecol <- GetExchangeableColumn(rstanarm_ij_config$exchangeable_col, df)
    ecol_vals <- unique(ecol)
    ecol_n <- length(ecol_vals)

    ###############################
    # Run the bootstraps
    boot_results <- foreach(b=1:rstanarm_ij_config$num_boots) %dopar% {
        options(mc.cores=1) # Don't do parallel within parallel
        w <- rmultinom(1, ecol_n, rep(1/ecol_n, ecol_n))[, 1]
        df_boot <- BootstrapByExchangableColumn(df, ecol, w)
        sampling_time <- Sys.time()
        boot_fit <- RunRstanArm(rstanarm_ij_config, df_boot, chains=num_mcmc_chains)
        sampling_time <- Sys.time() - sampling_time

        draws_mat_boot <- GetProcessedDrawsMat(boot_fit, rstanarm_ij_config)
        boot_means <- colMeans(draws_mat_boot)
        diagnostics <- summary(boot_fit)[, c("mean", "n_eff", "Rhat")]

        # Bootstrap the covariances to get a notion of their uncertainty

        lp_mat <- log_lik(boot_fit)
        if (rstanarm_ij_config$exchangeable_col != "") {
            stopifnot(rstanarm_ij_config$exchangeable_col %in% names(df_boot))
            exch_col <- df_boot[[rstanarm_ij_config$exchangeable_col]]
            lp_mat <- rstanarmijlib::GroupLogLikelihoodDraws(lp_mat, exch_col)
        }

        ij_cov <- ComputeIJCovariance(lp_mat, draws_mat_boot)
        bayes_cov <- cov(draws_mat_boot, draws_mat_boot)

        list(boot_means=boot_means,
             draws_mat_boot=draws_mat_boot,
             diagnostics=diagnostics,
             w=w,
             sampling_time=sampling_time,
             ij_cov=ij_cov,
             bayes_cov=bayes_cov)
    }


    ###############################
    # Compute the summary statistics

    boot_time <- do.call(sum, lapply(
      boot_results, function(x) { x$sampling_time } ))
    cat("Bootstrap time: ", boot_time, "\n")

    boot_means <- as.matrix(do.call(
      bind_rows, lapply(boot_results, function(x) { x$boot_means } )))
    boot_cov <- cov(boot_means, boot_means)

    boot_ij_covs <- lapply(
      boot_results, function(x) { x$ij_cov })

    boot_bayes_covs <- lapply(
      boot_results, function(x) { x$bayes_cov })

    boot_w <- as.matrix(do.call(
      rbind, lapply(boot_results, function(x) { x$w } )))

    # Note that the bootstrap samples alrady contain both Monte Carlo
    # and frequentist (bootstrapping) variability built in, since each bootstrap
    # is a new
    # Monte Carlo chain.  So we can treat each bootstrapped mean as an
    # independent random observation.
    boot_cov_se <- GetCovarianceMatrixSE(
      boot_means, boot_means, correlated_samples=FALSE)

    return(environment())
}
