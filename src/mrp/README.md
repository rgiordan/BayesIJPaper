# MRP Pipeline: Steps to Run postprocess_for_paper.R

## Stage 0: Data Preparation

**Step 1: Download raw data (manual)**

Download these three CSV files from https://github.com/JuanLopezMartin/MRPCaseStudy/tree/master/data_public/chapter1/data into `datasets/`:
- `cces18_common_vv.csv`
- `statelevel_predictors.csv`
- `poststrat_df.csv`

**Step 2: `clean_cces.R`**

Cleans and recodes the raw CCES survey data (features: abortion, state, male, ethnicity, age, education, region); merges with state-level predictors.

```bash
Rscript clean_cces.R
```

Produces: `datasets/cces18_common_vv.Rdata`

**Step 3: `generate_dataset.R`**

Subsamples 5,000 respondents and builds the post-stratification table.

```bash
Rscript generate_dataset.R
```

Produces: `datasets/cces18_subset.Rdata`

---

## Stage 1: Estimates on a single dataset

**Step 4: `run_mcmc.R` — original MCMC fit**

Full Bayesian logistic regression on the original dataset.

```bash
./run_mcmc.R --base_dir=$(pwd) --original --seed=134432
```

Produces: `bootstrap_data/mrp_original_seed134432_samples5000.Rdata`

**Step 5: `run_mcmc.R` — lmer fit**

Fits the same model using `lme4::glmer()` for comparison.

```bash
./run_mcmc.R --base_dir=$(pwd) --original --lmer --seed=134432
```

Produces: `bootstrap_data/mrp_originallmer_seed134432_samples5000.Rdata`

**Step 6: `run_mcmc.R` — MAP estimate**

Computes Maximum A Posteriori estimate via Stan optimization.

```bash
./run_mcmc.R --base_dir=$(pwd) --original --map --seed=134432
```

Produces: `bootstrap_data/mrp_originalmap_seed134432_samples5000.Rdata`


**Step 7: `analyze_map.R`**

Computes an improved MAP estimator using Stan and produces comparison tables (MCMC vs lmer vs MAP).

```bash
Rscript analyze_map.R
```

Produces: `bootstrap_data/custom_map_analysis.Rdata`

---

## Stage 2: Bootstrap and frequentist variability

**Step 7: `run_mcmc.R` — bootstrap and subsample replicates**

Runs MCMC on `RESAMPLE_N` bootstrap and `RESAMPLE_N` subsample replicates
(default 101, matching the production run; seeds run 0..RESAMPLE_N-1).
Controlled by the Makefile's `RUN_LOCALLY` flag:

```bash
make bootstrap_mcmc RUN_LOCALLY=false RESAMPLE_N=101   # SLURM (default)
make bootstrap_mcmc RUN_LOCALLY=true  RESAMPLE_N=101   # local, sequential
```

The SLURM path (`sbatch --array=0-$((RESAMPLE_N-1)) run_mcmc_slurm.sh`) is
fire-and-forget, same as running `sbatch run_mcmc_slurm.sh` directly — wait
for the array job to finish before moving to Stage 3. Local execution is
possible but slow (see runtime estimate below).

Produces: `bootstrap_data/mrp_{subsample,bootstrap}_seed*_samples5000.Rdata` files.

---

## Stage 3: Post-processing and Aggregation

**Step 8: `postprocess_mcmc.R`** (once per MCMC output file)

Evaluates MRP estimates, computes influence functions for variance estimation, and generates block bootstrap draws. This stage is fairly time-intensive, so it also respects `RUN_LOCALLY`:

```bash
make bootstrap_postprocess RUN_LOCALLY=false RESAMPLE_N=101   # SLURM (default)
make bootstrap_postprocess RUN_LOCALLY=true  RESAMPLE_N=101   # local, one Rscript call per file
```

The SLURM path (`sbatch --array=0-$((RESAMPLE_N-1)) postprocess_mcmc_slurm.sh`)
derives each task's filenames directly from `$SLURM_ARRAY_TASK_ID` (no file
list to prepare) and is fire-and-forget — wait for it to finish before
moving to Stage 4.

Note that you can postprocess a single file directly with
```bash
./postprocess_mcmc.R --base_dir=$(pwd) --mcmc_file=bootstrap_data/mrp_original_seed134432_samples5000.Rdata
```

Produces: `bootstrap_data/mrp_*_mrp_postprocessed.Rdata` for each MCMC output file

---


**Step 9: `compile_postprocessing.R`**

Concatenates all postprocessed results into a single combined dataframe.
This is invoked automatically by `make` with an explicit, comma-separated
`--file_pattern` and a fixed `--output_filename`; to run by hand:

```bash
./compile_postprocessing.R --base_dir=$(pwd) \
  --file_pattern=bootstrap_data/a_mrp_postprocessed.Rdata,bootstrap_data/b_mrp_postprocessed.Rdata \
  --description=mrp \
  --output_filename=bootstrap_data/mrp_combined_mrp.Rdata
```

Produces: `bootstrap_data/mrp_combined_mrp.Rdata` (or, if `--output_filename`
is omitted, an auto-timestamped `bootstrap_data/mrp_combined_mrp_<timestamp>.Rdata`).

---


## Stage 4: Final Post-processing for Paper

**Step 11: `postprocess_for_paper.R`**

Compares variance estimation methods (IJ, bootstrap, Bayes) across
original/subsampled/bootstrapped datasets; exports summary statistics and confidence
intervals for the LaTeX paper.

```bash
Rscript postprocess_for_paper.R --combined_file=bootstrap_data/mrp_combined_mrp.Rdata --seed=134432
```

(Options default to today's exact values, so plain `Rscript postprocess_for_paper.R` with no flags still works.)

Reads:
- `bootstrap_data/mrp_combined_mrp.Rdata` (`--combined_file`)
- `datasets/cces18_subset.Rdata`
- `bootstrap_data/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata` (seed from `--seed`)
- `bootstrap_data/mrp_original_seed134432_samples5000.Rdata` (seed from `--seed`)
- `bootstrap_data/mrp_originallmer_seed134432_samples5000.Rdata` (seed from `--seed`)
- `bootstrap_data/custom_map_analysis.Rdata`

Produces: `paper/experiment_data/mrp/mrp_postprocessed.Rdata` (`--output_filename`)

---

## Local sanity check (no SLURM)

```bash
make sanity_check                  # RESAMPLE_N=5, RUN_LOCALLY=true
make sanity_check RESAMPLE_N=10    # override the replicate count
```

Runs Stages 2-4 entirely locally with a small `RESAMPLE_N`, through to
`bootstrap_data/mrp_combined_mrp.Rdata` and
`paper/experiment_data/mrp/mrp_postprocessed.Rdata`. This **overwrites**
whatever real production output currently exists at those paths — intended
for a clean checkout, not for preserving cached production results.




# Rough runtime estimate

The runtime is dominated by the MCMC fits, each of which takes
roughly 25 minutes.  After the single MCMC run of stage 1,
stage 2 can be run in parallel, and can be expected to
take a total of roughly 200 * 25 minutes ~ 83 hours in total.

Each postprocessing call (step 8) also takes roughly a minute
due to the need to compute the array of predicted responses
as part of computing the MrP estimates.  Again, these
postprocessing steps can be run in parallel, for a total
of roughly 200 minutes of computation.

The other stages should run quickly, on the order of minutes.