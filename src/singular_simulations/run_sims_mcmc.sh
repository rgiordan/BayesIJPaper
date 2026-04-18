#!/bin/bash
#SBATCH -a 1-100
#SBATCH -c 1
#SBATCH --output=output/logs/mcmc_%A_%a_%j.out
#SBATCH --error=output/logs/mcmc_%A_%a_%j.err

BASE_DIR=$(git rev-parse --show-toplevel)
$BASE_DIR/src/singular_simulations/run_mcmc.R --sim \
    --sim_num=$SLURM_ARRAY_TASK_ID --base_dir=$BASE_DIR
