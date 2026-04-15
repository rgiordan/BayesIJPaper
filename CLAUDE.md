# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains code to reproduce experiments for the paper "The Bayesian Infinitesimal Jackknife for Variance" (Giordano, Broderick). It implements the Bayesian IJ (BayesIJ) method for variance estimation on Bayesian posterior draws.

## Setup

Install the three local R packages (requires `devtools`):

```bash
Rscript src/libs/install_packages_locally.sh
```

This installs:
- `rstanijlib` — BayesIJ tools for `rstan` models
- `rstanarmijlib` — BayesIJ tools for `rstanarm` models
- `bayesijlib` — general BayesIJ tools (bootstrapping, result processing)

The `mrpaw` package (in `src/libs/mrpaw/`) is a newer addition and has its own `install_local.sh`.

## Running Tests

For `bayesijlib`, from `src/libs/bayesijlib/`:
```bash
Rscript run_tests.sh
```

For `mrpaw`, from `src/libs/mrpaw/mrpaw/tests/`:
```bash
Rscript testthat.R
```

## Code Architecture

There are three independent analyses under `src/`, each self-contained:

### `src/rstanarm/`
Experiments using `rstanarm` mixed-effects models. Scripts follow a pattern of running a model (`rstanarm_experiment.R`), then loading/examining results (`load_rstanarm_*.R`, `examine_rstanarm_*.R`).

### `src/mrp/`
Multilevel Regression and Poststratification (MrP) analysis on CCES survey data. The pipeline is:
1. **Data prep**: `clean_cces.R` → `generate_dataset.R` (produces `datasets/cces18_subset.Rdata`)
2. **MCMC**: `run_mcmc.R` (supports `--original`, `--lmer`, `--map` flags; use `run_mcmc_slurm.sh` for batch runs on a SLURM cluster)
3. **Postprocessing**: `postprocess_mcmc.R` per-file, then `compile_postprocessing.R` to concatenate results
4. **Analysis**: `analyze_bootstrap_results.R` on the local machine after `scp`ing results from the cluster

Raw data files (`cces18_common_vv.csv`, `statelevel_predictors.csv`, `poststrat_df.csv`) must be downloaded separately into `src/mrp/datasets/` from the [MRPCaseStudy repo](https://github.com/JuanLopezMartin/MRPCaseStudy/tree/master/data_public/chapter1/data).

### `src/singular_simulations/`
Simpler standalone simulations. Run via `simpler_simulation.sh` locally or `slurm_simulations.sh` on a cluster.

## Local Libraries

- `bayesijlib` — general utilities: `LoadIntoEnv()`, `BootstrapByExchangableColumn()`, covariance/deconvolution tools
- `rstanijlib` — rstan-specific IJ computation
- `rstanarmijlib` — rstanarm/lme4-specific IJ computation, simulation utilities
- `mrpaw` — MrP approximate weights: MCMC weights, influence functions, diagnostics, simulation

Scripts that run locally (non-cluster) typically detect `interactive()` and set default paths accordingly.
