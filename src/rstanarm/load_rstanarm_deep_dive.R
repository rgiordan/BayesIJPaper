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




model_type <- "reg_misspecified"
file_suffix <- "0608"

model_list_filename <- file.path(
    stan_examples_dir,
    sprintf("simulations/%s/%s_model_list.json", model_type, model_type))

model_list_file <- file(model_list_filename, "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)


#####################
# Load some results

i <- which(sapply(model_list, function(x) x$model_name == "reg_misspecified_sim17_n500"))
model_config <- model_list[[i]]

base_model_filename <-
    file.path(base_dir, "output",
              sprintf("%s_base_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
boot_model_filename <-
    file.path(base_dir, "output",
              sprintf("%s_boot_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))
sim_model_filename <-
    file.path(base_dir, "output",
              sprintf("%s_sim_mcmc_%s_%s.Rdata", model_config$desc, model_type, file_suffix))

sim_results <- LoadIntoEnv(sim_model_filename)
base_results <- LoadIntoEnv(base_model_filename)
boot_results <- LoadIntoEnv(boot_model_filename)

View(this_tidy_result[c("params", sprintf("%s_cov", c("ij", "bayes", "bootstrap", "simulation")))])

stop()
#####################################
# Run a command interactively.

script <- "run_mcmc_simulations_rstanarm.R"
args <- paste0("--base_dir=", base_dir, " ",
               "--num_cores=4 --num_mcmc_chains=4 ",
               "--model_list_filename=rstanarm_ij_model_list.json ",
               "--model_list_ind=51 ",
               "--save_filename=/tmp/foo.Rdata ",
               "  --force  ",
               "--initial_fit_filename=",
               file.path(base_dir, "output", "ARM_Ch.13_earnings_vary_si_eth_base_mcmc_0523_cluster.Rdata")) %>%
    str_split("\\s+") %>%
    unlist()
source(file.path(base_dir, script), echo=TRUE, verbose=TRUE)


#####################################
# Load a particular model.

load(file.path(base_dir, "output", "simulation_combined_results.Rdata"))

i <- 54
model_config <- model_list[[i]]
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
    orig_model_filename <- 
        file.path(base_dir, "output",
                  sprintf("%s_base_mcmc_%s.Rdata", model_config$desc, "0523_cluster"))
    orig_results <- LoadIntoEnv(orig_model_filename)
    
    rstan_fit <- orig_results$rstan_fit
    df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
    df_sim <- SimulateDatasetFromFit(rstan_fit, df, model_config)
} else {
    cat("\nData file missing.\n",
        "\n", sim_model_filename, " found: ", file.exists(sim_model_filename), "\n",
        "\n", boot_model_filename, " found: ", file.exists(boot_model_filename), "\n",
        "\n", base_model_filename, " found: ", file.exists(base_model_filename), "\n")
}





##########################
# Let's try our own data.

DrawRandomCovMat <- function(d, varnames=NULL) {
    a <- matrix(rnorm(d ^ 2), d, d)
    mat <- 5 * diag(d) + t(a) %*% a
    if (!is.null(varnames)) {
        rownames(mat) <- varnames
        colnames(mat) <- varnames
    }
    return(mat)
}

df <- data.frame(x1=runif(12), x2=10 * runif(12), y=100 * runif(12),
                 z1=rep(1:4, each=3), z2=rep(1:4))
formula_str <- "y ~ x1 + (1 + x2 | z1) + (1 + x1 | z2)"

# Do this with an actual fit:
#beta <- fixef(rstan_fit)
# vcov_list <- VarCorr(rstan_fit)
# This is the format of VarCorr()'s output.

vcov_list <- list(
    z1=DrawRandomCovMat(2, c("(Intercept)", "x2")),
    z2=DrawRandomCovMat(2, c("(Intercept)", "x1")))
attr(vcov_list, "sc") <- 1.5

beta <- runif(ncol(glform$X))



SimulateDataset(formula_str, df, beta, vcov_list, gaussian())
SimulateDataset(formula_str, df, beta, vcov_list, binomial())
SimulateDataset(formula_str, df, beta, vcov_list, poisson())


########## 
library(lme4)
glm_result <- lmer(formula(model_config$formula_str), df, verbose=TRUE)
colnames(model.matrix(glm_result))

