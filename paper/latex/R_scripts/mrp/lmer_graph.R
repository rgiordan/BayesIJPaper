
mcmc_lmer_wide_df <- mrp_env$mcmc_lmer_wide_df
ggplot(mcmc_lmer_wide_df) +
  geom_point(aes(x=mcmc, y=lmer)) +
  geom_errorbarh(aes(xmin=mcmc - 2 * mcmc_sd, xmax=mcmc + 2 * mcmc_sd, y=lmer)) +
  geom_abline() +
  facet_grid(~ class)
