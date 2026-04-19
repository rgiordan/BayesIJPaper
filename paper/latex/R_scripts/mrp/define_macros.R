DefineMacro("mrpThetaDim", mrp_env$theta_dim, digits=0)
DefineMacro("mrpNobs", mrp_env$n_obs, digits=0)
DefineMacro("mrpNTotalobs", mrp_env$n_total_obs, digits=0)
DefineMacro("mrpNSamples", mrp_env$num_samples, digits=0)
DefineMacro("mrpNMCMC", mrp_env$num_mcmc_samples, digits=0)

DefineMacro("mrpNperD", mrp_env$n_obs / mrp_env$theta_dim, digits=3)

DefineMacro("mrpNBoot", mrp_env$num_samples, digits=0)
DefineMacro("mrpBootMinutes", mrp_env$boot_time_estimate / 60., digits=0)

DefineMacro("mrpIJSec", mrp_env$ij_time, digits=0)
DefineMacro("mrpLinpredSec", mrp_env$linpred_time, digits=0)
