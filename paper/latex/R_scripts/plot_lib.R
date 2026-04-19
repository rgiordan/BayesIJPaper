

# A convenient funciton for extracting only the legend from a ggplot.
# Taken from
# https://tinyurl.com/y8c742p6
GetLegend <- function(myggplot){
  warning("Use ggpubr::get_legend instead")
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}


# Define common colors.
GGColorHue <- function(n) {
    hues = seq(15, 375, length = n + 1)
    hcl(h = hues, l = 65, c = 100)[1:n]
}


GetMethodLabels <- function() {
    method_breaks <- c("ij", "boot", "bayes", "sim", "truth")
    method_labels <- c(
        "IJ",
        "Boot",
        "Bayes",
        "Sim",
        "Truth")
    names(method_labels) <- method_breaks
    return(list(breaks=method_breaks, labels=method_labels))
}


GetMethodScale <- function(type="color") {
  valid_types <- c("color", "shape")
  if (!(type %in% valid_types)) {
    stop(sprintf("%s is not a valid legend type for GetMethodScale", type))
  }
  method_labels <- GetMethodLabels()

  if (type == "color") {
    colors <- GGColorHue(length(method_labels$breaks))
    color_scale <-
      scale_color_manual(
        name="Method",
        values=colors,
        labels=method_labels$labels,
        aesthetics="color",
        drop=TRUE,
        limits = force)
    return(color_scale)
  } else if (type == "shape") {
    shapes <- 1:length(method_labels$breaks)
    shape_scale <-
      scale_shape_manual(
        name="Method",
        values=shapes,
        labels=method_labels$labels,
        aesthetics="shape",
        drop=TRUE,
        limits = force)
    return(shape_scale)
  } else {
    stop("This should never happen")
  }
}



VarianceCompPlot <- function(df, var, var_se) {
  method_labels <- GetMethodLabels()
  df %>%
    ggplot(aes(x=method, color=method, shape=method)) +
    geom_point(aes(y={{var}})) +
    geom_errorbar(aes(
      ymin={{var}} - 2 * {{var_se}},
      ymax={{var}} + 2 * {{var_se}}), width=0.2) +
    GetMethodScale("color") +
    GetMethodScale("shape") +
    theme(axis.title.x = element_blank()) +
    scale_x_discrete(breaks=method_labels$breaks,
                     labels=method_labels$labels)
}


PlotMetricHistogram <- function(df, xbound, num_bins=30) {
  plt <-
    ggplot(df) +
    geom_histogram(aes(x=value, y=..density..), alpha=0.5, bins=num_bins) +
    xlim(-abs(xbound), abs(xbound)) +
    ylab("Distinct covariance estimates\n(normalized count)") +
    facet_grid(has_sigma_label ~ big_n_label, scales="free")
  return(plt)
}
