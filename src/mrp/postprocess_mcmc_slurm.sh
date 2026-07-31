#!/bin/bash
#SBATCH --output=slurm_logs/postprocess_%A_%a_%j.out
#SBATCH --error=slurm_logs/postprocess_%A_%a_%j.err

# Example invocations
# sbatch --array=0-100 run_mcmc.sh
# run_mcmc.sh subsample

BASE_DIR=$(git rev-parse --show-toplevel)/src/mrp
METHOD=${1:-bootstrap} # Uses bootstrap by default; could also be subsample

if [[ "$METHOD" != "bootstrap" && "$METHOD" != "subsample" ]]; then
    echo "Error: first argument must be 'bootstrap' or 'subsample', got: $METHOD" >&2
    exit 1
fi

./postprocess_mcmc.R \
    --base_dir=${BASE_DIR} \
    --mcmc_file=bootstrap_data/mrp_${METHOD}_seed${SLURM_ARRAY_TASK_ID}.Rdata
