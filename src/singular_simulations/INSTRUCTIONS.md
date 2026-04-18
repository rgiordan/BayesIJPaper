Currently, src/singular_simulations/run_simulations.R both runs a base
simulation, saving a lot of data, and
a large number of separate simulations, saving less data.  This means a single script runs many
MCMC runs, which is challenging to parallelize.

While making minimal modifications to the code in run_simulations.R, please make
a single script, src/singular_simulations/run_mcmc.R, that can run either of
these tasks according to command-line arguments.  The argument should specify:

- Whether to run and save the base posterior or a "simulation" with less saved data
- Which simulation number to run as an integer
- The seed, which should be offset by the simulation number so that each simulation is
  different even if passed the same seed
- The parameters re_dim, obs_per_re, chains, num_draws, whcih are currently hard-coded
- An optional prefix for the description file, e.g. "TEST".  This should default to empty.

You may use src/mrp/run_mcmc.R as a template.

Do not modify any of the existing files, only create a new run_mcmc.R file.