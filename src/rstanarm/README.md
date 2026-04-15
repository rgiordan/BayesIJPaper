# src/rstanarm

This directory contains code for the rstanarm analysis in the paper.
The target script is `postprocess_ARM_results.R`, which processes compiled
MCMC results and saves a file used in producing paper figures.

## Pipeline to run `postprocess_ARM_results.R`


### Step 2 — Generate MCMC output files on a SLURM cluster

Run the Python submission script from `src/` (the repo's `src/` directory,
not this subdirectory):

```bash
# Base MCMC (one job per model in rstanarm_ij_model_list.json)
rstanarm/cluster/submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description='<date_tag>' \
    --model_list_filename=rstanarm_ij_model_list.json \
    --analysis=base

# Bootstrap MCMC
rstanarm/cluster/submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description='<date_tag>' \
    --model_list_filename=rstanarm_ij_model_list.json \
    --analysis=bootstrap
```

Each job calls `cluster/run_base_mcmc_rstanarm.R` or
`cluster/run_bootstrapped_mcmc_rstanarm.R` and saves results to
`cluster/output/` as:
- `<desc>_base_mcmc_<date_tag>_cluster.Rdata`
- `<desc>_boot_mcmc_<date_tag>_cluster.Rdata`


### Step 3 — Compile results with `load_rstanarm_results.R`

`load_rstanarm_results.R` iterates over all models in
`configs/rstanarm_ij_model_list.json`, loads the base and bootstrap `.Rdata`
files from `cluster/output/`, and writes a single compiled file:

```
cluster/output/compiled_results_<file_date>.Rdata
```


### Step 5 — Run `postprocess_ARM_results.R`

Run from `src/rstanarm/`:

```r
source("postprocess_ARM_results.R")
```

The script:
1. Reads `configs/rstanarm_ij_model_list.json` for model metadata.
2. Loads `cluster/output/compiled_results_1116.Rdata` (contains
   `combined_df_nore` and `timing_df` produced by `load_rstanarm_results.R`).
3. Applies filtering and labeling.
4. Saves `paper/experiment_data/rstanarm/data/ARM/arm_results_original_data_061721.Rdata`.

---

## Files not needed for this pipeline

The following scripts exist in `src/rstanarm/` but are **not** part of the
`postprocess_ARM_results.R` pipeline:

| File | Purpose |
|---|---|
| `rstanarm_experiment.R` | Exploratory sandbox; uses hardcoded paths to an old repository |
| `examine_rstanarm_results.R` | Downstream plotting; reads output of `postprocess_ARM_results.R` |
| `examine_rstanarm_detailed_results.R` | Downstream detailed analysis |
| `examine_rstanarm_results_with_convolution.R` | Downstream convolution analysis |
| `examine_rstanarm_simluation_results.R` | Downstream simulation analysis |
| `examine_lme4_results.R` | Downstream lme4 comparison plots |
| `deconvolve_rstanarm_results.R` | Separate deconvolution analysis |
| `kernel_analysis.R`, `kernel_example.R` | Separate kernel analysis |
| `nes_processing.R` | Processes a different dataset (NES) |
| `load_rstanarm_bootstrap_results.R` | Loads simulation-based bootstrap results (separate pipeline) |
| `load_rstanarm_ARM_simulation_results.R` | Loads ARM simulation results (separate pipeline) |
| `load_rstanarm_simulation_results.R` | Loads scaling simulation results (separate pipeline) |
| `load_rstanarm_deep_dive.R` | Exploratory deep-dive; uses hardcoded old paths |
| `rstanarm_meaning.R` | Exploratory script |
| `cluster/run_lme4.R` | Fits lme4 models; not used in `postprocess_ARM_results.R` |
| `cluster/run_mcmc_simulations_rstanarm.R` | Parametric bootstrap simulation pipeline |
| `configs/generate_rstanarm_configs.R` | Generates `rstanarm_ij_model_list.json`; already done |
| `configs/generate_ARM_simulated_datasets.R` | Generates simulation datasets; separate pipeline |

---

## Config and data files

| File | Description |
|---|---|
| `configs/rstanarm_ij_model_list.json` | Defines all ARM models; read by cluster scripts and `postprocess_ARM_results.R` |
| `configs/rstanarm_ij_configs.csv` | Source CSV used by `generate_rstanarm_configs.R` to produce the JSON |
| `cluster/output/compiled_results_1116.Rdata` | Compiled results loaded by `postprocess_ARM_results.R` |
