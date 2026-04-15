# src/rstanarm

This directory contains code for the rstanarm analysis in the paper.
The target script is `postprocess_ARM_results.R`, which processes compiled
MCMC results and saves a file used in producing paper figures.

## Pipeline to run `postprocess_ARM_results.R`

### Step 1 — Obtain the ARM example datasets (`src/example-models`)

**This directory is missing from the repository.**  All cluster scripts and
`configs/generate_rstanarm_configs.R` reference `src/example-models` as the
location of the ARM datasets from Gelman & Hill's "Data Analysis Using
Regression and Multilevel/Hierarchical Models."  The Stan project hosts a
compatible copy at `https://github.com/stan-dev/example-models`.  Clone or
copy it into `src/` so that `src/example-models/ARM/` exists.

### Step 2 — Generate `configs/rstanarm_ij_model_list.json`

`configs/generate_rstanarm_configs.R` reads `configs/rstanarm_ij_configs.csv`
and, for each model, loads the ARM dataset and briefly fits an rstanarm model
(1 iteration) to determine parameter names.  Run it from the repo root:

```r
source("src/rstanarm/configs/generate_rstanarm_configs.R")
```

**Known issues in this script that must be fixed before running:**

1. Missing library calls — add at the top:
   ```r
   library(rstanarm)
   library(rstanarmijlib)
   ```

2. Wrong output path — the final `save` writes to the repo root instead of
   `configs/`.  Change:
   ```r
   outfile <- file(file.path(base_dir, "rstanarm_ij_model_list.json"), "wb")
   ```
   to:
   ```r
   outfile <- file(file.path(config_dir, "rstanarm_ij_model_list.json"), "wb")
   ```

`configs/rstanarm_ij_model_list.json` is already present in the repository,
so **this step can be skipped** unless the config needs to be regenerated.

### Step 3 — Run MCMC on a SLURM cluster

Run the Python submission script from `src/` (the repo's `src/` directory):

```bash
# Base MCMC — one job per model
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
- `<desc>_base_mcmc_<date_tag>.Rdata`
- `<desc>_boot_mcmc_<date_tag>.Rdata`

After the jobs finish, use `cluster/sync_scf_results.sh` to copy the output
files from the cluster (update `REMOTE_GIT` in that script first).

**The output files for `date_tag=0924_cluster` and `1107_cluster` are already
committed to `cluster/output/`.  Skip this step if not regenerating from
scratch.**

### Step 4 — Compile results with `load_rstanarm_results.R`

`load_rstanarm_results.R` iterates over all models in
`configs/rstanarm_ij_model_list.json`, loads the per-model `.Rdata` files from
`cluster/output/`, and saves a single compiled file:

```
cluster/output/compiled_results_<file_date>.Rdata
```

**Two hardcoded variables must be updated before running:**

```r
# Near the top — replace the old hardcoded path:
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
# with:
repo_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
base_dir <- file.path(repo_dir, "src")

# Near the bottom — change the output date to match what postprocess_ARM_results.R loads:
file_date <- "0904"   # change to "1116"
```

`cluster/output/compiled_results_1116.Rdata` is already present.  **Skip
this step** unless you need to regenerate it.

### Step 5 — Create the output directory

`postprocess_ARM_results.R` saves its output to
`paper/experiment_data/rstanarm/data/ARM/`, which **does not exist** in the
repository.  Create it before running:

```bash
mkdir -p paper/experiment_data/rstanarm/data/ARM
```

### Step 6 — Run `postprocess_ARM_results.R`

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

The script ends with `stop()`, which is an interactive sentinel — all code
above it is intended to be executed.

---

## Missing files

| Missing path | Required by | Notes |
|---|---|---|
| `src/example-models/` | `generate_rstanarm_configs.R`, cluster scripts | Clone from `https://github.com/stan-dev/example-models` into `src/` |
| `paper/experiment_data/rstanarm/data/ARM/` | `postprocess_ARM_results.R` | Create with `mkdir -p` before running |

---

## Files not needed for this pipeline

| File | Notes |
|---|---|
| `configs/model_list.json` | Older, simpler model list format; superseded by `rstanarm_ij_model_list.json` |
| `cluster/scf_command.sh` | Historical record of past submission commands; all lines are commented out |
| `cluster/scf_sims_command.sh` | Commands for a simulation pipeline that has been removed; references model list files that no longer exist |
| `cluster/sync_arm_simulated_data.sh` | Syncs simulated data files for the removed simulation pipeline |
| `cluster/sync_scf_simulation_results.sh` | Syncs simulation results; references an old directory structure (`bayes/output/`) |
| `cluster/output/super_simple_simulation_base_results_redim100_obsperre100_seed100.Rdata` | Leftover output from the singular simulations analysis; not read by any script in this directory |
