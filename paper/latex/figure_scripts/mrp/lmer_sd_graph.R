
mcmc_lmer_wide_df <- mrp_env$mcmc_lmer_wide_df
mcmc_lmer_wide_df %>%
  filter(!is.na(lmer_sd)) %>%
  ggplot() +
  geom_point(aes(x=mcmc_sd, y=lmer_sd, color=par, shape=par)) +
  geom_abline() +
  expand_limits(y=0, x=0)
