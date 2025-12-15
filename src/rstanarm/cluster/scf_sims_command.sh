#!/bin/bash
# ./submit_slurm_scripts_rstanarm.py \
#     --base_dir=$(pwd) \
#     --description='regsim_0529' \
#     --analysis='base' \
#     --model_list_filename='example-models/simulations/reg_model_list.json'
# ./submit_slurm_scripts_rstanarm.py \
#     --base_dir=$(pwd) \
#     --description='regsim_0529' \
#     --analysis='simulation' \
#     --model_list_filename='example-models/simulations/reg_model_list.json' \
#     --sim_ground_truth='example-models/simulations/reg_ground_truth.Rdata'
# ./submit_slurm_scripts_rstanarm.py \
#     --base_dir=$(pwd) \
#     --description='regsim_0529' \
#     --analysis='bootstrap' \
#     --model_list_filename='example-models/simulations/reg_model_list.json'
# ./submit_slurm_scripts_rstanarm.py \
#     --base_dir=$(pwd) \
#     --description='bin_regsim_0529' \
#     --analysis='base' \
#     --model_list_filename='example-models/simulations/binary_reg_model_list.json'
# ./submit_slurm_scripts_rstanarm.py \
#     --base_dir=$(pwd) \
#     --description='bin_regsim_0529' \
#     --analysis='simulation' \
#     --model_list_filename='example-models/simulations/binary_reg_model_list.json' \
#     --sim_ground_truth='example-models/simulations/binary_reg_ground_truth.Rdata'
# ./submit_slurm_scripts_rstanarm.py \
#     --base_dir=$(pwd) \
#     --description='bin_regsim_0529' \
#     --analysis='bootstrap' \
#     --model_list_filename='example-models/simulations/binary_reg_model_list.json'

./submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description='re_regsim_0529' \
    --analysis='base' \
    --model_list_filename='example-models/simulations/reg_re_model_list.json' \
    --no-submit
./submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description='re_regsim_0529' \
    --analysis='bootstrap' \
    --model_list_filename='example-models/simulations/reg_re_model_list.json'
./submit_slurm_scripts_rstanarm.py \
    --base_dir=$(pwd) \
    --description='re_regsim_0529' \
    --analysis='simulation' \
    --model_list_filename='example-models/simulations/reg_re_model_list.json' \
    --sim_ground_truth='example-models/simulations/reg_re_ground_truth.Rdata'
