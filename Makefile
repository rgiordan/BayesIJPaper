REPO_ROOT := $(shell git rev-parse --show-toplevel)

PAPER_SIMULATIONS := $(REPO_ROOT)/paper/experiment_data/simulations/simpler_sim_results.Rdata
PAPER_ARM         := $(REPO_ROOT)/paper/experiment_data/arm/arm_results_postprocessed.Rdata
PAPER_MRP         := $(REPO_ROOT)/paper/experiment_data/mrp/mrp_postprocessed.Rdata

.PHONY: all simulations arm mrp

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
