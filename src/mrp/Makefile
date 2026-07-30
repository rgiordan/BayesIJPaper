REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/mrp
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/mrp

SEED        := 134432

# RESAMPLE_N controls how many bootstrap seeds (and, since each seed also
# produces a subsample replicate, how many subsample seeds) are generated
# and postprocessed. Defaults to today's full production count. Seeds run
# 0..RESAMPLE_N-1, matching run_mcmc_slurm.sh's #SBATCH -a 0-100 (101 seeds).
RESAMPLE_N  ?= 101

# RUN_LOCALLY selects local (Rscript) vs SLURM (sbatch) execution for the
# Stage 2 (bootstrap/subsample MCMC) and Stage 3 (per-file postprocessing)
# stages. Defaults to false, matching today's SLURM-only behavior.
RUN_LOCALLY ?= false

# NUM_MCMC_SAMPLES controls run_mcmc.R's --num_samples (brm()'s `iter`,
# which includes warmup -- --num_warmup_samples stays fixed at its own
# default of 500, not controlled by this flag, so keep NUM_MCMC_SAMPLES
# comfortably above 500). Unlike RESAMPLE_N, this has no effect on any
# filename -- run_mcmc.R's output filenames no longer encode sample count.
NUM_MCMC_SAMPLES ?= 5000

# Paths relative to SRC_DIR, matching the conventions in run_mcmc.R and
# postprocess_mcmc.R (which use --base_dir=$(SRC_DIR) and relative mcmc_file paths).
DATASET         := datasets/cces18_subset.Rdata
CLEANED_DATA    := datasets/cces18_common_vv.Rdata
ORIGINAL        := bootstrap_data/mrp_original_seed$(SEED).Rdata
ORIGINAL_LMER   := bootstrap_data/mrp_originallmer_seed$(SEED).Rdata
ORIGINAL_MAP    := bootstrap_data/mrp_originalmap_seed$(SEED).Rdata
CUSTOM_MAP      := bootstrap_data/custom_map_analysis.Rdata
ORIGINAL_PP     := bootstrap_data/mrp_original_seed$(SEED)_mrp_postprocessed.Rdata

# Deterministic (no timestamp) so it can be a stable Make dependency target;
# compile_postprocessing.R's --output_filename is always passed explicitly
# below, so its own auto-timestamped default is only exercised when that
# script is run by hand with no arguments.
COMBINED        := bootstrap_data/mrp_combined_mrp.Rdata

PAPER_OUTPUT    := $(PAPER_DIR)/mrp_postprocessed.Rdata

# The RESAMPLE_N bootstrap/subsample MCMC files, seeds 0..RESAMPLE_N-1
# (matching run_mcmc_slurm.sh's #SBATCH -a 0-100 seed indexing). No longer
# read from a committed mcmc_files.txt -- derived directly from RESAMPLE_N
# so production (RESAMPLE_N=101) and reduced sanity-check runs share one
# mechanism.
LOCAL_SEEDS     := $(shell seq 0 $$(($(RESAMPLE_N)-1)))
RAW_BOOT        := $(foreach s,$(LOCAL_SEEDS),bootstrap_data/mrp_bootstrap_seed$(s).Rdata)
RAW_SUB         := $(foreach s,$(LOCAL_SEEDS),bootstrap_data/mrp_subsample_seed$(s).Rdata)
MCMC_FILES      := $(RAW_BOOT) $(RAW_SUB)
POSTPROCESSED   := $(patsubst %.Rdata,%_mrp_postprocessed.Rdata,$(MCMC_FILES))

# Comma-joined list of postprocessed files for compile_postprocessing.R's
# --file_pattern, which now takes an explicit list rather than a shell glob.
FILE_LIST := $(shell echo $(addprefix $(SRC_DIR)/,$(POSTPROCESSED)) $(SRC_DIR)/$(ORIGINAL_PP) | tr ' ' ',')

.PHONY: all data original_mcmc bootstrap_mcmc bootstrap_postprocess sanity_check

all: $(PAPER_OUTPUT)

# -----------------------------------------------------------------------
# Sanity check: full pipeline, locally, with a small RESAMPLE_N . Writes
# to the same default locations as a production run -- run in a clean
# checkout, or accept that it overwrites real output.
# -----------------------------------------------------------------------
sanity_check:
	$(MAKE) RUN_LOCALLY=true RESAMPLE_N=5 NUM_MCMC_SAMPLES=500 all

# -----------------------------------------------------------------------
# Stage 4: Final paper output
# -----------------------------------------------------------------------
$(PAPER_OUTPUT): $(SRC_DIR)/$(COMBINED) $(SRC_DIR)/$(ORIGINAL_PP) \
                 $(SRC_DIR)/$(ORIGINAL_LMER) $(SRC_DIR)/$(CUSTOM_MAP) \
                 $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && Rscript ./postprocess_for_paper.R \
	    --combined_file=$(COMBINED) \
	    --seed=$(SEED)

# -----------------------------------------------------------------------
# Stage 3: Compile postprocessed replicates into single dataframe
# -----------------------------------------------------------------------
$(SRC_DIR)/$(COMBINED): $(addprefix $(SRC_DIR)/,$(POSTPROCESSED)) \
                         $(SRC_DIR)/$(ORIGINAL_PP)
	cd $(SRC_DIR) && ./compile_postprocessing.R \
	    --base_dir=$(SRC_DIR) \
	    --file_pattern="$(FILE_LIST)" \
	    --description=mrp \
	    --output_filename=$(COMBINED)

# Postprocess the original MCMC output (always needed locally; a single
# fast fit, not scaled by RESAMPLE_N or gated by RUN_LOCALLY).
$(SRC_DIR)/$(ORIGINAL_PP): $(SRC_DIR)/$(ORIGINAL) $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./postprocess_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --mcmc_file=$(ORIGINAL)

# Postprocessing the RESAMPLE_N bootstrap/subsample files is fairly
# time-intensive, so it also respects RUN_LOCALLY: local via the existing
# generic pattern rule (Rscript per file), or SLURM via
# postprocess_mcmc_slurm.sh (one array job covering all RESAMPLE_N seeds).
ifeq ($(RUN_LOCALLY),true)
$(SRC_DIR)/%_mrp_postprocessed.Rdata: $(SRC_DIR)/%.Rdata $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./postprocess_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --mcmc_file=$*.Rdata

bootstrap_postprocess: $(addprefix $(SRC_DIR)/,$(POSTPROCESSED))
else
# Fire-and-forget, like bootstrap_mcmc below: submits the array job and
# returns. Wait for it to finish, then re-run `make` to continue -- Make
# only checks whether $(POSTPROCESSED) files exist, not how they were
# produced, so the next stage picks them up regardless of RUN_LOCALLY.
# Depends on the raw MCMC_FILES already existing (from a completed
# bootstrap_mcmc run): the local generation pattern rules below are only
# defined under RUN_LOCALLY=true, so if they're missing this fails fast,
# locally, with "no rule to make target" instead of submitting a SLURM
# array that's doomed to fail once each task tries to load a nonexistent
# input file.
bootstrap_postprocess: $(SRC_DIR)/$(DATASET) $(addprefix $(SRC_DIR)/,$(MCMC_FILES))
	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/postprocess_mcmc_slurm.sh
endif

# -----------------------------------------------------------------------
# Stage 2: Bootstrap/subsample replicates
# -----------------------------------------------------------------------
ifeq ($(RUN_LOCALLY),true)
$(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed%.Rdata: $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R --seed=$* --base_dir=$(SRC_DIR) --num_samples=$(NUM_MCMC_SAMPLES)

$(SRC_DIR)/bootstrap_data/mrp_subsample_seed%.Rdata: $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R --seed=$* --base_dir=$(SRC_DIR) --subsample --num_samples=$(NUM_MCMC_SAMPLES)

bootstrap_mcmc: $(SRC_DIR)/$(DATASET) $(addprefix $(SRC_DIR)/,$(MCMC_FILES))
else
# Fire-and-forget, as today: submits the array job and returns. Wait for
# it to finish before running `make bootstrap_postprocess`. Note the
# SLURM path doesn't take NUM_MCMC_SAMPLES -- run_mcmc_slurm.sh always
# samples at run_mcmc.R's own default. Since filenames no longer encode
# sample count, this is just a "SLURM path doesn't get faster" gap, not a
# correctness issue.
bootstrap_mcmc: $(SRC_DIR)/$(DATASET)
	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/run_mcmc_slurm.sh
endif

# -----------------------------------------------------------------------
# Stage 1: Original MCMC fits
# -----------------------------------------------------------------------
original_mcmc: $(SRC_DIR)/$(ORIGINAL) $(SRC_DIR)/$(ORIGINAL_LMER) \
               $(SRC_DIR)/$(ORIGINAL_MAP) $(SRC_DIR)/$(CUSTOM_MAP)

$(SRC_DIR)/$(ORIGINAL): $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --original \
	    --seed=$(SEED) \
	    --num_samples=$(NUM_MCMC_SAMPLES)

$(SRC_DIR)/$(ORIGINAL_LMER): $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --original \
	    --lmer \
	    --seed=$(SEED) \
	    --num_samples=$(NUM_MCMC_SAMPLES)

$(SRC_DIR)/$(ORIGINAL_MAP): $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --original \
	    --map \
	    --seed=$(SEED) \
	    --num_samples=$(NUM_MCMC_SAMPLES)

$(SRC_DIR)/$(CUSTOM_MAP): $(SRC_DIR)/$(ORIGINAL)
	cd $(SRC_DIR) && Rscript ./analyze_map.R

# -----------------------------------------------------------------------
# Stage 0: Data preparation
# -----------------------------------------------------------------------
data: $(SRC_DIR)/$(DATASET)

$(SRC_DIR)/$(DATASET): $(SRC_DIR)/$(CLEANED_DATA)
	cd $(SRC_DIR) && Rscript ./generate_dataset.R

# Requires the raw CSV files to be downloaded manually into datasets/.
# See the README Stage 0 for download instructions.
$(SRC_DIR)/$(CLEANED_DATA): $(SRC_DIR)/datasets/cces18_common_vv.csv \
                            $(SRC_DIR)/datasets/statelevel_predictors.csv \
                            $(SRC_DIR)/datasets/poststrat_df.csv
	cd $(SRC_DIR) && Rscript ./clean_cces.R
