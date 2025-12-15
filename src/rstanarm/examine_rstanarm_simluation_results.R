# Load and process results produced by model_script.R.

library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)
library(broom)

# If TRUE do not run all the bootstraps and do not save.
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")

source(file.path(base_dir, "cov_se_lib.R"))
source(file.path(base_dir, "result_processing_lib.R"))
source(file.path(base_dir, "rstanarm_lib.R"))



########################
# Load combined results
model_type <- "reg_misspecified"
file_suffix <- "0608"

model_list_filename <- file.path(
    stan_examples_dir,
    sprintf("simulations/%s/%s_model_list.json", model_type, model_type))

model_list_file <- file(model_list_filename, "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)


load(file.path(base_dir, "output",
               sprintf("scaling_simulation_%s_%s_combined_results.Rdata", model_type, file_suffix)))


####################
# Run summarizing regressions

reg_results <- tibble()
#metrics <- c("bootstrap_simulation_diff", "ij_simulation_diff", "bayes_simulation_diff")
metrics <- c("bootstrap_simulation_diff", "ij_simulation_diff", "bayes_simulation_diff")
all_params <- unique(combined_df_long$params)
for (metric in metrics) { for (params in all_params) {
    reg_results <- bind_rows(
        reg_results,
        lm(log(abs(value)) ~ log(num_exch_obs) + 1,
           data=combined_df_long %>% filter(metric==!!metric, params==!!params)) %>%
            tidy() %>%
            mutate(metric=!!metric, params=!!params) %>%
            mutate(term=str_replace(term, fixed("(Intercept)"), "intercept")) %>%
            mutate(term=str_replace(term, fixed("log(num_exch_obs)"), "log_n"))
    )
}}

reg_results %>%
    filter(term == "log_n") %>%
    select(metric, params, estimate)


########################
# Scaling

combined_df_nore <-
    combined_df_nore %>%
    mutate(log_ij_simulation_diff_se=ij_simulation_diff_se / abs(ij_simulation_diff),
           log_bootstrap_simulation_diff_se=bootstrap_simulation_diff_se / abs(bootstrap_simulation_diff))

if (FALSE) {
    View(combined_df_nore[c("num_obs", "params",
                            "bayes_cov", "ij_cov", "simulation_cov",
                            "bayes_se", "ij_se", "simulation_se",
                            "bayes_simulation_reldiff", "ij_simulation_reldiff")] %>%
             arrange(params, num_obs))
}

filter(combined_df_long,
       params == "(Intercept) (Intercept)",
       metric %in% c("bayes_simulation_diff", "ij_simulation_diff"),
       num_obs == 500) %>%
    ggplot() +
    geom_histogram(aes(x=value)) +
    facet_grid(~ metric)


################

if (FALSE) {
    # Some of these are weird
    weird_ones <- combined_df_nore %>%
        filter(params == "x x") %>%
        filter(simulation_cov < bayes_cov) %>%
        select(sim, num_obs)
    
    for (i in 1:nrow(weird_ones)) {
        sim <- weird_ones[i,]$sim
        num_obs <- weird_ones[i, ]$num_obs
        log_filename <- sprintf("slurm*simulation_simulations_reg_misspecified_sim%d_n%d-run_model_script_simulation*.out", sim, num_obs)
        cat("tail ", log_filename, "\n")
    }
    for (i in 1:nrow(weird_ones)) {
        sim <- weird_ones[i,]$sim
        num_obs <- weird_ones[i, ]$num_obs
        output_filename <- sprintf("simulations_reg_misspecified_sim%d_n%d_sim_mcmc_reg_misspecified_0608.Rdata", sim, num_obs)
        cat("rm ", output_filename, " --interactive=never\n")
    }
    
    combined_df_long <- anti_join(combined_df_long, weird_ones, by=c("sim", "num_obs"))
    combined_df_nore <- anti_join(combined_df_nore, weird_ones, by=c("sim", "num_obs"))
}


#############

diff_metrics <- sprintf("%s_simulation_diff", c("ij", "bootstrap", "bayes"))
reldiff_metrics <- sprintf("%s_simulation_reldiff", c("ij", "bootstrap", "bayes"))
normdiff_metrics <- sprintf("%s_simulation_normdiff", c("ij", "bootstrap", "bayes"))

ggplot(combined_df_long %>% filter(metric %in% diff_metrics),
       aes(x=num_exch_obs, y=abs(value), group=sim)) +
    geom_point() + geom_line() +
    facet_grid(row_variable ~ column_variable, scales="free") +
    scale_x_log10() + scale_y_log10() +
    facet_grid(params ~ metric)

grid.arrange(
    ggplot(combined_df_nore, aes(x=num_exch_obs, group=sim)) +
        geom_point(aes(y=abs(ij_simulation_diff), color="ij")) +
        geom_line(aes(y=abs(ij_simulation_diff), color="ij")) +
        facet_grid(row_variable ~ column_variable, scales="free") +
        scale_x_log10() + scale_y_log10(),
    ggplot(combined_df_nore, aes(x=num_exch_obs, group=sim)) +
        geom_point(aes(y=abs(bootstrap_simulation_diff), color="boot")) +
        geom_line(aes(y=abs(bootstrap_simulation_diff), color="boot")) +
        facet_grid(row_variable ~ column_variable, scales="free") +
        scale_x_log10() + scale_y_log10(),
    ggplot(combined_df_nore, aes(x=num_exch_obs, group=sim)) +
        geom_point(aes(y=abs(bayes_simulation_diff), color="bayes")) +
        geom_line(aes(y=abs(bayes_simulation_diff), color="bayes")) +
        facet_grid(row_variable ~ column_variable, scales="free") +
        scale_x_log10() + scale_y_log10()
    , ncol=3
)

# These indicate the problem.
# Take a close look at a term that should be estimated well
#params <- "x x"
#params <- "(Intercept) (Intercept)"
params <- "log_sigma log_sigma"

ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=simulation_cov - 2 * simulation_se, ymax=simulation_cov + 2 * simulation_se, fill="sim"), alpha=0.2) +
    geom_ribbon(aes(ymin=bayes_cov - 2 * bayes_se, ymax=bayes_cov + 2 * bayes_se, fill="bayes"), alpha=0.2) +
    geom_ribbon(aes(ymin=bootstrap_cov - 2 * bootstrap_se, ymax=bootstrap_cov + 2 * bootstrap_se, fill="bootstrap"), alpha=0.2) +
    geom_ribbon(aes(ymin=ij_cov - 2 * ij_se, ymax=ij_cov + 2 * ij_se, fill="ij"), alpha=0.2) +
    geom_line(aes(y=bayes_cov, color="bayes")) +
    geom_line(aes(y=bootstrap_cov, color="bootstrap")) +
    geom_line(aes(y=ij_cov, color="ij")) +
    geom_line(aes(y=simulation_cov, color="sim")) +
    facet_grid(. ~ sim, scales="free")



ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=ij_cov - 2 * ij_se, ymax=ij_cov + 2 * ij_se, fill="ij"), alpha=0.2) +
    geom_ribbon(aes(ymin=simulation_cov - 2 * simulation_se, ymax=simulation_cov + 2 * simulation_se, fill="sim"), alpha=0.2) +
    geom_line(aes(y=ij_cov, color="ij")) +
    geom_line(aes(y=simulation_cov, color="sim")) +
    facet_grid(. ~ sim, scales="free")

ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=bayes_cov - 2 * bayes_se, ymax=bayes_cov + 2 * bayes_se, fill="bayes"), alpha=0.2) +
    geom_ribbon(aes(ymin=simulation_cov - 2 * simulation_se, ymax=simulation_cov + 2 * simulation_se, fill="sim"), alpha=0.2) +
    geom_line(aes(y=bayes_cov, color="bayes")) +
    geom_line(aes(y=simulation_cov, color="sim")) +
    facet_grid(. ~ sim, scales="free")

ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=bootstrap_cov - 2 * bootstrap_se, ymax=bootstrap_cov + 2 * bootstrap_se, fill="bootstrap"), alpha=0.2) +
    geom_ribbon(aes(ymin=simulation_cov - 2 * simulation_se, ymax=simulation_cov + 2 * simulation_se, fill="sim"), alpha=0.2) +
    geom_line(aes(y=bootstrap_cov, color="bootstrap")) +
    geom_line(aes(y=simulation_cov, color="sim")) +
    facet_grid(. ~ sim, scales="free")

ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=bootstrap_cov - 2 * bootstrap_se, ymax=bootstrap_cov + 2 * bootstrap_se, fill="bootstrap"), alpha=0.2) +
    geom_ribbon(aes(ymin=ij_cov - 2 * ij_se, ymax=ij_cov + 2 * ij_se, fill="ij"), alpha=0.2) +
    geom_line(aes(y=bootstrap_cov, color="bootstrap")) +
    geom_line(aes(y=ij_cov, color="ij")) +
    facet_grid(. ~ sim, scales="free")

ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=bayes_cov - 2 * bayes_se, ymax=bayes_cov + 2 * bayes_se, fill="bayes"), alpha=0.2) +
    geom_ribbon(aes(ymin=bootstrap_cov - 2 * bootstrap_se, ymax=bootstrap_cov + 2 * bootstrap_se, fill="bootstrap"), alpha=0.2) +
    geom_ribbon(aes(ymin=ij_cov - 2 * ij_se, ymax=ij_cov + 2 * ij_se, fill="ij"), alpha=0.2) +
    geom_line(aes(y=bayes_cov, color="bayes")) +
    geom_line(aes(y=bootstrap_cov, color="bootstrap")) +
    geom_line(aes(y=ij_cov, color="ij")) +
    facet_grid(. ~ sim, scales="free")

ggplot(combined_df_nore %>% filter(params == !!params),
       aes(x=sqrt(num_exch_obs), group=sim)) +
    geom_ribbon(aes(ymin=simulation_cov - 2 * simulation_se, ymax=simulation_cov + 2 * simulation_se, fill="sim"), alpha=0.2) +
    geom_line(aes(y=simulation_cov, color="sim")) +
    facet_grid(. ~ sim, scales="free")


# This is a good plot
ggplot(combined_df_long %>%
           filter(is_diag) %>%
           filter(metric %in% c("ij_simulation_diff",
                                "bootstrap_simulation_diff",
                                "bayes_simulation_diff")),
       aes(x=1 / num_exch_obs, group=sim, color=factor(sim))) +
    geom_hline(aes(yintercept=0), color="blue") +
    geom_point(aes(y=value)) +
    geom_line(aes(y=value)) +
    scale_x_reverse() +
    facet_grid(params ~ metric, scales="free")



# This is a good plot
ggplot(combined_df_long %>%
           filter(is_diag) %>%
           filter(metric %in% c("ij_simulation_diff",
                                "bootstrap_simulation_diff",
                                "bayes_simulation_diff")),
       aes(x=1 / num_exch_obs, y=abs(value),
           group=sim, color=factor(sim))) +
    geom_hline(aes(yintercept=0), color="blue") +
    geom_point() + geom_line() +
    scale_x_reverse() +
    facet_grid(params ~ metric, scales="free")


ggplot(combined_df_long %>%
           filter(is_diag) %>%
           filter(metric %in% c("ij_simulation_diff",
                                "bootstrap_simulation_diff",
                                "bayes_simulation_diff")),
       aes(x=1 / num_exch_obs, y=num_exch_obs * value, group=sim)) +
    geom_hline(aes(yintercept=0), color="blue") +
    geom_point() + geom_line() +
    facet_grid(params ~ metric, scales="free")

ggplot(combined_df_long %>%
           filter(is_diag) %>%
           filter(metric %in% c("ij_cov",
                                "bootstrap_cov",
                                "bayes_cov")),
       aes(x=1 / num_exch_obs, y=num_obs * value, group=sim)) +
    geom_hline(aes(yintercept=0), color="blue") +
    geom_point() + geom_line() +
    facet_grid(params ~ metric, scales="free")



grid.arrange(
    PlotComparisonPoints(combined_df_nore %>% filter(num_obs == 500, params == "log_Sigma log_Sigma"),
                         method1="bootstrap", method2="simulation"),
    PlotComparisonPoints(combined_df_nore %>% filter(num_obs == 500, params == "log_Sigma log_Sigma"),
                         method1="ij", method2="simulation"),
    PlotComparisonPoints(combined_df_nore %>% filter(num_obs == 500, params == "log_Sigma log_Sigma"),
                         method1="bayes", method2="simulation"),
    PlotComparisonPoints(combined_df_nore %>% filter(num_obs == 500, params != "log_Sigma log_Sigma"),
                         method1="bootstrap", method2="simulation"),
    PlotComparisonPoints(combined_df_nore %>% filter(num_obs == 500, params != "log_Sigma log_Sigma"),
                         method1="ij", method2="simulation"),
    PlotComparisonPoints(combined_df_nore %>% filter(num_obs == 500, params != "log_Sigma log_Sigma"),
                         method1="bayes", method2="simulation"),
    ncol=3
)



ggplot(combined_df_nore, aes(x=num_exch_obs, group=sim)) +
    geom_point(aes(y=abs(ij_simulation_diff), color="ij")) +
    geom_line(aes(y=abs(ij_simulation_diff), color="ij")) +
    geom_point(aes(y=abs(bootstrap_simulation_diff), color="boot")) +
    geom_line(aes(y=abs(bootstrap_simulation_diff), color="boot")) +
    facet_grid(params ~ ., scales="free") +
    scale_x_log10() + scale_y_log10()




# An ok plot
ggplot(combined_df_nore %>% filter(is_diag),
       aes(x=1/(num_exch_obs), group=sim)) +
    geom_point(aes(y=ij_simulation_diff, color="ij")) +
    geom_line(aes(y=ij_simulation_diff, color="ij")) +
    geom_errorbar(aes(ymin = ij_simulation_diff - 2 * ij_simulation_diff_se,
                      ymax = ij_simulation_diff + 2 * ij_simulation_diff_se,
                      color="ij")) +
    geom_point(aes(y=bootstrap_simulation_diff, color="bootstrap")) +
    geom_line(aes(y=bootstrap_simulation_diff, color="bootstrap")) +
    geom_errorbar(aes(ymin = (bootstrap_simulation_diff - 2 * bootstrap_simulation_diff_se),
                      ymax = (bootstrap_simulation_diff + 2 * bootstrap_simulation_diff_se),
                      color="bootstrap")) +
    facet_grid(row_variable ~ column_variable, scales="free")

ggplot(combined_df_nore %>% filter(is_diag),
       aes(x=1/(num_exch_obs), group=sim)) +
    geom_point(aes(y=abs(ij_simulation_diff), color="ij")) +
    geom_line(aes(y=abs(ij_simulation_diff), color="ij")) +
    geom_errorbar(aes(ymin = abs(ij_simulation_diff) - 2 * ij_simulation_diff_se,
                      ymax = abs(ij_simulation_diff) + 2 * ij_simulation_diff_se,
                      color="ij")) +
    geom_point(aes(y=abs(bootstrap_simulation_diff), color="bootstrap")) +
    geom_line(aes(y=abs(bootstrap_simulation_diff), color="bootstrap")) +
    geom_errorbar(aes(ymin = (abs(bootstrap_simulation_diff) - 2 * bootstrap_simulation_diff_se),
                      ymax = (abs(bootstrap_simulation_diff) + 2 * bootstrap_simulation_diff_se),
                      color="bootstrap")) +
    facet_grid(row_variable ~ column_variable, scales="free")


ggplot(combined_df_nore %>% filter(is_diag),
       aes(x=1/(num_exch_obs), group=sim)) +
    geom_point(aes(y=ij_simulation_diff, color="ij")) +
    geom_line(aes(y=ij_simulation_diff, color="ij")) +
    geom_errorbar(aes(ymin = ij_simulation_diff - 2 * ij_simulation_diff_se,
                      ymax = ij_simulation_diff + 2 * ij_simulation_diff_se,
                      color="ij")) +
    facet_grid(row_variable ~ column_variable, scales="free")

###############################
# Regressions


summary(lm(log(abs(ij_simulation_diff)) ~ log(num_exch_obs) + params,
           weights=1/(log_ij_simulation_diff_se^2),
           combined_df_nore %>% filter(is_diag)))
summary(lm(log(abs(bootstrap_simulation_diff)) ~ log(num_exch_obs) + params,
           weights=1/(log_bootstrap_simulation_diff_se^2),
           combined_df_nore %>% filter(is_diag)))

summary(lm(log(abs(ij_simulation_diff)) ~ log(num_exch_obs):params + params,
           weights=1/(log_ij_simulation_diff_se^2),
           combined_df_nore %>% filter(is_diag)))
summary(lm(log(abs(bootstrap_simulation_diff)) ~ log(num_exch_obs):params + params,
           weights=1/(log_bootstrap_simulation_diff_se^2),
           combined_df_nore %>% filter(is_diag)))


lm_df <- combined_df_nore %>% filter(is_diag)
num_sims <- length(unique(lm_df$sim))
ij_lm0 <- summary(lm(log(abs(ij_simulation_diff)) ~ log(num_exch_obs) + params, lm_df))
boot_lm0 <- summary(lm(log(abs(bootstrap_simulation_diff)) ~ log(num_exch_obs) + params, lm_df))

num_boots <- 200
ij_coeffs <- matrix(NA, num_boots, nrow(coefficients(ij_lm0)))
boot_coeffs <- matrix(NA, num_boots, nrow(coefficients(boot_lm0)))
for (b in 1:num_boots) {
    sim_boot <- rmultinom(1, num_sims, rep(1 / num_sims, num_sims))[, 1]
    w_df <- data.frame(sim=unique(lm_df$sim), w=sim_boot)
    boot_w <- inner_join(lm_df, w_df, by="sim")$w
    ij_lmw <- summary(lm(log(abs(ij_simulation_diff)) ~ log(num_exch_obs) + params,
                         lm_df, weights=boot_w))
    boot_lmw <- summary(lm(log(abs(bootstrap_simulation_diff)) ~ log(num_exch_obs) + params,
                           lm_df, weights=boot_w))
    ij_coeffs[b, ] <- coefficients(ij_lmw)[, "Estimate"]
    boot_coeffs[b, ] <- coefficients(boot_lmw)[, "Estimate"]
}

ij_se <- apply(ij_coeffs, FUN=sd, MARGIN=2)
boot_se <- apply(boot_coeffs, FUN=sd, MARGIN=2)

ij_coeff <- data.frame(coefficients(ij_lm0))
ij_coeff$BootSe <- ij_se

boot_coeff <- data.frame(coefficients(boot_lm0))
boot_coeff$BootSe <- boot_se

ij_coeff
boot_coeff



###############################
# Old plots


diff_range <-
    c(
        with(combined_df_nore,
             min(log(abs(ij_simulation_diff)),
                 log(abs(bootstrap_simulation_diff)))),
        with(combined_df_nore,
             max(log(abs(ij_simulation_diff)),
                 log(abs(bootstrap_simulation_diff)))))


ggplot(combined_df_nore %>% filter(is_diag),
       aes(x=log(num_exch_obs), group=sim)) +
    geom_point(aes(y=log(abs(ij_simulation_diff)), color="ij")) +
    geom_line(aes(y=log(abs(ij_simulation_diff)), color="ij")) +
    geom_errorbar(aes(ymin = log(abs(ij_simulation_diff)) - 2 * log_ij_simulation_diff_se,
                      ymax = log(abs(ij_simulation_diff)) + 2 * log_ij_simulation_diff_se,
                      color="ij")) +
    geom_point(aes(y=log(abs(bootstrap_simulation_diff)), color="bootstrap")) +
    geom_line(aes(y=log(abs(bootstrap_simulation_diff)), color="bootstrap")) +
    geom_errorbar(aes(ymin = log(abs(bootstrap_simulation_diff)) - 2 * log_bootstrap_simulation_diff_se,
                      ymax = log(abs(bootstrap_simulation_diff)) + 2 * log_bootstrap_simulation_diff_se,
                      color="bootstrap")) +
    facet_grid(row_variable ~ column_variable, scales="free") +
    ylim(diff_range[1], diff_range[2])
