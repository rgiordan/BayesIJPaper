REPO_ROOT   := $(shell git rev-parse --show-toplevel)
SRC_DIR     := $(REPO_ROOT)/src/mrp
PAPER_DIR   := $(REPO_ROOT)/paper/experiment_data/mrp

SEED        := 134432

# Paths relative to SRC_DIR, matching the conventions in run_mcmc.R and
# postprocess_mcmc.R (which use --base_dir=$(SRC_DIR) and relative mcmc_file paths).
DATASET         := datasets/cces18_subset.Rdata
CLEANED_DATA    := datasets/cces18_common_vv.Rdata
ORIGINAL        := bootstrap_data/mrp_original_seed$(SEED)_samples5000.Rdata
ORIGINAL_LMER   := bootstrap_data/mrp_originallmer_seed$(SEED)_samples5000.Rdata
ORIGINAL_MAP    := bootstrap_data/mrp_originalmap_seed$(SEED)_samples5000.Rdata
CUSTOM_MAP      := bootstrap_data/custom_map_analysis.Rdata
ORIGINAL_PP     := bootstrap_data/mrp_original_seed$(SEED)_samples5000_mrp_postprocessed.Rdata

# The compile step (compile_postprocessing.R) appends a timestamp to its output
# filename. The path below is the specific file that postprocess_for_paper.R
# hardcodes. If you regenerate the combined file, update this variable and the
# hardcoded path in postprocess_for_paper.R to match the new timestamp.
COMBINED        := bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata

PAPER_OUTPUT    := $(PAPER_DIR)/mrp_postprocessed.Rdata

# The 202 bootstrap/subsample MCMC files are listed in mcmc_files.txt.
# They were generated on a SLURM cluster (see run_mcmc_slurm.sh).
# This derives the corresponding postprocessed filenames.
MCMC_FILES      := $(shell cat $(SRC_DIR)/mcmc_files.txt)
POSTPROCESSED   := $(patsubst %.Rdata,%_mrp_postprocessed.Rdata,$(MCMC_FILES))

.PHONY: all data original_mcmc bootstrap_postprocess

all: $(PAPER_OUTPUT)

# -----------------------------------------------------------------------
# Stage 4: Final paper output
# -----------------------------------------------------------------------
$(PAPER_OUTPUT): $(SRC_DIR)/$(COMBINED) $(SRC_DIR)/$(ORIGINAL_PP) \
                 $(SRC_DIR)/$(ORIGINAL_LMER) $(SRC_DIR)/$(CUSTOM_MAP) \
                 $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && Rscript $(SRC_DIR)/postprocess_for_paper.R

# -----------------------------------------------------------------------
# Stage 3: Compile postprocessed replicates into single dataframe
# -----------------------------------------------------------------------
# Runs compile_postprocessing.R over all postprocessed files.
# NOTE: The output filename includes a timestamp; see COMBINED comment above.
$(SRC_DIR)/$(COMBINED): $(addprefix $(SRC_DIR)/,$(POSTPROCESSED)) \
                         $(SRC_DIR)/$(ORIGINAL_PP)
	cd $(SRC_DIR) && ./compile_postprocessing.R \
	    --base_dir=$(SRC_DIR) \
	    --file_pattern="bootstrap_data/mrp_*_samples5000_mrp_postprocessed.Rdata" \
	    --description=mrp

# Postprocess the original MCMC output (always needed locally).
$(SRC_DIR)/$(ORIGINAL_PP): $(SRC_DIR)/$(ORIGINAL) $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./postprocess_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --mcmc_file=$(ORIGINAL)

# Generic rule: postprocess any single MCMC output file.
# The 202 bootstrap/subsample files follow the same pattern.
$(SRC_DIR)/%_mrp_postprocessed.Rdata: $(SRC_DIR)/%.Rdata $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./postprocess_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --mcmc_file=$*.Rdata

# Convenience target: postprocess all files listed in mcmc_files.txt.
bootstrap_postprocess: $(addprefix $(SRC_DIR)/,$(POSTPROCESSED))

# -----------------------------------------------------------------------
# Stage 2: Bootstrap/subsample replicates
# These are intended for a SLURM cluster (see run_mcmc_slurm.sh).
# The target below runs them locally and sequentially as a fallback.
# -----------------------------------------------------------------------
bootstrap_mcmc: $(SRC_DIR)/$(DATASET)
	sbatch $(SRC_DIR)/run_mcmc_slurm.sh

# -----------------------------------------------------------------------
# Stage 1: Original MCMC fits
# -----------------------------------------------------------------------
original_mcmc: $(SRC_DIR)/$(ORIGINAL) $(SRC_DIR)/$(ORIGINAL_LMER) \
               $(SRC_DIR)/$(ORIGINAL_MAP) $(SRC_DIR)/$(CUSTOM_MAP)

$(SRC_DIR)/$(ORIGINAL): $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --original \
	    --seed=$(SEED)

$(SRC_DIR)/$(ORIGINAL_LMER): $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --original \
	    --lmer \
	    --seed=$(SEED)

$(SRC_DIR)/$(ORIGINAL_MAP): $(SRC_DIR)/$(DATASET)
	cd $(SRC_DIR) && ./run_mcmc.R \
	    --base_dir=$(SRC_DIR) \
	    --original \
	    --map \
	    --seed=$(SEED)

$(SRC_DIR)/$(CUSTOM_MAP): $(SRC_DIR)/$(ORIGINAL)
	cd $(SRC_DIR) && Rscript $(SRC_DIR)/analyze_map.R

# -----------------------------------------------------------------------
# Stage 0: Data preparation
# -----------------------------------------------------------------------
data: $(SRC_DIR)/$(DATASET)

$(SRC_DIR)/$(DATASET): $(SRC_DIR)/$(CLEANED_DATA)
	cd $(SRC_DIR) && Rscript $(SRC_DIR)/generate_dataset.R

# Requires the raw CSV files to be downloaded manually into datasets/.
# See the README Stage 0 for download instructions.
$(SRC_DIR)/$(CLEANED_DATA): $(SRC_DIR)/datasets/cces18_common_vv.csv \
                              $(SRC_DIR)/datasets/statelevel_predictors.csv \
                              $(SRC_DIR)/datasets/poststrat_df.csv
	cd $(SRC_DIR) && Rscript $(SRC_DIR)/clean_cces.R
