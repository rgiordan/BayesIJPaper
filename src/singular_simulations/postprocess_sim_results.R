library(tidyverse)
library(bayesijlib)
library(rstanarmijlib)
library(gridExtra)
library(broom)


options(mc.cores=4)
rstan_options(auto_write=TRUE)
base_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
results_dir <- file.path(base_dir, "src/singular_simulations")
output_dir <- file.path(base_dir, "paper/experiment_data/simulations")


seed_val <- 100
re_dim <- 100
obs_per_re <- 100

desc <- sprintf("redim%d_obsperre%d_seed%d", re_dim, obs_per_re, seed_val)

# These results should be found in
# src/singular_simulations
sim_filename <- file.path(results_dir, sprintf("super_simple_simulation_sim_results_%s.Rdata", desc))
base_filename <- file.path(results_dir, sprintf("super_simple_simulation_base_results_%s.Rdata", desc))
load(base_filename)
load(sim_filename)

############################

lp_draws <- log_lik(rstanarm_result)
num_exch_obs <- ncol(lp_draws)
#pars <- colnames(par_draws)[!grepl("^b\\[", colnames(par_draws))]

ij_cov <- ComputeIJCovariance(lp_draws, par_draws)
bayes_cov <- cov(par_draws, par_draws)

ij_freq_se <- ComputeIJFrequentistSe(lp_draws, par_draws)
ij_se <- se_results$ij_cov_se
ij_full_se <- sqrt(ij_freq_se^2 + ij_se^2)

bayes_freq_se <- ComputeIJFrequentistSe(par_draws, par_draws)
bayes_se <- se_results$bayes_cov_se
bayes_full_se <- sqrt(bayes_freq_se^2 + bayes_se^2)

###################################

sim_draws <-
    sim_means %>%
    pivot_wider(id_cols="sim", names_from="par", values_from="mean") %>%
    select(-sim) %>%
    as.matrix()

sim_cov <- cov(sim_draws, sim_draws)
sim_se <- GetCovarianceMatrixSE(sim_draws, sim_draws, correlated_samples=FALSE)
rownames(sim_se) <- colnames(sim_se) <- rownames(sim_cov)

cbind(num_exch_obs * diag(sim_cov),
      diag(ij_cov),
      num_exch_obs * diag(bayes_cov))


#####################

keep_pars <- c("(Intercept)", "x", "log_sigma")
keep_cols <- rownames(ij_cov) %in% keep_pars

ij_covs <- array(unlist(ij_cov_list), dim=c(dim(ij_cov_list[[1]]), length(ij_cov_list)))
stopifnot(max(abs(ij_covs[, ,1] - ij_cov_list[[1]])) < 1e-12)
ij_cov_boot_se <- apply(ij_covs, MARGIN=c(1,2), sd)


########################


cov_long_df <-
    bind_rows(
        CovarianceMatrixToDataframe(ij_cov, remove_repeats=TRUE) %>%
            mutate(method="ij", metric="mean"),
        CovarianceMatrixToDataframe(num_exch_obs * bayes_cov, remove_repeats=TRUE) %>%
            mutate(method="bayes", metric="mean"),
        CovarianceMatrixToDataframe(num_exch_obs * sim_cov, remove_repeats=TRUE) %>%
            mutate(method="sim", metric="mean"),
        CovarianceMatrixToDataframe(ij_full_se, remove_repeats=TRUE) %>%
            mutate(method="ij", metric="se"),
        CovarianceMatrixToDataframe(num_exch_obs * bayes_full_se, remove_repeats=TRUE) %>%
            mutate(method="bayes", metric="se"),
        CovarianceMatrixToDataframe(num_exch_obs * sim_se, remove_repeats=TRUE) %>%
            mutate(method="sim", metric="se")
    )

# parameter labels
unique(cov_long_df$row_variable)
GetVariableLabel <- function(variable, variable_label) {
    data.frame(variable, variable_label, stringsAsFactors=FALSE)
}

var_label_df <- bind_rows(
    GetVariableLabel("x", "\\beta"),
    GetVariableLabel("log_sigma", "\\log \\sigma_y"),
    GetVariableLabel("log_Sigma[z:(Intercept),(Intercept)]", "\\log \\sigma_\\mu")
)


cov_wide_df <-
    cov_long_df %>%
    pivot_wider(id_cols=c(row_variable, column_variable),
                names_from=c(method, metric), values_from=value) %>%
    filter(row_variable == column_variable) %>%
    rename(variable=row_variable) %>%
    inner_join(var_label_df, by="variable")


cov_wide2_df <-
    cov_long_df %>%
    pivot_wider(id_cols=c(row_variable, column_variable, method),
                names_from=metric, values_from=value) %>%
    mutate(se=case_when((row_variable == "log_Sigma[z:(Intercept),(Intercept)]" &
                         column_variable == "log_Sigma[z:(Intercept),(Intercept)]" &
                         method == "bayes") ~ 0, TRUE ~ se)) %>%
    filter(row_variable == column_variable) %>%
    rename(variable=row_variable) %>%
    inner_join(var_label_df, by="variable") %>%
    mutate(variable_label=factor(variable_label))

levels(cov_wide2_df$variable_label) <-
    TeX(sprintf("$%s$", levels(cov_wide2_df$variable_label)))

# ggplot(cov_wide2_df %>% filter(variable %in% plot_vars)) +
#     geom_bar(aes(y=mean, fill=method, x=method),
#              position="dodge", stat="Identity") +
#     geom_errorbar(aes(ymin=mean - 2 * se, ymax=mean + 2 * se, x=method)) +
#     facet_grid(. ~ variable_label, scales="free", labeller=label_parsed) +
#     ylab("Covariance") +
#     theme(legend.position="None")
#

num_mcmc_draws <- nrow(par_draws)
num_sims <- nrow(sim_draws)
save(cov_long_df, cov_wide_df, cov_wide2_df,
     re_dim, obs_per_re, num_exch_obs, seed_val, num_mcmc_draws, num_sims,
     file=file.path(output_dir, "simpler_sim_results.Rdata"))


stop()
