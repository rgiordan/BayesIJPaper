#!/bin/bash
#
# Script to run run_simulation.R with slurm.
# Run sbatch run_simulations.sh.
#
#SBATCH --output=output/logs/singular_simulations-%j-%a.out
#SBATCH --error=output/logs/singular_simulations-%j-%a.err
#SBATCH --cpus-per-task 4

./run_simulation.R