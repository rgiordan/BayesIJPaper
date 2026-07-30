REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/singular_simulations
OUTPUT_DIR  := $(SRC_DIR)/output
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/simulations

# Parameters — must match what run_mcmc.R and postprocess_for_paper.R expect.
SEED        := 100
RE_DIM      := 100
OBS_PER_RE  := 100

# RESAMPLE_N controls the number of simulation replicates (renamed from
# NUM_SIMS; same role, same default).
RESAMPLE_N  ?= 100

# RUN_LOCALLY selects local (Rscript) vs SLURM (sbatch run_sims_mcmc.sh)
# execution for the sim-replicate generation stage. Defaults to true,
# matching today's local-only Makefile behavior. Only the sim replicates
# are affected -- run_sims_mcmc.sh has no --base equivalent, so BASE_RESULT
# always runs locally.
RUN_LOCALLY ?= true

# PREFIX is threaded into run_mcmc.R/combine_simulations.R's existing
# --prefix option (blank default, unchanged convention).
PREFIX      ?=

DESC        := $(if $(PREFIX),$(PREFIX)_,)redim$(RE_DIM)_obsperre$(OBS_PER_RE)_seed$(SEED)

BASE_RESULT  := $(OUTPUT_DIR)/super_simple_simulation_base_results_$(DESC).Rdata
SIM_COMBINED := $(OUTPUT_DIR)/super_simple_simulation_sim_results_$(DESC).Rdata
PAPER_OUTPUT := $(PAPER_DIR)/simpler_sim_results.Rdata

SIM_NUMS  := $(shell seq 1 $(RESAMPLE_N))
SIM_FILES := $(foreach n,$(SIM_NUMS),$(OUTPUT_DIR)/super_simple_simulation_sim$(n)_results_$(DESC).Rdata)

.PHONY: all sim_files sanity_check

all: $(PAPER_OUTPUT)

# -----------------------------------------------------------------------
# Sanity check: full pipeline, locally, with a small RESAMPLE_N (default 5
# unless the caller already passed RESAMPLE_N on the command line).
# -----------------------------------------------------------------------
sanity_check:
	$(MAKE) RUN_LOCALLY=true RESAMPLE_N=5 all

# Final paper output — reads base result and combined sim results.
$(PAPER_OUTPUT): $(SIM_COMBINED) $(BASE_RESULT)
	Rscript $(SRC_DIR)/postprocess_for_paper.R \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) \
	    --prefix=$(PREFIX)

# Combine all per-replicate simulation files into a single file.
$(SIM_COMBINED): $(SIM_FILES)
	Rscript $(SRC_DIR)/combine_simulations.R \
	    --base_dir=$(REPO_ROOT) \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) \
	    --prefix=$(PREFIX)

# Sim replicates respect RUN_LOCALLY. Local: one rule covers all replicates
# (run with -j N to parallelise). SLURM: one array job via run_sims_mcmc.sh
# (fire-and-forget, like mrp's SLURM branches -- wait for it to finish,
# then re-run `make` to continue; run_sims_mcmc.sh is left unedited, since
# `sbatch --array=` overrides its #SBATCH -a 1-100 pragma).
ifeq ($(RUN_LOCALLY),true)
$(OUTPUT_DIR)/super_simple_simulation_sim%_results_$(DESC).Rdata:
	Rscript $(SRC_DIR)/run_mcmc.R \
	    --sim \
	    --sim_num=$* \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) \
	    --prefix=$(PREFIX) \
	    --base_dir=$(REPO_ROOT)

sim_files: $(SIM_FILES)
else
sim_files:
	sbatch --array=1-$(RESAMPLE_N) $(SRC_DIR)/run_sims_mcmc.sh
endif

# Base MCMC fit on the real data (needed by postprocess_for_paper.R).
# Always local -- no existing SLURM path for this single fit.
$(BASE_RESULT):
	Rscript $(SRC_DIR)/run_mcmc.R \
	    --base \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) \
	    --prefix=$(PREFIX) \
	    --base_dir=$(REPO_ROOT)
