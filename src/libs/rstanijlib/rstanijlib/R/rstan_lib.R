

# Generate a list suitable for use as a configuration file.
GenerateRstanConfig <- function(
    model_name,
    subdir,
    keep_pars,
    num_obs_var,
    weight_var = "w_",
    loglik_var = "lp_",
    num_samples = NA,
    num_boots = NA,
    stan_args = c()) {
    return(list(
        model_name = model_name,
        subdir = subdir,
        num_obs_var = num_obs_var,
        weight_var = weight_var,
        loglik_var = loglik_var,
        num_samples = num_samples,
        keep_pars = keep_pars,
        num_boots = num_boots,
        stan_args = stan_args
    ))
}
