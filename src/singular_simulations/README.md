# Singular Simulations Pipeline: Steps to Run postprocess_for_paper.R

## Stage 0: Prerequisites

**Step 1: Simulated data (no download needed)**

Unlike the `mrp` and `rstanarm` analyses, this pipeline needs no external
data. `run_mcmc.R` generates its own datasets on the fly with
`DrawSimulatedData()`: a random-effect grouping variable `z`, a predictor
`x`, and a response `y <- x^2 * rnorm(...) + x` whose heteroskedastic noise
is designed to produce singular (boundary) `lme4` fits some fraction of the
time. The base fit uses `set.seed(seed)`; simulation replicate `n` uses
`set.seed(seed + n)` so each replicate differs.

Make sure the packages loaded at the top of `run_mcmc.R`
(`rstanarm`, `tidyverse`, `bayesijlib`, `rstanarmijlib`, `rstan`, `lme4`,
`optparse`) are installed — see the top-level README's
`install_packages_locally.sh`.

---

## Stage 1: Base MCMC fit (single "real" dataset)

**Step 2: `run_mcmc.R --base`**

Fits `y ~ x - 1 + (1|z)` via `rstanarm::stan_glmer` on one simulated "base"
dataset, then computes Bayes and IJ standard errors from the posterior draws
(`ComputeIJStandardErrors`) for later comparison against the simulation
study.

```bash
./run_mcmc.R --base --seed=100 --re_dim=100 --obs_per_re=100
```

(These are also the defaults, so plain `./run_mcmc.R --base` is equivalent.
`--base_dir` defaults to the repo root via `git rev-parse --show-toplevel`.)

Produces: `output/super_simple_simulation_base_results_redim100_obsperre100_seed100.Rdata`

---

## Stage 2: Simulation replicates (`RESAMPLE_N` independent datasets)

**Step 3: `run_mcmc.R --sim --sim_num=N`** (repeat for N = 1..`RESAMPLE_N`)

Fits the same model to a freshly simulated dataset and saves a reduced
summary: the posterior mean of each parameter, the IJ and Bayes covariance
matrices, and whether `lme4::lmer` flagged the fit as singular.

Run one replicate directly:

```bash
./run_mcmc.R --sim --sim_num=1 --seed=100 --re_dim=100 --obs_per_re=100
```

Run all `RESAMPLE_N` replicates (default 100) via the Makefile, controlled
by `RUN_LOCALLY`:

```bash
make sim_files RUN_LOCALLY=true  RESAMPLE_N=100 -j 8   # local, parallel (default)
make sim_files RUN_LOCALLY=false RESAMPLE_N=100        # SLURM array job, fire-and-forget
```

The SLURM path (`sbatch --array=1-RESAMPLE_N run_sims_mcmc.sh`) doesn't read
`SEED`/`RE_DIM`/`OBS_PER_RE`/`PREFIX`/`NUM_MCMC_SAMPLES` from the Makefile
— it relies on `run_mcmc.R`'s own defaults, which match the Makefile's
defaults. If you override those away from their defaults, use
`RUN_LOCALLY=true` instead (known limitation, not fixed, to keep
`run_sims_mcmc.sh` unedited).

`NUM_MCMC_SAMPLES` (default 5000) controls `run_mcmc.R`'s `--num_draws`
(total MCMC iterations including warmup, for both `--base` and `--sim`
fits) and has no effect on any filename.

Produces: `output/super_simple_simulation_sim<N>_results_redim100_obsperre100_seed100.Rdata`
for N = 1..`RESAMPLE_N`

**Step 3b (optional, cluster only): `sync_remote_files.sh`**

If the replicates were run on a remote cluster, this script is a template
for `rsync`-ing the resulting `super_simple_simulation_sim*_results_*.Rdata`
files back into the local `output/` directory. The `HOST`, `REMOTE_BASE_DIR`,
`SCF_BASE_DIR`, and `MODEL_DIR` values are placeholders — edit them for your
remote setup before running it.

---

## Stage 3: Combine replicates

**Step 4: `combine_simulations.R`**

Loads all 100 per-replicate files matching the description string and
concatenates them into one combined file: posterior means (long dataframe),
and lists of IJ covariances, Bayes covariances, and singularity flags (one
entry per replicate).

```bash
./combine_simulations.R --seed=100 --re_dim=100 --obs_per_re=100
```

(Equivalent to plain `./combine_simulations.R`, since these are the
defaults.)

Reads: the 100 files from Stage 2
Produces: `output/super_simple_simulation_sim_results_redim100_obsperre100_seed100.Rdata`

---

## Stage 4: Final Post-processing for Paper

**Step 5: `postprocess_for_paper.R`**

Computes IJ, Bayes, and simulation-based estimates of the covariance of the
parameters (the regression coefficient `x`, `log_sigma`, and
`log_Sigma[z:(Intercept),(Intercept)]`) and their standard errors (via
block-bootstrap and delta-method calculations), and saves a tidy
long/wide dataframe for the paper's figures.

```bash
Rscript postprocess_for_paper.R --seed=100 --re_dim=100 --obs_per_re=100
```

(Options default to these same values, so plain `Rscript postprocess_for_paper.R` still works.)

Reads:
- `output/super_simple_simulation_sim_results_redim100_obsperre100_seed100.Rdata`
- `output/super_simple_simulation_base_results_redim100_obsperre100_seed100.Rdata`

Produces: `paper/experiment_data/simulations/simpler_sim_results.Rdata` (`--output_filename`)

`--seed`/`--re_dim`/`--obs_per_re`/`--prefix` are now CLI flags (previously
hard-coded near the top of the script) — the Makefile passes them explicitly
so the `Makefile`'s `SEED`/`RE_DIM`/`OBS_PER_RE`/`PREFIX` variables are the
single source of truth.

---

## Running the whole pipeline with `make`

The `Makefile` in this directory encodes the dependency graph above (base
fit + `RESAMPLE_N` sim replicates &rarr; combine &rarr; postprocess) and can
build everything, or any single output file, directly from
`src/singular_simulations`:

```bash
make                          # builds paper/experiment_data/simulations/simpler_sim_results.Rdata
                               # and everything it depends on (RESAMPLE_N=100, RUN_LOCALLY=true)
make -j 8                     # parallelize across the independent sim replicates
make RESAMPLE_N=20            # fewer replicates
make RUN_LOCALLY=false        # SLURM for the sim-replicate stage instead of local
```

## Local sanity check (no SLURM)

```bash
make sanity_check                                       # RESAMPLE_N=5, RUN_LOCALLY=true
make sanity_check RESAMPLE_N=10                         # override the replicate count
make sanity_check NUM_MCMC_SAMPLES=500                  # also shrink each individual fit
```

Runs the full pipeline locally with a small `RESAMPLE_N`, through to
`paper/experiment_data/simulations/simpler_sim_results.Rdata`. This
**overwrites** whatever real production output currently exists at those
paths — intended for a clean checkout. Note that since `DESC` (and hence
every output filename) doesn't depend on `RESAMPLE_N`, if the combined/base
files from a prior full run already exist, Make's normal up-to-date check
may skip rebuilding them — this is only meaningful in a clean checkout.


# Rough runtime estimate

The runtime is dominated by calls to `run_mcmc.R` in stages 1 and 2;
each such call takes roughly three minutes.  Stage 2 can be run in parallel.  The
other stages should run quickly.