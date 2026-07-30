REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/rstanarm
CONFIG_DIR  := $(SRC_DIR)/configs
OUTPUT_DIR  := $(SRC_DIR)/cluster/output
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/arm

# Description tag embedded in per-model output filenames. Threaded
# explicitly into load_rstanarm_results.R's --file_suffix below, so this
# is the single source of truth (no independently-hardcoded copies).
DESC        := 0924_cluster

NUM_MODELS  := 65
MODEL_INDICES := $(shell seq 1 $(NUM_MODELS))

# RESAMPLE_N controls the number of bootstrap replicates per model
# (--default_num_boots). It does NOT affect NUM_MODELS -- a sanity check
# still fits all 65 models, just with fewer bootstraps each.
RESAMPLE_N  ?= 200

# RUN_LOCALLY selects local (Rscript, via the .stamp_* targets) vs SLURM
# (cluster/submit_slurm_scripts_rstanarm.py) execution for the MCMC
# stages. Defaults to true, matching today's local-only Makefile behavior.
RUN_LOCALLY ?= true

# NUM_MCMC_SAMPLES controls --default_num_samples on both the base and
# bootstrap fits. Doesn't affect any filename.
NUM_MCMC_SAMPLES ?= 2000

COMPILED     := $(OUTPUT_DIR)/compiled_results_1116.Rdata
PAPER_OUTPUT := $(PAPER_DIR)/arm_results_postprocessed.Rdata

# Stamp files record completion of per-model MCMC runs whose actual output
# filenames are determined dynamically from the JSON config.
BASE_STAMPS := $(addprefix $(OUTPUT_DIR)/.stamp_base_,$(MODEL_INDICES))
BOOT_STAMPS := $(addprefix $(OUTPUT_DIR)/.stamp_boot_,$(MODEL_INDICES))

.PHONY: all configs base_mcmc boot_mcmc sanity_check

all: $(PAPER_OUTPUT)

# Regenerate the JSON model config from the CSV spreadsheet.
# The output is already committed; only run this if regenerating from scratch.
configs: $(CONFIG_DIR)/rstanarm_ij_model_list.json
$(CONFIG_DIR)/rstanarm_ij_model_list.json:
	Rscript $(SRC_DIR)/configs/generate_rstanarm_configs.R

# -----------------------------------------------------------------------
# Sanity check: full pipeline, locally, with a small RESAMPLE_N (default 5
# unless the caller already passed RESAMPLE_N on the command line). All 65
# models are still fit -- only the per-model bootstrap count shrinks.
# -----------------------------------------------------------------------
sanity_check:
	$(MAKE) RUN_LOCALLY=true RESAMPLE_N=5 NUM_MCMC_SAMPLES=500 all

# Final paper output — reads compiled_results. postprocess_for_paper.R's
# --compiled_file is relative to src/rstanarm (it joins with its own
# self-computed base_dir), so pass OUTPUT_DIR's fixed relative form rather
# than the absolute $(COMPILED) path.
$(PAPER_OUTPUT): $(COMPILED)
	Rscript $(SRC_DIR)/postprocess_for_paper.R \
	    --compiled_file=cluster/output/$(notdir $(COMPILED))

# Compile all per-model results into a single dataframe. Prerequisites are
# the actual stamp files (not the base_mcmc/boot_mcmc phony targets below),
# so this only builds automatically under RUN_LOCALLY=true -- under
# RUN_LOCALLY=false the stamp-file pattern rules don't exist (see below),
# so `make all RUN_LOCALLY=false` fails with a clear "no rule to make
# target" error until you've manually run `make boot_mcmc RUN_LOCALLY=false`
# and waited for the SLURM jobs to finish.
$(COMPILED): $(BASE_STAMPS) $(BOOT_STAMPS)
	Rscript $(SRC_DIR)/load_rstanarm_results.R \
	    --output_dir=$(OUTPUT_DIR) \
	    --file_suffix=$(DESC) \
	    --output_filename=$(notdir $(COMPILED))

ifeq ($(RUN_LOCALLY),true)
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
	    --default_num_samples=$(NUM_MCMC_SAMPLES) \
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
	    --default_num_boots=$(RESAMPLE_N) \
	    --default_num_samples=$(NUM_MCMC_SAMPLES) \
	    --force
	touch $@

base_mcmc: $(BASE_STAMPS)
boot_mcmc: $(BOOT_STAMPS)
else
# Fire-and-forget, mirroring mrp's SLURM branches: submits one SLURM job
# per model and returns. Wait for the jobs to finish before running
# `make all` (or `make $(COMPILED)`) to compile the results -- matches the
# existing manual two-step workflow (README Stage 1, Steps 3a/3b).
base_mcmc:
	python3 $(SRC_DIR)/cluster/submit_slurm_scripts_rstanarm.py \
	    --base_dir=$(REPO_ROOT) \
	    --analysis=base \
	    --description=$(DESC) \
	    --num_samples=$(NUM_MCMC_SAMPLES) \
	    --force

boot_mcmc:
	python3 $(SRC_DIR)/cluster/submit_slurm_scripts_rstanarm.py \
	    --base_dir=$(REPO_ROOT) \
	    --analysis=bootstrap \
	    --description=$(DESC) \
	    --num_boots=$(RESAMPLE_N) \
	    --num_samples=$(NUM_MCMC_SAMPLES) \
	    --force
endif
