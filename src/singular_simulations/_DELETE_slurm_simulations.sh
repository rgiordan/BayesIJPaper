#!/bin/bash
#SBATCH -a 1-100 --output=logs/simplesim-%a-%j.out --error=logs/simplesim-%a-%j.err

# Run with sbatch slurm_simulations.sh

 ./run_simpler_simulation.R \
    --seed=${SLURM_ARRAY_TASK_ID} \
    --output_description=scf \
    --num_draws=2000 \
    --chains=4 \
    --cores=1
