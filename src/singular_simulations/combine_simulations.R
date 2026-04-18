
# TODO: load all the simulations, and combine them into this
# single file.

sim_filename <- file.path(
  results_dir, 
  sprintf("super_simple_simulation_sim_results_%s.Rdata", desc))
load(sim_filename)