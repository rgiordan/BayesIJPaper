#!/usr/bin/env Rscript
# ./run_simpler_simulation.R --seed=1 --output_description=TEST --num_draws=10 --force

library(rstanarm)
library(rstan)
library(tidyverse)
library(lme4)
library(bayesijlib)

suppressPackageStartupMessages(library("argparse"))

parser <- ArgumentParser()

parser$add_argument(
    "-f", "--force", action="store_true", default=FALSE,
    help="Overwrite existing files [default]")
parser$add_argument(
    "--no_save_loglik", action="store_true", default=FALSE,
    help="Don't save full MCMC draws of the log likelihood [default]")
parser$add_argument(
    "--git_root",
    help=paste0("Path to git repo root.  If unset, is detected ",
                "from the current directory."))
parser$add_argument(
    "--num_draws", type="integer", default=2000,
    help="Number of MCMC draws per chain [default %(default)]",
    metavar="number")
parser$add_argument(
    "--output_description", default="resim",
    help="Default output filename base.  [default %(default)].")
parser$add_argument(
    "--seed", type="integer",
    help = "Random seed (use system seed if unset)")
parser$add_argument(
    "--cores", default=1,
    help=paste0("Number of course for MCMC [default %(default)] "))
parser$add_argument(
    "--chains", default=4,
    help=paste0("Number of chains for MCMC [default %(default)] "))


# Check that the analysis is valid
args <- parser$parse_args()
print(args)

options(mc.cores=args$cores)
rstan_options(auto_write=TRUE)


if (is.null(args$git_root)) {
    git_root <- system2("git", args=c("rev-parse", "--show-toplevel"), stdout=TRUE)
} else {
    git_root <- args$git_root
}

if (!dir.exists(git_root)) {
    stop(sprintf("Git directory %s does not exist", git_root))
}

cat("Git root:", git_root, "\n")

output_dir <- file.path(git_root, "src/singular_simulations/output")

if (!dir.exists(output_dir)) {
  stop(sprintf("Output dir does not exist: %s", output_dir))
}

ShouldRerun <- function(filename, force=parser$force) {
  if (force) {
    return(TRUE)
  } else {
    return(!file.exists(filename))
  }
}

#####################################################
# Simulate data and run misspecified inference

DrawSimulatedData <- function(num_re, obs_per_re) {
  z <- sample(1:num_re, num_re * obs_per_re, replace=TRUE)
  x <- rnorm(length(z))
  y <- x ^ 2 * rnorm(length(z)) + x

  df <- data.frame(y=y, x=x, z=z)

  return(df)
}

re_dim <- 100
obs_per_re <- 100
model_formula <- formula("y ~ x - 1 + (1|z)")

##################

if (!is.null(args$seed)) {
  print(sprintf("Using specified seed: %d.", args$seed))
  seed <- as.character(args$seed)
  set.seed(seed)
} else {
  print("Using system seed.")
  seed <- "UNSET"
}

desc <- sprintf("redim%d_obsperre%d_seed%s_%s",
                re_dim, obs_per_re, seed, args$output_description)


# Simulate and run

df_base <- DrawSimulatedData(re_dim, obs_per_re)

lmer_result <- lmer(model_formula, df_base)
is_singular <- length(lmer_result@optinfo$conv$lme4) > 0

# Transform these parameters with log
pars <- c("x", "sigma", "Sigma[z:(Intercept),(Intercept)]")

output_filename <-
  file.path(output_dir,
            sprintf("simplesim_mcmc_draws_%s.Rdata", desc))
print("Output filename:")
print(output_filename)

if (ShouldRerun(output_filename, force=args$force)) {
  mcmc_time <- Sys.time()
  rstanarm_result <-
    rstanarm::stan_glmer(model_formula,
                         df_base,
                         family=gaussian(),
                         chains=args$chains,
                         iter=args$num_draws)
  mcmc_time <- Sys.time() - mcmc_time
  print(mcmc_time)

  print("processing")
  par_draws <- as.matrix(rstanarm_result)
  par_draws <- par_draws[, pars]
  par_draws <-
    cbind(par_draws,
          log(par_draws[, "sigma"]),
          log(par_draws[, "Sigma[z:(Intercept),(Intercept)]"]))
  colnames(par_draws)[(ncol(par_draws) - 1):ncol(par_draws)] <-
    c("log_sigma", "log_Sigma[z:(Intercept),(Intercept)]")

  lp_draws <- log_lik(rstanarm_result)
  bayes_cov <- cov(par_draws, par_draws)
  ij_cov <- ComputeIJCovariance(lp_draws, par_draws)

  if ((args$no_save_loglik)) {
    lp_draws <- c()
  }

  print("saving")
  save(df_base, mcmc_time, rstanarm_result, par_draws,
       lmer_result, is_singular,
       ij_cov, bayes_cov, lp_draws,
       file=output_filename)

} else {
  print("Output exists, skipping the rerun.")
}

  print("Done!  ₊✩‧₊˚౨ৎ˚₊✩‧₊")
