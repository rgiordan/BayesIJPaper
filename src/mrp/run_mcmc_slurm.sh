#!/bin/bash
#SBATCH -a 0-100
#SBATCH --output=slurm_logs/mcmc_%A_%a_%j.out
#SBATCH --error=slurm_logs/mcmc_%A_%a_%j.err

BASE_DIR=/accounts/fac/rgiordano/Documents/git_repos/SurveyWeighting/MrPBook
./run_mcmc.R --seed=$SLURM_ARRAY_TASK_ID --base_dir=$BASE_DIR --subsample
./run_mcmc.R --seed=$SLURM_ARRAY_TASK_ID --base_dir=$BASE_DIR