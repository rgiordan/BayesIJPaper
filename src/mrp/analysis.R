library(tidyverse)
library(brms)
library(lme4)
library(tidybayes)


get_se_bernoulli <- function(p, n){
  return(sqrt(p*(1-p)/n))
}

Expit <- function(x) {
  return(exp(x) / (1 + exp(x)))
}

##################################################################################
# Data

load("cces18_common_vv.Rdata")
seed <- 1010
set.seed(seed)

# we will call the full survey with 60,000 respondents cces_all_df,
# while the 5,000 person sample will be called cces_df.
sample_size <- 10000
cces_df <- cces_all_df %>% sample_n(sample_size)

##################################################################################
# Define a model


regressor_string <- paste0(
  " ~ (1 | state) + (1 | eth) + (1 | educ) + male + ",
  "(1 | male:eth) + (1 | educ:age) + (1 | educ:eth) + ",
  "repvote + region")
model_string <- paste0("abortion ", regressor_string)

regressors <- c("state", "eth", "educ", "male", "age", "repvote", "region")
stopifnot(all(regressors %in% names(cces_df)))
stopifnot(all(regressors %in% names(poststrat_df)))

# MakeFactor <- function(colname) {
#   poststrat_df[[colname]] <<- factor(poststrat_df[[colname]])
#   cces_df[[colname]] <<- factor(cces_df[[colname]], levels=levels(poststrat_df[[colname]]))
# }
# 
# for (factor_col in setdiff(regressors, "repvote")) {
#   MakeFactor(factor_col)
# }
# 
# # aggregating doesn't do anything
# poststrat_agg_df <- poststrat_df %>%
#   group_by(across(all_of(regressors))) %>%
#   summarize(n=n(), .groups="drop")
# nrow(poststrat_agg_df) / nrow(poststrat_df)
# 
# poststrat_x <- model.matrix(formula(regressor_string), poststrat_df)
# table(cces_df$educ)

##################################################################################
# MCMC

analysis_desc <- sprintf("seed%d_sample%d", seed, sample_size)

num_draws <- 5000
force_rerun <- FALSE


brm_logit_filename <- sprintf("brms_logit_fit_%s.Rdata", analysis_desc)
if (!file.exists(brm_logit_filename) || force_rerun) {
  # 1) Logit model
  stan_time <- Sys.time()
  logit_post <- brm(formula(model_string), 
                    family = bernoulli(link="logit"),
                    data = cces_df,
                    #prior = normal(0, 1, autoscale = TRUE),
                    #prior_covariance = decov(scale = 0.50),
                    #adapt_delta = 0.99,
                    #refresh = 0,
                    #seed = 101, 
                    chains=4, cores=4, seed=1543, warmup=500, iter=num_draws)
  # abortion ~ (1 | state) + (1 | eth) + (1 | educ) + male +
  #   (1 | male:eth) + (1 | educ:age) + (1 | educ:eth) +
  #   repvote + factor(region)
  
  stan_time <- Sys.time() - stan_time
  print(stan_time)
  save(stan_time, logit_post, file=brm_logit_filename)
} else {
  load(brm_logit_filename)
}



brm_linear_filename <- sprintf("brms_linear_fit_%s.Rdata", analysis_desc)
if (!file.exists(brm_linear_filename) || force_rerun) {
  # 2) Normal model
  stan_time <- Sys.time()
  lin_post <- brm(formula(model_string), 
                  data = cces_df, family=gaussian(),
                  chains=4, cores=4, seed=1543, warmup=500, iter=num_draws)
  stan_time <- Sys.time() - stan_time
  print(stan_time)
  save(stan_time, lin_post, file=brm_linear_filename)
} else {
  load(brm_linear_filename)
}


print(lin_post)
print(logit_post) # very similar to fit in textbook


##################################################################################
# MrP


# 1) Logit model
# Posterior_epred returns posterior estimates for the different subgroups stored in poststrat_df 
head(poststrat_df)
yhat_pop <- posterior_epred(logit_post, newdata=poststrat_df, draws=num_draws)
mrp_draws_logit <- yhat_pop %*% poststrat_df$n / sum(poststrat_df$n)
mrp_estimate_logit <- c(mean = mean(mrp_draws_logit), sd = sd(mrp_draws_logit))
print('Logit')
cat("Logit MRP estimate mean, sd: ", round(mrp_estimate_logit, 3))

if (FALSE) {
  # Sanity check, should be zero.
  linpred_pop <- posterior_linpred(logit_post, newdata = poststrat_df, draws = num_draws)
  max(abs(Expit(linpred_pop) - yhat_pop))
  rm(linpred_pop); gc()
}

# Compare MrP to the 5,000-person unadjusted sample estimate:
sample_cces_estimate <- c(mean = mean(cces_df$abortion), 
                          se = get_se_bernoulli(mean(cces_df$abortion), nrow(cces_df)))
cat("Unadjusted 5000-respondent survey mean, sd: ", (round(sample_cces_estimate, 3)))

# Compare with the population support estimated by the full CCES (close to 60,000 participants)
full_cces_estimate <- c(mean = mean(cces_all_df$abortion), 
                        se = get_se_bernoulli(mean(cces_all_df$abortion), nrow(cces_all_df)))
cat("Unadjusted 60,000-respondent survey mean, sd: ", (round(full_cces_estimate, 3)))


# 2) Linear model
yhat_pop <- posterior_epred(lin_post, newdata = poststrat_df, draws = num_draws)
mrp_draws_lin <- yhat_pop %*% poststrat_df$n / sum(poststrat_df$n)
mrp_estimate_lin <- c(mean = mean(mrp_draws_lin), sd = sd(mrp_draws_lin))
print('Gaussian')
cat("MRP estimate mean, sd: ", round(mrp_estimate_lin, 3))

if (FALSE) {
  # Sanity check, should be zero.
  linpred_pop <- posterior_linpred(lin_post, newdata=poststrat_df, draws=num_draws)
  max(abs(linpred_pop - yhat_pop))
  rm(linpred_pop); gc()
}


cat("Linear MRP estimate mean, sd: ", round(mrp_estimate_lin, 3))
cat("Logit  MRP estimate mean, sd: ", round(mrp_estimate_logit, 3))

# Some cleanup
rm(yhat_pop); gc()


##################################################################################
# Implied weights

# 1) Get the influence scores for the logit model
# The log likelihood derivative for the n^th datapoint is just the theta^T x_n
ll_grad_draws_logit <- posterior_linpred(logit_post, newdata=cces_df, draws=num_draws)
w_logit <- cov(mrp_draws_logit, ll_grad_draws_logit)[1,]
length(w_logit)


# 2) Get the influence scores for the linear model
# The log likelihood derivative for the n^th datapoint is sigma^{-2} (y_n - \hat{y}_n)
sigma_draws <- lin_post %>% spread_draws(sigma) %>% pull(sigma)
yhat_draws <- posterior_linpred(lin_post, newdata = cces_df, draws = num_draws)
y_survey <- matrix(rep(cces_df$abortion, each = nrow(yhat_draws)), nrow = nrow(yhat_draws))

# Each row of y_survey should be a draw of the observed y, which should 
# always be the same across draws.
stopifnot(max(abs(apply(y_survey, var, MARGIN=2))) < 1e-6)
resid_draws <- (y_survey - yhat_draws)
ll_grad_draws_lin <- - resid_draws / (sigma_draws^2)
w_lin <- cov(mrp_draws_lin, ll_grad_draws_lin)[1,]


if (FALSE) {
  # Sanity check that I'm computing the log likelihood correctly
  # (I'm not taking into account the prior so there will be some small mismatch)
  lp_mat <- - 0.5 * resid_draws^2 / sigma_draws^2 - log(sigma_draws)
  lp_draws_check <- lin_post %>% spread_draws(lp__) %>% pull(lp__)
  lp_draws <- apply(lp_mat, FUN=sum, MARGIN=1)

  # Note that this is not working --- I think because the lp__ variable
  # contains the random effects prior, which is substantial.
  # TODO(confirm this!)
  cor(lp_draws, lp_draws_check)
  plot(lp_draws, lp_draws_check); abline(0,1)
}


if (FALSE) {
  # Histogram of implied weights
  hist(w_logit, breaks = 100)

  # Histogram of implied weights
  hist(w_lin, breaks = 100)
  
  # Compare weights
  ggplot() +
    geom_point(aes(x=w_logit, y=w_lin), alpha=0.2) +
    geom_density2d(aes(x=w_logit, y=w_lin)) +
    geom_abline(aes(slope=1, intercept=0))
  cor(w_logit, w_lin)
}


##################################################################################
# Linear or affine?

y_obs <- cces_df$abortion
mrp_estimate_logit["offset"] <- mrp_estimate_logit["mean"] - sum(w_logit * y_obs)
mrp_estimate_lin["offset"] <- mrp_estimate_lin["mean"] - sum(w_lin * y_obs)

cat(sprintf("Offset = %0.3f \t MrP = %0.3f (%0.3f)\n",  
            mrp_estimate_logit["offset"], mrp_estimate_logit["mean"], mrp_estimate_logit["sd"] ))
cat(sprintf("Offset = %0.3f \t MrP = %0.3f (%0.3f)\n",  
            mrp_estimate_lin["offset"], mrp_estimate_lin["mean"], mrp_estimate_lin["sd"] ))


##################################################################################
# weights vs covariates 

cced_df_weights = cbind(cces_df, w_logit, w_lin) %>%
  mutate(male = as.factor(male))

for (x in c('state', 'eth', 'male', 'age', 'educ', 'region')) {
  print(cced_df_weights %>%
    ggplot() +
    geom_boxplot(aes(!!sym(x), w_logit)) +
    #geom_jitter(aes(age, w_logit), alpha = 0.2)
    theme_bw())
  
  print(cced_df_weights %>%
    ggplot() +
    geom_boxplot(aes(!!sym(x), w_lin)) +
    #geom_jitter(aes(age, w_logit), alpha = 0.2)
    theme_bw())
}


##################################################################################
# Maximum likelihood

# Logit
logit_fit <- glmer(abortion ~  1 + (1 | state) + (1 | eth) + (1 | educ) + male +
                     (1 | male:eth) + (1 | educ:age) + (1 | educ:eth) +
                     repvote + factor(region), 
                   family = binomial(link = "logit"), 
                   data = cces_df)
print(logit_fit)

# Linear
lm_fit <- lmer(abortion ~ 1 + (1 | state) + (1 | eth) + (1 | educ) + male +
                 (1 | male:eth) + (1 | educ:age) + (1 | educ:eth) +
                 repvote + factor(region), cces_df)
print(lm_fit)


