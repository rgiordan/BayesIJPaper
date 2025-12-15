# Load and process results produced by model_script.R.

library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)

library(bayesijlib)
library(rstanarmijlib)

rstan_options(auto_write=TRUE)

# If TRUE do not run all the bootstraps and do not save.
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")
output_dir <- file.path(base_dir, "rstanarm/cluster/output")

model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, "rstanarm/configs/", model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

output_filename <- sprintf("compiled_results_%s.Rdata", "0924")
load(file=file.path(output_dir, output_filename))


######################################
# Derive more convenient versions

# Models 7 and 13, something went wrong, the variances are very large

combined_df_nore <- 
    combined_df_nore %>%
    filter(model_index != 7) %>%
    filter(model_index != 13) %>%
    mutate(has_sigma=ifelse(grepl("[Ss]igma", params), "Scale", "Location"),
           big_n=ifelse(num_exch_obs >= 240, "N >= 240", "N < 240"),
           is_cov=ifelse(is_diag, "Variance", "Covariance"))


index_cols <- c("desc", "model_index", "is_diag", "is_re", "has_sigma", "big_n", "is_cov")
par_cols <- c("row_variable", "column_variable",
              "row_variable_name", "column_variable_name",
              "params")

combined_df_long <-
    combined_df_nore %>%
    select(-any_of(par_cols)) %>%
    pivot_longer(cols=-any_of(index_cols), names_to="method", values_to="value")



##############################
# Deconvolve

# Compute something to deconvolve.
GetMetric <- function(cov1, cov2, cov2_se) {
    return((cov1 - cov2) / (abs(cov2) + cov2_se))
}

# Simulate its variance
num_sims <- 1000
ij_diffs <- matrix(NA, nrow(combined_df_nore), num_sims)
bayes_diffs <- matrix(NA, nrow(combined_df_nore), num_sims)
for (sim in 1:num_sims) {
    ij_diffs[, sim] <-
        GetMetric(
            cov1=rnorm(nrow(combined_df_nore),
                       mean=combined_df_nore$ij_cov,
                       sd=combined_df_nore$ij_se),
            cov2=rnorm(nrow(combined_df_nore),
                       mean=combined_df_nore$bootstrap_cov,
                       sd=combined_df_nore$bootstrap_se),
            cov2_se=combined_df_nore$bootstrap_se
        )
    bayes_diffs[, sim] <-
        GetMetric(
            cov1=rnorm(nrow(combined_df_nore),
                       mean=combined_df_nore$bayes_cov,
                       sd=combined_df_nore$bayes_se),
            cov2=rnorm(nrow(combined_df_nore),
                       mean=combined_df_nore$bootstrap_cov,
                       sd=combined_df_nore$bootstrap_se),
            cov2_se=combined_df_nore$ij_se
        )
}

ij_diff_list <- GetMetric(
    cov1=combined_df_nore$ij_cov,
    cov2=combined_df_nore$bootstrap_cov,
    cov2_se=combined_df_nore$bootstrap_se)
ij_se_list <- apply(ij_diffs, MARGIN=1, sd)

bayes_diff_list <- GetMetric(
    cov1=combined_df_nore$bayes_cov,
    cov2=combined_df_nore$bootstrap_cov,
    cov2_se=combined_df_nore$bootstrap_se)
bayes_se_list <- apply(bayes_diffs, MARGIN=1, sd)


combined_df_nore$ij_diff <- ij_diff_list
combined_df_nore$ij_diff_se <- ij_se_list

combined_df_nore$bayes_diff <- bayes_diff_list
combined_df_nore$bayes_diff_se <- bayes_se_list


if (FALSE) {
    diffs_sim_df <-
        data.frame(ij_diffs) %>%
        mutate(par=1:n()) %>%
        pivot_longer(cols=-par, names_to="sim")
    head(diffs_sim_df)
    
    ggplot(diffs_sim_df) +
        geom_qq(aes(sample=value, group=par), geom="line")
}


LocalDeconvolve <- function(diff_list, se_list) {
    grid_len <- 1000
    mu0_grid <- seq(min(diff_list), max(diff_list), length.out=grid_len)
    sd0_grid <- rep(2 * min(diff(mu0_grid)), grid_len)
    deconv_list <- Deconvolve(x=diff_list, x_se=se_list, mu0_grid=mu0_grid, sd0_grid=sd0_grid)
    return(deconv_list)
}

PythonSetup()

ij_deconv_list <- LocalDeconvolve(ij_diff_list, ij_se_list)
bayes_deconv_list <- LocalDeconvolve(bayes_diff_list, bayes_se_list)

combined_df_nore$ij_bootstrap_diff_norm_shrunk <- ij_deconv_list$e_mu
combined_df_nore$bayes_bootstrap_diff_norm_shrunk <- bayes_deconv_list$e_mu


# Deconvolution graphs

trim_level <- 0.005
xmin <- with(combined_df_nore,
             quantile(c(ij_bootstrap_diff_norm_shrunk, bayes_bootstrap_diff_norm_shrunk),
                      trim_level))
xmax <- with(combined_df_nore,
             quantile(c(ij_bootstrap_diff_norm_shrunk, bayes_bootstrap_diff_norm_shrunk),
                      1 - trim_level))

grid.arrange(
    ggplot(combined_df_nore) +
        geom_density(aes(x=ij_bootstrap_diff_norm_shrunk,
                         fill="shrunk"), alpha=0.2) +
        geom_density(aes(x=ij_bootstrap_diff_norm,
                         fill="unshrunk"), alpha=0.2) +
        facet_grid(has_sigma ~ big_n) +
        xlim(xmin, xmax) + ggtitle("IJ vs bootstrap"),
    ggplot(combined_df_nore) +
        geom_density(aes(x=bayes_bootstrap_diff_norm_shrunk,
                         fill="shrunk"), alpha=0.2) +
        geom_density(aes(x=bayes_bootstrap_diff_norm,
                         fill="unshrunk"), alpha=0.2) +
        facet_grid(has_sigma ~ big_n) +
        xlim(xmin, xmax) + ggtitle("Bayes vs bootstrap"),
    ncol=2
)


grid.arrange(
    ggplot(combined_df_nore) +
        geom_point(aes(x=ij_bootstrap_diff_norm_shrunk,
                       y=ij_bootstrap_diff_norm)) +
        geom_abline(aes(slope=1, intercept=0)) +
        facet_grid(has_sigma ~ big_n) +
        xlim(xmin, xmax) + ggtitle("IJ vs bootstrap"),
    ggplot(combined_df_nore) +
        geom_point(aes(x=bayes_bootstrap_diff_norm_shrunk,
                       y=bayes_bootstrap_diff_norm)) +
        geom_abline(aes(slope=1, intercept=0)) +
        facet_grid(has_sigma ~ big_n) +
        xlim(xmin, xmax) + ggtitle("Bayes vs bootstrap"),
    ncol=2
)



##################################
# Summaries of the results

names(combined_df_nore)


group_by(combined_df_nore, is_cov, big_n) %>%
    summarize(ij_boot_err = mean(abs(ij_bootstrap_diff_norm)),
              bayes_boot_err = mean(abs(bayes_bootstrap_diff_norm))
    )

group_by(combined_df_nore, has_sigma, is_cov, big_n) %>%
    summarize(ij_boot_err = mean(abs(ij_bootstrap_diff_norm)),
              bayes_boot_err = mean(abs(bayes_bootstrap_diff_norm))
    ) %>%
    pivot_longer(cols=c(ij_boot_err, bayes_boot_err)) %>%
    ggplot() +
    geom_bar(aes(x=big_n, y=value, fill=name), stat="identity", position="dodge") +
    facet_grid(has_sigma ~ is_cov)


# Shrunken differences
norm_xbound <-
    with(combined_df_nore,
         quantile(c(abs(bayes_bootstrap_diff_norm_shrunk),
                    abs(ij_bootstrap_diff_norm_shrunk),
                    2), 0.98, na.rm=TRUE) * 1.05 )

norm_xbound_diag <-
    with(combined_df_nore %>% filter(is_diag),
         quantile(c(abs(bayes_bootstrap_diff_norm_shrunk),
                    abs(ij_bootstrap_diff_norm_shrunk),
                    2), 0.98, na.rm=TRUE) * 1.05 )


# Shrunken normalized differences (relative to bootstrap covariance)
grid.arrange(
    ggplot(combined_df_nore %>% filter(is_diag)) +
        geom_density(aes(x=(ij_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="IJ vs bootstrap"), alpha=0.2) +
        geom_density(aes(x=(bayes_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="Bayes vs bootstrap"), alpha=0.2) +
        xlim(-norm_xbound_diag, norm_xbound_diag) +
        facet_grid(has_sigma ~ big_n, scales="free") +
        ggtitle("Relative differences (frequentist variances)")
    ,
    ggplot(combined_df_nore %>% filter(!is_diag)) +
        geom_density(aes(x=(ij_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="IJ vs bootstrap"), alpha=0.2) +
        geom_density(aes(x=(bayes_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="Bayes vs bootstrap"), alpha=0.2) +
        xlim(-norm_xbound, norm_xbound) +
        facet_grid(has_sigma ~ big_n, scales="free") +
        ggtitle("Relative differences (frequentist covariances)")
    , ncol=2
)



# Shrunken normalized differences (relative to bootstrap covariance)
grid.arrange(
    ggplot(combined_df_nore %>% filter(is_diag, num_exch_obs != num_obs)) +
        geom_density(aes(x=(ij_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="IJ vs bootstrap"), alpha=0.2) +
        geom_density(aes(x=(bayes_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="Bayes vs bootstrap"), alpha=0.2) +
        xlim(-norm_xbound_diag, norm_xbound_diag) +
        facet_grid(has_sigma ~ big_n, scales="free") +
        ggtitle("Relative differences (frequentist variances)")
    ,
    ggplot(combined_df_nore %>% filter(!is_diag, num_exch_obs != num_obs)) +
        geom_density(aes(x=(ij_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="IJ vs bootstrap"), alpha=0.2) +
        geom_density(aes(x=(bayes_bootstrap_diff_norm_shrunk), y=..density..,
                         fill="Bayes vs bootstrap"), alpha=0.2) +
        xlim(-norm_xbound, norm_xbound) +
        facet_grid(has_sigma ~ big_n, scales="free") +
        ggtitle("Relative differences (frequentist covariances)")
    , ncol=2
)
