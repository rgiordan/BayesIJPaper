REPO_ROOT := $(shell git rev-parse --show-toplevel)

PAPER_SIMULATIONS := $(REPO_ROOT)/paper/experiment_data/simulations/simpler_sim_results.Rdata
PAPER_ARM         := $(REPO_ROOT)/paper/experiment_data/arm/arm_results_postprocessed.Rdata
PAPER_MRP         := $(REPO_ROOT)/paper/experiment_data/mrp/mrp_postprocessed.Rdata

.PHONY: all simulations arm mrp sanity_check

all: $(PAPER_SIMULATIONS) $(PAPER_ARM) $(PAPER_MRP)

simulations: $(PAPER_SIMULATIONS)
arm:         $(PAPER_ARM)
mrp:         $(PAPER_MRP)

$(PAPER_SIMULATIONS):
	$(MAKE) -C $(REPO_ROOT)/src/singular_simulations

$(PAPER_ARM):
	$(MAKE) -C $(REPO_ROOT)/src/rstanarm

$(PAPER_MRP):
	$(MAKE) -C $(REPO_ROOT)/src/mrp

# Local sanity check (no SLURM): runs all three experiments end-to-end with
# a small RESAMPLE_N and no cluster. Each sub-Makefile's own sanity_check target forces
# RUN_LOCALLY=true internally.
sanity_check:
	$(MAKE) -C $(REPO_ROOT)/src/mrp sanity_check
	$(MAKE) -C $(REPO_ROOT)/src/rstanarm sanity_check
	$(MAKE) -C $(REPO_ROOT)/src/singular_simulations sanity_check
