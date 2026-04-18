# Load and process results produced by 
# run_base_mcmc_rstanarm.R and run_bootstrap_mcmc_rstanarm.

library(tidyverse)
library(rstanarm)
library(gridExtra)

library(broom)

library(bayesijlib)
library(rstanarmijlib)

repo_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
base_dir <- file.path(repo_dir, "src/rstanarm")
output_dir <- file.path(base_dir, "cluster/output")

model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, "configs/", model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

GetModelDf <- function(i) {
    model_config <- model_list[[i]]
    return(with(model_config,
                data.frame(
                    model_index=i,
                    model_name=model_name,
                    rstan_fun=rstan_fun,
                    family=family,
                    dataset=dataset,
                    exchangeable_col=exchangeable_col,
                    num_exchangeable_obs=num_exchangeable_obs,
                    desc=desc
    )))
}

model_df <- do.call(rbind, lapply(1:length(model_list), GetModelDf))




#####################################
#####################################
#####################################
# Compare IJ, Bayes, and bootstrap.

# Load the files with this suffix.
file_suffix <- "0924_cluster"
boot_file_suffix <- NULL


tidy_results <- tibble()
for (i in 1:length(model_list)) { 
    model_config <- model_list[[i]]
    cat("===================\n", "Loading", model_config$desc, "\n")
    
    res_list <- LoadModelResults(
        model_config, file_suffix=file_suffix,
        boot_file_suffix=boot_file_suffix, load_lme4=FALSE)

    if (res_list$all_found) {
        base_results <- res_list$base_results
        boot_results <- res_list$boot_results
        lme4_results <- res_list$lme4_results
        
        num_obs <- model_config$num_obs
        num_exch_obs <- model_config$num_exchangeable_obs
        
        # Note that lp_mat has already been grouped by the exchangeable column
        ij_cov <- base_results$mcmc_results$ij_cov
        ij_cov_se <- base_results$mcmc_results$se$ij_cov_se
        ij_freq_se <- with(base_results$mcmc_results,
                           ComputeIJFrequentistSe(lp_mat, draws_mat))
        rownames(ij_freq_se) <- colnames(ij_freq_se) <- rownames(ij_cov)
        ij_df <- with(
            base_results$mcmc_results,
            TidyCovarianceFrame(ij_cov, ij_cov_se, "ij"))
        ij_full_se <- sqrt(ij_cov_se^2 + ij_freq_se^2)
        ij_full_se_df <- with(
            base_results$mcmc_results,
            TidyCovarianceFrame(ij_cov, ij_full_se, "ij")) %>%
            select(-ij_cov) %>%
            rename(ij_full_se=ij_se)
        ij_freq_se_df <- with(
            base_results$mcmc_results,
            TidyCovarianceFrame(ij_cov, ij_freq_se, "ij")) %>%
            select(-ij_cov) %>%
            rename(ij_freq_se=ij_se)

        if (FALSE) {
            # Compute when these are done
            boot_ij_covs <-
                boot_results$boot_ij_covs %>%
                unlist() %>%
                array(dim=c(dim(boot_results$boot_ij_covs[[1]]),
                            length(boot_results$boot_ij_covs)))
            stopifnot(max(abs(boot_ij_covs[,,1] - boot_results$boot_ij_covs[[1]])) < 1e-12) # Sanity check
            ij_boot_se <- apply(boot_ij_covs, MARGIN=c(1, 2), sd)
            rownames(ij_boot_se) <- colnames(ij_boot_se) <- rownames(ij_cov)

            ij_boot_se_df <- with(
                base_results$mcmc_results,
                TidyCovarianceFrame(ij_cov, ij_boot_se, "ij")) %>%
                select(-ij_cov) %>%
                rename(ij_boot_se=ij_se)
        }
        
        bayes_cov_se <- base_results$mcmc_results$se$bayes_cov_se
        bayes_df <- with(
            base_results$mcmc_results,
            TidyCovarianceFrame(num_exch_obs * bayes_cov, num_exch_obs * bayes_cov_se, "bayes"))

        ij_m_bayes_cov_se <- base_results$mcmc_results$se$bayes_ij_diff_se
        diff_df <- with(
            base_results$mcmc_results,
            TidyCovarianceFrame(
                num_exch_obs * bayes_cov - ij_cov,
                ij_m_bayes_cov_se, "bayes_ij_diff")) %>%
            rename(bayes_ij_diff=bayes_ij_diff_cov) %>%
            mutate(bayes_ij_z=bayes_ij_diff / bayes_ij_diff_se)
    
        join_cols <- c("row_variable", "column_variable",
                       "row_variable_name", "column_variable_name",
                       "params")
        this_tidy_result <-
            ij_df %>%
            inner_join(bayes_df, by=join_cols) %>%
            inner_join(diff_df, by=join_cols) %>%
            inner_join(ij_full_se_df, by=join_cols) %>%
            inner_join(ij_freq_se_df, by=join_cols)
     
        boot_cov <- num_exch_obs * boot_results$boot_cov
        boot_cov_se <- num_exch_obs * boot_results$boot_cov_se
        colnames(boot_cov_se) <- colnames(boot_cov)
        rownames(boot_cov_se) <- rownames(boot_cov)
        boot_df <- TidyCovarianceFrame(boot_cov, boot_cov_se, "bootstrap")
        this_tidy_result <-
            this_tidy_result %>%
            inner_join(boot_df, by=join_cols)

        this_tidy_result %>%
            select(params, ij_cov, ij_se, ij_full_se, bootstrap_se)
        
        tidy_results <- bind_rows(
            tidy_results,
            this_tidy_result %>%
                mutate(desc=model_config$desc,
                       model_index=i,
                       num_exch_obs=num_exch_obs,
                       num_obs=num_obs))
    }
}


#####################################
# Do a little post-processing

NormalizeColumn <- function(tidy_results, col) {
    tidy_results[[paste(col, "norm", sep="_")]] <-
        tidy_results[[col]] / tidy_results$cov_scale
    tidy_results[[paste(col, "norm_se", sep="_")]] <-
        tidy_results[[paste(col, "se", sep="_")]] / tidy_results$cov_scale
    return(tidy_results)
}


ComputeRelativeError <- function(tidy_results, method1, method2,
                                 se1="se", se2="se", diffname="diff") {
    cov1 <- tidy_results[[paste0(method1, "_cov")]]
    cov1_se <- tidy_results[[paste0(method1, "_", se1)]]
    cov2 <- tidy_results[[paste0(method2, "_cov")]]
    cov2_se <- tidy_results[[paste0(method2, "_", se2)]]
    
    diff_se <- sqrt(cov1_se ^ 2 + cov2_se ^ 2)
    
    # Note that the errors of IJ and Bayes are not independent; use
    # the bayes_ij_diff_se column instead.
    tidy_results[[paste(method1, method2, diffname, sep="_")]] <- cov1 - cov2
    tidy_results[[paste(method1, method2, diffname, "se", sep="_")]] <- diff_se
    tidy_results[[paste(method1, method2, diffname, "z", sep="_")]] <- (cov1 - cov2) / diff_se

    return(tidy_results)
}


# Set the denominator for "relative" differences with cov_scale
combined_df <-
    tidy_results %>%
    ComputeRelativeError("ij", "bootstrap") %>%
    ComputeRelativeError("ij", "bootstrap", se1="full_se", diffname="freqdiff") %>%
    mutate("ij_bootstrap_ijdiff_z"=ij_bootstrap_diff / ij_full_se) %>%
    ComputeRelativeError("bayes", "bootstrap") %>%
    mutate(cov_scale=abs(bootstrap_cov) + bootstrap_se) %>%  
    NormalizeColumn("bayes_ij_diff") %>%
    NormalizeColumn("bayes_bootstrap_diff") %>%
    NormalizeColumn("ij_bootstrap_diff") %>%
    mutate(is_diag=(column_variable == row_variable)) %>%
    mutate(is_re=(column_variable_name == "b" | row_variable_name == "b"))

combined_df_nore <-
    combined_df %>%
    FilterVariableName("b") %>%
    FilterVariableName("Sigma") %>%
    FilterVariableName("sigma")




#####################################
#####################################
#####################################
# Compare IJ, Bayes, and bootstrap timings.


timing_df <- data.frame()
for (i in 1:length(model_list)) { 
    model_config <- model_list[[i]]
    file_desc <- model_config$desc
    cat("===================\n", "Loading", model_config$desc, "\n")
    
    res_list <- LoadModelResults(model_config, file_suffix, load_lme4=FALSE)
    
    if (res_list$all_found) {
        base_results <- res_list$base_results
        boot_results <- res_list$boot_results
        timing_df <-
            timing_df %>%
            bind_rows(tibble(fit_time=base_results$mcmc_results$fit_time,
                             boot_fit_time=boot_results$boot_time,
                             num_boots=nrow(boot_results$boot_means)) %>%
                          mutate(desc=file_desc, model_index=i))
    }
}

summarize(timing_df,
          fit_time=as.numeric(sum(fit_time), units="secs"),
          boot_fit_time=as.numeric(sum(boot_fit_time), units="secs")) %>%
    mutate(ratio=boot_fit_time / fit_time)







#####################################
#####################################
#####################################
# See which files are missing

if (FALSE) {
  file_suffix <- "0924_cluster"
  
  for (i in 1:length(model_list)) {
    model_config <- model_list[[i]]
    file_desc <- model_config$desc
    res_list <- LoadModelResults(model_config, file_suffix)
    if (res_list$all_found) {
      cat("====================================================\n",
          "Found", file_desc, "\n")
    } else {
      cat("++++++++++++++++++++++++++++++++++++++++++++++++++++\n",
          "Missing", file_desc, "\n")
      if (is.null(res_list$base_results)) {
        cat("Base results missing\n")
      }
      if (is.null(res_list$lme4_results)) {
        cat("MMLE lme4 results missing\n")
      }
      if (is.null(res_list$boot_results)) {
        cat("Boot results missing\n")
      }
    }
  }
}


###########################################
# Save a file for fast subsequent analysis

file_date <- "1116"
output_filename <- sprintf("compiled_results_%s.Rdata", file_date)
print(sprintf("Saving to %s", file.path(output_dir, output_filename)))
save(file_suffix, combined_df, combined_df_nore, timing_df, 
     file=file.path(output_dir, output_filename))

