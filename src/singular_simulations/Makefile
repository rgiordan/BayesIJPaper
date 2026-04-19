REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/singular_simulations
OUTPUT_DIR  := $(SRC_DIR)/output
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/simulations

# Parameters — must match what run_mcmc.R and postprocess_for_paper.R expect.
SEED        := 100
RE_DIM      := 100
OBS_PER_RE  := 100
NUM_SIMS    := 100

DESC        := redim$(RE_DIM)_obsperre$(OBS_PER_RE)_seed$(SEED)

BASE_RESULT  := $(OUTPUT_DIR)/super_simple_simulation_base_results_$(DESC).Rdata
SIM_COMBINED := $(OUTPUT_DIR)/super_simple_simulation_sim_results_$(DESC).Rdata
PAPER_OUTPUT := $(PAPER_DIR)/simpler_sim_results.Rdata

SIM_NUMS  := $(shell seq 1 $(NUM_SIMS))
SIM_FILES := $(foreach n,$(SIM_NUMS),$(OUTPUT_DIR)/super_simple_simulation_sim$(n)_results_$(DESC).Rdata)

.PHONY: all

all: $(PAPER_OUTPUT)

# Final paper output — reads base result and combined sim results.
$(PAPER_OUTPUT): $(SIM_COMBINED) $(BASE_RESULT)
	Rscript $(SRC_DIR)/postprocess_for_paper.R

# Combine all per-replicate simulation files into a single file.
$(SIM_COMBINED): $(SIM_FILES)
	Rscript $(SRC_DIR)/combine_simulations.R \
	    --base_dir=$(REPO_ROOT) \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE)

# One rule covers all simulation replicates. Run with -j N to parallelise.
$(OUTPUT_DIR)/super_simple_simulation_sim%_results_$(DESC).Rdata:
	Rscript $(SRC_DIR)/run_mcmc.R \
	    --sim \
	    --sim_num=$* \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) \
	    --base_dir=$(REPO_ROOT)

# Base MCMC fit on the real data (needed by postprocess_for_paper.R).
$(BASE_RESULT):
	Rscript $(SRC_DIR)/run_mcmc.R \
	    --base \
	    --seed=$(SEED) \
	    --re_dim=$(RE_DIM) \
	    --obs_per_re=$(OBS_PER_RE) \
	    --base_dir=$(REPO_ROOT)
