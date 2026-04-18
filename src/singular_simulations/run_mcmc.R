#!/usr/bin/env Rscript
#
# Run one MCMC task for the singular simulations: either the base fit
# or a single simulation replicate.
#
# Example invocations:
# ./run_mcmc.R --base --seed=100 --re_dim=100 --obs_per_re=100
# ./run_mcmc.R -sim --sim_num=1 --seed=100
# ./run_mcmc.R --sim --sim_num=3 --seed=100 --prefix=TEST

library(rstanarm)
library(tidyverse)
library(bayesijlib)
library(rstanarmijlib)
library(rstan)
library(lme4)
library(optparse)

option_list <- list(
  make_option(c("--base_dir"),
              default=system("git rev-parse --show-toplevel", intern=TRUE),
              help="The base directory (repo root)"),
  make_option(c("--base"),
              action="store_true",
              default=FALSE,
              help="If set, run the base fit (saves full posterior and SE results)"),
  make_option(c("--sim"),
              action="store_true",
              default=FALSE,
              help="If set, run a single simulation replicate (saves reduced output)"),
  make_option(c("--sim_num"),
              default=1L,
              type="integer",
              help="Simulation replicate index (used with --sim)"),
  make_option(c("--seed"),
              default=100L,
              type="integer",
              help="Base random seed; offset by sim_num so each replicate differs"),
  make_option(c("--re_dim"),
              default=100L,
              type="integer",
              help="Number of random-effect levels"),
  make_option(c("--obs_per_re"),
              default=100L,
              type="integer",
              help="Observations per random-effect level"),
  make_option(c("--chains"),
              default=4L,
              type="integer",
              help="Number of MCMC chains"),
  make_option(c("--num_draws"),
              default=5000L,
              type="integer",
              help="Total MCMC iterations (including warmup)"),
  make_option(c("--prefix"),
              default="",
              help="Optional prefix for the description string, e.g. TEST"),
  make_option(c("--force"),
              action="store_true",
              default=FALSE,
              help="If set, overwrite an existing output file")
)

opt <- parse_args(OptionParser(option_list=option_list))
print("===================")
print("Options:")
print(opt)
print("===================")

if (opt$base == opt$sim) {
  stop("Specify exactly one of --base or --sim.")
}

options(mc.cores=opt$chains)
rstan_options(auto_write=TRUE)

output_dir <- file.path(opt$base_dir, "src/singular_simulations/output")
if (!dir.exists(output_dir)) {
  stop(sprintf("Output dir %s does not exist", output_dir))
}

##############################################################################
# This simple data generating process produces singular models some
# fraction of the time

DrawSimulatedData <- function(num_re, obs_per_re) {
  z <- sample(1:num_re, num_re * obs_per_re, replace=TRUE)
  x <- rnorm(length(z))
  y <- x ^ 2 * rnorm(length(z)) + x
  data.frame(y=y, x=x, z=z)
}

##############################################################################
# Build description string

desc <- sprintf("redim%d_obsperre%d_seed%d", opt$re_dim, opt$obs_per_re, opt$seed)
if (nchar(opt$prefix) > 0) {
  desc <- paste0(opt$prefix, "_", desc)
}

model_formula <- formula("y ~ x - 1 + (1|z)")
pars <- c("x", "sigma", "Sigma[z:(Intercept),(Intercept)]")

##############################################################################
# Helpers shared by both modes

ExtractParDraws <- function(rstanarm_result) {
  pd <- as.matrix(rstanarm_result)[, pars]
  pd <- cbind(
    pd,
    log(pd[, "sigma"]),
    log(pd[, "Sigma[z:(Intercept),(Intercept)]"]))
  colnames(pd)[(ncol(pd) - 1):ncol(pd)] <-
    c("log_sigma", "log_Sigma[z:(Intercept),(Intercept)]")
  return(pd)
}

##############################################################################
# Base mode

if (opt$base) {
  set.seed(opt$seed)

  save_filename <- file.path(output_dir, sprintf(
    "super_simple_simulation_base_results_%s.Rdata", desc))

  if (file.exists(save_filename) && !opt$force) {
    cat(sprintf("File %s exists and --force not set; terminating.\n", save_filename))
    if (!interactive()) quit(save="no")
  }

  df_base <- DrawSimulatedData(opt$re_dim, opt$obs_per_re)
  lmer_result <- lmer(model_formula, df_base)

  mcmc_time <- Sys.time()
  rstanarm_result <- rstanarm::stan_glmer(
    model_formula, df_base, family=gaussian(),
    iter=opt$num_draws, chains=opt$chains)
  mcmc_time <- Sys.time() - mcmc_time
  print(mcmc_time)

  par_draws <- ExtractParDraws(rstanarm_result)

  lp_draws <- log_lik(rstanarm_result)

  se_results_env <- ComputeIJStandardErrors(
    lp_draws=lp_draws, par_draws=par_draws, num_blocks=100, num_draws=100)

  se_results <- list(
    bayes_cov_se=se_results_env$bayes_cov_se,
    bayes_cov_se_delta_method=se_results_env$bayes_cov_se_delta_method,
    ij_cov_se=se_results_env$ij_cov_se
  )

  # Don't save the lp draws, they take up too much disk space.
  cat(sprintf("Saving to %s\n", save_filename))
  save(df_base, mcmc_time, rstanarm_result, par_draws, se_results,
       file=save_filename)
}

##############################################################################
# Sim mode

if (opt$sim) {
  # Offset seed by sim_num so replicates differ even when base seed is shared.
  set.seed(opt$seed + opt$sim_num)

  save_filename <- file.path(output_dir, sprintf(
    "super_simple_simulation_sim%d_results_%s.Rdata", opt$sim_num, desc))

  if (file.exists(save_filename) && !opt$force) {
    cat(sprintf("File %s exists and --force not set; terminating.\n", save_filename))
    if (!interactive()) quit(save="no")
  }

  df_sim <- DrawSimulatedData(opt$re_dim, opt$obs_per_re)
  lme_res <- lmer(y ~ x - 1 + (1 | z), df_sim)
  is_singular <- length(lme_res@optinfo$conv$lme4) > 0

  mcmc_time <- Sys.time()
  rstanarm_result_sim <- rstanarm::stan_glmer(
    model_formula, df_sim, family=gaussian(),
    iter=opt$num_draws, chains=opt$chains)
  mcmc_time <- Sys.time() - mcmc_time
  print(mcmc_time)

  par_draws_sim <- ExtractParDraws(rstanarm_result_sim)

  sim_df <- as.data.frame(colMeans(par_draws_sim))
  colnames(sim_df) <- "mean"
  sim_df <- sim_df %>% mutate(sim=!!opt$sim_num, par=colnames(par_draws_sim))

  lp_draws_sim <- log_lik(rstanarm_result_sim)
  ij_cov  <- ComputeIJCovariance(lp_draws_sim, par_draws_sim)
  bayes_cov <- cov(par_draws_sim, par_draws_sim)

  cat(sprintf("Saving to %s\n", save_filename))
  save(sim_df, mcmc_time, ij_cov, bayes_cov, is_singular,
       file=save_filename)
}

cat("Done!\n")
