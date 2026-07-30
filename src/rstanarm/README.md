# rstanarm Pipeline: Steps to Run postprocess_for_paper.R


## Stage 0: Prerequisites

**Step 1: ARM example-models data**

The `example-models/ARM/` directory must exist with ARM dataset files. It is checked into
the repository. If missing, clone from https://github.com/stan-dev/example-models.

**Step 2: `configs/generate_rstanarm_configs.R`** (optional — output is already committed)

Generates the model configuration JSON from a CSV spreadsheet.

```bash
Rscript configs/generate_rstanarm_configs.R
```

Reads: `configs/rstanarm_ij_configs.csv`, `example-models/ARM/`
Produces: `configs/rstanarm_ij_model_list.json`

Skip unless regenerating configs from scratch.

---

## Stage 1: MCMC Runs

Both steps are controlled by the Makefile's `RUN_LOCALLY` flag — `true`
(default, matching today's behavior) runs `Rscript` directly per model;
`false` submits one SLURM job per model via
`cluster/submit_slurm_scripts_rstanarm.py`. `RESAMPLE_N` (default 200)
controls the number of bootstrap replicates per model; it does **not**
affect the number of models fit — that's `NUM_MODELS` (default 65,
override with `make NUM_MODELS=N ...`). Output files with suffix
`0924_cluster` already exist; skip unless regenerating.

**Step 3a: Base MCMC — `cluster/run_base_mcmc_rstanarm.R`**

Runs full Bayesian inference for each model via rstanarm.

```bash
make base_mcmc RUN_LOCALLY=true    # local, one Rscript call per model (default)
make base_mcmc RUN_LOCALLY=false   # SLURM, one job per model (fire-and-forget)
```

The SLURM path is equivalent to the previous manual workflow of running
`cluster/submit_slurm_scripts_rstanarm.py --analysis=base --description=<tag>`
and then `sbatch`-ing each generated script — it's fire-and-forget, so wait
for the jobs to finish before Step 3b.

Reads: `configs/rstanarm_ij_model_list.json`, `example-models/ARM/`
Produces: `cluster/output/{model_desc}_base_mcmc_{DESC}.Rdata` (one per model)

**Step 3b: Bootstrap MCMC — `cluster/run_bootstrapped_mcmc_rstanarm.R`**

Runs bootstrap resampling (`RESAMPLE_N` replicates) for each model.

```bash
make boot_mcmc RUN_LOCALLY=true  RESAMPLE_N=200   # local (default)
make boot_mcmc RUN_LOCALLY=false RESAMPLE_N=200   # SLURM, fire-and-forget
```

Reads: `configs/rstanarm_ij_model_list.json`, base MCMC outputs from Step 3a
Produces: `cluster/output/{model_desc}_boot_mcmc_{DESC}.Rdata` (one per model)

---

## Stage 2: Compile Results

**Step 4: `load_rstanarm_results.R`**

Loads all per-model base and bootstrap MCMC outputs and compiles them into a
single combined dataframe (with IJ covariances, bootstrap covariances, SEs,
timing, etc.). Invoked automatically by `make`; to run by hand:

```bash
Rscript load_rstanarm_results.R \
    --output_dir=cluster/output --file_suffix=0924_cluster \
    --output_filename=compiled_results_1116.Rdata
```

(Options default to these same values, so plain `Rscript load_rstanarm_results.R` still works.)

Reads: `configs/rstanarm_ij_model_list.json`, all `*_base_mcmc_0924_cluster.Rdata`
and `*_boot_mcmc_0924_cluster.Rdata` files in `cluster/output/`
Produces: `cluster/output/compiled_results_1116.Rdata`

---

## Stage 3: Final Post-processing for Paper

**Step 5: `postprocess_for_paper.R`**

Applies filtering and labels for paper visualizations; exports final summary data.

```bash
Rscript postprocess_for_paper.R --compiled_file=cluster/output/compiled_results_1116.Rdata
```

(Options default to today's exact values, so plain `Rscript postprocess_for_paper.R` with no flags still works.)

Reads:
- `configs/rstanarm_ij_model_list.json`
- `cluster/output/compiled_results_1116.Rdata` (`--compiled_file`)

Produces: `paper/experiment_data/arm/arm_results_postprocessed.Rdata` (`--output_filename`)

---

## Local sanity check (no SLURM)

```bash
make sanity_check                  # RESAMPLE_N=5, RUN_LOCALLY=true, all 65 models
make sanity_check RESAMPLE_N=10    # override the bootstrap count
```

Runs the full pipeline locally with a small `RESAMPLE_N` (all 65 models are
still fit, just with fewer bootstraps each), through to
`paper/experiment_data/arm/arm_results_postprocessed.Rdata`. This
**overwrites** whatever real production output currently exists at those
paths — intended for a clean checkout.

---


# Rough runtime estimate

Stage 1 is computationally expensive; in total, the initial fits took
roughly one hour total, and the bootstraps took roughly 267 hours total,
though the jobs can be run in parallel on a cluster. The MCMC time is dominated
by a small number of relatively slow models.

The other stages should run quickly, on the order of minutes.