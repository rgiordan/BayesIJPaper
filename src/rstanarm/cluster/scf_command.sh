#!/bin/bash
#./submit_slurm_scripts.py --base_dir=$(pwd) --description='boot_result_draws'
#./submit_slurm_scripts.py --base_dir=$(pwd) --description='0504_cluster'
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0521_cluster'
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0521_cluster' --analysis='bootstrap
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='base'
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='bootstrap'
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='base' --force # Rerun to save rstan output
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='simulation'
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='base' # Fix a bug dropping columns
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='simulation'
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --force --analysis='simulation' # Save a simulation datafile
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0526_cluster' --model_list_filename=rstanarm_ij_simulation_model_list.json --analysis='base' # Run the base MCMC on the simulations
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0526_cluster' --model_list_filename=rstanarm_ij_simulation_model_list.json --analysis='bootstrap' # Run the bootstrapped MCMC on the simulations
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='bootstrap' # Re-submit now that parallel is working (hopefully)
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --force --analysis='simulation' # Use the locally generated simulation files
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0526_cluster' --model_list_filename=rstanarm_ij_simulation_model_list.json --analysis='base' --force # rerun the base MCMC on the simulations
#./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0526_cluster' --model_list_filename=rstanarm_ij_simulation_model_list.json --analysis='bootstrap' --force # Rerun sim bootstraps

# Re-submit with new exchangeable units.  Only new models should run.
# ./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='bootstrap'
# ./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='base'
# ./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0523_cluster' --analysis='simulation'
# ./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0526_cluster' --model_list_filename=rstanarm_ij_simulation_model_list.json --analysis='base'
# ./submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --description='0526_cluster' --model_list_filename=rstanarm_ij_simulation_model_list.json --analysis='bootstrap'

# Starting over!
#./submit_slurm_scripts_rstanarm.py --description='0924_cluster' --model_list_filename=rstanarm_ij_model_list.json --analysis='base'
# ./submit_slurm_scripts_rstanarm.py --base_dir=/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes --description='0924_cluster' --model_list_filename=rstanarm_ij_model_list.json --analysis='bootstrap' --no-submit
#./submit_slurm_scripts_rstanarm.py  --description='0924_cluster' --model_list_filename=rstanarm_ij_model_list.json --analysis='lme4' --no-submit

# Save the ij covariance when you run the bootstrap
./submit_slurm_scripts_rstanarm.py --description='1107_cluster' --model_list_filename=rstanarm_ij_model_list.json --analysis='bootstrap' --no-submit
