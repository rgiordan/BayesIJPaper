
LoadModelResults <- function(model_config, file_suffix,
                             load_lme4=TRUE, load_boot=TRUE,
                             base_file_suffix=NULL,
                             boot_file_suffix=NULL,
                             lme4_file_suffix=NULL) {
    base_file_suffix <- paste0(
      "base_mcmc_",
      ifelse(is.null(base_file_suffix), file_suffix, base_file_suffix))
    lme4_file_suffix <- paste0(
      "lme4_",
      ifelse(is.null(lme4_file_suffix), file_suffix, lme4_file_suffix))
    boot_file_suffix <- paste0(
      "boot_mcmc_",
      ifelse(is.null(boot_file_suffix), file_suffix, boot_file_suffix))

    file_desc <- model_config$desc

    base_model_filename <- file.path(
        output_dir, sprintf("%s_%s.Rdata", file_desc, base_file_suffix))
    lme4_model_filename <- file.path(
        output_dir, sprintf("%s_%s.Rdata", file_desc, lme4_file_suffix))
    boot_model_filename <- file.path(
        output_dir, sprintf("%s_%s.Rdata", file_desc, boot_file_suffix))

    all_found <- TRUE
    SafeLoad <- function(filename) {
        if (file.exists(filename)) {
            return(LoadIntoEnv(filename))
        } else {
            print(sprintf("File %s missing", filename))
            all_found <<- FALSE
            return(NULL)
        }
    }

    result <-
      list(base_results=SafeLoad(base_model_filename))
    if (load_boot) {
      result$boot_results <- SafeLoad(boot_model_filename)
    }
    if (load_lme4) {
      result$lme4_results <- SafeLoad(lme4_model_filename)
    }
    result$all_found <- all_found
    return(result)
}



GetLME4Comparison <- function(model_config, base_results, boot_results, lme4_results) {
    PivotForCombination <- function(df, method) {
        df %>%
            select(par, mean, sd) %>%
            pivot_longer(-par, names_to="metric") %>%
            mutate(method=!!method)
    }

    TidySdsOnly <- function(cov_mat, keep_pars) {
        cov_df <-
            CovarianceMatrixToDataframe(cov_mat, remove_repeats=TRUE) %>%
            filter(row_variable == column_variable) %>%
            select(-column_variable) %>%
            rename(par=row_variable) %>%
            mutate(mean=NA, sd=sqrt(value)) %>%
            select(-value) %>%
            filter(par %in% keep_pars)
        return(cov_df)
    }

    lme4_fit <- lme4_results$lme4_fit
    lme4_df <- TidyLME4Results(lme4_fit)
    lme4_boot_agg <- TidyLME4Bootstrap(lme4_results$boot_results)

    keep_pars <- colnames(base_results$mcmc_results$draws_mat)
    keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]

    stan_point_estimates <-
        tibble(par=keep_pars,
               mean=colMeans(base_results$mcmc_results$draws_mat[, keep_pars]),
               sd=apply(base_results$mcmc_results$draws_mat[, keep_pars], FUN=sd, MARGIN=2))

    num_exch_obs <- model_config$num_exchangeable_obs

    ij_sd_df <- TidySdsOnly(base_results$mcmc_results$ij_cov / num_exch_obs, keep_pars)
    mcmc_boot_sd_df <- TidySdsOnly(boot_results$boot_cov, keep_pars)

    # Delta method:
    # var(sqrt(x)) = (1 / (2 sqrt(x))) * var(x) * (1 / (2 sqrt(x)))
    #              = var(x) / (4 abs(x))
    GetSdSe <- function(cov_se, point) {
        var_var <- diag(cov_se) ^ 2
        sd_se <- sqrt(var_var / (4 * abs(point)))
        return(sd_se)
    }

    # Ok now I regret some naming decisions
    ij_cov_se <- base_results$mcmc_results$se$ij_cov_se[keep_pars, keep_pars]
    point <- colMeans(base_results$mcmc_results$draws_mat[, keep_pars])
    ij_sd_se <- GetSdSe(ij_cov_se / num_exch_obs, point)
    ij_sd_se_df <- data.frame(par=names(ij_sd_se), mean=ij_sd_se, sd=NA)

    mcmc_boot_cov_se <- boot_results$boot_cov_se
    rownames(mcmc_boot_cov_se) <- colnames(boot_results$boot_means)
    colnames(mcmc_boot_cov_se) <- colnames(boot_results$boot_means)
    mcmc_boot_cov_se <- mcmc_boot_cov_se[keep_pars, keep_pars]
    point <- colMeans(boot_results$boot_means[, keep_pars])
    mcmc_boot_sd_se <- GetSdSe(mcmc_boot_cov_se, point)
    mcmc_boot_sd_se_df <- data.frame(par=names(mcmc_boot_sd_se), mean=mcmc_boot_sd_se, sd=NA)

    point_comb_df <-
        bind_rows(
            PivotForCombination(lme4_df, "lme4"),
            PivotForCombination(lme4_boot_agg, "lme4_boot"),
            PivotForCombination(stan_point_estimates, "mcmc"),
            PivotForCombination(ij_sd_df, "ij"),
            PivotForCombination(mcmc_boot_sd_df, "mcmc_boot"),
            PivotForCombination(ij_sd_se_df, "ij_se"),
            PivotForCombination(mcmc_boot_sd_se_df, "mcmc_boot_se")
        ) %>%
        pivot_wider(id_cols=c(par, metric), values_from=value, names_from=method) %>%
        filter(!is.na(mcmc)) # MCMC only keeps one of the two symmetric covariances.

    return(point_comb_df)
}
