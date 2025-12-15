#####################################################################################
# Save simulations based on the ARM models to which we can apply the IJ and bootstrap

library(ggplot2)
library(rstanarm)
library(tidyverse)


base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")
source(file.path(base_dir, "rstanarm_lib.R"))

########################
# Load the model list

model_list_file <- file(file.path(base_dir, "rstanarm_ij_model_list.json"), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)


#####################################################
# Loop through the models, generating saved data.

file_suffix <- "0523_cluster"

for (i in 1:length(model_list)) {
    set.seed(11220)
    model_config <- model_list[[i]]
    cat("========================================================================\n",
        model_config$desc, " ", i, "\n")
    df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
    orig_model_filename <- 
        file.path(base_dir, "output",
                  sprintf("%s_base_mcmc_%s.Rdata", model_config$desc, file_suffix))
    if (file.exists(orig_model_filename)) {
        orig_results <- LoadIntoEnv(orig_model_filename)
        if (is.null(orig_results$rstan_fit)) {
            cat("Missing rstan_fit.  Maybe an old version?\n")
        } else {
            df_sim <- SimulateDatasetFromFit(orig_results$rstan_fit, df, model_config)
            sim_filename <- with(model_config,
                                 file.path(stan_examples_dir, subdir,
                                           paste0(model_name, "_SIMULATED_IJ.data.R")))
            cat("Saving simulated data to", sim_filename, "\n")
            SaveDataFrameToFile(df_sim, model_config, sim_filename)
        }
    } else {
        cat("File not found: ", orig_model_filename, "\n")
    }
}


