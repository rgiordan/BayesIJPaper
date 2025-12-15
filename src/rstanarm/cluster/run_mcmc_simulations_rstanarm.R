#!/usr/bin/env Rscript
#
# Example usage:
# $ ./run_mcmc_simulations_rstanarm.R --base_dir=$(pwd) --model_list_ind="1" --save_filename="/tmp/test_sims.Rdata" --initial_fit_filename="/tmp/test_1.Rdata" --num_sims=5 --force

library(optparse)
library(tidyverse)
library(rstan)
library(rstansensitivity)

option_list <- list(
    make_option(c("--base_dir"),
                default="/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes",
                help="The base directory"),
    make_option(c("--model_list_filename"),
                default="rstanarm_ij_model_list.json",
                help="The name of the model list JSON file."),
    make_option(c("--model_list_ind"),
                help="The index of the model to fit.", type="integer"),
    make_option(c("--save_filename"),
                help="Optional filename and path relative to base_dir for the output"),
    make_option(c("--initial_fit_filename"),
                help="The full path to the initial fit or ground truth data file."),
    make_option(c("--simulate_from_ground_truth"),
                action="store_true",
                default=FALSE,
                help="If unset --initial_fit_filename is a fit.  Otherwise it is a ground truth file."),
    make_option(c("--force"),
                action="store_true",
                default=FALSE,
                help="If set, overwrite existing results"),
    make_option(c("--seed"),
                default=42,
                help="The random seed"),
    make_option(c("--num_cores"),
                default=1,
                help="Number of cores for parallel processing"),
    make_option(c("--default_num_samples"),
                default=2000,
                help="Default number of MCMC samples"),
    make_option(c("--num_sims"),
                default=200,
                help="Number of simulated datasets"),
    make_option(c("--num_mcmc_chains"),
                default=4,
                help="Number of MCMC chains")
)

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults.
if (exists("args_str")) {
  opt <- parse_args(OptionParser(option_list=option_list), args=args_str)
} else {
  opt <- parse_args(OptionParser(option_list=option_list))
}
print("===================")
print("Options:")
print(opt)
print("===================")

base_dir <- opt$base_dir
setwd(base_dir)
source(file.path(base_dir, "rstanarm_lib.R"))

stopifnot(!is.null(opt$model_list_ind))

model_list_ind <- opt$model_list_ind
stan_examples_dir <- file.path(base_dir, "example-models")

model_list_file <- file(file.path(base_dir, opt$model_list_filename), "rb")
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
  save_filename <- file.path(base_dir, "output",
                             sprintf("%s_simulated_mcmc.Rdata", rstanarm_ij_config$desc))
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


# Load the initial fit
if (file.exists(opt$initial_fit_filename)) {
  initial_fit <- LoadIntoEnv(opt$initial_fit_filename)
} else {
  cat("File\n", opt$initial_fit_filename, "\n", "does not exist, terminating.", sep="")
  stop("Missing initial fit file.")
}

if (opt$simulate_from_ground_truth) {
  ground_truth <- initial_fit
  required_columns <- c("beta", "vcov_list")
  missing_columns <- setdiff(required_columns, names(ground_truth))
  if (length(missing_columns) > 0) {
    cat("Ground truth file does not contain the required columns.  Missing ", missing_columns, "\n")
    stop("Missing columns from ground truth.")
  }
} else {
  if (!("rstan_fit" %in% names(initial_fit))) {
    stop("Initial fit does not have rstan_fit (maybe it was created with an old version of the code).")
  }
  if (is.null(initial_fit$rstan_fit)) {
    stop("rstan_fit is NULL (maybe the script was run with --no_save_rstan_fit)")
  }
  ground_truth <- initial_fit$rstan_fit
}


###############################
# Load the data

df <- LoadRstanarmDataframe(rstanarm_ij_config, stan_examples_dir)


################################
# Run simulations

sim_result <- RunRstanarmSimulations(
  ground_truth,
  df,
  rstanarm_ij_config,
  stan_examples_dir,
  num_sims=opt$num_sims,
  num_cores=opt$num_cores,
  simulate_from_fit=!opt$simulate_from_ground_truth)

###########################
# Save

initial_fit_filename <- opt$initial_fit_filename
num_sims <- length(sim_result)
with(sim_result,
     save(
       rstanarm_ij_config, initial_fit_filename,
       sim_means, sim_cov, sim_cov_se,
       num_sims, file=save_filename))

cat("Saved to", save_filename, "\n")
cat("Done!  （っ＾▿＾）  \n")
