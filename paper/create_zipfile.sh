#!/bin/bash

GIT_REPO=$(git rev-parse --show-toplevel)

# -sf does a dry run, which you can use to check for unnecessary files
# Here's how to check for big files to eliminate when using the -sf flag:
# FILES=$(for FILE in $(./create_zipfile.sh); do echo "/"$FILE; done)
# for f in $FILES; do [ -f "$f" ] && echo "$f"; done | xargs du -sh | sort -h

# Zip the repository, including data files, but excluding large
# collections of large intermediate data files.
zip -r ${GIT_REPO}/paper/bayesij_code.zip ${GIT_REPO} \
    --exclude ${GIT_REPO}"/.git/*" \
    --exclude ${GIT_REPO}"/.claude/*" \
    --exclude ${GIT_REPO}"/src/rstanarm/cluster/output/ARM_*.Rdata" \
    --exclude ${GIT_REPO}"/src/singular_simulations/output/super_simple_simulation_sim?*_results_redim100_obsperre100_seed100.Rdata" \
    --exclude ${GIT_REPO}"/src/mrp/bootstrap_data/mrp_bootstrap_seed1_samples5000.Rdata" \
    --exclude ${GIT_REPO}"/src/singular_simulations/output/super_simple_simulation_base_results_redim100_obsperre100_seed100.Rdata" \
    --exclude ${GIT_REPO}"/src/src/mrp/bootstrap_data/mrp_original_seed134432_samples5000.Rdata" \
    --exclude ${GIT_REPO}"/*/*.zip" \
    --exclude ${GIT_REPO}"/src/mrp/datasets/cces18_common_vv.csv" \
    --exclude ${GIT_REPO}"/libs/bayesijmrp/bayesijmrp/tests/testthat/mcmc_cache/*" \
    --exclude ${GIT_REPO}"/src/mrp/bootstrap_data/mrp_original_seed134432_samples5000.Rdata"


