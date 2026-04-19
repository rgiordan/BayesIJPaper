# Load and process results produced by model_script.R.

library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)

library(bayesijlib)
library(rstanarmijlib)

rstan_options(auto_write=TRUE)

# If TRUE do not run all the bootstraps and do not save.
repo_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/"
base_dir <- file.path(repo_dir, "src/bayes")
stan_examples_dir <- file.path(base_dir, "example-models")

# TODO: this should now be BayesIJPaper/src/rstanarm
output_dir <- file.path(base_dir, "rstanarm/cluster/output")
writing_dir <- file.path(repo_dir, "writing/bayes/")


model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, "rstanarm/configs/", model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

#output_filename <- sprintf("compiled_results_%s.Rdata", "0924")
#output_filename <- sprintf("compiled_results_%s.Rdata", "1104")
output_filename <- sprintf("compiled_results_%s.Rdata", "1116")
load(file=file.path(output_dir, output_filename))



####################################
# Model description dataframe

GetModelDFRow <- function(i) {
    model_config <- model_list[[i]] %>% SetConfigDefaults()
    data.frame(model_index=i,
               num_exchangeable_obs=model_config$num_exchangeable_obs,
               rstan_fun=model_config$rstan_fun,
               family=model_config$family,
               model_name=model_config$model_name,
               dataset=model_config$dataset,
               num_samples=model_config$num_samples,
               num_boots=model_config$num_boots,
               independent=model_config$exchangeable_col == "",
               stringsAsFactors=FALSE)
}

model_df <- do.call(bind_rows, lapply(1:length(model_list), GetModelDFRow))

# Remove test models.  Because we inner join later this will remove them from the paper as well.
model_df <- filter(model_df, model_name != "test")
model_df <- filter(model_df, model_name != "test_rstanarm")

# Models 7 and 13, something went wrong, the variances are very large.  Also,
# electric_1c was too slow to run 200 bootstraps.
model_df <- model_df %>%
    filter(model_index != 7) %>%
    filter(model_index != 12) %>%
    filter(model_index != 65)

combined_df_nore <-
    combined_df_nore %>%
    filter(model_index != 7) %>%
    filter(model_index != 13) %>%
    filter(model_index != 65) %>%
    mutate(params_full=paste(row_variable, column_variable))


######################################
# Make our own relative error columns

index_cols <- c("params", "params_full", "desc", "model_index", "is_diag")
par_cols <- c("row_variable", "column_variable",
              "row_variable_name", "column_variable_name", "is_re")
stopifnot(all(index_cols %in% names(combined_df_nore)))
stopifnot(all(par_cols %in% names(combined_df_nore)))
stopifnot(all(!combined_df_nore$is_re))

base_metric_cols <-
    c(sprintf("%s_cov", c("ij", "bayes", "bootstrap")),
      sprintf("%s_se", c("ij", "bayes", "bootstrap")),
      sprintf("ij_%s", c("full_se", "freq_se")))
stopifnot(all(base_metric_cols %in% names(combined_df_nore)))

combined_df_nore <- combined_df_nore[, c(index_cols, par_cols, base_metric_cols)]

combined_df_nore <-
    combined_df_nore %>%
    mutate(ij_bootstrap_diff_norm=(ij_cov - bootstrap_cov) / (abs(bootstrap_cov) + bootstrap_se)) %>%
    mutate(bayes_bootstrap_diff_norm=(bayes_cov - bootstrap_cov) / (abs(bootstrap_cov) + bootstrap_se)) %>%
    mutate(ij_bootstrap_diff_z=(ij_cov - bootstrap_cov) / sqrt(bootstrap_se^2 + ij_se^2))


######################################
# Derive a long-pivoted version

combined_df_long <-
    combined_df_nore %>%
    select(-any_of(par_cols)) %>%
    pivot_longer(cols=-any_of(index_cols), names_to="metric", values_to="value")

head(combined_df_long)

####################################
# More descriptive variable names

# Method labels
unique(combined_df_long$metric)
GetMetricLabel <- function(metric, metric_label) {
    data.frame(metric, metric_label, stringsAsFactors=FALSE)
}

# Note that metrics not included here will be discarded, which is ok
# because we wouldn't plot them anyway.
metric_label_df <- bind_rows(
    GetMetricLabel("ij_bootstrap_diff_norm", "IJ relative error"),
    GetMetricLabel("bayes_bootstrap_diff_norm", "Bayes relative error"),
    #GetMetricLabel("ij_bootstrap_freqdiff_z", "IJ error z score"),
    GetMetricLabel("ij_bootstrap_diff_z", "IJ error z score (no IJ freq)"),
    #GetMetricLabel("ij_full_se", "IJ standard error"),
    GetMetricLabel("ij_se", "IJ standard error"),
    GetMetricLabel("bayes_se", "Bayes standard error"),
    GetMetricLabel("bootstrap_se", "Bootstrap standard error"),
    GetMetricLabel("ij_cov", "IJ covariance"),
    GetMetricLabel("bayes_cov", "Bayes covariance"),
    GetMetricLabel("bootstrap_cov", "Bootstrap covariance")
)

stopifnot(metric_label_df$metric %>% unique() %>% length() == nrow(metric_label_df))
stopifnot(all(metric_label_df$metric %in% unique(combined_df_long$metric)))
#metric_label_df$metric[!(metric_label_df$metric %in% unique(combined_df_long$metric))]

# Join with the labels and name some factors.
combined_df_long_labeled <-
    combined_df_long %>%
    inner_join(metric_label_df, by="metric") %>%
    mutate(metric_label=factor(metric_label)) %>%
    inner_join(model_df, by="model_index") %>%
    mutate(has_sigma_label=ifelse(grepl("[Ss]igma", params),
              "Log scale parameter", "Regression parameter"),
           big_n_label=ifelse(num_exchangeable_obs >= 240, "N >= 240", "N < 240"),
           is_cov_label=ifelse(is_diag, "Variance estimate", "Cross-covariance estimate"),
           independent_label=ifelse(independent, "Independent data", "Grouped data")
    )


combined_df_long_labeled$independent_label <- factor(
    combined_df_long_labeled$independent,
    levels=c(TRUE, FALSE),
    labels=c("Independent observations", "Correlated observations"))
table(combined_df_long_labeled$independent_label)

combined_df_long_labeled$is_glmm_label <- factor(
    combined_df_long_labeled$rstan_fun,
    levels=c("stan_glm", "stan_glmer"),
    labels=c("Fixed effects only", "Random and fixed effects"))
table(combined_df_long_labeled$is_glmm_label)

table(combined_df_long_labeled$family)
combined_df_long_labeled$family_label <- factor(
    combined_df_long_labeled$family,
    levels=c("gaussian()", "binomial(link=\"logit\")"),
    labels=c("Linear regression", "Logistic regression"))
table(combined_df_long_labeled$family_label)


combined_df_long_labeled %>% filter(model_index == 65) %>% nrow() /
    combined_df_nore %>% filter(model_index == 65) %>% nrow()

colnames(combined_df_long_labeled)
# combined_df_wide_labeled <-
#     combined_df_long_labeled %>%
#     select(-metric_label) %>%
#     pivot_wider(id_cols=c(-value, -metric), names_from=metric, values_from=value)

combined_df_wide_labeled <-
  combined_df_long_labeled %>%
  select(-metric_label) %>%
  pivot_wider(names_from=metric, values_from=value)

##########################################
# Get a list of distinct models

if (FALSE) {
  # Ugh, are earning chapters 6 and 7 actually different models?
  combined_df_wide_labeled %>% 
    group_by(model_name, dataset, independent_label, desc) %>% 
    summarize(n=n()) %>% 
    group_by(model_name, dataset, independent_label) %>%
    summarize(n=n()) %>%
    filter(n > 1)
  
  combined_df_wide_labeled %>% 
    group_by(model_name, dataset, independent_label, desc) %>% 
    summarize(n=n()) %>% 
    View()
  
  combined_df_wide_labeled %>% 
    group_by(model_name, dataset, desc) %>% 
    summarize(n=n()) %>% 
    group_by(model_name, dataset) %>%
    summarize(n=n()) %>%
    filter(n > 1)
  
  combined_df_wide_labeled %>% 
    group_by(model_name, dataset) %>%
    summarize(n=n()) %>%
    nrow()
}


  


##########################################
# Save a file with all the ARM results

paper_filename <- sprintf("arm_results_original_data_061721.Rdata")
save(combined_df_long_labeled,
     combined_df_wide_labeled,
     model_df,
     timing_df,
     file=file.path(writing_dir, "data/ARM", paper_filename))






stop()
