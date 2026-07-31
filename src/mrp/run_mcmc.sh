#!/bin/bash
#SBATCH --output=slurm_logs/mcmc_%A_%a_%j.out
#SBATCH --error=slurm_logs/mcmc_%A_%a_%j.err

# Example invocations:
# sbatch --array=0-100 run_mcmc.sh
# run_mcmc.sh 500 --subsample

BASE_DIR=$(git rev-parse --show-toplevel)/src/mrp
NUM_SAMPLES=${1:-5000}  # Uses 5000 samples by default
SUBSAMPLE=${2:-} # Uses no subsample by default

if [[ "$SUBSAMPLE" != "" && "$SUBSAMPLE" != "--subsample" ]]; then
    echo "Error: second argument must be '--subsample' or omitted, got: $SUBSAMPLE" >&2
    exit 1
fi

./run_mcmc.R \
    --seed=$SLURM_ARRAY_TASK_ID \
    --base_dir=$BASE_DIR \
    --num_samples=$NUM_SAMPLES $SUBSAMPLE