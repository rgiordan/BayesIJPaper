#################################################
# Look at the Stan MAP results and ultimately
# compute our own, better MAP estimator.

library(tidyverse)
library(broom)
library(tidybayes)
library(rstan)
library(brms)
library(mcmcse)
rstan_options(auto_write=TRUE)


LoadIntoEnv <- function(filename) {
  this_env <- new.env()
  load(filename, envir=this_env)
  return(this_env)
}


GetMethod <- function(filename) {
  str_extract(filename, "mrp_[a-z]+_seed") %>%
    str_remove("mrp_") %>%
    str_remove("_seed")
}


GetSeed <- function(filename) {
  str_extract(filename, "seed[0-9]+") %>%
    str_remove("seed")
}


# Get all regexp matches from a vector
GetMatches <- function(re, strvec) {
  strvec[grepl(re, strvec)]
}

repo_dir <- system("git rev-parse --show-toplevel", intern=TRUE)
mrp_dir <- file.path(repo_dir, "src/mrp")

# Created with compile_postprocessing.R
data_env <- LoadIntoEnv(file.path(mrp_dir, "datasets/cces18_subset.Rdata"))
# base_fit <- LoadIntoEnv(file.path(
#   mrp_dir, "bootstrap_data/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata"))

# Note that due to the lack of posterior_epred for rstan draws, this is
# just the MAP and lmer fits, so we compare to base_mcmc directly.
base_mcmc <- LoadIntoEnv(file.path(
  mrp_dir, "bootstrap_data/mrp_original_seed134432_samples5000.Rdata"))
map_fit <- LoadIntoEnv(file.path(
  mrp_dir, "bootstrap_data/mrp_originalmap_seed134432_samples5000.Rdata"))




######################################################################
# Run Stan's MAP analysis to try to figure out what went wrong

print("Running sampler.")

survey_df <- data_env$survey_df

regressor_string <- paste0(
  " ~ (1 | state) + (1 | eth) + (1 | educ) + male + ",
  "(1 | male:eth) + (1 | educ:age) + (1 | educ:eth) + ",
  "repvote + region")
model_string <- paste0("abortion ", regressor_string)

cat_regressors <- c("state", "eth", "educ", "male", "age", "region")
regressors <- c(cat_regressors, "repvote")
stopifnot(all(regressors %in% names(survey_df)))

logit_prior <- c(prior(normal(0, 2), class = b), 
                 prior(normal(0, 10.5), class = b, coef = repvote), 
                 prior(exponential(0.5), class = sd))


print("Compiling Stan model")
code <- make_stancode(
  formula(model_string), 
  family = bernoulli(link="logit"),
  data = survey_df,
  prior = logit_prior)
data <- make_standata(
  formula(model_string), 
  family = bernoulli(link="logit"),
  data = survey_df,
  prior = logit_prior)
mod <- stan_model(model_code=code, auto_write=TRUE)



num_samples <- 5000
print("Starting MAP estimation")
stan_time <- Sys.time()
logit_map <- optimizing(
  mod, 
  data=data, 
  hessian=TRUE, 
  draws=num_samples, 
  constrained=TRUE,
  init=0,
  algorithm="LBFGS",
  verbose=TRUE)
stan_time <- Sys.time() - stan_time
print("MAP fit done!")

map_draws <- logit_map$theta_tilde
map_sd_pars <- GetMatches("^sd.*", colnames(map_draws))
map_fe_pars <- c("Intercept", GetMatches("^b\\[.*", colnames(map_draws)))
colMeans(map_draws[, map_sd_pars])



####################################
# Run and diagnose my own MAP

if (FALSE) {
  cat(mod@model_code)
  
  # r_x_1 is transformed to sd_x * z_x[1]
  # Then mu[n] is given r_x[J_x[n]] * Z_x_1[n] 

  # These are all constant REs so the Z_x_1 is 1.
  summary(data$Z_1_1)
  summary(data$Z_2_1)
  summary(data$Z_3_1)
  summary(data$Z_4_1)
  summary(data$Z_5_1)
}

logit_stanfit <- sampling(
  mod, 
  data=data, 
  algorithm="Fixed_param")


# Get some parameters.  The random inits produce enormous gradients.
stan_par <- logit_stanfit@inits[[1]]

stan_par$Intercept <- 0
stan_par$b <- rep(0, length(stan_par$b))

r_varnames <- GetMatches("^r_.*", names(stan_par))
for (r_var in r_varnames) {
  par_len <- length(stan_par[[r_var]])
  #stan_par[[r_var]] <- rep(0, par_len))
  stan_par[[r_var]] <- 0.01 * rnorm(par_len)
}

for (z_var in GetMatches("^z_.*", names(stan_par))) {
  #print(sprintf("%s: %f", z_var, stan_par[[z_var]]))
  par_len <- length(stan_par[[z_var]])
  stan_par[[z_var]] <- 0 * stan_par[[z_var]]
}


for (sd_par in GetMatches("sd_.*", names(stan_par))) {
  print(sprintf("%s: %f", sd_par, stan_par[[sd_par]]))
  stan_par[[sd_par]] <- array(0.1)
}

# Evaluate stuff

upar <- unconstrain_pars(logit_stanfit, stan_par)
glp <- rstan::grad_log_prob(logit_stanfit, upar)
constrain_pars(logit_stanfit, glp)

# r_1_1 has negative infinite gradient
# r_2_1 has zero gradient


# Manually compute the log odds

# Copy from code more or less
Xc <- scale(data$X[,2:data$K], center=TRUE, scale=FALSE)
fe_term <- Xc %*% stan_par$b

n <- 1
mu_vec <- rep(NA, data$N)
for (n in 1:data$N) {
  mu_vec[n] <-
    with(c(stan_par, data), 
         r_1_1[J_1[n]] * Z_1_1[n] + 
           r_2_1[J_2[n]] * Z_2_1[n] + 
           r_3_1[J_3[n]] * Z_3_1[n] + 
           r_4_1[J_4[n]] * Z_4_1[n] + 
           r_5_1[J_5[n]] * Z_5_1[n] + 
           r_6_1[J_6[n]] * Z_6_1[n] + Intercept)
}


data.frame(log_odds=mu_vec + fe_term, y=data$Y) %>%
ggplot() +
  geom_density(aes(x=log_odds, group=y))


# Recompute the MAP myself

sd_pars <- GetMatches("^sd_.*", names(stan_par))
EvalFun <- function(upar) {
  loss <- -1 * rstan::log_prob(logit_stanfit, upar)
  print(sprintf("%f", loss))
  par <- constrain_pars(logit_stanfit, upar) 
  #print(sapply(sd_pars, \(x) par[[x]]))
  return(loss)
}

EvalGrad <- function(upar) {
  return(-1 * rstan::grad_log_prob(logit_stanfit, upar))
}


init_par <- unconstrain_pars(logit_stanfit, stan_par)


opt_result <- optim(
  init_par, 
  EvalFun, 
  EvalGrad, 
  method="CG", 
  hessian=TRUE,
  control=list(reltol=1e-5, maxit=50000))
opt_par <- constrain_pars(logit_stanfit, opt_result$par)

opt_result$convergence
opt_result$message
opt_result$grad_at_opt <- EvalGrad(opt_result$par)
opt_result$hess_at_opt <- eigen(opt_result$hessian)$values
opt_result$newton_step_at_opt <- -1 * solve(opt_result$hessian, EvalGrad(opt_result$par))




######################################################################
# Look at the MCMC samples from the original dataset compared to lmer and MAP

colSds <- function(x) {
  apply(x, sd, MARGIN=2)
}

# Get the parameter dimensions
all_draws <- as.matrix(base_mcmc$logit_post)
nrow(all_draws)
ncol(all_draws)
par_names <- setdiff(colnames(all_draws), c("lprior", "lp__"))

mcmc_fe_names <- GetMatches("^b_.*", par_names)
mcmc_sd_names <- GetMatches("^sd_.*", par_names)
mcmc_state_names <- GetMatches("^r_state.*", par_names)

map_fe_names <- paste0("b_", colnames(data$X))
map_fe_est <- c(opt_par$Intercept, opt_par$b)

ordered_state_names <- unique(survey_df$state) %>% sort()
map_state_names <- paste0("r_state[", ordered_state_names, ",Intercept]")
map_state_est <- opt_par$r_6_1

stopifnot(all(map_state_names %in% mcmc_state_names))


if (FALSE) {
  # The random effects do not appear in any particular order.  :(
  # Or maybe it's lexicographic order?
  # But we can match them up using the number of distinct levels.
  
  # regressor_string <- paste0(
  #   " ~ (1 | state) + (1 | eth) + (1 | educ) + male + ",
  #   "(1 | male:eth) + (1 | educ:age) + (1 | educ:eth) + ",
  #   "repvote + region")
  
  map_fit$logit_post$data$N_1 # educ
  map_fit$logit_post$data$N_2 # educ:age
  map_fit$logit_post$data$N_3 # educ:eth
  map_fit$logit_post$data$N_4 # eth
  map_fit$logit_post$data$N_5 # male:eth
  map_fit$logit_post$data$N_6 # state
  
  # Note that the r_G_1 values are the random effect draws
  
  for (col in c("state", "eth", "male", "age", "educ")) {
    cat("\n")
    print(col)
    print(length(unique(orig_env$survey_df[[col]])))    
  }
  
  # Which levels of the RE are which?  They appear to be in lexicographic order.
  table(data$J_6)
  table(survey_df$state)
}
re_names <- c("educ", "educ:age", "educ:eth", "eth", "male:eth", "state")
map_sd_names <- paste0("sd_", re_names, "__Intercept")
map_sd_est <- sapply(1:6, \(x) opt_par[[paste0("sd_", x)]])


map_mcmc_df <- bind_rows(
  data.frame(
    par=mcmc_fe_names,
    est=colMeans(all_draws[,mcmc_fe_names]) %>% unname(),
    method="mcmc"
  )
  ,
  data.frame(
    par=mcmc_fe_names,
    est=colSds(all_draws[,mcmc_fe_names]) %>% unname(),
    method="mcmc_sd"
  )
  ,
  data.frame(
    par=map_fe_names,
    est=map_fe_est,
    method="map"
  )
  , #######################################
  data.frame(
    par=mcmc_sd_names,
    est=colMeans(all_draws[,mcmc_sd_names]) %>% unname(),
    method="mcmc"
  )
  ,
  data.frame(
    par=mcmc_sd_names,
    est=colSds(all_draws[,mcmc_sd_names]) %>% unname(),
    method="mcmc_sd"
  )
  ,
  data.frame(
    par=map_sd_names,
    est=map_sd_est,
    method="map"
  )
  , #######################################
  data.frame(
    par=mcmc_state_names,
    est=colMeans(all_draws[,mcmc_state_names]) %>% unname(),
    method="mcmc"
  )
  ,
  data.frame(
    par=mcmc_state_names,
    est=colSds(all_draws[,mcmc_state_names]) %>% unname(),
    method="mcmc_sd"
  )
  ,
  data.frame(
    par=map_state_names,
    est=map_state_est,
    method="map"
  )
)

map_mcmc_df <-
  map_mcmc_df %>%
  mutate(class=case_when(
    grepl("^b", par) ~ "Fixed effect",
    grepl("^sd", par) ~ "Scale parameter",
    grepl("^r", par) ~ "State random effect",
    TRUE ~ "Other"))

map_mcmc_wide_df <-
  map_mcmc_df %>%
  pivot_wider(id_cols=c(par, class), names_from=method, values_from=est)

if (FALSE) {
  ggplot(map_mcmc_wide_df) +
    geom_point(aes(x=mcmc, y=map, color=class)) +
    geom_errorbarh(aes(xmin=mcmc - 2 * mcmc_sd, xmax=mcmc + 2 * mcmc_sd, y=map)) +
    geom_abline() +
    facet_grid(~ class)
  
}


# Save our results here

save(map_mcmc_df, map_mcmc_wide_df, opt_result, opt_par,
     file=file.path(mrp_dir, "bootstrap_data/custom_map_analysis.Rdata"))
