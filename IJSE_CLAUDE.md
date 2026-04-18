# Audit of `ComputeIJStandardErrors` Return Value Usage

`ComputeIJStandardErrors` is defined in
`libs/bayesijlib/bayesijlib/R/cov_se_lib.R:162` and currently returns
`environment()`, which exposes every local variable in the function as a named
attribute. This document lists every attribute that callers actually access, and
flags attributes that are referenced but **not assigned** inside the function.

---

## Attributes currently assigned inside `ComputeIJStandardErrors`

| Attribute | How computed |
|---|---|
| `ij_se_list` | `GetBlockBootstrapCovarianceDraws(lp_draws, par_draws, ...)` |
| `num_pars` | `ncol(par_draws)` |
| `num_samples` | `dim(ij_se_list$cov_samples)[1]` |
| `ij_cov_draws` | array built from `ij_se_list$cov_samples` |
| `ij_cov_se` | `apply(ij_cov_draws, FUN=sd, MARGIN=c(2,3))` |
| `num_obs` | `ncol(lp_draws)` |
| `bayes_se_list` | `GetBlockBootstrapCovarianceDraws(par_draws, par_draws, ...)` |
| `bayes_cov_se` | `bayes_se_list$cov_se` |
| `bayes_cov_se_delta_method` | `GetCovarianceMatrixSE(par_draws, par_draws, correlated_samples=TRUE)` |
| `lp_draws`, `par_draws`, `num_blocks`, `num_draws` | function parameters (also in environment) |

**Not assigned but referenced by callers:** `bayes_ij_diff_se` — this attribute
is accessed in multiple places but is never computed inside the function, so it
will be `NULL` (or missing) at runtime.

---

## Call sites and attributes accessed

### 1. `libs/rstanarmijlib/rstanarmijlib/R/rstanarm_lib.R:292–296`

`ComputeIJStandardErrors` is called twice (base and block-doubled), and the
returned environments are stored as `se_results` and `se_results_block_doubled`
inside the enclosing `RunRstanarmBaseMCMC` environment. These are then returned
via `return(environment())` and consumed by the rstanarm scripts below.

No direct attribute access at this call site; the whole environment object is
forwarded.

---

### 2. `src/rstanarm/run_base_mcmc_rstanarm.R:153–168`

Fields are extracted from `mcmc_env$se_results` and
`mcmc_env$se_results_block_doubled` using the list `save_se_fields`:

```r
save_se_fields <- c(
  "ij_cov_se",
  "bayes_cov_se",
  "bayes_cov_se_delta_method",
  "bayes_ij_diff_se",        # ← NOT assigned in function
  "num_blocks",
  "num_draws",
  "num_obs"
)
```

Each field is saved to `mcmc_results$se[[field]]` and
`mcmc_results$se_block_doubled[[field]]`.

Attributes accessed (both `se_results` and `se_results_block_doubled`):

| Attribute | Status |
|---|---|
| `ij_cov_se` | assigned in function |
| `bayes_cov_se` | assigned in function |
| `bayes_cov_se_delta_method` | assigned in function |
| `bayes_ij_diff_se` | **NOT assigned in function** |
| `num_blocks` | function parameter (in environment) |
| `num_draws` | function parameter (in environment) |
| `num_obs` | assigned in function |

---

### 3. `src/rstanarm/load_rstanarm_results.R:71,108,113`

Reads from the `mcmc_results$se` sub-list saved by script 2 above.

| Line | Expression | Attribute |
|---|---|---|
| 71 | `base_results$mcmc_results$se$ij_cov_se` | `ij_cov_se` |
| 108 | `base_results$mcmc_results$se$bayes_cov_se` | `bayes_cov_se` |
| 113 | `base_results$mcmc_results$se$bayes_ij_diff_se` | `bayes_ij_diff_se` (**NOT assigned in function**) |

`bayes_ij_diff_se` is used on line 120 to compute a z-score
(`bayes_ij_z = bayes_ij_diff / bayes_ij_diff_se`), so this is active
(non-dead) code that will silently fail or produce `NA`/`Inf`.

---

### 4. `src/singular_simulations/run_mcmc.R:149–156`

Immediately after calling `ComputeIJStandardErrors`, six attributes are pulled
from the returned environment and stored in a plain list:

```r
se_results <- list(
  bayes_cov_se             = se_results_env$bayes_cov_se,
  bayes_cov_se_delta_method = se_results_env$bayes_cov_se_delta_method,
  bayes_ij_diff_se         = se_results_env$bayes_ij_diff_se,   # ← NOT assigned
  bayes_se_list            = se_results_env$bayes_se_list,
  ij_cov_se                = se_results_env$ij_cov_se,
  ij_se_list               = se_results_env$ij_se_list
)
```

| Attribute | Status |
|---|---|
| `bayes_cov_se` | assigned in function |
| `bayes_cov_se_delta_method` | assigned in function |
| `bayes_ij_diff_se` | **NOT assigned in function** |
| `bayes_se_list` | assigned in function |
| `ij_cov_se` | assigned in function |
| `ij_se_list` | assigned in function |

---

### 5. `src/singular_simulations/postprocess_for_paper.R:54,73`

| Line | Expression | Attribute | Live code? |
|---|---|---|---|
| 54 | `se_results$ij_cov_se$cov_se` | `ij_cov_se` (then sub-field `$cov_se`) | **Dead** — inside `if (FALSE)` block; also noted in a comment as based on an outdated use |
| 73 | `base_env$se_results$bayes_cov_se` | `bayes_cov_se` | Live |

---

## Summary: attributes that are actually used in live code

| Attribute | Used in |
|---|---|
| `ij_cov_se` | `run_base_mcmc_rstanarm.R`, `load_rstanarm_results.R`, `run_mcmc.R` |
| `bayes_cov_se` | `run_base_mcmc_rstanarm.R`, `load_rstanarm_results.R`, `run_mcmc.R`, `postprocess_for_paper.R` |
| `bayes_cov_se_delta_method` | `run_base_mcmc_rstanarm.R`, `run_mcmc.R` |
| `bayes_ij_diff_se` | `run_base_mcmc_rstanarm.R`, `load_rstanarm_results.R`, `run_mcmc.R` — **but never computed** |
| `num_blocks` | `run_base_mcmc_rstanarm.R` |
| `num_draws` | `run_base_mcmc_rstanarm.R` |
| `num_obs` | `run_base_mcmc_rstanarm.R` |
| `bayes_se_list` | `run_mcmc.R` (saved, unclear if downstream uses sub-fields) |
| `ij_se_list` | `run_mcmc.R` (saved, unclear if downstream uses sub-fields) |

## Attributes assigned in the function but never accessed by any caller

| Attribute | Notes |
|---|---|
| `num_pars` | intermediate computation only |
| `num_samples` | intermediate computation only |
| `ij_cov_draws` | intermediate computation only |
| `lp_draws`, `par_draws` | function parameters; not retrieved by callers |
