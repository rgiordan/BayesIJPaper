REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/rstanarm
CONFIG_DIR  := $(SRC_DIR)/configs
OUTPUT_DIR  := $(SRC_DIR)/cluster/output
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/arm

# Description tag embedded in per-model output filenames and used by
# load_rstanarm_results.R to locate them. Must match the file_suffix
# variable hardcoded in that script.
DESC        := 0924_cluster

NUM_MODELS  := 65
MODEL_INDICES := $(shell seq 1 $(NUM_MODELS))

COMPILED     := $(OUTPUT_DIR)/compiled_results_1116.Rdata
PAPER_OUTPUT := $(PAPER_DIR)/arm_results_postprocessed.Rdata

# Stamp files record completion of per-model MCMC runs whose actual output
# filenames are determined dynamically from the JSON config.
BASE_STAMPS := $(addprefix $(OUTPUT_DIR)/.stamp_base_,$(MODEL_INDICES))
BOOT_STAMPS := $(addprefix $(OUTPUT_DIR)/.stamp_boot_,$(MODEL_INDICES))

.PHONY: all configs

all: $(PAPER_OUTPUT)

# Regenerate the JSON model config from the CSV spreadsheet.
# The output is already committed; only run this if regenerating from scratch.
configs: $(CONFIG_DIR)/rstanarm_ij_model_list.json
$(CONFIG_DIR)/rstanarm_ij_model_list.json:
	Rscript $(SRC_DIR)/configs/generate_rstanarm_configs.R

# Final paper output — reads compiled_results.
$(PAPER_OUTPUT): $(COMPILED)
	Rscript $(SRC_DIR)/postprocess_for_paper.R

# Compile all per-model results into a single dataframe.
$(COMPILED): $(BASE_STAMPS) $(BOOT_STAMPS)
	Rscript $(SRC_DIR)/load_rstanarm_results.R

# Base MCMC for model index %. Output is saved under the model's desc name with
# the DESC suffix so load_rstanarm_results.R can find it.
# Run with -j N to parallelise across models.
$(OUTPUT_DIR)/.stamp_base_%:
	@model_ind=$*; \
	model_desc=$$(python3 -c "import json; d=json.load(open('$(CONFIG_DIR)/rstanarm_ij_model_list.json')); print(d[$$model_ind-1]['desc'])"); \
	Rscript $(SRC_DIR)/run_base_mcmc_rstanarm.R \
	    --base_dir=$(REPO_ROOT) \
	    --model_list_ind=$$model_ind \
	    --save_filename=$(OUTPUT_DIR)/$${model_desc}_base_mcmc_$(DESC).Rdata \
	    --save_draws \
	    --force
	touch $@

# Bootstrap MCMC for model index %. Depends on the base run being complete.
$(OUTPUT_DIR)/.stamp_boot_%: $(OUTPUT_DIR)/.stamp_base_%
	@model_ind=$*; \
	model_desc=$$(python3 -c "import json; d=json.load(open('$(CONFIG_DIR)/rstanarm_ij_model_list.json')); print(d[$$model_ind-1]['desc'])"); \
	Rscript $(SRC_DIR)/run_bootstrapped_mcmc_rstanarm.R \
	    --base_dir=$(REPO_ROOT) \
	    --model_list_ind=$$model_ind \
	    --save_filename=$(OUTPUT_DIR)/$${model_desc}_boot_mcmc_$(DESC).Rdata \
	    --force
	touch $@
