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

model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

sim_model_list_filename <- "rstanarm_ij_simulation_model_list.json"
sim_model_list_file <- file(file.path(base_dir, sim_model_list_filename), "rb")
sim_model_list <- jsonlite::fromJSON(sim_model_list_file, simplifyDataFrame=FALSE)
close(sim_model_list_file)


##################################

GetSimIndex <- function(model_config) {
    matches <- sapply(sim_model_list, function(x) { 
            x$model_name == paste0(model_config$model_name, "_SIMULATED_IJ") &&
            x$subdir == model_config$subdir
        })
    sum(matches)
    if (sum(matches) == 0) {
        stop("No matches")   
    }
    if (sum(matches) > 1) {
        stop("Multiple matches")   
    }
    return(which(matches))
}


#####################################
# See which models loaded and how long they took.

for (i in 1:length(model_list)) {
    model_config <- model_list[[i]]
    cat("\n\n\n===========================\n===========================\n",
        model_config$desc, "\n")

    # The names get confusing.  The models from sim_model_config contain the base MCMC computed
    # on simulated data.  The models from model_config contain simulations from the MCMC output
    # on the non-simulated data.
    sim_i <- GetSimIndex(model_config)
    sim_model_config <- sim_model_list[[sim_i]]

    sim_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_sim_mcmc_%s.Rdata", model_config$desc, "0523_cluster"))
    base_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_base_mcmc_%s.Rdata", sim_model_config$desc, "0526_cluster"))
    boot_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_boot_mcmc_%s.Rdata", sim_model_config$desc, "0526_cluster"))

    if (file.exists(sim_model_filename) &&
        file.exists(base_model_filename) &&
        file.exists(boot_model_filename)) {
        cat("Ok.\n")
    } else {
        cat("\nData file missing for index", i, "\n",
            "\n", sim_model_filename, " found: ", file.exists(sim_model_filename), "\n",
            "\n", boot_model_filename, " found: ", file.exists(boot_model_filename), "\n",
            "\n", base_model_filename, " found: ", file.exists(base_model_filename), "\n")
    }
}



#####################################
# Make a combined dataframe.

combined_df <- tibble()
for (i in 1:length(model_list)) {
    model_config <- model_list[[i]]
    cat("\n\n\n===========================\n===========================\n",
        model_config$desc, "\n")

    # The names get confusing.  The models from sim_model_config contain the base MCMC computed
    # on simulated data.  The models from model_config contain simulations from the MCMC output
    # on the non-simulated data.
    sim_i <- GetSimIndex(model_config)
    sim_model_config <- sim_model_list[[sim_i]]
    
    sim_model_filename <-
            file.path(base_dir, "output",
                      sprintf("%s_sim_mcmc_%s.Rdata", model_config$desc, "0523_cluster"))
    base_model_filename <- 
        file.path(base_dir, "output",
                  sprintf("%s_base_mcmc_%s.Rdata", sim_model_config$desc, "0526_cluster"))
    boot_model_filename <- 
        file.path(base_dir, "output",
                  sprintf("%s_boot_mcmc_%s.Rdata", sim_model_config$desc, "0526_cluster"))
    
    if (file.exists(sim_model_filename) &&
        file.exists(base_model_filename) &&
        file.exists(boot_model_filename)) {
        sim_results <- LoadIntoEnv(sim_model_filename)
        base_results <- LoadIntoEnv(base_model_filename)
        boot_results <- LoadIntoEnv(boot_model_filename)

        print(base_results$modelfit_summary[,c("mean", "n_eff", "Rhat")])

        num_obs <- model_config$num_obs
        num_exch_obs <- model_config$num_exchangeable_obs
        
        ij_df <- with(base_results, TidyCovarianceFrame(ij_cov * num_exch_obs, ij_cov_se * num_exch_obs, "ij"))
        bayes_df <- with(base_results, TidyCovarianceFrame(bayes_cov, bayes_cov_se, "bayes"))
        boot_df <- with(boot_results, TidyCovarianceFrame(boot_cov, boot_cov_se, "bootstrap"))
        sim_df <- with(sim_results, TidyCovarianceFrame(sim_cov, sim_cov_se, "simulation"))
        join_cols <- c("row_variable", "column_variable", "row_variable_name", "column_variable_name", "params")
        this_tidy_result <-
            ij_df %>%
            inner_join(bayes_df, by=join_cols) %>%
            inner_join(boot_df, by=join_cols) %>%
            inner_join(sim_df, by=join_cols) %>%
            mutate(desc=model_config$desc,
                   num_obs=num_obs,
                   num_exch_obs=num_exch_obs,
                   model_index=i,
                   sim_model_index=sim_i)
        combined_df <- bind_rows(combined_df, this_tidy_result)
        
    } else {
        cat("\nData file missing.\n",
            "\n", sim_model_filename, " found: ", file.exists(sim_model_filename), "\n",
            "\n", boot_model_filename, " found: ", file.exists(boot_model_filename), "\n",
            "\n", base_model_filename, " found: ", file.exists(base_model_filename), "\n")
    }
}


head(combined_df)
orig_combined_df <- combined_df

###################
# Process and save

combined_df <-
    orig_combined_df %>%
    ComputeRelativeError("ij", "simulation") %>%
    ComputeRelativeError("bayes", "simulation") %>%
    ComputeRelativeError("bootstrap", "simulation") %>%
    NormalizeCovariance("ij") %>%
    NormalizeCovariance("bootstrap") %>%
    NormalizeCovariance("bayes") %>%
    NormalizeCovariance("simulation") %>%
    mutate(is_diag=(column_variable == row_variable)) %>%
    mutate(is_re=(column_variable_name == "b" || row_variable_name == "b"))

combined_df_nore <-
    combined_df %>%
    FilterVariableName("b") %>%
    FilterVariableName("Sigma") %>%
    FilterVariableName("sigma")


if (FALSE) {
    # Run manually if you want to overwrite results.
    save(combined_df, combined_df_nore,
         file=file.path(base_dir, "output", "simulation_combined_results.Rdata"))
}

########################
# Plots

rel_xbound <- with(combined_df_nore,
               max(c(abs(ij_simulation_reldiff),
                     abs(bootstrap_simulation_reldiff),
                     abs(bayes_simulation_reldiff), 2)),
               na.rm=TRUE)
norm_xbound <- with(combined_df_nore,
                    quantile(c(abs(ij_simulation_normdiff),
                               abs(bootstrap_simulation_normdiff),
                               abs(bayes_simulation_normdiff), 2),
                             0.99,
                             na.rm=TRUE) * 1.05)
num_bins <- 60

grid.arrange(
    ggplot(combined_df_nore) +
        geom_histogram(aes(x=ij_simulation_reldiff), bins=num_bins) +
        xlim(-rel_xbound, rel_xbound) +
        ggtitle("IJ vs simulation relative difference")
,    
    ggplot(combined_df_nore) +
        geom_histogram(aes(x=bootstrap_simulation_reldiff), bins=num_bins) +
        xlim(-rel_xbound, rel_xbound) +
        ggtitle("Bootstrap vs simulation relative difference")
,    
    ggplot(combined_df_nore) +
        geom_histogram(aes(x=bayes_simulation_reldiff), bins=num_bins) +
        xlim(-rel_xbound, rel_xbound) +
        ggtitle("Bayes vs simulation relative difference")
, ncol=3
)


grid.arrange(
ggplot(combined_df_nore) +
    geom_point(aes(x=bayes_simulation_normdiff, y=ij_simulation_normdiff)) +
    geom_abline(aes(intercept=0, slope=1)) +
    xlim(-norm_xbound, norm_xbound) +
    ylim(-norm_xbound, norm_xbound) +
    ggtitle("IJ vs Bayes normalized difference")
,
ggplot(combined_df_nore) +
    geom_point(aes(x=bootstrap_simulation_normdiff, y=ij_simulation_normdiff)) +
    geom_abline(aes(intercept=0, slope=1)) +
    xlim(-norm_xbound, norm_xbound) +
    ylim(-norm_xbound, norm_xbound) +
    ggtitle("IJ vs Bootstrap normalized difference")
, ncol=2)

norm_xbound2 <- with(combined_df_nore,
                    quantile(c(abs(ij_simulation_normdiff),
                               abs(bootstrap_simulation_normdiff),
                               abs(bayes_simulation_normdiff), 2),
                             0.85,
                             na.rm=TRUE) * 1.05)

ggplot(combined_df_nore) +
    geom_density_2d(aes(x=bootstrap_simulation_normdiff, y=ij_simulation_normdiff)) +
    geom_abline(aes(intercept=0, slope=1)) +
    xlim(-norm_xbound2, norm_xbound2) +
    ylim(-norm_xbound2, norm_xbound2) +
    ggtitle("IJ vs simulation normalized difference")


#ggplot(combined_df_nore %>% mutate(nobs_cut=cut(1 / sqrt(num_exch_obs), breaks=20))) +
ggplot(combined_df_nore %>% mutate(nobs_cut=cut(num_exch_obs, breaks=20))) +
    geom_violin(aes(x=factor(nobs_cut), y=abs(ij_simulation_reldiff))) +
    geom_hline(aes(yintercept=2), color="red", lwd=1) +
    ggtitle("IJ vs simulation relative difference")



#####################################
# Generate and save a bunch of plots

method1 <- "ij"
method2 <- "bootstrap"
metric <- "cov"
metric_se <- "se"
tidy_result <- this_df


plt <- PlotComparisonPoints(this_df, "simulation", "ij") +
    facet_grid(is_diag ~ .)
print(plt)

    ggtitle(MakeTitle("IJ vs simulation"))
print(plt)


for (i in unique(combined_df$model_index)) {
    model_config <- model_list[[i]]
    cat("\n\n\n===========================\n===========================\n",
        model_config$desc, "\n")
    this_df <- filter(combined_df_nore, model_index == i)

    plot_filename <- sprintf("/tmp/sim_vs_all_%s.png", model_config$desc)
    cat("Saving to\n", plot_filename, "\n")
    plot_png <- png(plot_filename, width=1000, height=700)
    MakeTitle <- function(header) {
        sprintf("%s\n%s\nModel index %d\nnum_obs = %d\tnum_exch_obs = %d",
                header, model_config$desc, i,
                num_obs, num_exch_obs)
    }
    grid.arrange(
        PlotComparisonPoints(this_df, "simulation", "ij") +
            theme(legend.position="none") +
            ggtitle(MakeTitle("IJ vs simulation")) +
            facet_grid(is_diag ~ .)
        ,
        PlotComparisonPoints(this_df, "simulation", "bootstrap") +
            theme(legend.position="none") +
            ggtitle(MakeTitle("Bootstrap vs simulation")) +
            facet_grid(is_diag ~ .)
        ,
        PlotComparisonPoints(this_df, "simulation", "bayes") +
            theme(legend.position="none") +
            ggtitle(MakeTitle("Bayes vs simulation")) +
            facet_grid(is_diag ~ .)
        , ncol=3)
    dev.off()

    
    plot_filename <- sprintf("/tmp/sim_vs_all_normalized_%s.png", model_config$desc)
    cat("Saving to\n", plot_filename, "\n")
    plot_png <- png(plot_filename, width=1000, height=700)
    MakeTitle <- function(header) {
        sprintf("%s\n%s\nModel index %d\nnum_obs = %d\tnum_exch_obs = %d",
                header, model_config$desc, i,
                num_obs, num_exch_obs)
    }
    grid.arrange(
        PlotComparisonPoints(this_df, "simulation", "ij", "normcov", "normse") +
            theme(legend.position="none") +
            ggtitle(MakeTitle("IJ vs simulation"))
        ,
        PlotComparisonPoints(this_df, "simulation", "bootstrap", "normcov", "normse") +
            theme(legend.position="none") +
            ggtitle(MakeTitle("Bootstrap vs simulation"))
        ,
        PlotComparisonPoints(this_df, "simulation", "bayes", "normcov", "normse") +
            theme(legend.position="none") +
            ggtitle(MakeTitle("Bayes vs simulation"))
        , ncol=3)
    dev.off()
}    

