# You can check what make will do with
# make -n --debug=v

REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/rstanarm
CONFIG_DIR  := $(SRC_DIR)/configs
OUTPUT_DIR  := $(SRC_DIR)/cluster/output
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/arm

# Description tag embedded in per-model output filenames. Threaded
# explicitly into load_rstanarm_results.R's --file_suffix below, so this
# is the single source of truth (no independently-hardcoded copies).
DESC        := 0924_cluster

# NUM_MODELS controls how many models (from the start of the JSON config)
# to fit/compile. Defaults to the full production count (65); a sanity
# check can override it to a small number to skip most of the model fits.
# Out-of-range values are caught in R (run_base_mcmc_rstanarm.R,
# run_bootstrapped_mcmc_rstanarm.R, load_rstanarm_results.R), not here.
NUM_MODELS  ?= 65
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

# NUM_MCMC_CHAINS controls --num_mcmc_chains on both the base and
# bootstrap fits (matches run_base_mcmc_rstanarm.R/
# run_bootstrapped_mcmc_rstanarm.R's own default of 4). Only the local
# (RUN_LOCALLY=true) path respects it -- submit_slurm_scripts_rstanarm.py
# (SLURM) hardcodes num_mcmc_chains=4 and is left unedited, matching the
# existing NUM_MCMC_SAMPLES-style gap for that script.
NUM_MCMC_CHAINS ?= 4

COMPILED     := $(OUTPUT_DIR)/compiled_results_1116.Rdata
PAPER_OUTPUT := $(PAPER_DIR)/arm_results_postprocessed.Rdata

# Stamp files record completion of per-model MCMC runs whose actual output
# filenames are determined dynamically from the JSON config.
BASE_STAMPS := $(addprefix $(OUTPUT_DIR)/.stamp_base_,$(MODEL_INDICES))
BOOT_STAMPS := $(addprefix $(OUTPUT_DIR)/.stamp_boot_,$(MODEL_INDICES))

# Shared shell snippet: given $$model_ind (set earlier in the calling
# recipe), looks up that model's `desc` field from the JSON config and
# assigns it to $$model_desc. Recursively-expanded, so it re-reads
# $$model_ind fresh from whichever recipe invokes it.
define GET_MODEL_DESC
model_desc=$$(python3 -c "import json; d=json.load(open('$(CONFIG_DIR)/rstanarm_ij_model_list.json')); print(d[$$model_ind-1]['desc'][0])")
endef

.PHONY: all configs base_mcmc boot_mcmc sanity_check list_outputs

all: $(PAPER_OUTPUT)

# Files a successful `make all` run produces, so the user can review, cache,
# or manually delete them. Lists the stamp files themselves ($(BASE_STAMPS)/
# $(BOOT_STAMPS)) rather than the actual per-model MCMC .Rdata files they
# guard -- those real filenames are only known at recipe time (looked up
# from the JSON config via model_desc), not expressed as a Make variable.
ALL_OUTPUT_FILES := $(CONFIG_DIR)/rstanarm_ij_model_list.json \
                     $(BASE_STAMPS) \
                     $(BOOT_STAMPS) \
                     $(COMPILED) \
                     $(PAPER_OUTPUT)

list_outputs:
	@printf '%s\n' $(ALL_OUTPUT_FILES)

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
	$(MAKE) RUN_LOCALLY=true RESAMPLE_N=5 NUM_MCMC_SAMPLES=800 NUM_MCMC_CHAINS=2 all

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
	$(GET_MODEL_DESC); \
	Rscript $(SRC_DIR)/run_base_mcmc_rstanarm.R \
	    --base_dir=$(REPO_ROOT) \
	    --model_list_ind=$$model_ind \
	    --save_filename=$(OUTPUT_DIR)/$${model_desc}_base_mcmc_$(DESC).Rdata \
	    --default_num_samples=$(NUM_MCMC_SAMPLES) \
	    --num_mcmc_chains=$(NUM_MCMC_CHAINS) \
	    --save_draws \
	    --force
	touch $@

# Bootstrap MCMC for model index %. Depends on the base run being complete.
$(OUTPUT_DIR)/.stamp_boot_%: $(OUTPUT_DIR)/.stamp_base_%
	@model_ind=$*; \
	$(GET_MODEL_DESC); \
	Rscript $(SRC_DIR)/run_bootstrapped_mcmc_rstanarm.R \
	    --base_dir=$(REPO_ROOT) \
	    --model_list_ind=$$model_ind \
	    --save_filename=$(OUTPUT_DIR)/$${model_desc}_boot_mcmc_$(DESC).Rdata \
	    --default_num_boots=$(RESAMPLE_N) \
	    --default_num_samples=$(NUM_MCMC_SAMPLES) \
	    --num_mcmc_chains=$(NUM_MCMC_CHAINS) \
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
