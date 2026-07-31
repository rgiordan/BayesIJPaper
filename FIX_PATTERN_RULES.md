# Replace `%`/`$*` pattern rules with explicit per-file rules (mrp, singular_simulations)

**Status:** proposal, not yet implemented.

## Context

Three places in the Makefiles use GNU Make's `%` pattern-rule wildcard to
generate one rule that covers many per-seed/per-replicate files. The
problem: `%` is a purely syntactic wildcard — it matches *any* string that
makes the target's prefix/suffix line up, with no awareness that it's
"supposed to" only ever be a small integer. Concretely, the target pattern
`$(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed%.Rdata` will also match a
filename like `mrp_bootstrap_seed0_samples5000_mrp_postprocessed.Rdata`
(with `%` = `0_samples5000_mrp_postprocessed`) — a real, filed bug, since
that's very much not "seed 0." This is silently dangerous: if Make is ever
asked (directly, or as a prerequisite of some other rule) to build a
target that happens to share this rule's prefix/suffix, it will run
`./run_mcmc.R --seed=0_samples5000_mrp_postprocessed ...` — a nonsensical
invocation — rather than failing with "no rule to make target," which is
what should happen for a filename Make was never meant to produce this way.

The fix: replace each of these `%`-pattern rules with a set of
**explicitly generated, literal-filename rules** — one per known seed/sim
number, containing no wildcard at all — so Make can only ever match an
exact, intended filename.

## Investigation: the three sites (current file content, read directly)

1. **`src/mrp/Makefile:128-132`** (Stage 2, `RUN_LOCALLY=true` branch):
   ```make
   $(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed%.Rdata: $(SRC_DIR)/$(DATASET)
   	cd $(SRC_DIR) && ./run_mcmc.R --seed=$* --base_dir=$(SRC_DIR) --num_samples=$(NUM_MCMC_SAMPLES)

   $(SRC_DIR)/bootstrap_data/mrp_subsample_seed%.Rdata: $(SRC_DIR)/$(DATASET)
   	cd $(SRC_DIR) && ./run_mcmc.R --seed=$* --base_dir=$(SRC_DIR) --subsample --num_samples=$(NUM_MCMC_SAMPLES)
   ```
   This is the rule the user identified — `%` over-matches, as described
   above.
2. **`src/mrp/Makefile:103-106`** (Stage 3, `RUN_LOCALLY=true` branch) —
   the user flagged this as "a similar problem": the generic postprocessing
   rule's *prerequisite* is also an unguarded wildcard:
   ```make
   $(SRC_DIR)/%_mrp_postprocessed.Rdata: $(SRC_DIR)/%.Rdata $(SRC_DIR)/$(DATASET)
   	cd $(SRC_DIR) && ./postprocess_mcmc.R --base_dir=$(SRC_DIR) --mcmc_file=$*.Rdata
   ```
   `$(SRC_DIR)/%.Rdata` matches *any* `.Rdata` file in `bootstrap_data/`,
   not just MCMC output — same class of bug. Note `$(SRC_DIR)/$(ORIGINAL_PP)`
   already has its own fully-explicit rule (`Makefile:93-96`, no `%`
   anywhere) — that one is unaffected and needs no change; only this
   generic rule (which exists to cover the `RESAMPLE_N`-many bootstrap/
   subsample files in `$(POSTPROCESSED)`) needs replacing.
3. **`src/singular_simulations/Makefile:76-85`** (`RUN_LOCALLY=true`
   branch):
   ```make
   $(OUTPUT_DIR)/super_simple_simulation_sim%_results_$(DESC).Rdata:
   	Rscript $(SRC_DIR)/run_mcmc.R \
   	    --sim --sim_num=$* --seed=$(SEED) --re_dim=$(RE_DIM) \
   	    --obs_per_re=$(OBS_PER_RE) --prefix=$(PREFIX) \
   	    --num_draws=$(NUM_MCMC_SAMPLES) --base_dir=$(REPO_ROOT)
   ```
   Same shape of risk: `%` matches any string between
   `super_simple_simulation_sim` and `_results_$(DESC).Rdata`, not just a
   numeric replicate index.

`$(BASE_RESULT)` (singular_simulations) and `$(SRC_DIR)/$(ORIGINAL_PP)`/
Stage 1 rules (mrp) are already fully explicit (single literal target, no
`%`) — out of scope, no change needed.

## Design

GNU Make idiom for "generate N literal rules instead of one pattern
rule": `define`+`foreach`+`eval`. A `define...endef` block is a rule
*template* with a `$(1)`-style parameter; `$(foreach)` iterates the known,
explicit list of seeds/indices; `$(eval $(call ...))` instantiates one
real, non-pattern rule per iteration at Makefile-parse time. The automatic
variable `$*` (pattern stem) is replaced by the template parameter `$(1)`.

**Implementation gotcha to watch for:** recipe lines inside a
`define...endef` template must still start with a literal TAB character
once expanded — easy to lose when editing, since editors don't always
preserve tabs inside heredoc-like blocks. Verify with `cat -A` or
`make -n` after implementing, not just by eye.

### 1. `src/mrp/Makefile` — Stage 2 (lines 128-132)

Replace the two pattern rules with generated per-seed rules, iterating
the already-existing `$(LOCAL_SEEDS)` list (unchanged elsewhere in the
file):
```make
define MRP_BOOTSTRAP_RULE
$(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed$(1).Rdata: $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R --seed=$(1) --base_dir=$(SRC_DIR) --num_samples=$(NUM_MCMC_SAMPLES)
endef
define MRP_SUBSAMPLE_RULE
$(SRC_DIR)/bootstrap_data/mrp_subsample_seed$(1).Rdata: $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R --seed=$(1) --base_dir=$(SRC_DIR) --subsample --num_samples=$(NUM_MCMC_SAMPLES)
endef
$(foreach s,$(LOCAL_SEEDS),$(eval $(call MRP_BOOTSTRAP_RULE,$(s))))
$(foreach s,$(LOCAL_SEEDS),$(eval $(call MRP_SUBSAMPLE_RULE,$(s))))
```
`bootstrap_mcmc: $(SRC_DIR)/$(DATASET) $(addprefix $(SRC_DIR)/,$(MCMC_FILES))`
(and the whole `else` SLURM branch) stay exactly as-is — `$(MCMC_FILES)`
already enumerates the exact same literal filenames these generated rules
now cover one-for-one, so no other line in the file needs to change.

### 2. `src/mrp/Makefile` — Stage 3 (lines 103-106)

Replace the generic postprocessing pattern rule with one generated per
raw MCMC file (bootstrap + subsample only — `$(ORIGINAL_PP)` is untouched,
already explicit):
```make
define MRP_POSTPROCESS_RULE
$(SRC_DIR)/$(1)_mrp_postprocessed.Rdata: $(SRC_DIR)/$(1).Rdata $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./postprocess_mcmc.R --base_dir=$(SRC_DIR) --mcmc_file=$(1).Rdata
endef
$(foreach f,$(patsubst %.Rdata,%,$(MCMC_FILES)),$(eval $(call MRP_POSTPROCESS_RULE,$(f))))
```
`$(patsubst %.Rdata,%,$(MCMC_FILES))` strips the `.Rdata` suffix off each
of the `RAW_BOOT`/`RAW_SUB` entries (e.g.
`bootstrap_data/mrp_bootstrap_seed0`), so `$(1)_mrp_postprocessed.Rdata`/
`$(1).Rdata` reconstruct the exact literal filenames already present in
`$(POSTPROCESSED)`/`$(MCMC_FILES)`. `bootstrap_postprocess:
$(addprefix $(SRC_DIR)/,$(POSTPROCESSED))` and the whole `else` SLURM
branch stay exactly as-is, for the same reason as above.

### 3. `src/singular_simulations/Makefile` — line 76-85

Replace the sim-replicate pattern rule with one generated per replicate
number, iterating the already-existing `$(SIM_NUMS)` list:
```make
define SIM_RULE
$(OUTPUT_DIR)/super_simple_simulation_sim$(1)_results_$(DESC).Rdata:
	Rscript $(SRC_DIR)/run_mcmc.R \
	    --sim --sim_num=$(1) --seed=$(SEED) --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) --prefix=$(PREFIX) \
	    --num_draws=$(NUM_MCMC_SAMPLES) --base_dir=$(REPO_ROOT)
endef
$(foreach n,$(SIM_NUMS),$(eval $(call SIM_RULE,$(n))))
```
`sim_files: $(SIM_FILES)` (and the `else` SLURM branch) stay exactly
as-is, for the same reason as above.

## Note (not proposed, flagging for awareness only)

`src/rstanarm/Makefile`'s `.stamp_base_%`/`.stamp_boot_%` pattern rules
have the same theoretical shape of risk (`%` isn't restricted to a
numeric model index), but the practical exposure is much lower there:
nothing else in that Makefile could plausibly ask Make to build an
oddly-named stamp file the way a stray leftover `.Rdata` file can trigger
mrp's Stage 3 rule. Not included in this plan since the user didn't flag
it — say so if you'd like it converted the same way for consistency.

## Explicitly out of scope

- `$(BASE_RESULT)` (singular_simulations) and mrp's
  Stage 1 (`$(ORIGINAL)`/`$(ORIGINAL_LMER)`/`$(ORIGINAL_MAP)`/
  `$(ORIGINAL_PP)`) rules — already fully explicit, no `%` involved.
- rstanarm's `.stamp_*_%` rules (see note above).
- Any change to `RESAMPLE_N`/`RUN_LOCALLY`/`NUM_MCMC_SAMPLES` semantics —
  this is purely a Make-mechanics correctness fix, not a behavior change
  at any documented default.

## Verification plan (once implemented)

1. **Reproduce the original bug first, to confirm the fix actually closes
   it:** on the current (pre-fix) Makefile, create a decoy file
   `touch src/mrp/bootstrap_data/mrp_bootstrap_seed0_samples5000_mrp_postprocessed.Rdata`
   (or similar), then find a way to make Make request it as a target/
   prerequisite (e.g. temporarily add it to a dependency list, or
   `make -n src/mrp/bootstrap_data/mrp_bootstrap_seed0_samples5000_mrp_postprocessed.Rdata`
   directly against the *old* pattern rule) and confirm it spuriously
   matches `mrp_bootstrap_seed%.Rdata` with a nonsensical `--seed=` value
   — establishing the bug is real before claiming the fix addresses it.
2. After implementing, repeat step 1 against the *new* Makefile and
   confirm Make now reports "no rule to make target" for that same decoy
   filename instead of matching it.
3. `cd src/mrp && make -n bootstrap_mcmc RUN_LOCALLY=true RESAMPLE_N=3` —
   confirm it lists exactly 6 explicit `./run_mcmc.R --seed=0|1|2 ...`
   invocations (3 bootstrap + 3 subsample), byte-identical to what the
   old pattern rule produced for the same `RESAMPLE_N`.
4. `cd src/mrp && make -n sanity_check` — confirm the full chain
   (raw generation → postprocessing → combine → paper output) still
   builds identically to before this change.
5. `cd src/mrp && make -n all RUN_LOCALLY=false RESAMPLE_N=2` — confirm
   it still fails with "no rule to make target" for the *intended* reason
   (Stage 3 gated behind `RUN_LOCALLY=true`), not a new/different error —
   i.e. confirm this pre-existing, already-verified behavior isn't
   collaterally broken by removing the pattern rule.
6. `cd src/singular_simulations && make -n sanity_check` — confirm it
   lists exactly 5 explicit `Rscript run_mcmc.R --sim --sim_num=1|2|3|4|5 ...`
   invocations, byte-identical to what the old pattern rule produced.
7. `grep -c '%' src/mrp/Makefile src/singular_simulations/Makefile` (or a
   more targeted grep for `%` inside a target position) to visually
   confirm no stray pattern-rule wildcards remain in the touched sections.
8. Run `cat -A` (or equivalent) over the newly-added `define...endef`
   recipe lines specifically, to confirm they're real tabs, not spaces —
   per the implementation gotcha noted above.
