#!/bin/bash

GIT_REPO=$(git rev-parse --show-toplevel)

zip -r -sf ${GIT_REPO}/paper/bayesij_code.zip ${GIT_REPO} --exclude ${GIT_REPO}"/src/rstanarm/cluster/output/ARM_*.Rdata" ".git/*"

