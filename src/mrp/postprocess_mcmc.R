#!/usr/bin/env Rscript
# ./postprocess_mcmc.R --base_dir=$(pwd) --mcmc_file=bootstrap_data/mrp_original_seed134432_samples5000.Rdata
#
# This script takes the output of a single MCMC run produced by run_mcmc.R
# and evaluates MrP, the influence function and related quantities.
# The output filename is the same as the original but with the suffix
# `_mrp_postprocessed.Rdata`.

library(tidyverse)
library(brms)
library(mrpaw)
library(optparse)

source("mrp_lib.R")


option_list <- list(
  make_option(c("--base_dir"),
              default="/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/mrp",
              help="The base directory"),
  make_option(c("--mcmc_file"),
              default="",
              help="Which MCMC file to process (produced by run_bootstrap.R)")
              )
  
opt <- parse_args(OptionParser(option_list=option_list))
print("===================")
print("Options:")
print(opt)
print("===================")

if (opt$mcmc_file == "") {
  if (interactive()) {
    opt$mcmc_file <- "bootstrap_data/mrp_original_seed134432_samples5000.Rdata"
  } else {
    stop("You must specify --mcmc_file")
  }
}

load_into_env <- function(filename) {
  load_env <- environment()
  load(filename, envir=load_env)
  return(load_env)
}


print(sprintf("Processing %s", opt$mcmc_file))
save_filename <- paste0(sub("\\.[A-Za-z]+$", "", opt$mcmc_file), "_mrp_postprocessed.Rdata")
print(sprintf("Saving to %s", save_filename))

orig_env <- load_into_env(file.path(opt$base_dir, "datasets/cces18_subset.Rdata"))
load_env <- load_into_env(opt$mcmc_file)

weight_time <- Sys.time()
mrp_list <- mrpaw::GetLogitMCMCWeights(
  load_env$logit_post, 
  survey_df=load_env$survey_boot_df, 
  pop_df=orig_env$pop_agg_df, 
  pop_w=orig_env$pop_agg_df$w,
  save_preds=TRUE)
weight_time <- Sys.time() - weight_time

mrp <- mean(mrp_list$mrp_draws)
mrp_var <- var(mrp_list$mrp_draws)

infl <- mrpaw::EvalInfluenceFunction(mrp_list, load_env$logit_post, load_env$survey_boot_df)

# For fairness, time the IJ computation on its own rather than through MrPaw
post <- load_env$logit_post

ij_time <- Sys.time()
stopifnot(class(post) == "brmsfit")
linpred_time <- Sys.time()
eta_draws <- posterior_linpred(post, newdata=load_env$survey_boot_df)
linpred_time <- Sys.time() - linpred_time
y <- post$data$abortion
lp_mat <- (y * t(eta_draws) - log(1 + exp(t(eta_draws)))) %>% t()
lp_draws <- apply(lp_mat, FUN = sum, MARGIN = 1)
infl_vec <- cov(mrp_list$mrp_draws, lp_mat) %>% as.numeric()
n_obs <- length(y)
ij_var <- n_obs * var(infl_vec)
ij_time <- Sys.time() - ij_time

stopifnot(ij_var == infl$ij_var)

stan_time <- ifelse(is.null(load_env$stan_time), NA, load_env$stan_time)

# Compute standard errors of the IJ covariance
lp_draws <- infl$lp_mat
par_draws <- as.matrix(mrp_list$mrp_draws, ncol=1)
num_blocks <- 100
infl_block_boostrap_list <- GetBlockBootstrapCovarianceDraws(
  lp_draws, par_draws, num_blocks=num_blocks, num_draws=500, show_progress_bar=TRUE
)

# infl_block_boostrap_list$cov_samples contains block bootstrap draws of the
# influence function.  From these we need to compute draws of the ij variance.
n_data_obs <- ncol(lp_draws)
ij_var_draws <- apply(
  infl_block_boostrap_list$cov_samples[,,1], 
  FUN=\(infl_vec) n_data_obs * var(infl_vec), MARGIN=1)

if (FALSE) {
  # Some sanity checks, looks okay
  plot(infl_block_boostrap_list$cov_samples[1,,], infl$infl_vec); abline(0,1) # ok
  mean(ij_var_draws)
  length(ij_var_draws)
}

ij_var_mcmc_se <- sd(ij_var_draws)

result_df <- data.frame(
  filename=opt$mcmc_file,
  mrp=mrp,
  mrp_var=mrp_var,
  ij_var=ij_var,
  ij_var_mcmc_se=ij_var_mcmc_se,
  mcmc_time=stan_time)

infl_vec <- infl$infl_vec
save(result_df, infl_vec, num_blocks, ij_time, weight_time, linpred_time, file=save_filename)
