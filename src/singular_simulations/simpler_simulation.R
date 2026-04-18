#!/usr/bin/env Rscript
# Example invocations:
# ./simpler_simulation

library(ggplot2)
library(rstanarm)
library(tidyverse)
library(bayesijlib)
library(rstanarmijlib)
library(lme4)
library(gridExtra)
library(broom)
library(doParallel)
library(sandwich)

options(mc.cores=4)
rstan_options(auto_write=TRUE)
base_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
output_dir <- file.path(base_dir, "src/singular_simulations/output")

##############################################################################
# This simple data generating process produces singular models some 
# fraction of the time

DrawSimulatedData <- function(num_re, obs_per_re) {
  z <- sample(1:num_re, num_re * obs_per_re, replace=TRUE)
  x <- rnorm(length(z))
  y <- x ^ 2 * rnorm(length(z)) + x
  
  df <- data.frame(y=y, x=x, z=z)
  
  return(df)
}

##################
# Set parameters

seed_val <- 100
set.seed(seed_val)

re_dim <- 100
obs_per_re <- 100

desc <- sprintf("redim%d_obsperre%d_seed%d", re_dim, obs_per_re, seed_val)

model_formula <- formula("y ~ x - 1 + (1|z)")

df_base <- DrawSimulatedData(re_dim, obs_per_re)
lmer_result <- lmer(model_formula, df_base)


pars <- c("x", "sigma", "Sigma[z:(Intercept),(Intercept)]")

# Set which analysis you want to rerun.  Note that the
# simulations take a long time.

rerun_sims <- TRUE
rerun_fit <- TRUE

#############################################################
# Compute the base fit that we will use to compute the IJ

base_filename <- file.path(output_dir, sprintf(
  "super_simple_simulation_base_results_%s.Rdata", desc))
if (rerun_fit) {
  mcmc_time <- Sys.time()
  rstanarm_result <- rstanarm::stan_glmer(
    model_formula, df_base, family=gaussian(), iter=5000)
  mcmc_time <- Sys.time() - mcmc_time
  print(mcmc_time)
  rstanarm_result

  par_draws <- as.matrix(rstanarm_result)
  par_draws <- par_draws[, pars]
  par_draws <- cbind(
    par_draws,
    log(par_draws[, "sigma"]),
    log(par_draws[, "Sigma[z:(Intercept),(Intercept)]"]))
  colnames(par_draws)[(ncol(par_draws) - 1):ncol(par_draws)] <-
    c("log_sigma", "log_Sigma[z:(Intercept),(Intercept)]")
  
  head(par_draws)
  
  lp_draws <- log_lik(rstanarm_result)
  num_exch_obs <- ncol(lp_draws)
  
  se_results_env <- ComputeIJStandardErrors(
    lp_draws=lp_draws, par_draws=par_draws, num_blocks=100, num_draws=100)
  
  se_results <- list(
    bayes_cov_se=se_results_env$bayes_cov_se,
    bayes_cov_se_delta_method=se_results_env$bayes_cov_se_delta_method,
    bayes_ij_diff_se=se_results_env$bayes_ij_diff_se,
    bayes_se_list=se_results_env$bayes_se_list,
    ij_cov_se=se_results_env$ij_cov_se,
    ij_se_list=se_results_env$ij_se_list
  )
  
  # Don't save the lp draws, they take up too much disk space.
  save(df_base, mcmc_time, rstanarm_result, par_draws, se_results,
       file=base_filename)
  
} else {
  load(base_filename)
}

lp_draws <- log_lik(rstanarm_result)
#pars <- colnames(par_draws)[!grepl("^b\\[", colnames(par_draws))]

ij_cov <- ComputeIJCovariance(lp_draws, par_draws)
bayes_cov <- cov(par_draws, par_draws)

ij_freq_se <- ComputeIJFrequentistSe(lp_draws, par_draws)
ij_se <- se_results$ij_cov_se
ij_full_se <- sqrt(ij_freq_se^2 + ij_se^2)

bayes_freq_se <- ComputeIJFrequentistSe(par_draws, par_draws)
bayes_se <- se_results$bayes_cov_se
bayes_full_se <- sqrt(bayes_freq_se^2 + bayes_se^2)

cbind(num_exch_obs * diag(bayes_cov),
      diag(ij_cov))





########################################################
# Run simulations to get the true frequentist variance

sim_filename <- file.path(
  output_dir, sprintf("super_simple_simulation_sim_results_%s.Rdata", desc))
pars <- c("x", "sigma", "Sigma[z:(Intercept),(Intercept)]")
if (rerun_sims) {
  num_sims <- 100
  sim_means <- data.frame()
  ij_cov_list <- list()
  bayes_cov_list <- list()
  is_singular_list <- list()
  sim_time <- Sys.time()
  for (sim in 1:num_sims) {
    cat("------------------------------------\n", sim, "\n")
    df_sim <- DrawSimulatedData(re_dim, obs_per_re)
    lme_res <- lmer(y ~ x - 1 + (1 | z), df_sim)
    is_singular <- length(lme_res@optinfo$conv$lme4) > 0
    is_singular_list[[sim]] <- is_singular
    
    rstanarm_result_sim <- rstanarm::stan_glmer(model_formula, df_sim, family=gaussian(), iter=5000)
    par_draws_sim <- as.matrix(rstanarm_result_sim)
    par_draws_sim <- par_draws_sim[, pars]
    par_draws_sim <- cbind(
      par_draws_sim,
      log(par_draws_sim[, "sigma"]),
      log(par_draws_sim[, "Sigma[z:(Intercept),(Intercept)]"]))
    colnames(par_draws_sim)[(ncol(par_draws_sim) - 1):ncol(par_draws_sim)] <-
      c("log_sigma", "log_Sigma[z:(Intercept),(Intercept)]")
    sim_df <- as.data.frame(colMeans(par_draws_sim))
    colnames(sim_df) <- "mean"
    sim_df <-
      sim_df %>%
      mutate(sim=!!sim, par=colnames(par_draws_sim))
    
    sim_means <- bind_rows(sim_means, sim_df)
    
    # Compute the covariance to check for bias.
    lp_draws_sim <- log_lik(rstanarm_result_sim)
    num_exch_obs <- ncol(lp_draws_sim)
    
    ij_cov_sim <- ComputeIJCovariance(lp_draws_sim, par_draws_sim)
    
    ij_cov_list[[sim]] <- ij_cov_sim
    bayes_cov_list[[sim]] <- cov(par_draws_sim, par_draws_sim)
  }
  sim_time <- Sys.time() - sim_time

  save(sim_means, sim_time, ij_cov_list, bayes_cov_list, is_singular_list,
       file=sim_filename)
} else {
  load(sim_filename)
}





