#!/usr/bin/env python3
"""Create and submit shell scripts to run ``model_script.R`` for a set of models.

Example
rstanarm/cluster/submit_slurm_scripts_rstanarm.py --base_dir=$(pwd) --no-submit --description='test' --analysis='base'
"""

import argparse
import datetime
import itertools
import json
import os
import subprocess

_BASE = 'base'
_BOOT = 'bootstrap'
_SIM = 'simulation'
_LME4 = 'lme4'
_VALID_ANALYSES = [ _BASE, _BOOT, _SIM, _LME4 ]

# Optionally set this to a default remote folder
default_base_dir = None

parser = argparse.ArgumentParser()
parser.add_argument('--submit', dest='submit', action='store_true')
parser.add_argument('--no-submit', dest='submit', action='store_false',
                    help='Submit to slurm.')
parser.add_argument('--base_dir', default=default_base_dir, type=str)
parser.add_argument('--model_list_filename',
                    default="rstanarm_ij_model_list.json", type=str)
parser.add_argument('--description', default='', type=str)
parser.add_argument('--force', dest='force', action='store_true')
parser.add_argument('--no-force', dest='force', action='store_false')
parser.add_argument('--no_save_rstan_fit', dest='no_save_rstan_fit', action='store_true')
parser.add_argument('--sim_ground_truth', type=str)
parser.add_argument('--num_sims', type=int, default=200)
parser.add_argument('--analysis', type=str,
                    help='Analysis to perform in ' + str(_VALID_ANALYSES))
parser.set_defaults(submit=True)
parser.set_defaults(force=False)
parser.set_defaults(no_save_rstan_fit=False)


# parse the arguments
args = parser.parse_args()

analysis = args.analysis
if not analysis in _VALID_ANALYSES:
    print('Valid analyses:', str(_VALID_ANALYSES))
    raise ValueError('Invalid analysis ' + analysis)

model_list_full_path = os.path.join(
    args.base_dir, 'rstanarm/configs/', args.model_list_filename)
if not os.path.isfile(model_list_full_path):
    raise ValueError('Cannot find model list JSON file {}'.format(
        model_list_full_path))

with open(model_list_full_path, "r") as f:
    model_list = json.loads(f.read())

# Set which script to run.
r_script_dir = os.path.join(args.base_dir, 'rstanarm/cluster')
if analysis == _BASE:
    script = os.path.join(r_script_dir, 'run_base_mcmc_rstanarm.R')
elif analysis == _BOOT:
    script = os.path.join(r_script_dir, 'run_bootstrapped_mcmc_rstanarm.R')
elif analysis == _SIM:
    script = os.path.join(r_script_dir, 'run_mcmc_simulations_rstanarm.R')
elif analysis == _LME4:
    script = os.path.join(r_script_dir, 'run_lme4.R')

if not os.path.isfile(script):
    raise ValueError('Script {} does not exist.'.format(script))

config = {
    'base_dir': args.base_dir,
    'script': script,
    'num_cores': 4,
    'num_mcmc_chains': 4,
    'model_list_filename': args.model_list_filename }

slurm_script_dir = os.path.join(
    args.base_dir, 'rstanarm/cluster/slurm_scripts')
if not os.path.isdir(slurm_script_dir):
    raise ValueError('Script directory {} does not exist.'.format(
        slurm_script_dir))

# Process the models
for model_ind in range(len(model_list)):
    entry = model_list[model_ind]
    desc = entry['desc'][0]

    # Set the name of the shell script that will contain the command
    script_name = 'run_model_script_{}_{}_{}.sh'.format(
        analysis, model_ind, desc)
    full_script_name = os.path.join(slurm_script_dir, script_name)

    # Set the configuration options
    output_dir = os.path.join(args.base_dir, 'rstanarm/cluster/output')
    this_config = config.copy()
    if analysis == _BASE:
        save_filename = os.path.join(
            output_dir,
            '{}_base_mcmc_{}.Rdata'.format(desc, args.description))
    elif analysis == _BOOT:
        save_filename = os.path.join(
            output_dir,
            '{}_boot_mcmc_{}.Rdata'.format(desc, args.description))
    elif analysis == _SIM:
        save_filename = os.path.join(
            output_dir,
            '{}_sim_mcmc_{}.Rdata'.format(desc, args.description))
    elif analysis == _LME4:
        save_filename = os.path.join(
            output_dir,
            '{}_lme4_{}.Rdata'.format(desc, args.description))

    this_config.update({
        'model_list_ind': model_ind + 1, # python is zero-indexed, R one-indexed
        'save_filename': save_filename })
    command_string = \
        ('{script} ' +
         '--base_dir={base_dir} ' +
         '--num_cores={num_cores} ' +
         '--num_mcmc_chains={num_mcmc_chains} ' +
         '--model_list_filename="{model_list_filename}" ' +
         '--model_list_ind="{model_list_ind}" ' +
         '--save_filename="{save_filename}" '
         ).format(**this_config)
    if args.force:
        command_string += ' --force '

    # Append analysis-specific arguments.
    # For base MCMC:
    if analysis == _BASE:
        # Save the MCMC and bootstrap draws
        command_string += ' --save_draws '
        if args.no_save_rstan_fit:
            command_string += ' --no_save_rstan_fit '

    # For simulations:
    if analysis == _SIM:
        command_string += ' --num_sims={} '.format(args.num_sims)
        if args.sim_ground_truth is None:
            # Use an rstan fit as the basis for the simulation
            initial_fit_filename = os.path.join(
                output_dir,
                '{}_base_mcmc_{}.Rdata'.format(desc, args.description))
        else:
            # Use a ground truth file as the basis for the simulation
            initial_fit_filename = os.path.join(
                output_dir, args.sim_ground_truth)
            command_string += ' --simulate_from_ground_truth '

        command_string += ' --initial_fit_filename={}'.format(
            initial_fit_filename)

    # Write the command to the script and call it if requested.
    with open(full_script_name, 'w') as slurm_script:
        # https://statistics.berkeley.edu/computing/servers/cluster
        slurm_script.write('#!/bin/bash\n')
        slurm_script.write(
            '#SBATCH --cpus-per-task {}\n'.format(config['num_cores']))

        # Set the slurm logging destination
        log_filename = '{}_{}_{}'.format(
            datetime.datetime.now().strftime("%Y%m%d_%H%M"),
            analysis,
            desc)
        slurm_script.write(
            '#SBATCH --output=slurm_logs/slurm-{}-%x.%j.%a.out\n'.format(
                log_filename))
        slurm_script.write(
            '#SBATCH --error=slurm_logs/slurm-{}-%x.%j.%a.out\n'.format(
                log_filename))
        slurm_script.write('export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK\n')

        slurm_script.write(command_string)
        slurm_script.write('\n')

    if args.submit:
        print('Submitting {}'.format(full_script_name))
        command = ['sbatch', full_script_name]
        subprocess.run(command)
    else:
        print('Generating (but not submitting) shell script {}'.format(
            full_script_name))
