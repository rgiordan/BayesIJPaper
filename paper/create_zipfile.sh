#!/bin/bash

GIT_REPO=$(git rev-parse --show-toplevel)

# -sf does a dry run, which you can use to check for unnecessary files

# Zip the repository, including data files, but excluding large
# collections of large intermediate data files.
zip -r -sf ${GIT_REPO}/paper/bayesij_code.zip ${GIT_REPO} \
    --exclude ${GIT_REPO}"/.git/*" \
    --exclude ${GIT_REPO}"/.claude/*" \
    --exclude ${GIT_REPO}"/src/rstanarm/cluster/output/ARM_*.Rdata" \
    --exclude ${GIT_REPO}"/src/singular_simulations/output/super_simple_simulation_sim?*_results_redim100_obsperre100_seed100.Rdata"

