# Notes on the combined `bayesijpaper` package

`libs/bayesijpaper/bayesijpaper` was created by combining the four existing
packages below without modifying any source files.

| Source package | Original location |
|---|---|
| `bayesijlib` | `libs/bayesijlib/bayesijlib/` |
| `bayesijmrp` | `libs/bayesijmrp/bayesijmrp/` |
| `rstanarmijlib` | `libs/rstanarmijlib/rstanarmijlib/` |
| `rstanijlib` | `libs/rstanijlib/rstanijlib/` |

## File provenance

### R/
| File in `bayesijpaper/R/` | Copied from |
|---|---|
| `common_lib.R` | `bayesijlib/R/common_lib.R` |
| `cov_se_lib.R` | `bayesijlib/R/cov_se_lib.R` |
| `result_processing_lib.R` | `bayesijlib/R/result_processing_lib.R` |
| `utils_lib.R` | `bayesijmrp/R/utils_lib.R` |
| `weights_mcmc_lib.R` | `bayesijmrp/R/weights_mcmc_lib.R` |
| `lme4_lib.R` | `rstanarmijlib/R/lme4_lib.R` |
| `postprocessing_lib.R` | `rstanarmijlib/R/postprocessing_lib.R` |
| `rstanarm_lib.R` | `rstanarmijlib/R/rstanarm_lib.R` |
| `run_ij_lib.R` | `rstanijlib/R/run_ij_lib.R` |

### tests/testthat/
| File in `bayesijpaper/tests/testthat/` | Copied from |
|---|---|
| `test_lib.R` | `bayesijlib/tests/testthat/test_lib.R` |
| `helper.R` | `bayesijmrp/tests/testthat/helper.R` |
| `test_utils.R` | `bayesijmrp/tests/testthat/test_utils.R` |
| `mcmc_cache/*.rds` | `bayesijmrp/tests/testthat/mcmc_cache/` |

### man/
All four `.Rd` files copied verbatim from `bayesijmrp/man/`. The other three
packages had no `man/` directories (they used `exportPattern` without roxygen
docs).

---

## Duplications noticed

### 1. `SetConfigDefaults` defined in two files

`rstanarm_lib.R` (from `rstanarmijlib`) and `run_ij_lib.R` (from `rstanijlib`)
both define a function called `SetConfigDefaults`. The signatures differ
slightly:

- `rstanarm_lib.R`: `SetConfigDefaults(rstanarm_ij_config, default_num_samples=2000, default_num_boots=200)`
- `run_ij_lib.R`: `SetConfigDefaults(model_config, default_num_samples, default_num_boots)`

In a flat package these will conflict. One must be renamed or the two merged.

### 2. `GetBlockBootstrapCovarianceDraws` defined in `bayesijlib` but documented and exported in `bayesijmrp`

The function body lives in `cov_se_lib.R` (originally `bayesijlib`). However,
`bayesijmrp`'s `NAMESPACE` exports it and `bayesijmrp/man/` contains a
`GetBlockBootstrapCovarianceDraws.Rd` doc page whose header says
`"Please edit documentation in R/utils_lib.R"` — indicating the function was
previously defined in `bayesijmrp/R/utils_lib.R` and was later moved to
`bayesijlib` without removing the stale NAMESPACE export and man page from
`bayesijmrp`. In the combined package only one copy of the function and one
man page should remain.

### 3. `test_lib.R` duplicated within `bayesijlib`

`bayesijlib` contains two copies of the same test file with identical content:
- `bayesijlib/tests/test_lib.R`
- `bayesijlib/tests/testthat/test_lib.R`

Only the `testthat/` version was copied into `bayesijpaper`.

### 4. Overlapping `library()` calls in R source files

Several R files call `library()` at the top level (e.g. `library(mcmcse)` in
`cov_se_lib.R`, `library(rstan)` in `run_ij_lib.R`). In a proper package these
should be `Imports`/`Depends` entries in `DESCRIPTION` rather than inline
`library()` calls, since `library()` in package source emits a warning on
`R CMD check`. These are inherited as-is from the originals.

### 5. `lme4_lib.R` is entirely commented-out dead code

`rstanarmijlib/R/lme4_lib.R` contains only commented-out functions
(`TidyLME4Results`, `TidyLME4Bootstrap`). It was copied as-is.
