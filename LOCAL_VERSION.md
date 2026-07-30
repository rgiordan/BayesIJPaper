# Local sanity-check mode for mrp / rstanarm / singular_simulations

**Status:** proposal, concrete steps and verification plan added. Not yet
implemented.

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

The goal is to modify all three experiments so that:

- There is an option `RESAMPLE_N` in each Makefile that controls the
  number of bootstrap replicates and, for mrp, the number of resamples
  (subsamples).
- `RESAMPLE_N` is respected by all the scripts. Command-line arguments are
  added or modified as necessary.
- Hardcoded suffixes are removed. Where an override mechanism is already
  implemented (e.g. singular_simulations' `--prefix`), it's left in place
  with a blank default rather than reworked.
- Each Makefile has a flag `RUN_LOCALLY`. If true, the Makefile uses local
  (`Rscript`) commands. If false, it uses the SLURM (`sbatch`) commands as
  appropriate.
- As much as possible, existing scripts are left as-is — ideally only
  their command-line arguments change, not their internal logic.

It is acceptable to overwrite existing files; there is no need to maintain
a separate set of "sanity check" output. This is intended to be run in a
clean checkout of the repository when doing a sanity check.

## Old findings

Key findings from investigation (see "Concrete implementation" below for
how these interact with the final design — a couple of these hazards no
longer apply now that overwriting production output is accepted):

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
  sim replicates. Running the pipeline with `RUN_LOCALLY=true` and a
  small `RESAMPLE_N` **will overwrite these** — that's expected and
  accepted per the "clean repo" assumption above, not a hazard to design
  around.
- Every script in this repo already uses `optparse` for its CLI, except
  the four files that need new options for this feature
  (`rstanarm/load_rstanarm_results.R`, both `postprocess_for_paper.R`
  scripts for rstanarm/singular_simulations, and mrp's
  `postprocess_for_paper.R`), so adding `optparse` blocks there is
  idiomatic, not a new pattern.
- mrp's `run_mcmc_slurm.sh` is `#SBATCH -a 0-100` — **101 array tasks,
  indices 0 through 100** (not 1 through 101). Each task runs two
  `run_mcmc.R` invocations with the same seed: one plain (bootstrap), one
  with `--subsample`. This is important for exactly reproducing today's
  202-file production set from `RESAMPLE_N` (see mrp section).
- rstanarm's `Makefile` never calls `sbatch`; its
  `cluster/submit_slurm_scripts_rstanarm.py` does, and already has a
  `--num_sims` argparse option (default 200) that is **currently dead
  code** — never threaded into the R command it constructs. This needs a
  one-line fix to actually respect a replicate count.
- singular_simulations' `run_mcmc.R`/`combine_simulations.R` already have
  `--prefix` (default `""`); its `postprocess_for_paper.R` has **no** CLI
  args at all and hardcodes `seed_val`/`re_dim`/`obs_per_re <- 100` and
  always writes to `simpler_sim_results.Rdata` regardless of prefix/seed —
  flagged as a hazard in its own README (`README.md:122-125`). Its
  `run_sims_mcmc.sh` SLURM script only covers `--sim` replicates (no
  `--base` equivalent), and hardcodes `#SBATCH -a 1-100` with no
  seed/re_dim/obs_per_re/prefix passthrough — `sbatch --array=` can
  override the array bound without editing the script.

## Concrete implementation

One convention, reused across all three Makefiles:

- **`RESAMPLE_N`** (`?=`, defaulting to each experiment's current
  production count: mrp 101, rstanarm 200, singular_simulations 100)
  controls the number of replicates of the expensive per-replicate stage.
- **`RUN_LOCALLY`** (`?=`, `true`/`false`) selects local (`Rscript`) vs.
  SLURM (`sbatch`) execution for that same stage, independent of
  `RESAMPLE_N`. Each experiment's *current* behavior becomes its default,
  so a bare `make all`/`make bootstrap_mcmc` with no flags behaves
  **exactly** as it does today: `RUN_LOCALLY ?= false` for mrp (only
  SLURM exists today), `RUN_LOCALLY ?= true` for rstanarm and
  singular_simulations (only local exists today).
- A **`sanity_check`** target per experiment forces `RUN_LOCALLY=true` and
  gives `RESAMPLE_N` its own small default (5) *unless* the caller already
  set it on the command line, using GNU Make's `$(origin)` function:
  ```make
  sanity_check:
  	$(MAKE) RUN_LOCALLY=true \
  	    $(if $(filter command line,$(origin RESAMPLE_N)),,RESAMPLE_N=5) all
  ```
  `make sanity_check` alone → `RESAMPLE_N=5`; `make sanity_check
  RESAMPLE_N=10` → `RESAMPLE_N=10`. **Verify this `$(origin)` idiom works
  as expected early in implementation** — it's standard GNU Make, but
  worth a quick smoke test before relying on it in all three Makefiles.
- No distinct output paths/filenames — `sanity_check` writes to the same
  default locations as full production runs (per "acceptable to
  overwrite").

### 1. mrp

**`src/mrp/Makefile`** — today, bootstrap/subsample replicates only exist
via `sbatch run_mcmc_slurm.sh`; add a local alternative and unify the
production and reduced-`RESAMPLE_N` paths through one mechanism:

- `RESAMPLE_N ?= 101`, `RUN_LOCALLY ?= false`.
- New pattern rules calling the **existing, unmodified** `run_mcmc.R`
  directly (no `sbatch`), mirroring `run_mcmc_slurm.sh`'s two lines:
  ```make
  bootstrap_data/mrp_bootstrap_seed%_samples5000.Rdata:
  	cd $(SRC_DIR) && ./run_mcmc.R --seed=$* --base_dir=$(SRC_DIR)

  bootstrap_data/mrp_subsample_seed%_samples5000.Rdata:
  	cd $(SRC_DIR) && ./run_mcmc.R --seed=$* --base_dir=$(SRC_DIR) --subsample
  ```
- **Seeds must start at 0, not 1**, to exactly match what
  `run_mcmc_slurm.sh`'s `#SBATCH -a 0-100` produces today:
  `LOCAL_SEEDS := $(shell seq 0 $$(($(RESAMPLE_N)-1)))`. At the default
  `RESAMPLE_N=101` this reproduces seeds 0–100 — identical to today's
  production seed set.
- Replace the Makefile's `MCMC_FILES := $(shell cat $(SRC_DIR)/mcmc_files.txt)`
  with a `RESAMPLE_N`-derived list — this is deliberately a
  **single-line swap**, since everything downstream (`POSTPROCESSED`,
  `bootstrap_postprocess`, the `$(COMBINED)` prerequisite list) is
  already parameterized off `MCMC_FILES` and needs no further edits:
  ```make
  RAW_BOOT    := $(foreach s,$(LOCAL_SEEDS),bootstrap_data/mrp_bootstrap_seed$(s)_samples5000.Rdata)
  RAW_SUB     := $(foreach s,$(LOCAL_SEEDS),bootstrap_data/mrp_subsample_seed$(s)_samples5000.Rdata)
  MCMC_FILES  := $(RAW_BOOT) $(RAW_SUB)     # was: $(shell cat $(SRC_DIR)/mcmc_files.txt)
  ```
  **Decision (settled):** `mcmc_files.txt` is removed from the pipeline
  entirely — the Makefile no longer reads it anywhere, for either
  production or reduced-`RESAMPLE_N` runs. At the default
  `RESAMPLE_N=101` this reproduces the identical 202-file set production
  uses today (verified via the seed-0-indexing fix above), so this is
  behavior-preserving at the default. The committed `mcmc_files.txt` file
  itself becomes unreferenced anywhere in the Makefile or scripts and can
  be deleted from the repo. (`postprocess_mcmc_slurm.sh` is **not**
  legacy — see the new Stage 3 bullet below; it's actively modified and
  used.)
- `bootstrap_mcmc` gains a `RUN_LOCALLY` toggle. The SLURM branch
  parameterizes the array bound (sbatch's `--array` CLI flag overrides
  the script's `#SBATCH -a 0-100` pragma, so `run_mcmc_slurm.sh` itself
  needs no edits) instead of always requesting 101:
  ```make
  ifeq ($(RUN_LOCALLY),true)
  bootstrap_mcmc: $(SRC_DIR)/$(DATASET) $(addprefix $(SRC_DIR)/,$(MCMC_FILES))
  else
  bootstrap_mcmc: $(SRC_DIR)/$(DATASET)
  	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/run_mcmc_slurm.sh
  endif
  ```
  As today, the SLURM branch is fire-and-forget (submits and returns; the
  user still waits for the array job and re-invokes the next stage
  manually) — `RUN_LOCALLY=false` doesn't change that async behavior,
  just parameterizes the count.
- **Stage 3 (per-file postprocessing) also gets a `RUN_LOCALLY` toggle —
  new requirement, since this stage is fairly time-intensive and
  shouldn't be forced local.** Today the existing generic pattern rule
  (`Makefile:63-66`, `$(SRC_DIR)/%_mrp_postprocessed.Rdata: $(SRC_DIR)/%.Rdata …`)
  runs unconditionally via `Rscript`; make it conditional so
  `RUN_LOCALLY=false` goes through SLURM instead, mirroring
  `postprocess_mcmc_slurm.sh` (currently a manual, non-Makefile-wired
  script):
  ```make
  ifeq ($(RUN_LOCALLY),true)
  $(SRC_DIR)/%_mrp_postprocessed.Rdata: $(SRC_DIR)/%.Rdata $(SRC_DIR)/$(DATASET)
  	cd $(SRC_DIR) && ./postprocess_mcmc.R --base_dir=$(SRC_DIR) --mcmc_file=$*.Rdata

  bootstrap_postprocess: $(addprefix $(SRC_DIR)/,$(POSTPROCESSED))
  else
  bootstrap_postprocess: $(SRC_DIR)/$(DATASET)
  	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/postprocess_mcmc_slurm.sh
  endif
  ```
  The `else` branch deliberately has **no prerequisite on the raw MCMC
  files themselves** — like `bootstrap_mcmc`'s SLURM branch, this is
  fire-and-forget, and Make can't know whether the (also asynchronous)
  `bootstrap_mcmc` SLURM array has finished producing them. This matches
  today's already-manual, multi-stage SLURM workflow (README already
  tells the user to wait between stages) rather than inventing new
  blocking behavior. `$(SRC_DIR)/$(COMBINED)`'s prerequisites stay the
  actual `$(POSTPROCESSED)` files unconditionally (`Makefile:48-49`) —
  Make only cares whether they exist by the time it's invoked, not how
  they were created, so once both SLURM arrays finish and the user
  re-runs `make`, the combine step proceeds normally regardless of
  `RUN_LOCALLY`. If invoked too early (before the SLURM postprocessing
  array has actually produced the files), Make fails with a clear "no
  rule to make target" error rather than silently falling back to local
  computation — that's intentional, since the generic pattern rule above
  is only defined under `RUN_LOCALLY=true`.

**`src/mrp/postprocess_mcmc_slurm.sh`** — rewrite per the user's request
to use "a manually specified slurm array rather than a text file of mcmc
files to process," mirroring `run_mcmc_slurm.sh`'s own indexing
convention (array index == seed, 0-based) instead of doing an `awk`
lookup into `mcmc_files.txt`:
```bash
#!/bin/bash
## Array size (RESAMPLE_N seeds, 0-indexed) is set by the caller, e.g.
## sbatch --array=0-$((RESAMPLE_N-1)) postprocess_mcmc_slurm.sh
## -- matches run_mcmc_slurm.sh's own seed indexing; no mcmc_files.txt
## lookup needed.
#SBATCH -a 0-100
#SBATCH --output=slurm_logs/postprocess_%A_%a_%j.out
#SBATCH --error=slurm_logs/postprocess_%A_%a_%j.err

BASE_DIR=$(git rev-parse --show-toplevel)/src/mrp

./postprocess_mcmc.R --base_dir=${BASE_DIR} \
    --mcmc_file=bootstrap_data/mrp_bootstrap_seed${SLURM_ARRAY_TASK_ID}_samples5000.Rdata
./postprocess_mcmc.R --base_dir=${BASE_DIR} \
    --mcmc_file=bootstrap_data/mrp_subsample_seed${SLURM_ARRAY_TASK_ID}_samples5000.Rdata
```
This drops the `CONFIG_FILE=mcmc_files.txt`/`awk -v ID=${SLURM_ARRAY_TASK_ID} 'NR==ID'`
lookup (current lines 14-16) and the header comment instructing the user
to regenerate `mcmc_files.txt` via `ls` (current lines 1-4), replacing
both with direct filename construction from `$SLURM_ARRAY_TASK_ID` —
exactly parallel to how `run_mcmc_slurm.sh` already works. Each array
task now postprocesses both files (bootstrap + subsample) for its own
seed, same two-calls-per-task structure as `run_mcmc_slurm.sh`.
- `sanity_check` per the shared pattern above (forces `RUN_LOCALLY=true`,
  so both Stage 2 and Stage 3 run locally for a sanity check).

**`src/mrp/compile_postprocessing.R`** — two changes:
1. **Change `--file_pattern` from a glob to a comma-separated list of
   exact files**, since the Makefile now always knows the exact file set
   (no more filesystem discovery needed): replace
   `Sys.glob(opt$file_pattern)` with `strsplit(opt$file_pattern, ",")[[1]]`.
   Makefile builds the comma list from `$(POSTPROCESSED)` (now
   `RESAMPLE_N`-driven) plus `$(ORIGINAL_PP)`:
   ```make
   FILE_LIST := $(shell echo $(addprefix $(SRC_DIR)/,$(POSTPROCESSED)) $(SRC_DIR)/$(ORIGINAL_PP) | tr ' ' ',')
   ```
2. Add `--output_filename` (default `""`, meaning "keep today's
   auto-timestamped name" — the R script's internal `date_stamp`/
   `sprintf(...)` logic is otherwise untouched). The Makefile's
   `$(COMBINED)` recipe **always passes `--output_filename=$(COMBINED)`
   explicitly**, so the auto-timestamp default is only ever exercised by
   manual, non-Makefile invocations (preserving that behavior exactly).
   `COMBINED` itself changes from the frozen
   `bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata` to a fixed,
   non-timestamped name, e.g. `bootstrap_data/mrp_combined_mrp.Rdata` —
   this is required regardless of the above, since a Make target's name
   must be knowable in advance, and it directly fixes the hazard the
   Makefile and README already flag in comments (`Makefile:17-20`,
   `README.md:147-151`: "if you regenerate this file, update the
   hardcoded path in `postprocess_for_paper.R`").

**`src/mrp/postprocess_for_paper.R`** — add an `optparse` block:
`--combined_file` (default = today's hardcoded
`bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata`, even though in
practice the Makefile always overrides it with `$(COMBINED)`),
`--output_filename` (default `mrp_postprocessed.Rdata`), and `--seed`
(default `134432`, matching the Makefile's `SEED`) — used to build the
other four hardcoded paths (`original`/`originallmer`/`custom_map`,
currently seed-134432-hardcoded independently of the Makefile) so there's
one source of truth. Replaces the five hardcoded lines. Everything
downstream (variance estimates, plots-data, `compiled_df`) already
operates on whatever rows are present, so it naturally scales with
`RESAMPLE_N` — results are just noisier, expected for a smoke test.

### 2. rstanarm

**`src/rstanarm/Makefile`**:
- `RESAMPLE_N ?= 200`, `RUN_LOCALLY ?= true`. `NUM_MODELS := 65` stays
  **untouched** — a sanity check still fits all 65 models, just with
  fewer bootstraps each (model count and bootstrap count are independent
  axes here, unlike mrp/singular_simulations).
- `.stamp_boot_%` recipe gets `--default_num_boots=$(RESAMPLE_N)` added
  to its existing `run_bootstrapped_mcmc_rstanarm.R` call (no-op at the
  default of 200, since that already matches the script's own default).
- `.PHONY` aliases `base_mcmc: $(BASE_STAMPS)` (unconditional — no SLURM
  variant needed, base fits aren't replicate-count-scaled) and a
  conditional `boot_mcmc`:
  ```make
  ifeq ($(RUN_LOCALLY),true)
  boot_mcmc: $(BOOT_STAMPS)
  else
  boot_mcmc: base_mcmc
  	python3 $(SRC_DIR)/cluster/submit_slurm_scripts_rstanarm.py \
  	    --base_dir=$(REPO_ROOT) --analysis=bootstrap \
  	    --description=$(DESC) --num_boots=$(RESAMPLE_N) --force
  endif
  ```
  Fire-and-forget, same as mrp's SLURM branch — submits and returns.
- `sanity_check` per the shared pattern above.

**`src/rstanarm/cluster/submit_slurm_scripts_rstanarm.py`** — minimal,
CLI-only fix: rename the currently-dead `--num_sims` argparse option
(default 200, never used) to `--num_boots`, and thread it into the
constructed bootstrap command as `--default_num_boots={num_boots}` when
`--analysis=bootstrap`. This is the one code change needed to make the
existing SLURM submission script actually respect a replicate count —
everything else about the script is untouched.

**`src/rstanarm/load_rstanarm_results.R`** — add an `optparse` block (zero
CLI options today): `--output_dir` (default = today's hardcoded
`cluster/output`), `--file_suffix` (default `0924_cluster`),
`--output_filename` (default `compiled_results_1116.Rdata`), replacing
the hardcoded `file_suffix <- "0924_cluster"` and `file_date <- "1116"` /
derived `output_filename`. Makefile's `$(COMPILED)` recipe passes
`--output_dir=$(OUTPUT_DIR) --file_suffix=$(DESC)
--output_filename=$(notdir $(COMPILED))` explicitly — collapsing what are
today three independently-hardcoded copies (Makefile comment
`Makefile:7-9` already flags "must match the file_suffix variable
hardcoded in that script") down to the Makefile's `DESC`/`COMPILED`
variables as the single source of truth. The existing `SafeLoad()` helper
already skips missing files rather than erroring
(`libs/rstanarmijlib/.../postprocessing_lib.R:26-34`) — no change needed
there, so fewer bootstraps or (if the user overrides `NUM_MODELS`) fewer
models are already handled gracefully.

**`src/rstanarm/postprocess_for_paper.R`** — add an `optparse` block:
`--compiled_file` (default = today's hardcoded
`cluster/output/compiled_results_1116.Rdata`) and `--output_filename`
(default `arm_results_postprocessed.Rdata`), replacing the corresponding
hardcoded `load()`/`save()` lines. Makefile passes
`--compiled_file=$(COMPILED)` explicitly.

### 3. singular_simulations

**`src/singular_simulations/Makefile`**:
- Rename `NUM_SIMS` → `RESAMPLE_N` (same role, same default 100, `?=`).
  `RUN_LOCALLY ?= true`. `PREFIX ?=` (kept, blank default, unchanged
  existing convention — not removed, not reworked).
- Thread `--prefix=$(PREFIX)` (conditionally, only if non-empty) into the
  three existing `Rscript` invocations (`sim%` pattern rule,
  `$(BASE_RESULT)` rule, `$(SIM_COMBINED)` rule) — the Makefile
  currently builds `DESC` itself without ever exposing `--prefix`, even
  though `run_mcmc.R`/`combine_simulations.R` already support it.
- SLURM toggle applies only to the sim-replicate generation stage (mirrors
  `run_sims_mcmc.sh`'s existing scope — it only ever covered `--sim`
  jobs, never `--base`, so `$(BASE_RESULT)` stays local in both modes):
  ```make
  ifeq ($(RUN_LOCALLY),true)
  sim_files: $(SIM_FILES)
  else
  sim_files:
  	sbatch --array=1-$(RESAMPLE_N) $(SRC_DIR)/run_sims_mcmc.sh
  endif
  $(SIM_COMBINED): sim_files $(BASE_RESULT)
  	... (existing combine_simulations.R recipe, now with --prefix=$(PREFIX) threaded)
  ```
  `run_sims_mcmc.sh` itself is **left completely unedited** — `sbatch
  --array=` overrides its `#SBATCH -a 1-100` pragma without touching the
  file, consistent with "leave scripts as-is." **Known limitation** (not
  a new regression — matches today's status quo): `run_sims_mcmc.sh`
  doesn't read `SEED`/`RE_DIM`/`OBS_PER_RE`/`PREFIX`, so if those are
  overridden from their Makefile defaults, the `RUN_LOCALLY=false` path
  won't pick up the override the way the local path does. Worth a
  one-line README caveat rather than a script change, unless that should
  be closed too.
- `sanity_check` per the shared pattern above.

**`src/singular_simulations/postprocess_for_paper.R`** — currently has no
CLI options at all. Add `optparse` with `--seed`/`--re_dim`/`--obs_per_re`
(defaults 100/100/100, matching today's hardcoded values), `--prefix`
(default `""`, mirroring `run_mcmc.R`/`combine_simulations.R`'s existing
convention exactly — not a new mechanism, just extended to the third
script for consistency), and `--output_filename` (default
`simpler_sim_results.Rdata`). Replace the hardcoded
`seed_val`/`re_dim`/`obs_per_re` assignments and `desc` construction (add
the same `if (nchar(prefix) > 0) desc <- paste0(prefix, "_", desc)` logic
already used in the sibling scripts) and the final `save_filename` line.
Makefile's `$(PAPER_OUTPUT)` recipe passes
`--seed=$(SEED) --re_dim=$(RE_DIM) --obs_per_re=$(OBS_PER_RE)
--prefix=$(PREFIX)` explicitly — resolving the exact hazard the script's
own README already flags (`README.md:122-125`).

### 4. Top-level `Makefile`

```make
RESAMPLE_N ?= 5
.PHONY: sanity_check
sanity_check:
	$(MAKE) -C $(REPO_ROOT)/src/mrp sanity_check RESAMPLE_N=$(RESAMPLE_N)
	$(MAKE) -C $(REPO_ROOT)/src/rstanarm sanity_check RESAMPLE_N=$(RESAMPLE_N)
	$(MAKE) -C $(REPO_ROOT)/src/singular_simulations sanity_check RESAMPLE_N=$(RESAMPLE_N)
```
Each sub-Makefile's own `sanity_check` already forces `RUN_LOCALLY=true`
internally, so the top-level target doesn't need to pass it through.

### Documentation

Update each of `src/mrp/README.md`, `src/rstanarm/README.md`,
`src/singular_simulations/README.md`, and the top-level `README.md`:
- A short "Local sanity check" section: `make sanity_check
  [RESAMPLE_N=N]`, what it produces, and an explicit note that it
  **overwrites** whatever real production output currently exists in
  those default paths — intended for a clean checkout.
- A short note on the new `RUN_LOCALLY=true|false` toggle on the main
  pipeline targets, replacing/updating mrp's sbatch-only instructions and
  rstanarm's `submit_slurm_scripts_rstanarm.py`-only instructions
  (`README.md:26-30`) to also mention the Makefile-driven path.
- Remove mrp's README instruction to manually edit
  `postprocess_for_paper.R`'s hardcoded combined-file path
  (`README.md:147-151`) — no longer applicable once `COMBINED` is a fixed
  name always passed explicitly via `--output_filename`.
- Remove mrp's README instructions to regenerate `mcmc_files.txt`
  (`README.md:108`) and the `#SBATCH -a 1-202` mention
  (`README.md:119-121`) — both stages now take their array bound from
  `RESAMPLE_N` via `sbatch --array=`, and `mcmc_files.txt` is no longer
  read anywhere.

## Explicitly out of scope

- Reducing per-replicate MCMC iteration/warmup/chain counts
  (`--num_samples`, `--num_draws`, etc.) — the request is about replicate
  *count*, not per-fit cost. A 5-replicate mrp sanity check is still ~10
  real ~25-minute fits unless the user also passes
  `--num_samples`/`--num_warmup_samples` manually.
- SLURM support for singular_simulations' `--base` fit (no existing SLURM
  path for it).
- Making the SLURM branches block until jobs complete (`sbatch --wait` or
  similar) — all three stay fire-and-forget, matching mrp's existing
  behavior.
- Threading `SEED`/`RE_DIM`/`OBS_PER_RE`/`PREFIX` into
  singular_simulations' `run_sims_mcmc.sh` (noted as a known limitation
  above, not fixed, to keep that script untouched).

## Verification plan

1. **mrp, local, small N:**
   `cd src/mrp && make bootstrap_mcmc RUN_LOCALLY=true RESAMPLE_N=2` —
   confirm no `sbatch` call; confirm exactly 4 new raw `.Rdata` files
   appear (seeds 0-1, bootstrap + subsample), built directly via
   `Rscript`.
2. **mrp, local, sanity_check end-to-end:**
   `cd src/mrp && make sanity_check` (no args) — confirm `RESAMPLE_N`
   resolves to 5, `RUN_LOCALLY=true`, no `sbatch` call, and it runs fully
   through to `bootstrap_data/mrp_combined_mrp.Rdata` and
   `paper/experiment_data/mrp/mrp_postprocessed.Rdata`. Then
   `make sanity_check RESAMPLE_N=10` — confirm the override actually takes
   (10 seeds' worth of files, not 5) — this is the specific behavior the
   `$(origin)` idiom needs to get right.
3. **mrp, SLURM, count parameterization (Stage 2):**
   `cd src/mrp && make bootstrap_mcmc RUN_LOCALLY=false RESAMPLE_N=2`
   (inspect the constructed command rather than actually submitting, if no
   cluster access) — confirm it calls
   `sbatch --array=0-1 run_mcmc_slurm.sh`.
4. **mrp, local, Stage 3 postprocessing:**
   `cd src/mrp && make bootstrap_postprocess RUN_LOCALLY=true RESAMPLE_N=2`
   (after step 1's raw files exist) — confirm no `sbatch` call and that
   the 4 postprocessed files are built directly via `Rscript`.
5. **mrp, SLURM, Stage 3 postprocessing:**
   `cd src/mrp && make bootstrap_postprocess RUN_LOCALLY=false RESAMPLE_N=2`
   (inspect constructed command) — confirm it calls
   `sbatch --array=0-1 postprocess_mcmc_slurm.sh`, and confirm the
   rewritten script derives both filenames from `$SLURM_ARRAY_TASK_ID`
   directly with no reference to `mcmc_files.txt`/`awk` anywhere in it.
6. **mrp, Stage 3 gating is real, not just cosmetic:**
   With `RUN_LOCALLY=false` and none of the postprocessed files present
   yet, run `make all RESAMPLE_N=2` (or `$(COMBINED)` directly) — confirm
   it fails with a "no rule to make target" error (expected, per the
   design above) rather than silently postprocessing locally. Then,
   simulating the SLURM array having completed (e.g. by first running the
   `RUN_LOCALLY=true` postprocessing step to produce the same files),
   re-run `make all` and confirm it now proceeds to build `$(COMBINED)`
   and the paper output.
7. **mrp, `mcmc_files.txt` fully decoupled:**
   `grep -rn "mcmc_files.txt" src/mrp` after the change — confirm no
   remaining references in the Makefile, `postprocess_mcmc_slurm.sh`, or
   README; confirm the pipeline runs end-to-end with the file deleted.
8. **mrp, production path unaffected at the default:**
   `cd src/mrp && make all` with no flags — confirm the resulting file set
   (202 raw files, `mrp_combined_mrp.Rdata`, `mrp_postprocessed.Rdata`)
   and its content is unchanged from a run against the current
   `mcmc_files.txt`-based Makefile (i.e., confirm the seed-0-to-100 fix
   above actually reproduces today's exact 202-file set before relying on
   it for real).
9. **rstanarm, local:**
   `cd src/rstanarm && make boot_mcmc RUN_LOCALLY=true RESAMPLE_N=2` —
   open one resulting `*_boot_mcmc_*.Rdata` and check `num_boots == 2`;
   confirm all 65 `.stamp_base_*`/relevant `.stamp_boot_*` targets are
   still attempted (i.e. `NUM_MODELS` is untouched by `RESAMPLE_N`).
10. **rstanarm, SLURM:**
    `cd src/rstanarm && make boot_mcmc RUN_LOCALLY=false RESAMPLE_N=2`
    (inspect constructed command) — confirm
    `submit_slurm_scripts_rstanarm.py --num_boots=2` is invoked and that
    value actually reaches `--default_num_boots=2` in the per-model R
    command it constructs (this is the fix to the previously-dead
    `--num_sims` option — test it directly, don't just trust the diff).
11. **rstanarm, sanity_check:**
    `cd src/rstanarm && make sanity_check` — confirm
    `arm_results_postprocessed.Rdata` is produced/overwritten using all 65
    models with `RESAMPLE_N=5` bootstraps each.
12. **singular_simulations, local:**
    `cd src/singular_simulations && make sanity_check RESAMPLE_N=2` —
    confirm 2 sim files, `RUN_LOCALLY=true`, no `sbatch` call, and
    `paper/experiment_data/simulations/simpler_sim_results.Rdata` updates.
13. **singular_simulations, SLURM:**
    `cd src/singular_simulations && make sim_files RUN_LOCALLY=false RESAMPLE_N=2`
    (inspect constructed command) — confirm
    `sbatch --array=1-2 run_sims_mcmc.sh` with no edits to that script.
14. **Top-level:**
    `make sanity_check` from the repo root with no args — confirm it runs
    all three sub-experiments with `RESAMPLE_N=5`, `RUN_LOCALLY=true`, and
    no `sbatch` calls anywhere.
15. **No-args backward compatibility:**
    Confirm every modified R script still runs identically with **no**
    flags (`./postprocess_for_paper.R`, `./load_rstanarm_results.R`,
    `./compile_postprocessing.R`, etc.) — i.e. default option values
    reproduce today's exact hardcoded paths/behavior, so the full-scale
    reproduction path documented in each README still works verbatim for
    anyone who runs the scripts by hand instead of through `make`.
16. **`--file_pattern` contract change:**
    Run `compile_postprocessing.R` by hand with a comma-separated
    `--file_pattern` of 2-3 real files and confirm it loads exactly those
    files (not a glob) — and confirm the old glob-style invocation now
    fails loudly (expected, since this is an intentional breaking change
    to that one flag's contract) rather than silently matching nothing.
17. **`git status`/`git diff --stat` after each `sanity_check` run** to
    confirm which production files got overwritten matches expectations
    (accepted per the "clean repo" assumption) and nothing unrelated
    changed.
