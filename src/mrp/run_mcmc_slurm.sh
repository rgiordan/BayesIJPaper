#!/bin/bash
#SBATCH -a 0-100
#SBATCH --output=slurm_logs/mcmc_%A_%a_%j.out
#SBATCH --error=slurm_logs/mcmc_%A_%a_%j.err



BASE_DIR=$(git rev-parse --show-toplevel)/src/mrp
./run_mcmc.R --seed=$SLURM_ARRAY_TASK_ID --base_dir=$BASE_DIR --subsample
./run_mcmc.R --seed=$SLURM_ARRAY_TASK_ID --base_dir=$BASE_DIR