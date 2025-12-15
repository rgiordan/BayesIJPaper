# Load and process results produced by model_script.R.

library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)

rstan_options(auto_write=TRUE)

# If TRUE do not run all the bootstraps and do not save.
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"

source(file.path(base_dir, "cov_se_lib.R"))
source(file.path(base_dir, "result_processing_lib.R"))

# TODO: update this use of ModelList
model_list <- GetModelList()

file_suffix <- "base_mcmc_0504_cluster"
loaded_models <- list()
for (chapter in unique(model_list$chapter)) {
    loaded_models[[chapter]] <- list()
}

i <- 1

total_ij_time <- 0
for (i in 1:nrow(model_list)) {
    chapter <- model_list[i, ]$chapter
    model_name <- model_list[i, ]$model_name
    cat("\n\n\n===========================\n===========================\n",
        chapter, model_name, "\n")
    stan_examples_dir <- file.path(base_dir, "example-models/ARM")
    model_loc <- file.path(stan_examples_dir, chapter)
    load_filename <- sprintf("%s_%s.Rdata", model_name, file_suffix)
    if (file.exists(file.path(model_loc, load_filename))) {
        ij_results <- LoadIJResults(chapter, model_name, file_suffix)
        loaded_models[[chapter]] <- c(loaded_models[[chapter]], model_name)
        cat("Number of observations:", ij_results$num_obs, "\n")
        total_ij_time <- total_ij_time + ij_results$ij_fit_time
        cat("IJ time:", as.numeric(total_ij_time, units="mins"), "minutes\n")
        print(ij_results$modelfit_ij_summary$summary[,c("mean", "n_eff", "Rhat")])
    } else {
        cat("\n\n", load_filename, "not found.\n")
    }
}

# Recall that this is wall time, and includes parallelization.
cat("Total IJ time:", as.numeric(total_ij_time, units="hours"), "hours\n")

for (chapter in names(loaded_models)) { for (model_name in loaded_models[[chapter]]) {
    cat("\n\n\n===========================\n===========================\n", chapter, model_name, "\n")

    ij_results <- LoadIJResults(chapter, model_name, file_suffix)
    tidy_results <- TidyResults(ij_results)
    num_obs <- ij_results$num_obs
    num_boot <- length(ij_results$boot_results)

    plot_title <- sprintf("IJ vs bootstrap covariances\n%s\nnum_obs = %d, num_boot = %d",
                          model_name, num_obs, num_boot)
    PlotBootstrapIJ(tidy_results, model_name) +
        ggtitle(plot_title) +
        theme(legend.position="none")
    plot_filename <- sprintf("/tmp/ij_vs_boot_var_%s_%s.png", chapter, model_name, "\n")
    cat("Saving to", plot_filename, "\n")
    ggsave(file=plot_filename)

    plot_title <- sprintf("Bayes vs bootstrap covariances\n%s\nnum_obs = %d, num_boot = %d",
                          model_name, num_obs, num_boot)
    PlotBootstrapBayes(tidy_results, model_name) +
        ggtitle(plot_title) +
        theme(legend.position="none")
    plot_filename <- sprintf("/tmp/bayes_vs_boot_var_%s_%s.png", chapter, model_name, "\n")
    cat("Saving to", plot_filename, "\n")
    ggsave(file=plot_filename)

}}


#################################
############## One-off


# TODO: check ESS for some of the new models
chapter <- "Ch.17"
model_name <- "multilevel_logistic_17.4"

ij_results <- LoadIJResults(chapter, model_name, file_suffix)

ij_results$modelfit_summary$summary

