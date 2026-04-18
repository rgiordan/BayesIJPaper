# rstanarm Pipeline: Steps to Run postprocess_for_paper.R

## Stage 0: Prerequisites

**Step 1: ARM example-models data**

The `example-models/ARM/` directory must exist with ARM dataset files. It is checked into the repository. If missing, clone from https://github.com/stan-dev/example-models.

**Step 2: `configs/generate_rstanarm_configs.R`** (optional — output is already committed)

Generates the model configuration JSON from a CSV spreadsheet.

```bash
Rscript configs/generate_rstanarm_configs.R
```

Reads: `configs/rstanarm_ij_configs.csv`, `example-models/ARM/`
Produces: `configs/rstanarm_ij_model_list.json`

Skip unless regenerating configs from scratch.

---

## Stage 1: MCMC Runs (cluster)

Both steps are designed for SLURM. Generate submission scripts with
`cluster/submit_slurm_scripts_rstanarm.py`, then submit with `sbatch`.
Output files with suffix `0924_cluster` already exist; skip unless regenerating.

**Step 3a: Base MCMC — `cluster/run_base_mcmc_rstanarm.R`**

Runs full Bayesian inference for each model via rstanarm.

```bash
# From src/ directory — generates slurm scripts without submitting:
rstanarm/cluster/submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description=<date_tag> \
    --model_list_filename=rstanarm_ij_model_list.json \
    --analysis=base \
    --no-submit
# then: sbatch each script in rstanarm/cluster/slurm_scripts/
```

Reads: `configs/rstanarm_ij_model_list.json`, `example-models/ARM/`
Produces: `cluster/output/{model_desc}_base_mcmc_{description}.Rdata` (one per model)

**Step 3b: Bootstrap MCMC — `cluster/run_bootstrapped_mcmc_rstanarm.R`**

Runs bootstrap resampling for each model.

```bash
rstanarm/cluster/submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description=<date_tag> \
    --model_list_filename=rstanarm_ij_model_list.json \
    --analysis=bootstrap \
    --no-submit
# then: sbatch each script in rstanarm/cluster/slurm_scripts/
```

Reads: `configs/rstanarm_ij_model_list.json`, base MCMC outputs from Step 3a
Produces: `cluster/output/{model_desc}_bootstrap_mcmc_{description}.Rdata` (one per model)

---

## Stage 2: Compile Results

**Step 4: `load_rstanarm_results.R`**

Loads all per-model base and bootstrap MCMC outputs and compiles them into a
single combined dataframe (with IJ covariances, bootstrap covariances, SEs,
timing, etc.).

```bash
Rscript load_rstanarm_results.R
```

Reads: `configs/rstanarm_ij_model_list.json`, all `*_base_mcmc_0924_cluster.Rdata`
and `*_boot_mcmc_0924_cluster.Rdata` files in `cluster/output/`
Produces: `cluster/output/compiled_results_1116.Rdata`

---

## Stage 3: Final Post-processing for Paper

**Step 5: `postprocess_for_paper.R`**

Applies filtering and labels for paper visualizations; exports final summary data.

```bash
Rscript postprocess_for_paper.R
```

Reads:
- `configs/rstanarm_ij_model_list.json`
- `cluster/output/compiled_results_1116.Rdata`

Produces: `paper/experiment_data/arm/arm_results_original_data_061721.Rdata`

---

## Dependency Summary

```
configs/rstanarm_ij_model_list.json
        |
        +---> run_base_mcmc_rstanarm.R ---------> {model}_base_mcmc_{tag}.Rdata
        |                                                    |
        +---> run_bootstrapped_mcmc_rstanarm.R -> {model}_bootstrap_mcmc_{tag}.Rdata
                                                             |
                                                   load_rstanarm_results.R
                                                             |
                                                   compiled_results_1116.Rdata
                                                             |
                                                   postprocess_for_paper.R
                                                             |
                                          arm_results_original_data_061721.Rdata
```
