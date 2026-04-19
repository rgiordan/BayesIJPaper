#!/usr/bin/env Rscript
#
# Load all per-simulation files produced by run_mcmc.R --sim and combine
# them into the single file that postprocess_for_paper.R expects.
#
# Example invocations:
# ./combine_simulations.R --seed=100 --obs_per_re=100 --re_dim=100
# ./combine_simulations.R --seed=100 --prefix=TEST

library(tidyverse)
library(optparse)

option_list <- list(
  make_option(c("--base_dir"),
              default=system("git rev-parse --show-toplevel", intern=TRUE),
              help="The base directory (repo root)"),
  make_option(c("--seed"),
              default=100L,
              type="integer",
              help="Base random seed used when running the simulations"),
  make_option(c("--re_dim"),
              default=100L,
              type="integer",
              help="Number of random-effect levels"),
  make_option(c("--obs_per_re"),
              default=100L,
              type="integer",
              help="Observations per random-effect level"),
  make_option(c("--prefix"),
              default="",
              help="Optional prefix used when running the simulations, e.g. TEST"),
  make_option(c("--force"),
              action="store_true",
              default=FALSE,
              help="If set, overwrite an existing combined output file")
)

opt <- parse_args(OptionParser(option_list=option_list))
print("===================")
print("Options:")
print(opt)
print("===================")

results_dir <- file.path(opt$base_dir, "src/singular_simulations/output")

desc <- sprintf("redim%d_obsperre%d_seed%d", opt$re_dim, opt$obs_per_re, opt$seed)
if (nchar(opt$prefix) > 0) {
  desc <- paste0(opt$prefix, "_", desc)
}

sim_filename <- file.path(
  results_dir,
  sprintf("super_simple_simulation_sim_results_%s.Rdata", desc))

if (file.exists(sim_filename) && !opt$force) {
  cat(sprintf("File %s exists and --force not set; terminating.\n", sim_filename))
  if (!interactive()) quit(save="no")
}

sim_files <- list.files(
  path=results_dir, 
  pattern = sprintf("super_simple_simulation_sim[0-9]+_results_%s.Rdata", desc), 
  full.names = TRUE)

if (length(sim_files) == 0) {
  stop(sprintf("No simulation files found in %s for desc=%s", results_dir, desc))
}
cat(sprintf("Found %d simulation files.\n", length(sim_files)))

sim_means        <- data.frame()
ij_cov_list      <- list()
bayes_cov_list   <- list()
is_singular_list <- list()

for (f in sim_files) {
  cat(sprintf("Loading %s\n", f))
  e <- new.env()
  load(f, envir=e)
  sim_means        <- bind_rows(sim_means, e$sim_df)
  sim_num          <- e$sim_df$sim[[1]]
  ij_cov_list[[sim_num]]      <- e$ij_cov
  bayes_cov_list[[sim_num]]   <- e$bayes_cov
  is_singular_list[[sim_num]] <- e$is_singular
}

cat(sprintf("Saving combined results to %s\n", sim_filename))
save(sim_means, ij_cov_list, bayes_cov_list, is_singular_list,
     file=sim_filename)
cat("Done!\n")
