
LoadModelResults <- function(model_config, file_suffix,
                             load_lme4=TRUE, load_boot=TRUE,
                             base_file_suffix=NULL,
                             boot_file_suffix=NULL,
                             lme4_file_suffix=NULL) {
    base_file_suffix <- paste0(
      "base_mcmc_",
      ifelse(is.null(base_file_suffix), file_suffix, base_file_suffix))
    lme4_file_suffix <- paste0(
      "lme4_",
      ifelse(is.null(lme4_file_suffix), file_suffix, lme4_file_suffix))
    boot_file_suffix <- paste0(
      "boot_mcmc_",
      ifelse(is.null(boot_file_suffix), file_suffix, boot_file_suffix))

    file_desc <- model_config$desc

    base_model_filename <- file.path(
        output_dir, sprintf("%s_%s.Rdata", file_desc, base_file_suffix))
    lme4_model_filename <- file.path(
        output_dir, sprintf("%s_%s.Rdata", file_desc, lme4_file_suffix))
    boot_model_filename <- file.path(
        output_dir, sprintf("%s_%s.Rdata", file_desc, boot_file_suffix))

    all_found <- TRUE
    SafeLoad <- function(filename) {
        if (file.exists(filename)) {
            return(LoadIntoEnv(filename))
        } else {
            print(sprintf("File %s missing", filename))
            all_found <<- FALSE
            return(NULL)
        }
    }

    result <-
      list(base_results=SafeLoad(base_model_filename))
    if (load_boot) {
      result$boot_results <- SafeLoad(boot_model_filename)
    }
    if (load_lme4) {
      result$lme4_results <- SafeLoad(lme4_model_filename)
    }
    result$all_found <- all_found
    return(result)
}


