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

Runs MCMC on ~100 bootstrap and subsample replicates. Designed for a SLURM cluster; local execution is possible but slow.

Make sure the paths in `run_mcmc_slurm.sh` are correct, and then run

```bash
sbatch run_mcmc_slurm.sh
```

Produces: many `bootstrap_data/mrp_{subsample,bootstrap}_seed*.Rdata` files.

---

## Stage 3: Post-processing and Aggregation

**Step 8: Create a list of mcmc runs**

Make sure you're on a system that has copies of all the MCMC
runs in the `bootstrap_data` directory, including the original
run, the subsampled runs, and the bootstraps.  If you ran step 7
remotely, this probably means copying the output of the original
MCMC fit to the remote machine.

Run

```bash
ls -1a bootstrap_data/mrp_*_seed[0-9]*_samples5000.Rdata > mcmc_files.txt
```

The next step will postprocess every file in `mcmc_files.txt`.

---

**Step 8: `postprocess_mcmc.R`** (once per MCMC output file)

Evaluates MRP estimates, computes influence functions for variance estimation, and generates block bootstrap draws. Designed for batch execution via SLURM.

Make sure the `#SBATCH -a 1-202` command in
`postprocess_mcmc_slurm.sh` has the right number of tasks;
there should be one task for each row in `mcmc_files.txt`.  Then run

```bash
sbatch postprocess_mcmc_slurm.sh
```

Note that you can postprocess a single file with
```bash
./postprocess_mcmc.R --base_dir=$(pwd) --mcmc_file=bootstrap_data/mrp_original_seed134432_samples5000.Rdata
```

Produces: `bootstrap_data/mrp_*_mrp_postprocessed.Rdata` for each MCMC output file

---


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

---


## Stage 4: Final Post-processing for Paper

**Step 11: `postprocess_for_paper.R`**

Compares variance estimation methods (IJ, bootstrap, Bayes) across
original/subsampled/bootstrapped datasets; exports summary statistics and confidence
intervals for the LaTeX paper.

```bash
Rscript postprocess_for_paper.R
```

Reads:
- `bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata`
- `datasets/cces18_subset.Rdata`
- `bootstrap_data/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata`
- `bootstrap_data/mrp_original_seed134432_samples5000.Rdata`
- `bootstrap_data/mrp_originallmer_seed134432_samples5000.Rdata`
- `bootstrap_data/custom_map_analysis.Rdata`

Produces: `paper/experiment_data/mrp/mrp_postprocessed.Rdata`
