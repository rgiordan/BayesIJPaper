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

## Stage 1: MCMC Runs

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

**Step 7: `run_mcmc.R` — bootstrap and subsample replicates**

Runs MCMC on ~100 bootstrap and subsample replicates. Designed for a SLURM cluster; local execution is possible but slow.

```bash
sbatch run_mcmc_slurm.sh
```

Produces: many `bootstrap_data/mrp_{subsample,bootstrap}_seed*.Rdata` files

---

## Stage 2: Post-processing

**Step 8: `postprocess_mcmc.R`** (once per MCMC output file)

Evaluates MRP estimates, computes influence functions for variance estimation, and generates block bootstrap draws. Designed for batch execution via SLURM.

```bash
sbatch postprocess_mcmc_slurm.sh
# or, for a single file:
./postprocess_mcmc.R --base_dir=$(pwd) --mcmc_file=bootstrap_data/mrp_original_seed134432_samples5000.Rdata
```

Produces: `bootstrap_data/mrp_*_mrp_postprocessed.Rdata` for each MCMC output file

---

## Stage 3: Aggregation

**Step 9: `compile_postprocessing.R`**

Concatenates all postprocessed results into a single combined dataframe.

```bash
./compile_postprocessing.R --base_dir=$(pwd) \
  --file_pattern=bootstrap_data/mrp_*_samples5000_mrp_postprocessed.Rdata \
  --description=mrp
```

Produces: `bootstrap_data/mrp_combined_mrp_<timestamp>.Rdata`

> **Note:** The output filename includes a timestamp. The path is hard-coded in
> `postprocess_for_paper.R` as `bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata`.
> If you regenerate this file, update that path in `postprocess_for_paper.R`.

**Step 10: `analyze_map.R`**

Computes an improved MAP estimator using Stan and produces comparison tables (MCMC vs lmer vs MAP).

```bash
Rscript analyze_map.R
```

Produces: `custom_map_analysis.Rdata`

---

## Stage 4: Final Post-processing for Paper

**Step 11: `postprocess_for_paper.R`**

Compares variance estimation methods (IJ, bootstrap, Bayes) across original/subsampled/bootstrapped datasets; exports summary statistics and confidence intervals for the LaTeX paper.

```bash
Rscript postprocess_for_paper.R
```

Reads:
- `bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata`
- `datasets/cces18_subset.Rdata`
- `bootstrap_data/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata`
- `bootstrap_data/mrp_original_seed134432_samples5000.Rdata`
- `bootstrap_data/mrp_originallmer_seed134432_samples5000.Rdata`
- `custom_map_analysis.Rdata`

Produces: `paper/experiment_data/mrp/mrp_postprocessed.Rdata`
