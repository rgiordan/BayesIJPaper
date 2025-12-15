library(tidyverse)
#library(lme4)
#library(brms)
library(tidybayes)
library(broom)
library(mcmcse)

library(mrpaw)


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


# Created with compile_postprocessing.R
comb_env <- LoadIntoEnv("bootstrap_data/mrp_combined_mrp_20240724_1418.Rdata")
data_env <- LoadIntoEnv("datasets/cces18_subset.Rdata")
base_fit <- LoadIntoEnv("bootstrap_data/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata")

# Note that due to the lack of posterior_epred for rstan draws, this is
# just the MAP and lmer fits, so we compare to base_mcmc directly.
base_mcmc <- LoadIntoEnv("bootstrap_data/mrp_original_seed134432_samples5000.Rdata")
lmer_fit <- LoadIntoEnv("bootstrap_data/mrp_originallmer_seed134432_samples5000.Rdata")
map_fit <- LoadIntoEnv("bootstrap_data/mrp_originalmap_seed134432_samples5000.Rdata")


# The columns are defined in postprocess_mcmc.R.
# Note that as of 2/4 the mrp_var was actually sd(mrp)  -_-
incorrect_mrp_var <- TRUE
result_df <-
  comb_env$result_df %>%
  mutate(method=GetMethod(filename), seed=GetSeed(filename)) %>%
  mutate(mrp_var=mrp_var^2)

warning("Check whether mrp_var is actually the variance!!!")

unique(result_df$method)

boot_var <- 
  filter(result_df, method=="bootstrap") %>%
  pull(mrp) %>%
  var()

true_var <- 
  filter(result_df, method=="subsample") %>%
  pull(mrp) %>%
  var()

ij_var_orig <- 
  filter(result_df, method=="original") %>%
  pull(ij_var)

ij_var_samples <- 
  filter(result_df, method=="subsample") %>%
  arrange(seed) %>%
  pull("ij_var")

bayes_var_samples <- 
  filter(result_df, method=="subsample") %>%
  arrange(seed) %>%
  pull("mrp_var")

compiled_df <- data.frame(
  ij_var=ij_var_samples, 
  bayes_var=bayes_var_samples, 
  true_var=true_var, 
  boot_var=boot_var)

ggplot(compiled_df) +
  geom_hline(aes(yintercept=sqrt(true_var), color="Truth")) +
  geom_boxplot(aes(x="IJ", y=sqrt(ij_var))) +
  geom_boxplot(aes(x="Bayes", y=sqrt(bayes_var))) +
  geom_point(aes(x="Bootstrap", y=sqrt(boot_var))) +
  geom_point(aes(x="IJ", y=sqrt(ij_var_orig)), color="green")


mean(result_df$ij_var < boot_var)





######################################################################
# Look at the MCMC samples from the original dataset compared to lmer and MAP

# Helper to extract elements from a string matching a regexp
GetMatches <- function(re, strvec) {
  strvec[grepl(re, strvec)]
}


all_draws <- as.matrix(base_mcmc$logit_post)
nrow(all_draws)
ncol(all_draws)
par_names <- setdiff(colnames(all_draws), c("lprior", "lp__"))

theta_dim <- length(par_names)
n_obs <- nrow(data_env$survey_df)
n_obs / theta_dim



##############
# Look at the MAP

map_draws <- map_fit$logit_post$theta_tilde


if (FALSE) {
  # Try to figure out which MAP parameters correspond to which brms parameters.
  dim(map_draws)
  colnames(map_draws)
  colnames(all_draws)
  
  # Look at the compiled code to get a sense of the relationship
  # between named brms output and the abstract stan output
  # https://mc-stan.org/math/group__multivar__dists_gacf3272d33273a5bccc23eec9c9c09c14.html
  map_fit$logit_post$code
}



# Note that the intercept is named differently
# num_fe <- map_fit$logit_post$data$Kc
# fe_names <- colnames(map_fit$logit_post$data$X)[2:(num_fe + 1)]
fe_names <- colnames(map_fit$logit_post$data$X)

re_names <- c("educ", "educ:age", "educ:eth", "eth", "male:eth", "state")
  
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
}


map_sd_pars <- GetMatches("^sd.*", colnames(map_draws))
map_fe_pars <- c("Intercept", GetMatches("^b\\[.*", colnames(map_draws)))
mcmc_sd_pars <- GetMatches("^sd_.*", colnames(all_draws))
mcmc_fe_pars <- GetMatches("^b_.*", colnames(all_draws))

map_sd_draws <- map_draws[, map_sd_pars]
colnames(map_sd_draws) <- paste0("sd_", re_names)

map_fe_draws <- map_draws[, map_fe_pars]
colnames(map_fe_draws) <- paste0("b_", fe_names)

colSds <- function(draws) {
  apply(draws, sd, MARGIN=2)
}

map_df <-
  bind_rows(
    data.frame(
      par_mcmc=mcmc_sd_pars,
      par_map=map_sd_pars,
      estimate=colMeans(map_sd_draws),
      estimate_map_mcmc=colMeans(all_draws[, mcmc_sd_pars]),
      sd_map=colSds(map_sd_draws),
      sd_mcmc=colSds(all_draws[, mcmc_sd_pars]),
      type="sd"
    ),
    data.frame(
      par_mcmc=mcmc_fe_pars,
      par_map=map_fe_pars,
      estimate_map=colMeans(map_fe_draws),
      sd_map=colSds(map_fe_draws),
      estimate_mcmc=colMeans(all_draws[, mcmc_fe_pars]),
      sd_mcmc=colSds(all_draws[, mcmc_fe_pars]),
      type="fe"
    )
)


if (FALSE) {
  ggplot(map_df) +
    geom_point(aes(x=estimate_mcmc, y=estimate, color=par_map)) +
    geom_abline(aes(slope=1, intercept=0)) +
    facet_grid(type ~ ., scales="free")
  
  # Definitely pathology in the sd estimates
  summary(map_draws[, "r_1_1[1]"])
  summary(map_draws[, "r_1_1[2]"])
  
  map_df %>%
    mutate(diff_z = (estimate - estimate_mcmc) / sd_mcmc)
}


#######################################
# Check for a separating hyperplane with logistic regression


# regressor_string <- paste0(
#   " ~ (1 | state) + (1 | eth) + (1 | educ) + male + ",
#   "(1 | male:eth) + (1 | educ:age) + (1 | educ:eth) + ",
#   "repvote + region")
regressor_string <- paste0(
  " ~ state + eth + educ + male + ",
  "male*eth + educ*age + educ*eth + ",
  "repvote + region")
model_string <- paste0("abortion ", regressor_string)

cat_regressors <- c("state", "eth", "educ", "male", "age", "region")
regressors <- c(cat_regressors, "repvote")

survey_df <-
  data_env$survey_df %>%
  mutate(
    state=factor(state),
    eth=factor(eth),
    educ=factor(educ),
    male=factor(male),
    region=factor(region)
  )

if (FALSE) {
  head(survey_df)
  model.matrix(formula(model_string), survey_df,
               contrasts.arg=list(
                 # ... not sure what this is actually doing
               ))
  
}

logistic_reg <- 
  glm(formula(model_string), family=binomial(link="logit"), data=survey_df)
summary(logistic_reg)
logistic_reg$converged
logistic_reg$boundary



##############
# Look at lmer

print(lmer_fit$logit_post@optinfo$conv)
hess <- print(lmer_fit$logit_post@optinfo$derivs$Hessian)
eigen(hess)$values

summary(lmer_fit$logit_post)


# Match the lmer names with the MCMC names
lmer_df <-
  broom.mixed::tidy(lmer_fit$logit_post) %>%
  mutate(par=case_when(is.na(group) ~ term, TRUE ~ group)) %>%
  mutate(par=sub("\\(", "", par)) %>%
  mutate(par=sub("\\)", "", par)) %>%
  mutate(par_prefix=case_when(is.na(group) ~ "b_", TRUE ~ "sd_")) %>%
  mutate(par_suffix=case_when(is.na(group) ~ "", TRUE ~ "__Intercept")) %>%
  mutate(par_mcmc=paste0(par_prefix, par, par_suffix))

par_mcmc <- lmer_df$par_mcmc
mcmc_draws_df <- tidy_draws(all_draws)
stopifnot(all(par_mcmc %in% names(mcmc_draws_df)))


##############################
# Combine lmer and MCMC


mcmc_summary_df <-
  mcmc_draws_df %>%
  select(all_of(par_mcmc)) %>%
  mutate(draw=1:n()) %>%
  pivot_longer(cols=-draw, names_to="par_mcmc") %>%
  group_by(par_mcmc) %>%
  summarize(mcmc_mean=mean(value), mcmc_sd=sd(value), mcmc_se=mcse(value)$se)



# mcmc_se_df <- fixef(base_mcmc$logit_post) %>% as.data.frame()
# mcmc_se_df$par_mcmc <- paste0("b_", rownames(mcmc_se_df))

lmer_map_comb_df <- 
  lmer_df %>%
  select(par_mcmc, estimate, std.error) %>%
  rename(estimate_lmer=estimate, sd_lmer=std.error) %>%
  left_join(mcmc_summary_df, by="par_mcmc") %>%
  left_join(map_df %>% select(par_mcmc, estimate_map, sd_map), 
            by="par_mcmc", suffix=c("", "_map"))




if (FALSE) {
  ggplot(mcmc_lmer_df) +
    geom_point(aes(x=estimate, y=mcmc_mean)) +
    geom_errorbar(aes(x=estimate, ymin=mcmc_mean - 2 * mcmc_se, ymax=mcmc_mean + 2 * mcmc_se)) +
    geom_abline(aes(slope=1, intercept=0)) 
  
  mcmc_lmer_df %>% filter(is_sd) %>%
    ggplot() +
    geom_point(aes(x=estimate, y=mcmc_mean)) +
    geom_errorbar(aes(x=estimate, ymin=mcmc_mean - 2 * mcmc_se, ymax=mcmc_mean + 2 * mcmc_se)) +
    geom_abline(aes(slope=1, intercept=0)) + 
    xlab("LMER estimate") + ylab("MCMC estimate")
  
  
  ggplot(mcmc_lmer_df) +
    geom_point(aes(x=std.error, y=mcmc_sd, color=par_mcmc)) +
    geom_abline(aes(slope=1, intercept=0)) 
}

