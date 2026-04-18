# This script loads and post-processes for LaTeX results from the
# folder `InfinitesimalJackknifeWorkbench/src/bayes/mrp`.
# For more details on how to generate the necessary files see the README therein

library(tidyverse)
library(broom)
library(tidybayes)
library(mcmcse)
library(lme4)


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



# Use the delta method to approximate the sampling variance of an estimated covariance
GetCovarianceSE <- function(x_draws, y_draws=NULL) {
  if (is.null(y_draws)) {
    y_draws <- x_draws
  }
  stopifnot(length(x_draws) == length(y_draws))
  n_draws <- length(x_draws)
  arg_draws <- cbind(x_draws * y_draws, x_draws, y_draws)
  arg_means <- colMeans(arg_draws)
  xy_mean <- arg_means[1]
  x_mean <- arg_means[2]
  y_mean <- arg_means[3]
  arg_var_mat <- cov(arg_draws)
  grad_g <- c(1, -1 * y_mean, -1 * x_mean)
  g_var <- t(grad_g) %*% arg_var_mat %*% grad_g
  g_se <- as.numeric(sqrt(g_var  / n_draws))
  return(g_se)
}

repo_dir <- system("git rev-parse --show-toplevel", intern=TRUE)


mrp_dir <- file.path(repo_dir, "src/mrp")
output_dir <- file.path(repo_dir, "paper/experiment_data/mrp")

stopifnot(dir.exists(mrp_dir))
stopifnot(dir.exists(output_dir))

# Created with compile_postprocessing.R
comb_env <- LoadIntoEnv(file.path(
  mrp_dir, "bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata"))
data_env <- LoadIntoEnv(file.path(
  mrp_dir, "datasets/cces18_subset.Rdata"))
base_fit <- LoadIntoEnv(file.path(
  mrp_dir, "bootstrap_data/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata"))

# Note that due to the lack of posterior_epred for rstan draws, this is
# just the MAP and lmer fits, so we compare to base_mcmc directly.
base_mcmc <- LoadIntoEnv(file.path(
  mrp_dir, "bootstrap_data/mrp_original_seed134432_samples5000.Rdata"))
lmer_fit <- LoadIntoEnv(file.path(
  mrp_dir, "bootstrap_data/mrp_originallmer_seed134432_samples5000.Rdata"))

# Stan's MAP fit is no good, use our own instead
map_fit <- LoadIntoEnv(file.path(mrp_dir, "custom_map_analysis.Rdata"))






result_df <-
  comb_env$result_df %>%
  mutate(method=GetMethod(filename), seed=GetSeed(filename))

# The first ten runs didn't save the mcmc time, for no systematic
# reason, just because I hadn't implemented saving yet.
num_boots <- sum(result_df$method == "bootstrap")
num_samples <- sum(result_df$method == "subsample")
boot_time_estimate <- mean(result_df$mcmc_time, na.rm=TRUE) * num_boots
if (FALSE) {
  result_df %>%
    select(method, seed)
}

warning("Check whether mrp_var is actually the variance!!!")

unique(result_df$method)

mrp_boot_draws <- 
  filter(result_df, method=="bootstrap") %>%
  pull(mrp)
boot_var <- var(mrp_boot_draws)
boot_var_se <- GetCovarianceSE(mrp_boot_draws)


mrp_draws <- 
  filter(result_df, method=="subsample") %>%
  pull(mrp)
true_var <- var(mrp_draws)
true_var_se <- GetCovarianceSE(mrp_draws)

ij_var_orig <- 
  filter(result_df, method=="original") %>%
  pull(ij_var)

ij_var_samples <- 
  filter(result_df, method=="subsample") %>%
  arrange(seed) %>%
  pull("ij_var")

# Estimate MCMC and frequentist error for IJ
ij_var_mcmc_se <- base_fit$result_df$ij_var_mcmc_se
infl_vec <- sqrt(length(base_fit$infl_vec)) * base_fit$infl_vec
stopifnot(var(infl_vec) == ij_var_orig) # sqrt N is the right scaling
ij_freq_se <- GetCovarianceSE(infl_vec)


bayes_var_orig <- 
  filter(result_df, method=="original") %>%
  arrange(seed) %>%
  pull("mrp_var")

bayes_var_samples <- 
  filter(result_df, method=="subsample") %>%
  arrange(seed) %>%
  pull("mrp_var")

compiled_df <- data.frame(
  ij_var=ij_var_samples,
  bayes_var=bayes_var_samples, 
  true_var=true_var, 
  true_var_se=true_var_se,
  boot_var=boot_var,
  boot_var_se=boot_var_se,
  ij_var_orig=ij_var_orig,
  ij_var_mcmc_se=ij_var_mcmc_se,
  ij_freq_se=ij_freq_se,
  ij_var_se=sqrt(ij_freq_se^2 + ij_var_mcmc_se^2),
  bayes_var_orig=bayes_var_orig)

if (FALSE) {
  ggplot(compiled_df) +
    geom_point(aes(x="IJ", y=(ij_var_orig))) +
    geom_boxplot(aes(x="IJ", y=(ij_var))) +
    geom_errorbar(aes(x="IJ", ymin=ij_var_orig - 2 * ij_var_se, ymax=ij_var_orig + 2 * ij_var_se )) +
    # geom_point(aes(x="Bayes", y=(bayes_var_orig))) +
    # geom_boxplot(aes(x="Bayes", y=(bayes_var))) +
    geom_point(aes(x="Bootstrap", y=(boot_var))) +
    geom_errorbar(aes(x="Bootstrap", ymin=boot_var - 2 * boot_var_se, ymax=boot_var + 2 * boot_var_se )) +
    geom_hline(aes(yintercept=(true_var), color="Estimated true variance")) +
    geom_errorbar(aes(x="Truth", ymin=true_var - 2 * true_var_se, ymax=true_var + 2 * true_var_se ))
  
  mean(result_df$ij_var < boot_var)
}


if (FALSE) {
  # What's up with our variance estimates?
  
  num_boots <- 1000
  num_m <- length(mrp_draws)
  var_b_draws <- rep(NA, num_boots)
  for (b in 1:1000) {
    mrp_draws_boot <- sample(mrp_draws, length(mrp_draws), replace=TRUE)
    var_b_draws[b] <- var(mrp_draws_boot)
  }
  sd(var_b_draws)
  true_var_se
  
  # It's actually about right for IJ
  sd(ij_var_samples) / sqrt(ij_var_mcmc_se^2 + ij_freq_se^2)
  
  # The reason is that the bootstraps are heavier--tailed than the IJ
  ggplot() +
    geom_density(aes(x=infl_vec - mean(infl_vec), color="Influence function")) +
    geom_density(aes(x=mrp_boot_draws - mean(mrp_boot_draws), color="Bootstrap draws"))

  data.frame(infl=infl_vec, y=factor(data_env$survey_df$abortion)) %>%
  ggplot() +
    geom_density(aes(x=infl, color=y, group=y))
  
}










######################################################################
# Look at the MCMC samples from the original dataset compared to lmer and MAP

# Get the parameter dimensions
all_draws <- as.matrix(base_mcmc$logit_post)
nrow(all_draws)
ncol(all_draws)
par_names <- setdiff(colnames(all_draws), c("lprior", "lp__"))

theta_dim <- length(par_names)
n_obs <- nrow(data_env$survey_df)
n_obs / theta_dim

n_total_obs <- nrow(data_env$cces_all_df)


###########################
# Look at lmer
print(lmer_fit$logit_post@optinfo$conv)
lmer_covergence <- lmer_fit$logit_post@optinfo$conv

hess <- print(lmer_fit$logit_post@optinfo$derivs$Hessian)
eigen(hess)$values

summary(lmer_fit$logit_post)
class(lmer_fit$logit_post)

lmer_fit$logit_post



# Match the lmer names with the MCMC names
lmer_df <-
  broom.mixed::tidy(lmer_fit$logit_post) %>%
  mutate(par=case_when(is.na(group) ~ term, TRUE ~ group)) %>%
  mutate(par=sub("\\(", "", par)) %>%
  mutate(par=sub("\\)", "", par)) %>%
  mutate(par_prefix=case_when(is.na(group) ~ "b_", TRUE ~ "sd_")) %>%
  mutate(par_suffix=case_when(is.na(group) ~ "", TRUE ~ "__Intercept")) %>%
  mutate(par_mcmc=paste0(par_prefix, par, par_suffix)) %>%
  rename(lmer=estimate, lmer_sd=std.error) %>%
  select(par_mcmc, lmer, lmer_sd) %>%
  rename(par=par_mcmc)

state_re_est <- ranef(lmer_fit$logit_post)$state
lmer_re_df <-
  data.frame(par_lmer=rownames(state_re_est),
             lmer=state_re_est[["(Intercept)"]],
             lmer_sd=NA) %>%
  mutate(par=paste0("r_state[", par_lmer, ",Intercept]")) %>%
  select(-par_lmer)

par_mcmc <- c(lmer_df$par, lmer_re_df$par)
mcmc_draws_df <- tidy_draws(all_draws)
stopifnot(all(par_mcmc %in% names(mcmc_draws_df)))

# Summarize MCMC

mcmc_summary_df <-
  mcmc_draws_df %>%
  select(all_of(par_mcmc)) %>%
  mutate(draw=1:n()) %>%
  pivot_longer(cols=-draw, names_to="par_mcmc") %>%
  group_by(par_mcmc) %>%
  summarize(mcmc=mean(value), mcmc_sd=sd(value), mcmc_se=mcse(value)$se) %>%
  rename(par=par_mcmc)


# Joining
mcmc_lmer_df <- 
  bind_rows(
    mcmc_summary_df %>% pivot_longer(c(mcmc, mcmc_sd, mcmc_se), names_to="method", values_to="est"),
    lmer_re_df %>% pivot_longer(c(lmer, lmer_sd), names_to="method", values_to="est"),
    lmer_df %>% pivot_longer(c(lmer, lmer_sd), names_to="method", values_to="est")
  ) %>%
  mutate(class=case_when(
    grepl("^b", par) ~ "Fixed effect",
    grepl("^sd", par) ~ "Scale parameter",
    grepl("^r", par) ~ "State random effect",
    TRUE ~ "Other"))

mcmc_lmer_wide_df <-
  mcmc_lmer_df %>%
  pivot_wider(id_cols=c(par, class), names_from=method, values_from=est)


if (FALSE) {
  ggplot(mcmc_lmer_wide_df) +
    geom_point(aes(x=mcmc, y=lmer, color=class)) +
    geom_errorbarh(aes(xmin=mcmc - 2 * mcmc_sd, xmax=mcmc + 2 * mcmc_sd, y=lmer)) +
    geom_abline() +
    facet_grid(~ class)
  
  mcmc_lmer_wide_df %>%
    filter(!is.na(lmer_sd)) %>%
    ggplot() +
      geom_point(aes(x=mcmc_sd, y=lmer_sd, color=par)) +
      geom_abline() +
      expand_limits(y=0, x=0)
}


###################################
# Write a latex friendly file

map_mcmc_wide_df <- map_fit$map_mcmc_wide_df
ij_time <- as.double(base_fit$ij_time, units="secs")
linpred_time <- as.double(base_fit$linpred_time, units="secs")
num_mcmc_samples <- nrow(mcmc_draws_df)

n_obs / theta_dim

save(n_obs, 
     theta_dim,
     compiled_df,
     mcmc_lmer_wide_df,
     map_mcmc_wide_df,
     n_total_obs,
     num_boots,
     num_samples,
     boot_time_estimate,
     ij_time,
     linpred_time,
     num_mcmc_samples,
     file=file.path(output_dir, "mrp_postprocessed.Rdata"))