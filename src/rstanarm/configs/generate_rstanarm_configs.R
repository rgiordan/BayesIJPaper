library(ggplot2)
library(tidyverse)
library(rstanarm)
library(rstanarmijlib)

base_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
config_dir <- file.path(base_dir, "src/rstanarm/configs")
stan_examples_dir <- file.path(base_dir, "src/rstanarm/example-models")


########################
# Make JSON files with rstanarm configurations.

GenerateRstanarmIJConfig <- function(..., dataset, num_boots, exchangeable_col) {
    rstanarm_config <- GenerateRstanarmConfig(...)
    rstanarm_config$dataset <- dataset
    rstanarm_ij_config <- append(
        rstanarm_config,
        GetIJConfig(rstanarm_config, stan_examples_dir,
                    num_boots=num_boots,
                    exchangeable_col=exchangeable_col))
    return(rstanarm_ij_config)
}

AppendModelConfig <- function(config_list) {
    model_list[[length(model_list) + 1]] <<- config_list
}


#########################
# Generate configurations.

model_df <- read.csv(file.path(config_dir, "rstanarm_ij_configs.csv"),
                     header=TRUE, stringsAsFactors=FALSE)

model_list <- list()
for (i in 1:nrow(model_df)) {
    row <- model_df[i, ]
    if (row$valid) {
        cat(row$subdir, row$model_name, "\n")
        cat(row$formula_str, "\n")
        if (is.na(row$num_boots)) {
            num_boots <- NA
        } else {
            if (row$num_boots == "") {
                num_boots <- NA
            } else {
                num_boots <- as.integer(row$num_boots)
            }
        }
        flush.console()
        GenerateRstanarmIJConfig(
            model_name =  row$model_name,
            subdir =      row$subdir,
            formula =     row$formula_str,
            rstan_fun =   row$rstan_fun,
            family =      row$family,
            num_obs_var = row$num_obs_var,
            dataset = row$dataset,
            num_boots   = num_boots,
            exchangeable_col = row$exchangeable_col) %>%
            AppendModelConfig()
    }
}

length(model_list)


# Save as JSON
model_json <- jsonlite::toJSON(model_list)
outfile <- file(file.path(config_dir, "rstanarm_ij_model_list.json"), "wb")
write(model_json, file=outfile)
close(outfile)


########################################
# Get configurations for a rerun.

if (FALSE) {
    rerun_inds <- which(model_df$rerun)
    rerun_model_list <- lapply(rerun_inds, function(i) { model_list[[i]] })
    rerun_model_list[[6]]

    # Save as JSON
    rerun_model_json <- jsonlite::toJSON(rerun_model_list)
    outfile <- file(file.path(base_dir, "rerun_rstanarm_ij_model_list.json"), "wb")
    write(rerun_model_json, file=outfile)
    close(outfile)
}

