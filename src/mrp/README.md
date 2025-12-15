Steps to reproduce.  All run in the mrp directory.

- Download the data into `datasets` (see README therein)
- Run `clean_ccecs.R` to clean the raw data
- Run `generate_dataset.R` to subsample a pseudo dataset

- On the SCF cluster:
    - Run `./run_mcmc.R --base_dir=$(pwd) --original` to get the original MCMC
    - Run `./run_mcmc.R --base_dir=$(pwd) --original --lmer` to get the lme4 fit
    - Run `./run_mcmc.R --base_dir=$(pwd) --original --map` to get the MAP fit
    - Run `sbatch run_mcmc_slurm.sh` to 
      run MCMC on a bunch of subsamples, and bootstraps of the pseudo dataset.
    - Run `ls -1a bootstrap_data/mrp_*_seed[0-9]*_samples5000.Rdata > mcmc_files.txt` to make a list of MCMC runs.  Note that this list should include
      the original, the sumsampled runs, and the bootstrap runs.  
    - Make sure the array size is correct in `postprocess_mcmc_slurm.sh`, then  
      `sbatch` it.  This computes MrP and the influence functions for 
      each MCMC run.
    - Run `./compile_postprocessing.R --base_dir=$(pwd)    --file_pattern=bootstrap_data/mrp_*_samples5000_mrp_postprocessed.Rdata --description=mrp`.  
      This concatenates all the matching files into
      a single `mrp_combined_mrp_20240724_1226.Rdata` file.
- Back on the home machine, scp the result of the last command 
  (e.g. `bootstrap_data/mrp_combined_mrp_20240724_1226.Rdata`), as well as the
  original run and lmer fit.  This can be done with sync_scf.sh.
- Run `analyze_bootstrap_results.R` to look at the results.

SCF
