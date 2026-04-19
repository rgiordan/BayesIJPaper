
df <- arm_env$combined_df_long_labeled %>%
  filter(metric == "bayes_bootstrap_diff_norm")

# Set boundaries for the axes.
norm_xbound <-
  with(arm_env$combined_df_wide_labeled,
       quantile(c(abs(df$value),
                  abs(df$value),
                  2), 0.98, na.rm=TRUE) * 1.05 )


plt <- PlotMetricHistogram(df, norm_xbound) +
  xlab("Relative error between the bootstrap and posterior covariance")
print(plt)
