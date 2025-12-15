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

#output_filename <- sprintf("compiled_results_%s.Rdata", "0924")
#output_filename <- sprintf("compiled_results_%s.Rdata", "1104")
output_filename <- sprintf("compiled_results_%s.Rdata", "1107_incomplete")
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



# Checking
if (FALSE) {
    combined_df_nore %>% filter(model_index == 65) %>% View()
}

index_cols <- c("desc", "model_index", "is_diag", "is_re", "has_sigma", "big_n", "is_cov")
par_cols <- c("row_variable", "column_variable",
              "row_variable_name", "column_variable_name",
              "params")

combined_df_long <-
    combined_df_nore %>%
    select(-any_of(par_cols)) %>%
    pivot_longer(cols=-any_of(index_cols), names_to="method", values_to="value")

unique(combined_df_long$method)


####################################
# Examine the bootstrap vs ij tests

for (z_col in c("ij_bootstrap_diff_z",
                "ij_bootstrap_freqdiff_z",
                "ij_bootstrap_bootdiff_z",
                "ij_bootstrap_ijdiff_z")) {
    cat("\n\n==========================\n", z_col, "\n\n")
    rej_level <- 0.1
    combined_df_nore %>%
        group_by(big_n, is_cov) %>%
        summarize(rej_prop=mean(abs(get(z_col)) > qnorm(1 - rej_level / 2)),
                  num=n()) %>%
        print()
    
    combined_df_nore %>%
        group_by(big_n, has_sigma) %>%
        summarize(rej_prop=mean(abs(get(z_col)) > qnorm(1 - rej_level / 2)),
                  num=n()) %>%
        print()
}

z_col <- "ij_bootstrap_ijdiff_z"
unif_z <- combined_df_nore %>% pull(z_col) %>% pnorm()
ggplot(combined_df_nore %>% mutate(unif_z=pnorm(get(z_col)))) +
    geom_histogram(aes(x=unif_z, y=..density..), fill="gray", color="black", bins=10) +
    facet_grid(big_n ~ is_cov)

ggplot(combined_df_nore %>% mutate(unif_z=pnorm(get(z_col)))) +
    geom_histogram(aes(x=unif_z, y=..density..), fill="gray", color="black", bins=10) +
    facet_grid(big_n ~ has_sigma)


###################################
# Graph summaries


#View(combined_df_nore %>% select(params, ij_cov, bayes_cov, bootstrap_cov, bayes_ij_diff))
norm_xbound <-
    with(combined_df_nore,
         quantile(c(abs(bayes_bootstrap_diff_norm),
                    abs(ij_bootstrap_diff_norm),
                    2), 0.98, na.rm=TRUE) * 1.05 )

norm_xbound_diag <-
    with(combined_df_nore %>% filter(is_diag),
         quantile(c(abs(bayes_bootstrap_diff_norm),
                    abs(ij_bootstrap_diff_norm),
                    2), 0.98, na.rm=TRUE) * 1.05 )


table(combined_df_long$has_sigma)

names(combined_df_nore)

# Normalized differences (relative to bootstrap covariance).
# These are the graphs we wnat.
ggplot(combined_df_nore %>% filter(is_diag)) +
    geom_density(aes(x=(ij_bootstrap_diff_norm), y=..density..,
                     fill="IJ vs bootstrap", color="IJ vs bootstrap"), alpha=0.2) +
    geom_density(aes(x=(bayes_bootstrap_diff_norm), y=..density..,
                     fill="Bayes vs bootstrap", color="Bayes vs bootstrap"), alpha=0.2) +
    xlim(-norm_xbound_diag, norm_xbound_diag) +
    facet_grid(has_sigma ~ big_n, scales="free") +
    ggtitle("Relative differences (frequentist variances)")


ggplot(combined_df_nore %>% filter(!is_diag)) +
    geom_density(aes(x=(ij_bootstrap_diff_norm), y=..density..,
                     fill="IJ vs bootstrap", color="IJ vs bootstrap"), alpha=0.2) +
    geom_density(aes(x=(bayes_bootstrap_diff_norm), y=..density..,
                     fill="Bayes vs bootstrap", color="Bayes vs bootstrap"), alpha=0.2) +
    xlim(-norm_xbound, norm_xbound) +
    facet_grid(has_sigma ~ big_n, scales="free") +
    ggtitle("Relative differences (frequentist covariances)")


# log-log plot
ggplot(combined_df_nore) +
    geom_point(aes(x=abs(bootstrap_cov + 1e-3), y=abs(bayes_cov + 1e-3), color="bayes")) +
    geom_point(aes(x=abs(bootstrap_cov + 1e-3), y=abs(ij_cov +  + 1e-3), color="ij")) +
    geom_abline(aes(slope=1, intercept=0)) +
    facet_grid(big_n ~ is_cov) +
    scale_x_log10() + scale_y_log10()


ggplot(combined_df_nore %>% filter(is_diag)) +
    geom_point(aes(x=abs(bootstrap_cov + 1e-3), y=abs(bayes_cov + 1e-3), color="bayes")) +
    geom_point(aes(x=abs(bootstrap_cov + 1e-3), y=abs(ij_cov +  + 1e-3), color="ij")) +
    geom_abline(aes(slope=1, intercept=0)) +
    facet_grid(big_n ~ has_sigma) +
    scale_x_log10() + scale_y_log10()


##################
# Look using QQ plots

x <- combined_df_nore$ij_bootstrap_diff_norm
y <- combined_df_nore$bayes_bootstrap_diff_norm

ggplot(with(combined_df_nore,
            GetQuantileSamples(ij_bootstrap_diff_norm,
                               bayes_bootstrap_diff_norm))) +
    geom_point(aes(x=x, y=y)) +
    geom_abline(aes(slope=1, intercept=0)) +
    xlab("IJ bootstrap normdiff") +
    ylab("Bayes bootstrap normdiff")


#####################
# How do the delta method and bootstrap IJ ses compare?

ggplot(combined_df_nore) +
    geom_point(aes(x=ij_full_se, y=ij_boot_se, color=factor(model_index))) +
    geom_abline(aes(slope=1, intercept=0)) +
    scale_x_log10() + scale_y_log10()

# How do the MCMC and frequentist errors compare?
ggplot(combined_df_nore) +
    geom_point(aes(x=ij_freq_se, y=ij_se, color=factor(model_index))) +
    geom_abline(aes(slope=1, intercept=0)) +
    scale_x_log10() + scale_y_log10()


if (FALSE) {
    combined_df_nore %>%
        mutate(ij_se_boot_err=log10(ij_boot_se) - log10(ij_full_se),
               ij_se_boot_abs_err=abs(ij_se_boot_err)) %>%
        filter(is_diag, ij_se_boot_abs_err > log10(1.5)) %>%
        arrange(desc(ij_se_boot_abs_err)) %>%
        select(model_index, params, ij_se_boot_err, ij_boot_se, ij_full_se, ij_freq_se, ij_se) %>%
        View()
}
