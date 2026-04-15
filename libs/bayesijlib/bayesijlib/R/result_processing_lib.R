library(jsonlite)




TidyCovarianceFrame <- function(cov_mat, cov_mat_se, method) {
    param_names <- colnames(cov_mat)
    tidy_result <- bind_rows(
        CovarianceMatrixToDataframe(cov_mat, remove_repeats=TRUE) %>%
            mutate(method=!!method, metric="cov"),
        CovarianceMatrixToDataframe(cov_mat_se, remove_repeats=TRUE) %>%
            mutate(method=!!method, metric="se")
    ) %>%
        pivot_wider(names_from=c("method", "metric")) %>%
        mutate(row_variable_name=gsub("\\[.*\\]", "", row_variable),
               column_variable_name=gsub("\\[.*\\]", "", column_variable)) %>%
        mutate(params=paste(row_variable_name, column_variable_name))
    return(tidy_result)
}



####################################################
# Plotting and comparing tidy covariance dataframes.
#
# ComputeRelativeError <- function(tidy_results, method1, method2) {
#   cov1 <- tidy_results[[paste0(method1, "_cov")]]
#   cov1_se <- tidy_results[[paste0(method1, "_se")]]
#   cov2 <- tidy_results[[paste0(method2, "_cov")]]
#   cov2_se <- tidy_results[[paste0(method2, "_se")]]
#
#   # cov_bayes <- tidy_results[["bayes_cov"]]
#   # cov_bayes_reg <- abs(tidy_results[["bayes_cov"]]) + abs(tidy_results[["bayes_se"]])
#
#   cov_boot <- tidy_results[["bootstrap_cov"]]
#   cov_boot_reg <- abs(tidy_results[["bootstrap_cov"]]) + abs(tidy_results[["bootstrap_se"]])
#
#   diff_se <- sqrt(cov1_se ^ 2 + cov2_se ^ 2)
#
#   # TODO: note that the errors of IJ and Bayes are not independent.
#   tidy_results[[paste(method1, method2, "diff", sep="_")]] <- cov1 - cov2
#   tidy_results[[paste(method1, method2, "diff_se", sep="_")]] <- diff_se
#   tidy_results[[paste(method1, method2, "reldiff", sep="_")]] <- (cov1 - cov2) / diff_se
#   # tidy_results[[paste(method1, method2, "normdiff", sep="_")]] <- (cov1 - cov2) / cov_bayes_reg
#   tidy_results[[paste(method1, method2, "normdiff", sep="_")]] <- (cov1 - cov2) / cov_boot_reg
#
#   return(tidy_results)
# }

# NormalizeCovariance <- function(tidy_results, method) {
#   cov <- tidy_results[[paste0(method, "_cov")]]
#   cov_se <- tidy_results[[paste0(method, "_se")]]
#
#   cov_bayes <- tidy_results[["bayes_cov"]]
#   cov_bayes_reg <- abs(tidy_results[["bayes_cov"]]) + abs(tidy_results[["bayes_se"]])
#
#   # TODO: note that the errors of IJ and Bayes are not independent.
#   tidy_results[[paste(method, "normcov", sep="_")]] <- cov / cov_bayes_reg
#   tidy_results[[paste(method, "normse", sep="_")]] <- cov_se / cov_bayes_reg
#
#   return(tidy_results)
# }


FilterVariableName <- function(tidy_results, variable_name) {
  filter(tidy_results,
         column_variable_name != !!variable_name,
         row_variable_name != !!variable_name)
}



PlotComparisonPoints <- function(tidy_result, method1, method2,
                                 metric="cov", metric_se="se", num_ses=2) {
  cov1_col <- paste0(method1, "_", metric)
  cov2_col <- paste0(method2, "_", metric)
  se1_col <- paste0(method1, "_", metric_se)
  se2_col <- paste0(method2, "_", metric_se)

  ggplot(tidy_result) +
    geom_point(aes(x=get(cov1_col), y=get(cov2_col), color=params)) +
    geom_errorbar(aes(x=get(cov1_col),
                      ymin=get(cov2_col) - num_ses * get(se2_col),
                      ymax=get(cov2_col) + num_ses * get(se2_col),
                      color=params)) +
    geom_errorbarh(aes(y=get(cov2_col),
                       xmin=get(cov1_col) - num_ses * get(se1_col),
                       xmax=get(cov1_col) + num_ses * get(se1_col),
                       color=params)) +
    xlab(method1) + ylab(method2) +
    geom_abline(aes(slope=1, intercept=0))
}


PlotBootstrapIJ <- function(tidy_result, model_name, num_ses=2) {
  PlotComparisonPoints(tidy_result, method1="bootstrap", method2="ij") +
    ggtitle(sprintf("Bootstrap vs IJ covariances\n%s", model_name))
}


PlotBootstrapBayes <- function(tidy_result, model_name, num_ses=2) {
  PlotComparisonPoints(tidy_result, method1="bootstrap", method2="bayes") +
    ggtitle(sprintf("Bootstrap vs Bayes covariances\n%s", model_name))
}


PlotBayesIJ <- function(tidy_result, model_name, num_ses=2) {
  PlotComparisonPoints(tidy_result, method1="bayes", method2="ij") +
    ggtitle(sprintf("Bayes vs IJ covariances\n%s", model_name))
}



TidyResults <- function(ij_results) {
    draws_mat <- ij_results$draws_mat
    num_obs <- ij_results$num_obs

    draw_ij_cov <- ij_results$draw_ij_cov
    draw_ij_cov_se <- ij_results$draw_ij_cov_se

    draw_bayes_cov <- ij_results$draw_bayes_cov
    draw_bayes_cov_se <- ij_results$draw_bayes_cov_se

    draw_boot_cov <- ij_results$draw_boot_cov
    draw_boot_cov_se <- ij_results$draw_boot_cov_se


    ##################
    # Tidy data frame

    param_names <- colnames(draws_mat)

    tidy_result <- bind_cols(
      TidyCovarianceFrame(draw_ij_cov * num_obs, draw_ij_cov_se * num_obs, "ij"),
      TidyCovarianceFrame(draw_bayes_cov, draw_bayes_cov_se, "bayes"),
      TidyCovarianceFrame(draw_boot_cov, draw_boot_cov_se, "bootstrap")
    )
  return(tidy_result)
}


# A tool for making two-sample QQ plots
GetQuantileSamples <- function(x, y) {
  # x0 will be the shorter of the two
  x_shorter <- (length(x) < length(y))
  if (x_shorter) {
    x0 <- x
    x1 <- y
  } else {
    x0 <- y
    x1 <- x
  }

  x0_sorted <- sort(x0)
  n0 <- length(x0)
  n1 <- length(x1)
  quants0 <- seq(1 / n0, 1 - 1 / n0, length.out=n0)
  quants1 <- seq(1 / n1, 1 - 1 / n1, length.out=n1)
  x1_sorted <- approx(x=quants1, y=sort(x1), xout=quants0)$y
  if (x_shorter) {
    return(data.frame(q=quants0, x=x0_sorted, y=x1_sorted))
  } else {
    return(data.frame(q=quants0, x=x1_sorted, y=x0_sorted))
  }
}
