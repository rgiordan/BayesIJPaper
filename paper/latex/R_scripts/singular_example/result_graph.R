
PlotVar <- function(v) {
    simple_sim_env$cov_wide2_df %>% filter(variable == !!v) %>%
        VarianceCompPlot(mean, se) +
        facet_grid(. ~ variable_label, scales="free", labeller=label_parsed) +
        ylab("Variance")
}

legend <- GetLegend(PlotVar("x"))

grid.arrange(
  PlotVar("x") + theme(legend.position="None") +
    expand_limits(y=0),
  PlotVar("log_sigma") + theme(legend.position="None") +
    expand_limits(y=0),
  PlotVar("log_Sigma[z:(Intercept),(Intercept)]") +
    theme(legend.position="None") +
    ylab("Variance (log10 scale)") +
    scale_y_log10(),
  legend,
  widths=c(1,1,1,0.5)
)