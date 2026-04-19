
df <- arm_env$combined_df_wide_labeled
DefineMacro("armNumModels", length(unique(df$desc)), digits=0)
DefineMacro("armNumDatasets", length(unique(df$dataset)), digits=0)
DefineMacro("armNumCovsEstimated", nrow(df), digits=0)  # This is also the total number of distinct parameters
DefineMacro("armNumMCMCSamples", max(df$num_samples), digits=0)
DefineMacro("armNumBootstraps", max(df$num_boots), digits=0)
DefineMacro("armMedianNumObs", median(df$num_exchangeable_obs), digits=0)
DefineMacro("armMinNumObs", min(df$num_exchangeable_obs), digits=0)
DefineMacro("armMaxNumObs", max(df$num_exchangeable_obs), digits=0)


timing_df <- arm_env$timing_df
DefineMacro(
  "armMinMCMCTimeSecs",
  min(as.numeric(timing_df$fit_time, units="secs")), digits=2)
DefineMacro(
  "armMaxMCMCTimeMins",
  max(as.numeric(timing_df$fit_time, units="mins")), digits=2)
DefineMacro(
  "armTotalMCMCTimeMins",
  sum(as.numeric(timing_df$fit_time, units="mins")), digits=2)
DefineMacro(
  "armTotalBootTimeHours",
  sum(as.numeric(timing_df$boot_fit_time, units="hours")), digits=2)
