library(ggplot2)
library(bayesplot)
library(rstanarm)
library(rstan)
library(tidyverse)
library(gridExtra)
library(GLMMmisc)

num_cores <- 4
options(mc.cores=num_cores)


########################
# Get IJ

base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
rstan_options(auto_write=TRUE)
source(file.path(base_dir, "result_processing_lib.R"))
source(file.path(base_dir, "cov_se_lib.R"))
source(file.path(base_dir, "run_ij_lib.R"))
source(file.path(base_dir, "rstanarm_lib.R"))



#############################
# we're going to do some checks on the simulation generated model


model_prefix <- "bin_reg_re_misspecified"
formula_str <- "y ~ 1 + x + (1 | z)"
generative_formula_str <- "y ~ 1 + x + I(x^3) + (1 | z)"
rstan_fun <- "stan_glmer"
model_seed <- sum(utf8ToInt(model_prefix))
subdir <- file.path("simulations", model_prefix)

# Set the ground truth
beta <- c(0.05, 0.3, 0.07)
vcov_list <- list("z"=matrix(0.15, 1, 1))
#attr(vcov_list, "sc") <- sigma
ground_truth <- list(beta=beta, model_seed=model_seed,
                     vcov_list=vcov_list)


if (FALSE) {
    i <- 10000000
    model_configs <- GenerateSimulationConfigAndData(
        rstan_fun=rstan_fun,
        family_str="binomial(link=\"logit\")",
        ground_truth=ground_truth,
        model_prefix=paste0(model_prefix, "_sim", i),
        subdir=subdir,
        formula_str=formula_str,
        generative_formula_str=generative_formula_str,
        exchangeable_col="z",
        n_min=50, n_max=500, num_sims=10)
}
model_config <- model_configs[[length(model_configs)]]

ij_result <- RunRstanarmBaseMCMC(
    model_config,
    stan_examples_dir,
    num_mcmc_chains=4,
    num_cores=4)

ij_result$bayes_cov

ij_cov_se <- ij_result$se_envr$draw_ij_cov_se
bayes_cov_se <- ij_result$se_envr$draw_bayes_cov_se
num_exch_obs <- model_config$num_exchangeable_obs

join_cols <- c("row_variable", "column_variable", "row_variable_name", "column_variable_name", "params")
comb_df <- inner_join(
    with(ij_result, TidyCovarianceFrame(ij_cov * num_exch_obs, ij_cov_se * num_exch_obs, "ij")),
    with(ij_result, TidyCovarianceFrame(bayes_cov, bayes_cov_se, "bayes")),
    by=join_cols) %>%
    FilterVariableName("b") %>%
    FilterVariableName("Sigma") %>%
    FilterVariableName("sigma") %>%
    mutate(is_diag=(column_variable == row_variable))


# 
# View(comb_df)
# View(TidyCovarianceFrame(ij_result$bayes_cov, bayes_cov_se, "bayes"))
# View(comb_df[, c("bayes_cov", "params")])

PlotComparisonPoints(comb_df %>% filter(is_diag), "ij", "bayes")
comb_df[, c("params", "bayes_cov", "ij_cov", "bayes_se", "ij_se")]

##############################
# Set model

num_chains <- 4
stan_examples_dir <- file.path(base_dir, "example-models")

# Load the model list

#model_list_file <- file(file.path(base_dir, "rstanarm_ij_model_list.json"), "rb")
model_list_file <- file(file.path(base_dir, "rstanarm_ij_simulation_model_list.json"), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)

lapply(model_list, function(x) { paste(x$subdir, x$model_name, x$rstan_fun) })

#model_config <- model_list[[1]]
#model_config <- model_list[[64]]
#model_config <- model_list[[19]]
#model_config <- model_list[[3]]


##################
################ 

rstanarm_ij_config <- model_list[[51]] %>% SetConfigDefaults()
df <- LoadRstanarmDataframe(rstanarm_ij_config, stan_examples_dir)
ij_results <- LoadIntoEnv(file.path(base_dir, "output",
                                    paste0(model_config$desc,
                                           "_base_mcmc_0523_cluster.Rdata")))

summary(ij_results$rstan_fit)
as.matrix(ij_results$rstan_fit, pars="sigma")
sigma(ij_results$rstan_fit)

foo <- SimulateDataset(ij_results$rstan_fit, df, rstanarm_ij_config)
plot(foo$x, foo$y)



###########################
###########################
# Simulate data.  Note that this will not work with interactions in the random effects.

# 1, 64, 19
model_config <- model_list[[51]] %>% SetConfigDefaults()
df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
head(df)

rstan_fit <- RunRstanarmBaseMCMC(model_config, stan_examples_dir, num_cores=4)

model_config$formula_str


#model_filename <- sprintf("%s_%s.Rdata", model_config$desc, file_suffix)
#full_model_filename <- file.path(base_dir, "output", model_filename)
full_model_filename <- "/tmp/test_19.Rdata"
ij_results <- LoadIntoEnv(full_model_filename)
ij_results$rstan_fit

model_config$num_samples <- 2000


rstan_fit <- ij_results$rstan_fit

head(df_sim)
head(df)

if (FALSE) {
    grid.arrange(
        qplot(df_sim$y, geom="histogram"),
        qplot(df$y, geom="histogram"),
        ncol=2
    )
}




##################################
##################################
# Old stuff


###########################
###########################
# Get MAP?  Not easy



############################

womensrole_bglm_opt$covmat
stanfit_opt <- womensrole_bglm_opt$stanfit
stanfit_opt@theta_tilde

length(womensrole_bglm_opt$log_g)
womensrole_bglm_opt$log_p

########
object <- womensrole_bglm_opt

opt <- object$algorithm == "optimizing"
mer <- !is.null(object$glmod) # used stan_(g)lmer
stanfit <- object$stanfit
family <- object$family
y <- object$y
x <- object$x
nvars <- ncol(x)
nobs <- NROW(y)
ynames <- if (is.matrix(y)) rownames(y) else names(y)

is_betareg <- is.beta(family$family)
stanmat <- stanfit$theta_tilde

# nlist --- use this!



womensrole_bglm_opt <- stan_glm(cbind(agree, disagree) ~ education + gender,
                                data = womensrole,
                                family = binomial(link = "logit"), 
                                prior = student_t(df = 7), 
                                prior_intercept = student_t(df = 7),
                                seed = 12345,  iter=10000, hessian=TRUE,
                                algorithm="optimizing")

# What are these?  I think the draws are from the inverse Hessian.

# See line 285 of stan_glm.R
draws_opt <- as.matrix(womensrole_bglm_opt)
lp_opt <- log_lik(womensrole_bglm_opt)

hinv <- womensrole_bglm_opt$covmat

map_fit <- womensrole_bglm_opt$stanfit
map_fit_par <- colMeans(draws_opt) # I think it doesn't save the actual optimum

dummy_modelfit_ij <- womensrole_bglm_1$stanfit

# Get the optimal unconstrained parameters
# dummy_modelfit_ij <- GetDummyStanfit(model_ij, stan_data)
par_names <- dummy_modelfit_ij@model_pars
par_list <- get_inits(dummy_modelfit_ij)[[1]]
for (par in par_names) {
    par_list[[par]] <- map_fit_par[[par]]
}
upars <- unconstrain_pars(dummy_modelfit_ij, par_list)

# Get the Hessian
hess_upars <- numDeriv::jacobian(function(x) { grad_log_prob(dummy_modelfit_ij, x)}, upars)
hess_upars <- 0.5 * (hess_upars + t(hess_upars))

# This should match
hess_upars2 <- numDeriv::hessian(function(x) { log_prob(dummy_modelfit_ij, x)}, upars)

# Get the variance of the score by evaluating the full score with weightings on each
# individual datapoint.
grad_log_prob_mat <- matrix(NA, nrow=num_obs, ncol=length(upars))
pb <- txtProgressBar(min = 0, max = num_obs, style = 3)
for (obs_n in 1:num_obs) {
    setTxtProgressBar(pb, obs_n)
    stan_data_w <- stan_data
    w_n <- rep(0, num_obs)
    w_n[obs_n] <- 1
    stan_data_w[[bayes_ij_config$w_var]] <- w_n
    n_modelfit_ij <- GetDummyStanfit(model_ij, stan_data_w)
    grad_log_prob_mat[obs_n, ] <- grad_log_prob(n_modelfit_ij, upars)
}
close(pb)
score_cov <- cov(grad_log_prob_mat, grad_log_prob_mat)

draw_example <- as.matrix(dummy_modelfit_ij, pars=bayes_ij_config$stan_vars)
hess_eig <- eigen(hess_upars)
if (min(abs(hess_eig$values)) > 1e-8) {
    # Use Monte Carlo to get the covariance of the constrained pars.
    # Sadly I don't know how to safely convert from a parameter list to a matrix except using a StanFit.
    sandwich_cov <- solve(hess_upars, t(solve(hess_upars, score_cov)))
    upar_draws <- rmvnorm(n=num_draws, mean=upars, sigma=sandwich_cov)
    const_par_draws <- matrix(NA, nrow(upar_draws), ncol(draw_example))
    pb <- txtProgressBar(min = 0, max = nrow(upar_draws), style = 3)
    for (b in 1:nrow(upar_draws)) {
        setTxtProgressBar(pb, b)
        par_draw <- constrain_pars(dummy_modelfit_ij, upar_draws[b, ])
        dummy_modelfit_ij <- GetDummyStanfit(model_ij, stan_data, init=list(par_draw))
        const_par_draws[b, ]  <- as.matrix(dummy_modelfit_ij, bayes_ij_config$stan_vars)
    }
    close(pb)
    draw_map_cov <- cov(const_par_draws)
    colnames(draw_map_cov) <- colnames(draw_example)
    rownames(draw_map_cov) <- colnames(draw_example)
} else {
    cat("The Hessian is singular.")
    print(hess_eig$values)
    sandwich_cov <- NULL
    const_par_draws <- NULL
    draw_map_cov <- NULL
}


