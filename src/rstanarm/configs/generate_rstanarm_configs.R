library(ggplot2)
library(tidyverse)

base_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
config_dir <- file.path(base_dir, "src/rstanarm/configs")
stan_examples_dir <- file.path(base_dir, "example-models")
#source(file.path(base_dir, "rstanarm_lib.R"))


# Automatically process an rstanarm_config and dataset to get variables to save
# for computing the IJ.
GetIJConfig <- function(rstanarm_config, stan_examples_dir,
                        num_samples=NA, num_boots=NA,
                        exchangeable_col=c(), num_saved_re_pars=5) {
    # Append values to ij_config that will be saved in the configuration.
    ret_ij_config <- list()
    with(rstanarm_config, {
        ij_config <- list()
        ij_config$num_samples <- num_samples
        ij_config$num_boots <- num_boots
        ij_config$exchangeable_col <- exchangeable_col

        stan_data <- new.env()
        source(file.path(stan_examples_dir, subdir,
                         paste(model_name, "data.R", sep=".")), local=stan_data)
        stan_data <- as.list(stan_data)

        # Auto-generate the parameters to save
        num_obs <- stan_data[[num_obs_var]]
        ij_config$num_obs <- num_obs

        # Run the model to get the actual parameter names and levels.
        stopifnot(length(exchangeable_col) <= 1)

        df <- GetRstanarmDataFrame(stan_data, num_obs)
        stan_fun <- GetRstanarmFunction(rstan_fun)
        suppressWarnings(
            empty_fit <- stan_fun(formula(formula_str),
                                  data = df,
                                  family = eval(parse(text=family)),
                                  prior = eval(parse(text=prior)),
                                  prior_intercept = eval(parse(text=prior_intercept)),
                                  iter=1,
                                  chains=1,
                                  cores=1)
        )

        par_names <- colnames(as.matrix(empty_fit))
        re_inds <- grepl("^b\\[.*\\]", par_names)
        pars <- par_names[!re_inds]
        re_pars <- par_names[re_inds]

        if (is.na(num_saved_re_pars)) {
            num_saved_re_pars <- 5
        }

        # See this for documenation of flist:
        # https://www.rdocumentation.org/packages/lme4/versions/1.1-21/topics/mkReTrms
        keep_re_pars <- c()
        flist <- empty_fit$glmod$reTrms$flist
        for (re_level in names(flist)) {
            cat(re_level, levels(flist[[re_level]]), "\n")
            vals <- levels(flist[[re_level]])
            level_num_saved_re_pars <- min(num_saved_re_pars, length(vals))
            keep_vals <- sort(sample(vals, level_num_saved_re_pars, replace=FALSE))
            re_par_levels <- as.character(paste(re_level, keep_vals, sep=":"))
            for (re_par_level in re_par_levels) {
                keep_re_pars <- c(keep_re_pars,
                                  re_pars[str_detect(re_pars, paste0(re_par_level, "\\]"))])
            }
        }
        stopifnot(all(keep_re_pars %in% re_pars))
        keep_pars <- c(keep_re_pars, pars)
        ij_config$keep_pars <- keep_pars

        # TODO: exchangeable_col is "" when empty, not length zero.
        stopifnot(length(exchangeable_col) == 1)
        if (exchangeable_col == "") {
            exchangeable_col_name <- "independent"
        } else {
            exchangeable_col_name <- exchangeable_col
        }

        if (exchangeable_col == "") {
            ij_config$num_exchangeable_obs <- num_obs
        } else {
            ij_config$num_exchangeable_obs <- length(unique(df[[exchangeable_col]]))
        }

        ij_config$desc <-
            paste(str_replace(subdir, "\\/", "_"),
                  model_name,
                  exchangeable_col_name, sep="_")

        ret_ij_config <<- ij_config
    })
    return(ret_ij_config)
}


# Generate a list suitable for use as a configuration file.
GenerateRstanarmConfig <- function(
    model_name,
    subdir,
    formula_str,
    rstan_fun,
    family,
    num_obs_var) {
    return(list(
        model_name = model_name,
        subdir = subdir,
        formula_str = formula_str,
        rstan_fun = rstan_fun,
        family = family,
        num_obs_var = num_obs_var
    ))
}




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

