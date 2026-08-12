#!/bin/bash
# Create a zipfile with all the code for reproducing the paper.

GIT_REPO=$(git rev-parse --show-toplevel)

# -sf does a dry run, which you can use to check for unnecessary files
# Here's how to check for big files to eliminate when using the -sf flag:
# FILES=$(for FILE in $(./create_supplemental_zipfile.sh); do echo "/"$FILE; done)
# for f in $FILES; do [ -f "$f" ] && echo "$f"; done | xargs du -sh | sort -h

# Zip the code, including data files, but excluding large
# collections of large intermediate data files, and the paper itself.
zip -r ${GIT_REPO}/bayesij_code_supplement.zip ${GIT_REPO}/* \
    --exclude ${GIT_REPO}"/*/*.zip" \
    --exclude ${GIT_REPO}"/.git/*" \
    --exclude ${GIT_REPO}"/paper/latex/arxiv/*" \
    --exclude ${GIT_REPO}"/*/.claude/*" \
    --exclude ${GIT_REPO}"/src/rstanarm/cluster/slurm_logs/*" \
    --exclude ${GIT_REPO}"/src/rstanarm/cluster/output/*.Rdata" \
    --exclude ${GIT_REPO}"/src/singular_simulations/output/*.Rdata" \
    --exclude ${GIT_REPO}"/src/singular_simulations/output/logs/*" \
    --exclude ${GIT_REPO}"/src/mrp/bootstrap_data/*.Rdata" \
    --exclude ${GIT_REPO}"/src/mrp/slurm_logs/*" \
    --exclude ${GIT_REPO}"/src/mrp/datasets/cces18_common_vv.csv" \
    --exclude ${GIT_REPO}"/src/rstanarm/cluster/slurm_scripts/*" \
    --exclude ${GIT_REPO}"/libs/bayesijmrp/bayesijmrp/tests/testthat/mcmc_cache/*"


# Create a single zipfile with the code and the supplement pdf.
zip bayesij_supplement.zip bayesij_code_supplement.zip paper/latex/supplement.pdf