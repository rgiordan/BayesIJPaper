#!/bin/bash
## To prepare the files, run
## > ls -1a bootstrap_data/mrp_*_seed[0-9]*_samples5000.Rdata > mcmc_files.txt
## Set the array size to `cat mcmc_files.txt | wc -l` 
#SBATCH -a 1-202
#SBATCH --output=slurm_logs/postprocess_%A_%a_%j.out
#SBATCH --error=slurm_logs/postprocess_%A_%a_%j.err
#
## Run with sbatch postprocess_mcmc_slurm.sh

## https://blog.ronin.cloud/slurm-job-arrays/


CONFIG_FILE=mcmc_files.txt
BASE_DIR=$(git rev-parse --show-toplevel)/src/mrp
MCMC_FILE=$(awk -v ID=${SLURM_ARRAY_TASK_ID} 'NR==ID' ${CONFIG_FILE})

./postprocess_mcmc.R --base_dir=${BASE_DIR} --mcmc_file=${MCMC_FILE}
