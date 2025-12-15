library(ggplot2)
library(tidyverse)

base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
config_dir <- file.path(base_dir, "rstanarm/configs")
stan_examples_dir <- file.path(base_dir, "example-models")
source(file.path(base_dir, "rstanarm_lib.R"))

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
row <- filter(model_df, subdir == "ARM/Ch.13", model_name == "earnings_latin_square")

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
outfile <- file(file.path(base_dir, "rstanarm_ij_model_list.json"), "wb")
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


######################################################
# Generate configurations for simulated datasets.

AppendSimModelConfig <- function(config_list) {
    sim_model_list[[length(sim_model_list) + 1]] <<- config_list
}

sim_model_list <- list()
for (model_config in model_list) {
    sim_model_config <- model_config
    sim_model_config$model_name <-
        paste0(model_config$model_name, "_SIMULATED_IJ")
    exchangeable_col <- sim_model_config$exchangeable_col
    if (exchangeable_col == "") {
        exchangeable_col_name <- "independent"
    } else {
        exchangeable_col_name <- exchangeable_col
    }
    sim_model_config$desc <-
        with(sim_model_config,
             paste(str_replace(subdir, "\\/", "_"),
                   model_name,
                   exchangeable_col_name, sep="_")
        )
    AppendSimModelConfig(sim_model_config)
}


# Save as JSON
model_json <- jsonlite::toJSON(sim_model_list)
outfile <- file(file.path(base_dir, "rstanarm_ij_simulation_model_list.json"), "wb")
write(model_json, file=outfile)
close(outfile)




#########################
# Test loading and running

if (FALSE) {
    model_list_file <- file(file.path(base_dir, "rstanarm_ij_model_list.json"), "rb")
    load_model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
    close(model_list_file)

    for (rstanarm_ij_config in load_model_list) {
        if (rstanarm_ij_config$subdir == "ARM/Ch.13") {
            cat("=====================\n", rstanarm_ij_config$desc, "\n", sep="")
            RunRstanarmBaseMCMC(rstanarm_ij_config, stan_examples_dir)
        }
    }
}
