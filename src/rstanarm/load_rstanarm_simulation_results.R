# Load and process results produced by model_script.R.

library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)

# If TRUE do not run all the bootstraps and do not save.
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")

source(file.path(base_dir, "cov_se_lib.R"))
source(file.path(base_dir, "result_processing_lib.R"))
source(file.path(base_dir, "rstanarm_lib.R"))

# model_type <- "reg"
# file_suffix <- "0601"

# model_type <- "re_reg"
# file_suffix <- "0601"

model_type <- "reg_misspecified"
file_suffix <- "0608"

# model_type <- "bin_reg_re"
# file_suffix <- "0601"

# model_type <- "bin_reg_re_misspecified"
# file_suffix <- "0601"

##################
# Load model file.

model_list_filename <- file.path(
    stan_examples_dir,
    sprintf("simulations/%s/%s_model_list.json", model_type, model_type))

model_list_file <- file(model_list_filename, "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)


#####################################
# See which models loaded and how long they took.

sapply(model_list, function(x) { x$model_name })

num_found <- 0
for (i in 1:length(model_list)) {
    model_config <- model_list[[i]]
    cat("\n\n\n===========================\n===========================\n",
        model_config$desc, "\n")

    base_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_base_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
    boot_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_boot_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
    sim_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_sim_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
    
    file.exists(base_model_filename)
    file.exists(boot_model_filename)
    file.exists(sim_model_filename)
    
    if (file.exists(sim_model_filename) &&
        file.exists(base_model_filename) &&
        file.exists(boot_model_filename)) {
        cat("Ok.\n")
        num_found <- num_found + 1
    } else {
        cat("\nData file missing for index", i, "\n",
            "\n", sim_model_filename, " found: ", file.exists(sim_model_filename), "\n",
            "\n", boot_model_filename, " found: ", file.exists(boot_model_filename), "\n",
            "\n", base_model_filename, " found: ", file.exists(base_model_filename), "\n")
    }
}
cat("Num found", num_found, "\n")


#####################################
# Make a combined dataframe.

posterior_df <- tibble()
combined_df <- tibble()
for (i in 1:length(model_list)) {
    model_config <- model_list[[i]]
    cat("\n\n\n===========================\n===========================\n",
        model_config$desc, "\n")

    base_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_base_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
    boot_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_boot_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
    sim_model_filename <-
        file.path(base_dir, "output",
                  sprintf("%s_sim_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
    
    if (file.exists(sim_model_filename) &&
        file.exists(base_model_filename) &&
        file.exists(boot_model_filename)) {
        sim_results <- LoadIntoEnv(sim_model_filename)
        base_results <- LoadIntoEnv(base_model_filename)
        boot_results <- LoadIntoEnv(boot_model_filename)

        print(base_results$modelfit_summary[,c("mean", "sd", "n_eff", "Rhat")])

        num_obs <- model_config$num_obs
        num_exch_obs <- model_config$num_exchangeable_obs
        
        ij_df <- with(base_results,
                      TidyCovarianceFrame(
                          ij_cov * (num_exch_obs^2),
                          ij_cov_se * (num_exch_obs^2), "ij"))
        bayes_df <- with(base_results,
                         TidyCovarianceFrame(
                             num_exch_obs * bayes_cov,
                             num_exch_obs * bayes_cov_se, "bayes"))
        boot_df <- with(boot_results,
                        TidyCovarianceFrame(
                            num_exch_obs * boot_cov,
                            num_exch_obs * boot_cov_se, "bootstrap"))
        sim_df <- with(sim_results,
                       TidyCovarianceFrame(
                           num_exch_obs * sim_cov,
                           num_exch_obs * sim_cov_se, "simulation"))
        sim_number <- str_extract(model_config$model_name, "sim[0-9]*") %>% str_remove("^sim") %>% as.numeric()
        join_cols <- c("row_variable", "column_variable", "row_variable_name", "column_variable_name", "params")
        this_tidy_result <-
            ij_df %>%
            inner_join(bayes_df, by=join_cols) %>%
            inner_join(boot_df, by=join_cols) %>%
            inner_join(sim_df, by=join_cols) %>%
            mutate(desc=model_config$desc,
                   model_name=model_config$model_name,
                   sim=sim_number,
                   num_obs=num_obs,
                   num_exch_obs=num_exch_obs,
                   model_index=i)
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

if (FALSE) {
    # Load a single result that was successful
    i <-
        unique(combined_df[c("num_obs", "model_index")]) %>%
        filter(num_obs == max(num_obs)) %>%
        `[[`('model_index') %>%
        min()
    
    draws_mat <- base_results$draws_mat
    colnames(draws_mat)
    
    par_colnames <- c("(Intercept)", "x", "b[(Intercept) z:1]", "log_Sigma[z:(Intercept),(Intercept)]")
    i <- 4
    ggplot() +
        geom_density(aes(x=draws_mat[, par_colnames[i]])) +
        ggtitle(par_colnames[i])
    
    
    i <- 4
    ggplot() +
        geom_qq(aes(sample=draws_mat[, par_colnames[i]])) +
        ggtitle(par_colnames[i])
}


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

# Save a long version of the combined dataset.
data_cols <-
    unique(c(
        tidyselect::vars_select(names(combined_df_nore), contains("bayes")),
        tidyselect::vars_select(names(combined_df_nore), contains("boot")),
        tidyselect::vars_select(names(combined_df_nore), contains("ij")),
        tidyselect::vars_select(names(combined_df_nore), contains("simulation"))
    ))

id_cols <- setdiff(names(combined_df_nore), data_cols)
combined_df_long <-
    combined_df_nore %>%
    pivot_longer(cols=matches(data_cols), names_to="metric")


if (FALSE) {
    # Run manually if you want to overwrite results.
    save(combined_df, combined_df_nore, combined_df_long,
         file=file.path(base_dir, "output",
                        sprintf("scaling_simulation_%s_%s_combined_results.Rdata", model_type, file_suffix)))
}


