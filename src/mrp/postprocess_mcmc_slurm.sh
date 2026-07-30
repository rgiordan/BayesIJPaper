#!/bin/bash
## Array size (RESAMPLE_N seeds, 0-indexed) is set by the caller, e.g.
## sbatch --array=0-$((RESAMPLE_N-1)) postprocess_mcmc_slurm.sh
## -- matches run_mcmc_slurm.sh's own seed indexing; no mcmc_files.txt
## lookup needed.
#SBATCH -a 0-100
#SBATCH --output=slurm_logs/postprocess_%A_%a_%j.out
#SBATCH --error=slurm_logs/postprocess_%A_%a_%j.err
#
## Run with: sbatch --array=0-$((RESAMPLE_N-1)) postprocess_mcmc_slurm.sh

BASE_DIR=$(git rev-parse --show-toplevel)/src/mrp

./postprocess_mcmc.R --base_dir=${BASE_DIR} \
    --mcmc_file=bootstrap_data/mrp_bootstrap_seed${SLURM_ARRAY_TASK_ID}_samples5000.Rdata
./postprocess_mcmc.R --base_dir=${BASE_DIR} \
    --mcmc_file=bootstrap_data/mrp_subsample_seed${SLURM_ARRAY_TASK_ID}_samples5000.Rdata
