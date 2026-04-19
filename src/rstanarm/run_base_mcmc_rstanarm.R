#!/usr/bin/env Rscript
#
# Example usage:
# $ ./run_base_mcmc_rstanarm.R --model_list_ind="1" --save_draws --save_filename="/tmp/test_1.Rdata" --force
# $ ./run_base_mcmc_rstanarm.R --model_list_ind="64" --save_draws --save_filename="/tmp/test_64.Rdata" --force
# $ ./run_base_mcmc_rstanarm.R --model_list_ind="19" --save_draws --save_filename="/tmp/test_19.Rdata" --force

library(optparse)
library(tidyverse)
library(rstan)
library(bayesijlib)
library(rstanarmijlib)

num_boot_cores <- 2
num_mcmc_cores <- 2

option_list <- list(
    make_option(c("--base_dir"),
                default=system("git rev-parse --show-toplevel", intern=TRUE),
                help="The base directory of the repository"),
    make_option(c("--model_list_filename"),
                default="rstanarm_ij_model_list.json",
                help="The name of the model list JSON file."),
    make_option(c("--model_list_ind"),
                help="The index of the model to fit.", type="integer"),
    make_option(c("--save_filename"),
                help="Optional filename and path relative to base_dir for the output"),
    make_option(c("--force"),
                action="store_true",
                default=FALSE,
                help="If set, overwrite existing results"),
    make_option(c("--save_draws"),
                action="store_true",
                default=FALSE,
                help="Save the draws including the log likelihood"),
    make_option(c("--no_save_rstan_fit"),
                action="store_true",
                default=FALSE,
                help="If set, don't save the rstan fit"),
    make_option(c("--num_cores"),
                default=1,
                help="Number of cores for parallel processing"),
    make_option(c("--default_num_samples"),
                default=2000,
                help="Default number of MCMC samples"),
    make_option(c("--num_mcmc_chains"),
                default=4,
                help="Number of MCMC chains")
)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
opt <- parse_args(OptionParser(option_list=option_list))
print("===================")
print("Options:")
print(opt)
print("===================")

base_dir <- opt$base_dir

stopifnot(!is.null(opt$model_list_ind))

model_list_ind <- opt$model_list_ind
stan_examples_dir <- file.path(base_dir, "src/rstanarm/example-models")

model_list_file <- file(file.path(
  base_dir, "src/rstanarm/configs", opt$model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

if (model_list_ind > length(model_list)) {
  stop(sprintf("model_list has only %d entries", length(model_list)))
}

rstanarm_ij_config <- model_list[[opt$model_list_ind]]
print("===================")
print("rstanarm_ij_config:")
print(rstanarm_ij_config)
print("===================")

rstanarm_ij_config <- SetConfigDefaults(
  rstanarm_ij_config,
  default_num_samples=opt$default_num_samples)


if (is.null(opt$save_filename)) {
  save_filename <- file.path(base_dir, "src/rstanarm/cluster/output",
                             sprintf("%s_base_mcmc.Rdata", rstanarm_ij_config$desc))
} else {
  save_filename <- opt$save_filename
}

if (file.exists(save_filename)) {
  if (opt$force) {
    cat("Overwriting\n", save_filename, "\n", sep="")
  } else {
    cat("File\n", save_filename, "\n", "already exists, terminating.", sep="")
    quit()
  }
}


####################
# Set up

cat("\n\n\n===========================",
    "===========================\n",
    "Model index ", model_list_ind, "\n",
    rstanarm_ij_config$desc, sep="")

mcmc_env <- RunRstanarmBaseMCMC(
  rstanarm_ij_config,
  stan_examples_dir,
  num_mcmc_chains=opt$num_mcmc_chains,
  num_cores=opt$num_cores)


###########################
# Save

mcmc_results <- list()

mcmc_save_fields <- c(
  "fit_time",
  "bayes_cov",
  "ij_cov")

for (field in mcmc_save_fields) {
  mcmc_results[[field]] <- mcmc_env[[field]]
}

mcmc_results$modelfit_summary <- summary(mcmc_env$rstan_fit)

if (opt$save_draws) {
  mcmc_results$lp_mat <- mcmc_env$lp_mat
  mcmc_results$draws_mat <- mcmc_env$draws_mat
} else {
  lp_mat <- NULL
  draws_mat <- NULL
}

if (opt$no_save_rstan_fit) {
  mcmc_results$rstan_fit <- NULL
} else {
  mcmc_results$rstan_fit <- mcmc_env$rstan_fit
}

# Save standard errors
save_se_fields <- c(
  "ij_cov_se",
  "bayes_cov_se",
  "bayes_cov_se_delta_method",
  "num_blocks",
  "num_draws",
  "num_obs")

mcmc_results$se <- list()
mcmc_results$se_block_doubled <- list()
for (field in save_se_fields) {
  mcmc_results$se[[field]] <-
    mcmc_env$se_results[[field]]
  mcmc_results$se_block_doubled[[field]] <-
    mcmc_env$se_results_block_doubled[[field]]
}

save(
  rstanarm_ij_config,
  mcmc_results,
  file=save_filename)

cat("Saved to", save_filename, "\n")
cat("Done!  （っ＾▿＾）  \n")
