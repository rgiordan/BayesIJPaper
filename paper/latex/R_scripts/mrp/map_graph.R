ggplot(mrp_env$map_mcmc_wide_df) +
  geom_point(aes(x=mcmc, y=map)) +
  geom_errorbarh(aes(xmin=mcmc - 2 * mcmc_sd, xmax=mcmc + 2 * mcmc_sd, y=map)) +
  geom_abline() +
  facet_grid(~ class)
