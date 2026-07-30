# Local sanity-check mode for mrp / rstanarm / singular_simulations

**Status:** proposal, not yet implemented.

## Context

Each of the three experiment pipelines (`src/mrp`, `src/rstanarm`,
`src/singular_simulations`) spends nearly all its runtime on a large number
of bootstrap/subsample/resample MCMC fits (202 replicates for mrp, up to
200 bootstraps × 65 models for rstanarm, 100 simulation replicates for
singular_simulations). These replicate counts are currently baked into
SLURM array bounds, a committed file list, or R-script defaults, and the
final `postprocess_for_paper.R` script in each experiment hardcodes the
exact production filenames/timestamps that the full-scale run produces,
with no CLI overrides. There is no way to quickly run "a handful of
replicates" end-to-end — through data generation, bootstrapping,
postprocessing, aggregation, *and* the final paper-output step — to check
that a pipeline still works after a code change, without either
submitting to SLURM or hand-editing multiple files.

The goal is to modify all three experiments so that

- There is an option RESAMPLE_N in each makefile that controls the number
  of bootstrap replicates and, for mrp, the number of resamples;
- RESAMPLE_N is respected by all the scripts.  Command line arguments need
  to be added or modified as necessary.
- Hard-coded suffixes are removed.  Where they are implemented, they can
  be left in place with blank defaults.
- Each makefile should have a flag RUN_LOCALLY.  If true, the makefile should
  use local command.  If false, the makefile should use the slurm commands as
  appropriate.
- As much as possible, existing scripts are to be left as-is.  Ideally, only
  command line arguments are changed.

It is acceptable to overwrite existing files, there is no need to maintain
a separate set of "sanity check" output.  The idea is that this would
be run in a clean version of the repository when doing a sanity check.


## Old findings

Key findings from investigation:
- **rstanarm's and singular_simulations' Makefiles already run 100%
  locally today** — `make all` invokes `Rscript` directly, never
  `sbatch`; only a separate, decoupled Python script
  (`cluster/submit_slurm_scripts_rstanarm.py`) and shell script
  (`run_sims_mcmc.sh`) touch SLURM. Only **mrp**'s `bootstrap_mcmc`
  Makefile target actually calls `sbatch run_mcmc_slurm.sh`.
- This repository's working tree already has **real, full-scale results
  cached locally** in each experiment's output directory (gitignored but
  present): `src/rstanarm/cluster/output/` has 193 real per-model
  `.Rdata` files, and `src/singular_simulations/output/` has all 100 real
  sim replicates. `src/rstanarm` has no stamp files yet, so a naive
  `make` would even **overwrite** real production `.Rdata` files (the
  recipes always pass `--force`). A naive `make NUM_SIMS=5` for
  singular_simulations would have `combine_simulations.R` silently glob
  in all 100 pre-existing files regardless of how many were freshly
  built. The design below avoids both hazards with distinct output
  locations/filenames.
- Every script in this repo already uses `optparse` for its CLI, except
  the four files that need new options for this feature
  (`rstanarm/load_rstanarm_results.R`, both `postprocess_for_paper.R`
  scripts for rstanarm/singular_simulations, and mrp's
  `postprocess_for_paper.R`), so adding `optparse` blocks there is
  idiomatic, not a new pattern.

## Design notes


### 1. mrp

**`src/mrp/Makefile`** — today, bootstrap/subsample replicates only exist
via `sbatch run_mcmc_slurm.sh`.

- Add an option to produce the bootstrap/subsample replicates locally
  calling the **existing, unmodified** `run_mcmc.R`
  directly (no `sbatch`) for a given seed:
  `bootstrap_data/mrp_bootstrap_seed%_samples5000.Rdata` and
  `bootstrap_data/mrp_subsample_seed%_samples5000.Rdata` (adds
  `--subsample`) — mirroring the two lines already in `run_mcmc_slurm.sh`.
  ```

**`src/mrp/compile_postprocessing.R`** — two small, additive changes:
1. Change file_pattern to accept a comma-separated list of files.  The
   invocation should then produce this list with a shell command rather
   than relying on the glob within R.
2. Add `--output_filename` (default `""`, meaning "keep today's
   auto-timestamped name") so the sanity-check target can use a fixed,
   predictable filename instead of a timestamp it can't know in advance
   from the Makefile.

**`src/mrp/postprocess_for_paper.R`** — add an `optparse` block with
`--combined_file` (default = today's hardcoded
`bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata`) and
`--output_filename` (default `mrp_postprocessed.Rdata`), replacing the
two corresponding hardcoded lines.


### 2. rstanarm

**`src/rstanarm/Makefile`**:

- `NUM_BOOTS ?= 200`, threaded into the existing `.stamp_boot_%` recipe
  as `--default_num_boots=$(NUM_BOOTS)` (the flag already exists in
  `run_bootstrapped_mcmc_rstanarm.R`; the Makefile just never passed it).
  No-op for existing behavior at the default of 200.
- Two `.PHONY` aliases, `base_mcmc: $(BASE_STAMPS)` and
  `boot_mcmc: $(BOOT_STAMPS)` (there's currently no way to target "just
  the stamps" from the CLI without listing full paths).
- Note that we want to run for all 65 rstanarm models, just reduce the number
  of bootstraps.
- **`src/rstanarm/load_rstanarm_results.R`** — add an `optparse` block
  (the script currently has zero CLI options) with `--output_dir` (default
  = today's hardcoded `cluster/output` path) and `--file_suffix` (default
  `0924_cluster`), replacing the corresponding hardcoded assignments. The
  existing `for (i in 1:length(model_list))` loops already call
  `LoadModelResults(..., load_lme4=FALSE)`, which uses a `SafeLoad()` helper
  that sets `all_found <- FALSE` and returns `NULL` for any missing file
  rather than erroring (`libs/rstanarmijlib/.../postprocessing_lib.R:26-34`)
- **`src/rstanarm/postprocess_for_paper.R`** — add an `optparse` block with
  `--compiled_file` (default = today's hardcoded
  `cluster/output/compiled_results_1116.Rdata`) and `--output_filename`
  (default `arm_results_postprocessed.Rdata`), replacing the corresponding
  hardcoded `load()` and `save()` lines.




### 3. singular_simulations

- **`src/singular_simulations/Makefile`** — `run_mcmc.R` and
  `combine_simulations.R` **already** both implement an identical `--prefix`
  option folded into their internal `desc` string; the Makefile just never
  exposes or threads it.
- **`src/singular_simulations/postprocess_for_paper.R`** — currently has no
  CLI options at all (no `optparse` import). Add one, with `--prefix`
  (default `""`, mirroring `run_mcmc.R`/`combine_simulations.R`'s existing
  convention exactly), `--seed`/`--re_dim`/`--obs_per_re` (defaults 100/100/100,
  matching today's hardcoded values), and `--output_filename` (default
  `simpler_sim_results.Rdata`). Replace the hardcoded
  `seed_val`/`re_dim`/`obs_per_re` assignments and `desc` construction (add
  the same `if (nchar(prefix) > 0) desc <- paste0(prefix, "_", desc)` logic
  already used in the sibling scripts) and the final `save_filename` line.


### 4. Top-level `Makefile`

```make
RESAMPLE_N ?= 5
.PHONY: sanity_check
sanity_check:
	$(MAKE) -C $(REPO_ROOT)/src/mrp sanity_check RESAMPLE_N=$(RESAMPLE_N)
	$(MAKE) -C $(REPO_ROOT)/src/rstanarm sanity_check RESAMPLE_N=$(RESAMPLE_N)
	$(MAKE) -C $(REPO_ROOT)/src/singular_simulations sanity_check RESAMPLE_N=$(RESAMPLE_N)
```

### Documentation

Add a short "Local sanity check (no SLURM)" section to each of
`src/mrp/README.md`, `src/rstanarm/README.md`,
`src/singular_simulations/README.md`, and the top-level `README.md`,
showing the one-line `make sanity_check [LOCAL_N=N]` invocation, what it
produces, and where (distinct from every production output filename).

## Explicitly out of scope

Reducing per-replicate MCMC iteration/warmup/chain counts (`--num_samples`,
`--num_draws`, etc.) — the request was specifically about the *number of
bootstrap/subsample replicates*, not per-fit cost. Each individual local
replicate still runs a real (if smaller-count) MCMC fit, so a 5-replicate
mrp sanity check is still ~10 real ~25-minute fits unless the user also
passes existing flags like `--num_samples`/`--num_warmup_samples`
manually. Worth flagging as a possible follow-up if the sanity check still
feels slow in practice.

## Verification plan (once implemented)

TODO