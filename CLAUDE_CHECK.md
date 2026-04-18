# Repository Audit: BayesIJPaper

This document records errors, style inconsistencies, missing dependencies, and
documentation problems found during a reproducibility audit of the repository.
Issues are organized from most to least critical.  The goal is that successful
runs of the three `postprocess_for_paper.R` scripts produce all paper results.

---

## CRITICAL BUGS — will prevent `postprocess_for_paper.R` from running

### 1. `singular_simulations/postprocess_for_paper.R` — broken pipeline

**Files:** `src/singular_simulations/postprocess_for_paper.R`,
`src/singular_simulations/run_simpler_simulation.R`

Multiple disconnects between what `postprocess_for_paper.R` expects and what
the pipeline actually produces:

<!-- **(a) Wrong search directory for input files.**
`postprocess_for_paper.R` line 11 sets `results_dir` to
`src/singular_simulations/`, but `run_simpler_simulation.R` saves to
`src/singular_simulations/output/`. -->

**(b) Completely different file-naming conventions.**  
`postprocess_for_paper.R` lines 23–24 looks for:
```
super_simple_simulation_sim_results_redim100_obsperre100_seed100.Rdata
super_simple_simulation_base_results_redim100_obsperre100_seed100.Rdata
```
`run_simpler_simulation.R` line 120 saves files as:
```
simplesim_mcmc_draws_redim100_obsperre100_seed<N>_<description>.Rdata
```
These names never match.

**(c) Missing `sim_results` file — no script generates it.**  
`postprocess_for_paper.R` loads a `sim_results` file (line 26) containing
`sim_means` and `ij_cov_list` (used at lines 47 and 66). No script in the
repository generates this file. The simulation pipeline is incomplete.

**(d) Variables referenced but not saved by the simulation script.**  
`postprocess_for_paper.R` uses `se_results$ij_cov_se` (line 37) and
`se_results$bayes_cov_se` (line 40), but `run_simpler_simulation.R` does not
compute or save `se_results`.

**Fix needed:**
- Decide whether to update `postprocess_for_paper.R` to match the current
  output of `run_simpler_simulation.R`, or update the simulation script to
  generate files with the expected names, directory, and contents.
- Write (or recover) a script that aggregates multiple simulation runs into a
  `sim_results` file containing `sim_means` and `ij_cov_list`.
- Ensure `se_results` (block-bootstrap standard errors for IJ and Bayes
  covariances) is computed and saved by the simulation script.

---

### 2. `mrp/postprocess_mcmc.R` — wrong variable name for survey data

**File:** `src/mrp/postprocess_mcmc.R` lines 56, 67, 75

`postprocess_mcmc.R` reads the saved MCMC output and references the survey
data as `load_env$survey_boot_df` (three times).  However,
`src/mrp/run_mcmc.R` line 222 saves the variable as `survey_sample_df`:

```r
save(logit_post, survey_sample_df, opt, sys_info, sys_time, stan_time,
     file=save_filename)
```

`survey_boot_df` does not exist in the saved file; all three calls will receive
`NULL` and fail at runtime.

**Fix:** Replace `survey_boot_df` with `survey_sample_df` on lines 56, 67, and
75 of `postprocess_mcmc.R`.

---

<!-- ### 3. `rstanarm` pipeline — requires `rstansensitivity` package

**Files:**  
- `src/rstanarm/postprocess_for_paper.R` line 3: `library(rstansensitivity)`  
- `src/rstanarm/load_rstanarm_results.R` line 3: `library(rstansensitivity)`  
- `src/rstanarm/cluster/run_bootstrapped_mcmc_rstanarm.R` line 356:
  `rstansensitivity::GroupLogLikelihoodDraws(...)`

`rstansensitivity` is not on CRAN and is not installed by
`libs/install_packages_locally.sh`.  Without it the rstanarm pipeline cannot
run.

Note: `GroupLogLikelihoodDraws` is already implemented in `rstanarmijlib`
(`libs/rstanarmijlib/rstanarmijlib/R/rstanarm_lib.R`), so the namespace-
qualified call in `run_bootstrapped_mcmc_rstanarm.R` could simply drop the
`rstansensitivity::` prefix.  The `library(rstansensitivity)` calls in the
other two scripts should either be removed or replaced with an instruction to
install a version from source/GitHub.

**Fix options:**
- If `rstansensitivity` is still actively maintained, add it to the
  installation instructions and to `install_packages_locally.sh`.
- Otherwise, remove the `library(rstansensitivity)` lines (the package does
  not appear to be used beyond `GroupLogLikelihoodDraws`), and change
  `rstansensitivity::GroupLogLikelihoodDraws` → `GroupLogLikelihoodDraws` in
  `run_bootstrapped_mcmc_rstanarm.R`. -->

---

<!-- ### 4. `experiment_run_map.R` — `stan_time` undefined at save point

**File:** `src/mrp/experiment_run_map.R` line 156

```r
save(map_fit, survey_sample_df, sys_info, sys_time, stan_time, file=save_filename)
```

In the MAP branch of this script, `stan_time` is never assigned.  (It is
assigned in the lmer branch only in `run_mcmc.R`, not in
`experiment_run_map.R`.)  The `save()` call will throw
`"object 'stan_time' not found"`.

**Fix:** Add `stan_time <- NA` before the `save()` call, or compute it by
timing the `optimizing()` call as done in the MAP branch of `run_mcmc.R`.

--- -->

<!-- ## MODERATE BUGS

### 5. Typo `dirnamte()` in two error-message paths

**Files:**  
- `src/mrp/run_mcmc.R` line 131  
- `src/mrp/experiment_run_map.R` line 93

```r
stop(sprintf("Failed to create save directory %s", dirnamte(save_filename)))
```

`dirnamte` is not a function; it should be `dirname`.  This only triggers when
directory creation fails, but when it does the error handler itself will error,
obscuring the original problem.

**Fix:** Replace `dirnamte` → `dirname` in both files. -->
<!--
---

### 6. `generate_rstanarm_configs.R` — argument name mismatch

**File:** `src/rstanarm/configs/generate_rstanarm_configs.R` line 55

Calls `GenerateRstanarmIJConfig(formula = row$formula_str, ...)`, but
`GenerateRstanarmConfig` (in `rstanarmijlib`) expects the parameter named
`formula_str`, not `formula`.  R will throw "unused argument" when someone
tries to regenerate the config JSON.

The pre-committed `rstanarm_ij_model_list.json` means this does not block
current reproduction, but it will prevent regenerating configs from scratch.

**Fix:** Change `formula = row$formula_str` → `formula_str = row$formula_str`
on line 55.

--- -->

## DOCUMENTATION ERRORS
<!--
### 7. README.md — wrong directory name and wrong package count

**File:** `README.md` lines 12–13

> "There are three R packages that implement repeatedly-used functionality.
> These packages are found in the `lib` directory"

- The directory is `libs/` (plural), not `lib/`.
- There are **four** packages (`bayesijlib`, `rstanijlib`, `rstanarmijlib`,
  `bayesijmrp`), not three.

--- -->

<!-- ### 8. CLAUDE.md — wrong path to `libs/` and incomplete package list

**File:** `CLAUDE.md`

- Refers to `src/libs/install_packages_locally.sh` but the actual path is
  `libs/install_packages_locally.sh` (under the repo root, not under `src/`).
- Lists only three packages; `bayesijmrp` is omitted.

--- -->
<!--
### 9. `src/rstanarm/README.md` — wrong script name

**File:** `src/rstanarm/README.md` (Step 5 and the source command)

Calls the final step script `postprocess_ARM_results.R`, but the file in the
repo is `postprocess_for_paper.R`.  Same typo also appears in the `source()`
example:

```r
source("src/rstanarm/postprocess_ARM_results.R")  # wrong
source("src/rstanarm/postprocess_for_paper.R")    # correct
```

--- -->

### 10. `src/mrp/README.md` (and identical text in `mcmc_files.txt`) — two errors

**Files:** `src/mrp/README.md`, `src/mrp/mcmc_files.txt`

- "Run `clean_ccecs.R`" — typo; the script is `clean_cces.R`.
- "Finally, run `postprocess_results_for_latex.R`" — this file does not exist;
  the correct script is `postprocess_for_paper.R`.

---

### 11. `src/README.md` — typo

**File:** `src/README.md` line 1

> "This directory simualtes data"

"simualtes" → "simulates".

---

### 12. `custom_map_analysis.Rdata` — undocumented provenance

**File:** `src/mrp/custom_map_analysis.Rdata`

This file is loaded by `postprocess_for_paper.R` (line 77) as the MAP
analysis, with a comment that Stan's MAP optimizer was inadequate.  No script
in the repository documents how this file was produced.  `analyze_map.R`
appears to be the generating script but is not referenced in the README and is
not obviously connected to `experiment_run_map.R`.

**Fix:** Add a note in `src/mrp/README.md` explaining that
`custom_map_analysis.Rdata` is generated by `analyze_map.R` (or whichever
script actually produced it), with the command to reproduce it.

---

### 13. `postprocess_for_paper.R` (mrp) — stale development warning

**File:** `src/mrp/postprocess_for_paper.R` line 98

```r
warning("Check whether mrp_var is actually the variance!!!")
```

This is a debugging note left in production code.  It fires every time the
script runs, obscuring real warnings.

---

## CODE-QUALITY ISSUES

### 14. `library()` called inside package source files

Several package source files call `library()` at the top level.  This is
incorrect for R packages (should use `Imports:` / `@importFrom` / `::`) and
can cause side effects when the package is loaded.

Affected files:
- `libs/bayesijmrp/bayesijmrp/R/weights_mcmc_lib.R`: `library(tidyverse)`,
  `library(brms)`
- `libs/bayesijmrp/bayesijmrp/R/utils_lib.R`: `library(tidyverse)`
- `libs/bayesijlib/bayesijlib/R/cov_se_lib.R`: `library(mcmcse)`,
  `library(reshape2)`
- `libs/rstanarmijlib/rstanarmijlib/R/rstanarm_lib.R`: `library(rstanarm)`,
  `library(doParallel)`, `library(lme4)`

Note that `tidyverse`, `brms`, `lme4`, `mcmcse`, and `reshape2` are listed in
`Depends:` in the respective `DESCRIPTION` files, so the `library()` calls are
redundant as well as non-standard.

---

### 15. Duplicate `GetBlockBootstrapCovarianceDraws` across two packages

**Files:**  
- `libs/bayesijlib/bayesijlib/R/cov_se_lib.R` lines 88–153  
- `libs/bayesijmrp/bayesijmrp/R/utils_lib.R` lines 61–134

Both packages contain an essentially identical implementation of
`GetBlockBootstrapCovarianceDraws`.  `postprocess_mcmc.R` loads `bayesijmrp`
(which exports this function) and calls it without namespace qualification,
so it currently works.  But the duplication creates a maintenance risk.

---

### 16. Scoping bug in `GetExchangeableColumn` (non-blocking)

**File:** `libs/rstanarmijlib/rstanarmijlib/R/rstanarm_lib.R` line 311

```r
GetExchangeableColumn <- function(exchangeable_col, df) {
  if (rstanarm_ij_config$exchangeable_col == "") {   # uses outer-scope variable
```

The function takes `exchangeable_col` as a parameter but then checks
`rstanarm_ij_config$exchangeable_col` from the enclosing scope.  This works in
`RunRstanarmBootstraps` because `rstanarm_ij_config` is defined there, but it
will silently fail if `GetExchangeableColumn` is called from any other context.

---

## ORPHANED / EXPLORATORY SCRIPTS

The following scripts are not referenced by any pipeline step and have no
README entry explaining their purpose.  They should either be documented as
optional exploratory tools or removed to reduce confusion:

| File | Notes |
|------|-------|
| `src/mrp/analysis.R` | Exploratory analysis, not in pipeline |
| `src/mrp/analyze_bootstrap_results.R` | Listed as "optional" in README but not connected to `postprocess_for_paper.R` |
| `src/mrp/analyze_map.R` | May have generated `custom_map_analysis.Rdata`; undocumented |
| `src/mrp/bootstrap_data/sync_scf.sh` | Cluster sync helper; purpose not documented |

---

## SUMMARY TABLE

| # | Severity | Location | Issue |
|---|----------|----------|-------|
| 1 | **CRITICAL** | `singular_simulations/postprocess_for_paper.R` | Missing sim_results file; wrong directory; missing variables |
| 2 | **CRITICAL** | `mrp/postprocess_mcmc.R` lines 56, 67, 75 | `survey_boot_df` → should be `survey_sample_df` |
| 3 | **CRITICAL** | `rstanarm/postprocess_for_paper.R`, `load_rstanarm_results.R`, `run_bootstrapped_mcmc_rstanarm.R` | Requires `rstansensitivity` package (not installable) |
| 4 | **CRITICAL** | `experiment_run_map.R` line 156 | `stan_time` used but never assigned |
| 5 | moderate | `run_mcmc.R` line 131, `experiment_run_map.R` line 93 | Typo `dirnamte()` → `dirname()` |
| 6 | moderate | `generate_rstanarm_configs.R` line 55 | `formula=` → `formula_str=` |
| 7 | documentation | `README.md` | Wrong dir name `lib` → `libs`; says 3 packages, actually 4 |
| 8 | documentation | `CLAUDE.md` | Wrong path `src/libs/` → `libs/`; missing `bayesijmrp` |
| 9 | documentation | `src/rstanarm/README.md` | Wrong script name `postprocess_ARM_results.R` |
| 10 | documentation | `src/mrp/README.md`, `mcmc_files.txt` | Typo in script name; wrong final script name |
| 11 | documentation | `src/README.md` | Typo "simualtes" |
| 12 | documentation | `src/mrp/README.md` | `custom_map_analysis.Rdata` provenance undocumented |
| 13 | style | `mrp/postprocess_for_paper.R` line 98 | Development `warning()` left in |
| 14 | style | Multiple package `.R` files | `library()` called inside package source |
| 15 | style | `bayesijlib`, `bayesijmrp` | Duplicate `GetBlockBootstrapCovarianceDraws` |
| 16 | style | `rstanarmijlib/R/rstanarm_lib.R` line 311 | Scoping bug in `GetExchangeableColumn` |
| — | info | `src/mrp/analysis.R` etc. | Orphaned exploratory scripts (4 files) |
