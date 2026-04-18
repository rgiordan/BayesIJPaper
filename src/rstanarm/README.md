# src/rstanarm

This directory contains code for the rstanarm analysis in the paper.
The target script is `postprocess_ARM_results.R`, which processes compiled
MCMC results and saves a file used in producing paper figures.

## Pipeline to run `postprocess_ARM_results.R`

### Step 1 — ARM example datasets (`example-models/`)

`example-models/` must exist inside `src/rstanarm/`.  It is already present
in the repository (`src/rstanarm/example-models/`).  If it needs to be
recreated, clone from `https://github.com/stan-dev/example-models` into
`src/rstanarm/`.

### Step 2 — Generate `configs/rstanarm_ij_model_list.json`

`configs/rstanarm_ij_model_list.json` is already present in the repository.
**Skip this step** unless the config needs to be regenerated.

If regenerating, run `configs/generate_rstanarm_configs.R` from the repo root:

```r
source("src/rstanarm/configs/generate_rstanarm_configs.R")
```


### Step 3 — Run MCMC on a SLURM cluster

Output files for `file_suffix = "0924_cluster"` are already present in
`cluster/output/`.  **Skip this step** unless regenerating from scratch.

If regenerating, run the Python submission script from `src/`:

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


### Step 4 — Compile results with `load_rstanarm_results.R`

`cluster/output/compiled_results_1116.Rdata` is already present.  **Skip
this step** unless regenerating.

If regenerating, run:

```r
source("src/rstanarm/load_rstanarm_results.R")
```

This iterates over all models in `configs/rstanarm_ij_model_list.json`, loads
the per-model `.Rdata` files from `cluster/output/`, and saves
`cluster/output/compiled_results_1116.Rdata`.

### Step 5 — Run `postprocess_for_paper.R`

```r
source("src/rstanarm/postprocess_for_paper.R")
```

The script:
1. Reads `configs/rstanarm_ij_model_list.json` for model metadata.
2. Loads `cluster/output/compiled_results_1116.Rdata`.
3. Applies filtering and labeling.
4. Saves `paper/experiment_data/arm/arm_results_original_data_061721.Rdata`.

