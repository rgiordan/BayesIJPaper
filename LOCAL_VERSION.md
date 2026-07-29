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

The goal is a `make sanity_check` (customizable replicate count, default
**5**) per experiment that runs a small number of bootstrap/subsample
replicates **entirely locally** (no `sbatch`) all the way through to a
locally-produced, distinctly-named paper-output file, reusing the
existing per-replicate R scripts unchanged wherever possible, and touching
as little existing code as possible otherwise.

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

## Design

One convention, reused across all three: a Makefile variable `LOCAL_N`
(default `5`, override with `make sanity_check LOCAL_N=10`), and a new
`.PHONY` target `sanity_check` per experiment `Makefile` that runs the
full pipeline — replicate generation → postprocessing → aggregation →
paper-output — locally, writing every output under a distinct
"local"/"local_sanity" name so nothing it touches can ever collide with,
skip-because-of, or overwrite real production output. Plus a convenience
`sanity_check` target in the top-level `Makefile` that calls all three.
`LOCAL_N` only affects the new `sanity_check` target; all existing default
targets (`all`, `bootstrap_mcmc`, etc.) and their default output are
completely untouched.

Every new script option below defaults to the exact value that's
currently hardcoded, so existing invocations (`./postprocess_for_paper.R`
with no args) behave identically to today.

### 1. mrp

**`src/mrp/Makefile`** — today, bootstrap/subsample replicates only exist
via `sbatch run_mcmc_slurm.sh`. Add:

- Two new pattern rules calling the **existing, unmodified** `run_mcmc.R`
  directly (no `sbatch`) for a given seed:
  `bootstrap_data/mrp_bootstrap_seed%_samples5000.Rdata` and
  `bootstrap_data/mrp_subsample_seed%_samples5000.Rdata` (adds
  `--subsample`) — mirroring the two lines already in `run_mcmc_slurm.sh`.
- `LOCAL_N ?= 5`, `LOCAL_SEEDS := $(shell seq 1 $(LOCAL_N))`, and
  `LOCAL_RAW`/`LOCAL_POSTPROCESSED` variables listing the `2*LOCAL_N`
  explicit filenames for seeds `1..LOCAL_N`. The **existing** generic
  pattern rule `$(SRC_DIR)/%_mrp_postprocessed.Rdata: $(SRC_DIR)/%.Rdata …`
  already postprocesses any raw MCMC file locally with no changes needed.
- `sanity_check`, depending on `$(LOCAL_POSTPROCESSED)` plus the existing
  `$(ORIGINAL_PP)`/`$(ORIGINAL_LMER)`/`$(CUSTOM_MAP)` targets (Stage-1
  single-run artifacts, unaffected by `LOCAL_N`, reused as-is — the
  combined dataframe needs an `"original"` row too, since
  `postprocess_for_paper.R` filters `result_df` by
  `method=="original"`). Recipe:
  ```make
  cd $(SRC_DIR) && ./compile_postprocessing.R \
      --base_dir=$(SRC_DIR) \
      --file_pattern="$(LOCAL_POSTPROCESSED) $(ORIGINAL_PP)" \
      --description=mrp_local \
      --output_filename=mrp_combined_mrp_local.Rdata
  cd $(SRC_DIR) && ./postprocess_for_paper.R \
      --combined_file=bootstrap_data/mrp_combined_mrp_local.Rdata \
      --output_filename=mrp_postprocessed_local.Rdata
  ```

**`src/mrp/compile_postprocessing.R`** — two small, additive changes:
1. `Sys.glob(opt$file_pattern)` only accepts a single shell-glob string,
   but `LOCAL_POSTPROCESSED` expands to several explicit, space-separated
   paths. `Sys.glob()` is vectorized (each element of a character vector
   is globbed separately, and a no-wildcard pattern just matches itself),
   so: `Sys.glob(strsplit(opt$file_pattern, "\\s+")[[1]])`. Fully
   backward compatible with the existing single-pattern production usage.
2. Add `--output_filename` (default `""`, meaning "keep today's
   auto-timestamped name") so the sanity-check target can use a fixed,
   predictable filename instead of a timestamp it can't know in advance
   from the Makefile.

**`src/mrp/postprocess_for_paper.R`** — add an `optparse` block with
`--combined_file` (default = today's hardcoded
`bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata`) and
`--output_filename` (default `mrp_postprocessed.Rdata`), replacing the
two corresponding hardcoded lines. Everything downstream (variance
estimates, plots-data, `compiled_df`, etc.) already operates on whatever
rows are present, so it naturally scales down to `LOCAL_N` bootstrap +
`LOCAL_N` subsample rows with no other change — results will just be much
noisier, which is expected and fine for a smoke test.

### 2. rstanarm

**`src/rstanarm/Makefile`**:

- `NUM_BOOTS ?= 200`, threaded into the existing `.stamp_boot_%` recipe
  as `--default_num_boots=$(NUM_BOOTS)` (the flag already exists in
  `run_bootstrapped_mcmc_rstanarm.R`; the Makefile just never passed it).
  No-op for existing behavior at the default of 200.
- Two `.PHONY` aliases, `base_mcmc: $(BASE_STAMPS)` and
  `boot_mcmc: $(BOOT_STAMPS)` (there's currently no way to target "just
  the stamps" from the CLI without listing full paths).
- `LOCAL_N ?= 5` and:
  ```make
  sanity_check:
  	mkdir -p $(SRC_DIR)/cluster/output_local
  	$(MAKE) OUTPUT_DIR=$(SRC_DIR)/cluster/output_local \
  	        DESC=local_sanity \
  	        NUM_MODELS=$(LOCAL_N) \
  	        NUM_BOOTS=$(LOCAL_N) \
  	        boot_mcmc
  	Rscript $(SRC_DIR)/load_rstanarm_results.R \
  	    --output_dir=$(SRC_DIR)/cluster/output_local \
  	    --file_suffix=local_sanity
  	Rscript $(SRC_DIR)/postprocess_for_paper.R \
  	    --compiled_file=$(SRC_DIR)/cluster/output_local/compiled_results_1116.Rdata \
  	    --output_filename=arm_results_postprocessed_local.Rdata
  ```
  Because `OUTPUT_DIR`, `DESC`, `NUM_MODELS`, `NUM_BOOTS`, `BASE_STAMPS`,
  `BOOT_STAMPS` are ordinary Makefile variables (no `override` directive
  anywhere), the recursive `$(MAKE)` re-evaluates them fresh — `boot_mcmc`
  builds `LOCAL_N` models × `LOCAL_N` bootstraps, entirely under a
  separate `cluster/output_local/` directory. This can never
  read/skip/overwrite the real `cluster/output/*_0924_cluster.Rdata`
  files. `NUM_MODELS` reuses `LOCAL_N` (rather than defaulting to the
  full 65) purely for speed — each ARM model is a distinct Stan program
  that must compile, so running all 65 even with few bootstraps would
  still be slow. `postprocess_for_paper.R` already filters out
  `model_name %in% c("test", "test_rstanarm")` (models 1-2) and specific
  known-bad indices (7, 12/13, 65), so with the default `LOCAL_N=5` there
  are 3 real models (indices 3-5) left to produce non-empty output; a
  very small `LOCAL_N` (1-2) could produce an empty result after
  filtering — worth a one-line README caveat rather than special-casing
  in code.

**`src/rstanarm/load_rstanarm_results.R`** — add an `optparse` block
(the script currently has zero CLI options) with `--output_dir` (default
= today's hardcoded `cluster/output` path) and `--file_suffix` (default
`0924_cluster`), replacing the corresponding hardcoded assignments. The
existing `for (i in 1:length(model_list))` loops already call
`LoadModelResults(..., load_lme4=FALSE)`, which uses a `SafeLoad()` helper
that sets `all_found <- FALSE` and returns `NULL` for any missing file
rather than erroring (`libs/rstanarmijlib/.../postprocessing_lib.R:26-34`)
— confirmed by reading that helper — so models beyond `LOCAL_N` (whose
files don't exist under `output_local/`) are already silently skipped
with no code change needed there.

**`src/rstanarm/postprocess_for_paper.R`** — add an `optparse` block with
`--compiled_file` (default = today's hardcoded
`cluster/output/compiled_results_1116.Rdata`) and `--output_filename`
(default `arm_results_postprocessed.Rdata`), replacing the corresponding
hardcoded `load()` and `save()` lines.

### 3. singular_simulations

**`src/singular_simulations/Makefile`** — `run_mcmc.R` and
`combine_simulations.R` **already** both implement an identical `--prefix`
option folded into their internal `desc` string; the Makefile just never
exposes or threads it. Add:

- `LOCAL_N ?= 5` and `PREFIX ?=` (empty by default, preserving current
  behavior exactly).
- `DESC := $(if $(PREFIX),$(PREFIX)_,)redim$(RE_DIM)_obsperre$(OBS_PER_RE)_seed$(SEED)`
  (was `DESC := redim...`) — matches exactly how `run_mcmc.R`/
  `combine_simulations.R` already build their own `desc` internally, so
  Make's dependency tracking (`BASE_RESULT`, `SIM_FILES`, `SIM_COMBINED`,
  all derived from `$(DESC)`) stays consistent with what the R scripts
  actually write.
- Append `$(if $(PREFIX),--prefix=$(PREFIX))` to the three existing
  `Rscript` invocations (`sim%` pattern rule, `$(BASE_RESULT)` rule,
  `$(SIM_COMBINED)` rule).
- Two `.PHONY` aliases: `sim_combined: $(SIM_COMBINED)` and
  `base_result: $(BASE_RESULT)` (stable names usable from a recursive
  `$(MAKE)` call, since `$(SIM_COMBINED)`/`$(BASE_RESULT)` are only
  resolved after `DESC`/`PREFIX` are known).
- ```make
  sanity_check:
  	$(MAKE) NUM_SIMS=$(LOCAL_N) PREFIX=local_sanity sim_combined base_result
  	Rscript $(SRC_DIR)/postprocess_for_paper.R \
  	    --prefix=local_sanity --seed=$(SEED) --re_dim=$(RE_DIM) --obs_per_re=$(OBS_PER_RE) \
  	    --output_filename=simpler_sim_results_local.Rdata
  ```
  With `PREFIX=local_sanity`, every output filename gets a
  `local_sanity_` prefix, so `combine_simulations.R`'s glob only ever
  matches the freshly-built local files — it cannot pick up any of the
  100 pre-existing real `redim100_obsperre100_seed100` files, since the
  prefix changes `<desc>` itself.

**`src/singular_simulations/postprocess_for_paper.R`** — currently has no
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
LOCAL_N ?= 5
.PHONY: sanity_check
sanity_check:
	$(MAKE) -C $(REPO_ROOT)/src/mrp sanity_check LOCAL_N=$(LOCAL_N)
	$(MAKE) -C $(REPO_ROOT)/src/rstanarm sanity_check LOCAL_N=$(LOCAL_N)
	$(MAKE) -C $(REPO_ROOT)/src/singular_simulations sanity_check LOCAL_N=$(LOCAL_N)
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

1. `cd src/mrp && make sanity_check LOCAL_N=2` — confirm no `sbatch` is
   invoked; check for 4 new raw `.Rdata` files (seeds 1-2, bootstrap +
   subsample) and postprocessed versions in `bootstrap_data/`, one
   `mrp_combined_mrp_local.Rdata`, and one
   `paper/experiment_data/mrp/mrp_postprocessed_local.Rdata`; confirm the
   real `mcmc_files.txt`, `mrp_combined_mrp_20240724_1418.Rdata`, and
   `mrp_postprocessed.Rdata` are untouched (unchanged mtime).
2. `cd src/rstanarm && make sanity_check LOCAL_N=2` — confirm
   `cluster/output_local/` is created with stamps/`.Rdata` files tagged
   `local_sanity`, a `compiled_results_1116.Rdata` inside that same local
   dir, and `paper/experiment_data/arm/arm_results_postprocessed_local.Rdata`;
   open one `*_boot_mcmc_local_sanity.Rdata` and check `num_boots == 2`;
   confirm the 193 existing `cluster/output/*_0924_cluster.Rdata` files
   and `arm_results_postprocessed.Rdata` are untouched (unchanged mtime).
3. `cd src/singular_simulations && make sanity_check LOCAL_N=2` — confirm
   `output/local_sanity_super_simple_simulation_sim{1,2}_results_*.Rdata`,
   a `local_sanity_...base_results_*.Rdata`, a combined
   `local_sanity_...sim_results_*.Rdata`, and
   `paper/experiment_data/simulations/simpler_sim_results_local.Rdata`
   appear; confirm the existing 100 unprefixed sim files and
   `simpler_sim_results.Rdata` are untouched.
4. `make sanity_check` from the repo root — confirm it runs all three
   above with the default `LOCAL_N=5` and completes without any `sbatch`
   call.
5. Re-run `git status` after each of the above to confirm only the new,
   distinctly-named local-sanity files show up as (gitignored) additions
   — no production-named file's mtime or contents changed.
6. Confirm each modified R script still runs identically with **no**
   flags (`./postprocess_for_paper.R`, `./load_rstanarm_results.R`, etc.)
   — i.e. default option values reproduce today's exact hardcoded paths —
   so the full-scale reproduction path in each README is unaffected.
