#!/usr/bin/env Rscript
#
# Example usage:
# $ rstanarm/cluster/run_lme4.R --base_dir=$(pwd) --model_list_ind="1" --save_filename="/tmp/test_1.Rdata" --force

library(optparse)
library(tidyverse)
library(doParallel)
library(rstanarmijlib)
library(bayesijlib)

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
    make_option(c("--force"),
                action="store_true",
                default=FALSE,
                help="If set, overwrite existing results"),
    make_option(c("--num_cores"),
                default=1,
                help="Number of cores for parallel processing"),
    make_option(c("--default_num_boots"),
                default=200,
                help="Default number of bootstrap samples"),
    make_option(c("--num_mcmc_chains"),
                default=4,
                help="Number of MCMC chains")
)

# The last two option doesn't do anything, but makes it easier to
# call with the same arguments as the other scripts.  Forgive me.

# get command line options, if help option encountered print help and exit,
# otherwise if options not found on command line then set defaults,
opt <- parse_args(OptionParser(option_list=option_list))
print("===================")
print("Options:")
print(opt)
print("===================")

base_dir <- opt$base_dir
# setwd(base_dir)
# source(file.path(base_dir, "rstanarm_lib.R"))

registerDoParallel(cores=opt$num_cores)

stopifnot(!is.null(opt$model_list_ind))

model_list_ind <- opt$model_list_ind
stan_examples_dir <- file.path(base_dir, "example-models")

#model_list_file <- file(file.path(base_dir, opt$model_list_filename), "rb")
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


if (is.null(opt$save_filename)) {
  save_filename <- file.path(base_dir, "output",
                             sprintf("%s_lme4.Rdata", rstanarm_ij_config$desc))
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
# Run base model

cat("\n\n\n===========================",
    "===========================\n",
    "Model index ", model_list_ind, "\n",
    rstanarm_ij_config$desc, "\n", sep="")

df <- LoadRstanarmDataframe(rstanarm_ij_config, stan_examples_dir)


cat("Fitting.\n")
lme4_time <- Sys.time()
lme4_fit <- RunLME4(rstanarm_ij_config, df)
lme4_time <- Sys.time() - lme4_time

####################
# Run bootstraps

ecol <- GetExchangeableColumn(rstanarm_ij_config$exchangeable_col, df)
ecol_vals <- unique(ecol)
ecol_n <- length(ecol_vals)

cat("Bootstrapping.\n")
boot_results <- foreach(b=1:opt$default_num_boots) %dopar% {
    w <- rmultinom(1, ecol_n, rep(1/ecol_n, ecol_n))[, 1]
    df_boot <- BootstrapByExchangableColumn(df, ecol, w)
    lme4_time <- Sys.time()
    lme4_fit <- RunLME4(rstanarm_ij_config, df_boot)
    lme4_time <- Sys.time() - lme4_time

    list(lme4_fit=lme4_fit,
         w=w, b=b,
         lme4_time=lme4_time)
}


save(
  rstanarm_ij_config,
  lme4_fit,
  boot_results,
  num_exch_obs=ecol_n,
  file=save_filename)

cat("Saved to", save_filename, "\n")
cat("Done!  （っ＾▿＾）  \n")
