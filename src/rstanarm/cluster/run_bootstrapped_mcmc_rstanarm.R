#!/usr/bin/env Rscript
#
# Example usage:
# $ rstanarm/cluster/run_bootstrapped_mcmc_rstanarm.R --base_dir=$(pwd) --model_list_ind="1" --default_num_boots=2 --save_filename="/tmp/test.Rdata" --force

library(optparse)
library(tidyverse)
library(rstan)
library(rstansensitivity)

library(bayesijlib)
library(rstanarmijlib)

option_list <- list(
    make_option(c("--base_dir"),
                default="./",
                help="The base directory"),
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
    make_option(c("--num_cores"),
                default=1,
                help="Number of cores for parallel processing"),
    make_option(c("--default_num_samples"),
                default=2000,
                help="Default number of MCMC samples"),
    make_option(c("--default_num_boots"),
                default=200,
                help="Default number of bootstrap samples"),
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
stan_examples_dir <- file.path(base_dir, "rstanarm/example-models")

model_list_file <- file(file.path(
  base_dir, "rstanarm/configs", opt$model_list_filename), "rb")
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
  default_num_samples=opt$default_num_samples,
  default_num_boots=opt$default_num_boots)


if (is.null(opt$save_filename)) {
  save_filename <- file.path(
    base_dir, "output",
    sprintf("%s_bootstrap_mcmc.Rdata", rstanarm_ij_config$desc))
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

boot_result <- RunRstanarmBootstraps(
    rstanarm_ij_config,
    stan_examples_dir,
    num_mcmc_chains=opt$num_mcmc_chains,
    num_cores=opt$num_cores)


###########################
# Save

num_boots <- length(boot_result)
with(boot_result,
     save(
       rstanarm_ij_config,
       boot_means, boot_cov, boot_cov_se, boot_time, boot_w, num_boots,
       boot_ij_covs, boot_bayes_covs,
       file=save_filename))

cat("Saved to", save_filename, "\n")
cat("Done!  （っ＾▿＾）  \n")
