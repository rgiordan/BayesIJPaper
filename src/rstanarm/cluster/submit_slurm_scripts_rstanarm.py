#!/usr/bin/env python3
"""Create and submit shell scripts to run MCMC for a set of rstanarm models.

Example
./submit_slurm_scripts_rstanarm.py --no-submit --description='test' --analysis='base'
./submit_slurm_scripts_rstanarm.py --no-submit --description='test' --analysis='bootstrap'
"""

import argparse
import datetime
import itertools
import json
import os
import subprocess

def get_git_root():
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()

_BASE = 'base'
_BOOT = 'bootstrap'
_VALID_ANALYSES = [ _BASE, _BOOT ]

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

if args.base_dir is None:
    args.base_dir = get_git_root()

model_list_full_path = os.path.join(
    args.base_dir, 'src/rstanarm/configs/', args.model_list_filename)
if not os.path.isfile(model_list_full_path):
    raise ValueError('Cannot find model list JSON file {}'.format(
        model_list_full_path))

with open(model_list_full_path, "r") as f:
    model_list = json.loads(f.read())

# Set which script to run.
r_script_dir = os.path.join(args.base_dir, 'src/rstanarm/')
if analysis == _BASE:
    script = os.path.join(r_script_dir, 'run_base_mcmc_rstanarm.R')
elif analysis == _BOOT:
    script = os.path.join(r_script_dir, 'run_bootstrapped_mcmc_rstanarm.R')

if not os.path.isfile(script):
    raise ValueError('Script {} does not exist.'.format(script))

config = {
    'base_dir': args.base_dir,
    'script': script,
    'num_cores': 4,
    'num_mcmc_chains': 4,
    'model_list_filename': args.model_list_filename }

slurm_script_dir = os.path.join(
    args.base_dir, 'src/rstanarm/cluster/slurm_scripts')
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
    output_dir = os.path.join(args.base_dir, 'src/rstanarm/cluster/output')
    this_config = config.copy()
    if analysis == _BASE:
        save_filename = os.path.join(
            output_dir,
            '{}_base_mcmc_{}.Rdata'.format(desc, args.description))
    elif analysis == _BOOT:
        save_filename = os.path.join(
            output_dir,
            '{}_boot_mcmc_{}.Rdata'.format(desc, args.description))

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
