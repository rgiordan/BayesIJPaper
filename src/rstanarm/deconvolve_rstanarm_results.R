# Load and process results produced by model_script.R.

library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)

rstan_options(auto_write=TRUE)

# If TRUE do not run all the bootstraps and do not save.
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")

source(file.path(base_dir, "cov_se_lib.R"))
source(file.path(base_dir, "result_processing_lib.R"))
source(file.path(base_dir, "rstanarm_lib.R"))
source(file.path(base_dir, "deconvolution_lib.R"))

model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

output_filename <- sprintf("compiled_results_%s.Rdata", "2020-07-28")
load(file=file.path(base_dir, "output", output_filename))


combined_df_nore <- 
    combined_df_nore %>%
    mutate(has_sigma=grepl("[Ss]igma", params),
           big_n=num_exch_obs >= 240) %>%
    mutate(has_sigma=ifelse(has_sigma, "has sigma", "no sigma"),
           big_n=ifelse(big_n, "n >= 240", "n < 240"))


###################################
# Deconvolve


# Compute something to deconvolve.
GetMetric <- function(cov1, cov2, cov2_se) {
    return((cov1 - cov2) / (abs(cov2) + cov2_se))
}

num_sims <- 100
diffs <- matrix(NA, nrow(combined_df_nore), num_sims)
bayes_diffs <- matrix(NA, nrow(combined_df_nore), num_sims)
for (sim in 1:num_sims) {
    diffs[, sim] <-
        GetMetric(
            cov1=rnorm(nrow(combined_df_nore),
                         mean=combined_df_nore$ij_cov,
                         sd=combined_df_nore$ij_se),
            cov2=rnorm(nrow(combined_df_nore),
                         mean=combined_df_nore$bootstrap_cov,
                         sd=combined_df_nore$bootstrap_se),
            cov2_se=combined_df_nore$bootstrap_se
        )
    # Note: this is wrong, the Bayes and IJ are highly correlated.
    bayes_diffs[, sim] <-
        GetMetric(
            cov1=rnorm(nrow(combined_df_nore),
                       mean=combined_df_nore$bayes_cov,
                       sd=combined_df_nore$bayes_se),
            cov2=rnorm(nrow(combined_df_nore),
                       mean=combined_df_nore$ij_cov,
                       sd=combined_df_nore$ij_se),
            cov2_se=combined_df_nore$ij_se
        )
}
diff_list <- GetMetric(
    cov1=combined_df_nore$ij_cov,
    cov2=combined_df_nore$bootstrap_cov,
    cov2_se=combined_df_nore$bootstrap_se)
se_list <- apply(diffs, MARGIN=1, sd)
combined_df_nore$diff <- diff_list
combined_df_nore$diff_se <- se_list

bayes_diff_list <- GetMetric(
    cov1=combined_df_nore$bayes_cov,
    cov2=combined_df_nore$ij_cov,
    cov2_se=combined_df_nore$ij_se)
bayes_se_list <- apply(diffs, MARGIN=1, sd)
combined_df_nore$bayes_diff <- bayes_diff_list
combined_df_nore$bayes_diff_se <- bayes_se_list


if (FALSE) {
    diffs_sim_df <-
        data.frame(diffs) %>%
        mutate(par=1:n()) %>%
        pivot_longer(cols=-par, names_to="sim")
    head(diffs_sim_df)

    ggplot(diffs_sim_df) +
        geom_qq(aes(sample=value, group=par), geom="line")
}

if (FALSE) {
    hist(diff_list, 100)
    plot(diff_list, se_list)
}

source(file.path(base_dir, "deconvolution_lib.R"))

grid_len <- 1000
mu0_grid <- seq(min(diff_list), max(diff_list), length.out=grid_len)
sd0_grid <- rep(2 * min(diff(mu0_grid)), grid_len)

deconv_list <- Deconvolve(x=diff_list, x_se=se_list, mu0_grid=mu0_grid, sd0_grid=sd0_grid)
combined_df_nore$diff_shrunk <- deconv_list$e_mu

mu0_grid <- seq(min(bayes_diff_list), max(bayes_diff_list), length.out=grid_len)
sd0_grid <- rep(2 * min(diff(mu0_grid)), grid_len)

bayes_deconv_list <- Deconvolve(x=bayes_diff_list, x_se=bayes_se_list, mu0_grid=mu0_grid, sd0_grid=sd0_grid)
combined_df_nore$bayes_diff_shrunk <- bayes_deconv_list$e_mu


#########################
# Graphs

trim_level <- 0.001
xmin <- quantile(combined_df_nore$diff_shrunk, trim_level)
xmax <- quantile(combined_df_nore$diff_shrunk, 1 - trim_level)

ggplot(combined_df_nore) +
    geom_density(aes(x=diff_shrunk,
                     fill="shrunk", color="shrunk"), alpha=0.2) +
    geom_density(aes(x=diff,
                     fill="unshrunk", color="unshrunk"), alpha=0.2) +
    facet_grid(has_sigma ~ big_n) +
    xlim(xmin, xmax)

diff_threshold <- 0.5
ggplot(combined_df_nore) +
    geom_density(aes(x=diff_shrunk), fill="gray") +
    facet_grid(has_sigma ~ big_n) +
    xlab("Deconvolved relative difference (IJ - Boot) / |Boot + Boot_se|") +
    geom_vline(aes(xintercept=!!diff_threshold), color="red") +
    geom_vline(aes(xintercept=-!!diff_threshold), color="red") +
    xlim(xmin, xmax)


diff_threshold <- 0.5
{
    cat("Diff threshold: ", diff_threshold, "\n")
    group_by(combined_df_nore, has_sigma, big_n) %>%
        summarize(large_diff = 100 * mean(abs(diff_shrunk) > !!diff_threshold)) %>%
        pivot_wider(id_cols=big_n, names_from=has_sigma, values_from=large_diff)
}


ymax <- quantile(combined_df_nore$diff_se, 0.999)
ggplot(combined_df_nore) +
    geom_point(aes(x=diff, y=diff_se, color=factor(model_index))) +
    geom_density_2d(aes(x=diff, y=diff_se), contour_var="ndensity") +
    geom_abline(aes(slope=1, intercept=-!!diff_threshold), color="purple") +
    geom_abline(aes(slope=-1, intercept=-!!diff_threshold), color="purple") +
    geom_abline(aes(slope=0.5, intercept=-!!diff_threshold / 2), color="red") +
    geom_abline(aes(slope=-0.5, intercept=-!!diff_threshold / 2), color="red") +
    geom_vline(aes(xintercept=!!diff_threshold), color="black") +
    geom_vline(aes(xintercept=-!!diff_threshold), color="black") +
    facet_grid(has_sigma ~ big_n) +
    scale_y_continuous(limits=c(0, ymax + 0.001), expand = c(0, 0)) +
    theme(legend.position="none") +
    xlab("Relative difference = (IJ - Boot) / (Boot + SE)") +
    ylab("SE of relative difference")
    

#########################
# Graphs

trim_level <- 0.01
xmin <- quantile(combined_df_nore$bayes_diff_shrunk, trim_level)
xmax <- quantile(combined_df_nore$bayes_diff_shrunk, 1 - trim_level)

ggplot(combined_df_nore) +
    geom_density(aes(x=bayes_diff_shrunk,
                     fill="shrunk", color="shrunk"), alpha=0.2) +
    geom_density(aes(x=bayes_diff,
                     fill="unshrunk", color="unshrunk"), alpha=0.2) +
    facet_grid(has_sigma ~ big_n) +
    xlim(xmin, xmax)

diff_threshold <- 0.5
ggplot(combined_df_nore) +
    geom_density(aes(x=bayes_diff_shrunk), fill="gray") +
    facet_grid(has_sigma ~ big_n) +
    xlab("Deconvolved relative difference (Bayes - IJ) / |IJ + IJ_se|") +
    geom_vline(aes(xintercept=!!diff_threshold), color="red") +
    geom_vline(aes(xintercept=-!!diff_threshold), color="red") +
    xlim(xmin, xmax)


diff_threshold <- 0.5
{
    cat("Diff threshold: ", diff_threshold, "\n")
    group_by(combined_df_nore, has_sigma, big_n) %>%
        summarize(large_diff = 100 * mean(abs(bayes_diff_shrunk) > !!diff_threshold)) %>%
        pivot_wider(id_cols=big_n, names_from=has_sigma, values_from=large_diff)
}


ymax <- quantile(combined_df_nore$diff_se, 0.999)
ggplot(combined_df_nore) +
    geom_point(aes(x=bayes_diff, y=bayes_diff_se, color=factor(model_index))) +
    geom_density_2d(aes(x=bayes_diff, y=bayes_diff_se), contour_var="ndensity") +
    geom_abline(aes(slope=1, intercept=-!!diff_threshold), color="purple") +
    geom_abline(aes(slope=-1, intercept=-!!diff_threshold), color="purple") +
    geom_abline(aes(slope=0.5, intercept=-!!diff_threshold / 2), color="red") +
    geom_abline(aes(slope=-0.5, intercept=-!!diff_threshold / 2), color="red") +
    geom_vline(aes(xintercept=!!diff_threshold), color="black") +
    geom_vline(aes(xintercept=-!!diff_threshold), color="black") +
    facet_grid(has_sigma ~ big_n, scales="free") +
    scale_y_continuous(limits=c(0, ymax + 0.001), expand = c(0, 0)) +
    theme(legend.position="none") +
    xlab("Deconvolved relative difference (Bayes - IJ) / |IJ + IJ_se|") +
    ylab("SE of relative difference")
