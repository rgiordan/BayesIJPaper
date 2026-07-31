# You can check what make will do with
# make -n --debug=v

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

.PHONY: all data original_mcmc bootstrap_mcmc bootstrap_postprocess sanity_check list_outputs

all: $(PAPER_OUTPUT)

# Every file a successful `make all` run produces, so the user can review,
# cache, or manually delete them.
ALL_OUTPUT_FILES := $(SRC_DIR)/$(CLEANED_DATA) \
                     $(SRC_DIR)/$(DATASET) \
                     $(SRC_DIR)/$(ORIGINAL) \
                     $(SRC_DIR)/$(ORIGINAL_LMER) \
                     $(SRC_DIR)/$(ORIGINAL_MAP) \
                     $(SRC_DIR)/$(CUSTOM_MAP) \
                     $(SRC_DIR)/$(ORIGINAL_PP) \
                     $(addprefix $(SRC_DIR)/,$(MCMC_FILES)) \
                     $(addprefix $(SRC_DIR)/,$(POSTPROCESSED)) \
                     $(SRC_DIR)/$(COMBINED) \
                     $(PAPER_OUTPUT)

list_outputs:
	@printf '%s\n' $(ALL_OUTPUT_FILES)

# -----------------------------------------------------------------------
# Sanity check: full pipeline, locally, with a small RESAMPLE_N . Writes
# to the same default locations as a production run -- run in a clean
# checkout, or accept that it overwrites real output.
# -----------------------------------------------------------------------
sanity_check:
	$(MAKE) RUN_LOCALLY=true RESAMPLE_N=5 NUM_MCMC_SAMPLES=1000 all

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
# time-intensive, so it also respects RUN_LOCALLY: local via explicit,
# literal per-seed-per-method rules (postprocess_mcmc_slurm.sh, with
# SLURM_ARRAY_TASK_ID set to the known seed -- no wildcard matching, no
# parsing of the target name to recover method/seed), or SLURM via the
# same script (one array job per method, covering all RESAMPLE_N seeds).
ifeq ($(RUN_LOCALLY),true)
define MRP_POSTPROCESS_BOOTSTRAP_RULE
$(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed$(1)_mrp_postprocessed.Rdata: $(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed$(1).Rdata $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && SLURM_ARRAY_TASK_ID=$(1) ./postprocess_mcmc_slurm.sh bootstrap
endef
define MRP_POSTPROCESS_SUBSAMPLE_RULE
$(SRC_DIR)/bootstrap_data/mrp_subsample_seed$(1)_mrp_postprocessed.Rdata: $(SRC_DIR)/bootstrap_data/mrp_subsample_seed$(1).Rdata $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && SLURM_ARRAY_TASK_ID=$(1) ./postprocess_mcmc_slurm.sh subsample
endef
$(foreach s,$(LOCAL_SEEDS),$(eval $(call MRP_POSTPROCESS_BOOTSTRAP_RULE,$(s))))
$(foreach s,$(LOCAL_SEEDS),$(eval $(call MRP_POSTPROCESS_SUBSAMPLE_RULE,$(s))))

bootstrap_postprocess: $(addprefix $(SRC_DIR)/,$(POSTPROCESSED))
else
# Fire-and-forget, like bootstrap_mcmc below: submits the array jobs and
# returns. Wait for them to finish, then re-run `make` to continue -- Make
# only checks whether $(POSTPROCESSED) files exist, not how they were
# produced, so the next stage picks them up regardless of RUN_LOCALLY.
# Two separate sbatch submissions, one per method, since
# postprocess_mcmc_slurm.sh now does one thing per invocation (bootstrap or
# subsample, not both) -- avoids a single job/recipe producing two output
# files, which would otherwise race under parallel execution. Depends on
# the raw MCMC_FILES already existing (from a completed bootstrap_mcmc
# run): the local generated rules above are only defined under
# RUN_LOCALLY=true, so if they're missing this fails fast, locally, with
# "no rule to make target" instead of submitting a SLURM array that's
# doomed to fail once each task tries to load a nonexistent input file.
bootstrap_postprocess: $(SRC_DIR)/$(DATASET) $(addprefix $(SRC_DIR)/,$(MCMC_FILES))
	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/postprocess_mcmc_slurm.sh bootstrap
	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/postprocess_mcmc_slurm.sh subsample
endif

# -----------------------------------------------------------------------
# Stage 2: Bootstrap/subsample replicates
# -----------------------------------------------------------------------
ifeq ($(RUN_LOCALLY),true)
define MRP_BOOTSTRAP_RULE
$(SRC_DIR)/bootstrap_data/mrp_bootstrap_seed$(1).Rdata: $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && SLURM_ARRAY_TASK_ID=$(1) ./run_mcmc.sh $(NUM_MCMC_SAMPLES)
endef
define MRP_SUBSAMPLE_RULE
$(SRC_DIR)/bootstrap_data/mrp_subsample_seed$(1).Rdata: $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && SLURM_ARRAY_TASK_ID=$(1) ./run_mcmc.sh $(NUM_MCMC_SAMPLES) --subsample
endef
$(foreach s,$(LOCAL_SEEDS),$(eval $(call MRP_BOOTSTRAP_RULE,$(s))))
$(foreach s,$(LOCAL_SEEDS),$(eval $(call MRP_SUBSAMPLE_RULE,$(s))))

bootstrap_mcmc: $(SRC_DIR)/$(DATASET) $(addprefix $(SRC_DIR)/,$(MCMC_FILES))
else
# Fire-and-forget, as today: submits the array jobs and returns. Wait for
# them to finish before running `make bootstrap_postprocess`. Two separate
# sbatch submissions -- run_mcmc.sh does one thing per invocation (plain or
# --subsample), each producing a distinct per-seed file, so unlike before
# this now also honors NUM_MCMC_SAMPLES on the SLURM path.
bootstrap_mcmc: $(SRC_DIR)/$(DATASET)
	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/run_mcmc.sh $(NUM_MCMC_SAMPLES)
	sbatch --array=0-$$(($(RESAMPLE_N)-1)) $(SRC_DIR)/run_mcmc.sh $(NUM_MCMC_SAMPLES) --subsample
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
	cd $(SRC_DIR) && Rscript ./analyze_map.R --seed=$(SEED)

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
