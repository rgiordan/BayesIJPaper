# What does the rstanarm output mean?

library(ggplot2)
library(bayesplot)
library(rstanarm)
library(rstan)
library(tidyverse)
library(gridExtra)
library(lme4)
library(tidybayes)

num_cores <- 4
options(mc.cores=num_cores)

# https://github.com/pcdjohnson/GLMMmisc/
library(GLMMmisc)  

if (FALSE) {
    num_obs <- 500
    num_groups <- 70
    x <- rnorm(num_obs)
    z1 <- sample.int(num_groups, num_obs, replace=TRUE)
    z2 <- sample.int(num_groups, num_obs, replace=TRUE)
    
    form_str <- "y ~ x + (1|z1) + (1|z2)"
    data_df <- data.frame(x=x, z1=z1, z2=z2)
    
    z1_sd <- sqrt(50)
    z2_sd <- sqrt(10)
    df <-
        sim.glmm(
            design.data=data_df,
            fixed.eff=list(intercept=0, x=1.0),
            rand.V=list(z1=z1_sd^2, z2=z2_sd^2), distribution="gaussian",
            SD=0.1) %>%
        rename(y=response)
}

if (FALSE) {
    num_obs <- 500
    num_groups <- 70
    x <- rnorm(num_obs)
    z <- sample.int(num_groups, num_obs, replace=TRUE)

    form_str <- "y ~ x + (1 + x|z)"
    data_df <- data.frame(x=x, z=factor(z))

    z1_sd <- sqrt(50)
    zx_sd <- sqrt(10)
    z_cov <- matrix(0.1, 2, 2) + diag(c(z1_sd^2, zx_sd^2))
    colnames(z_cov) <- rownames(z_cov) <- c("intercept", "x")
    
    df <-
        sim.glmm(
            design.data=data_df,
            fixed.eff=list(intercept=0, x=1.0),
            rand.V=list("z"=z_cov), distribution="gaussian",
            SD=0.1) %>%
        rename(y=response)
    
}





print(sqrt(diag(z_cov)))
glmer_fit <- lmer(
    formula(form_str),
    data = df)


fit_time <- Sys.time()
rstan_fit <- stan_glmer(
    formula(form_str),
     data = df,
     family = gaussian(), 
     prior = student_t(7), 
     prior_intercept = student_t(7),
     iter=2000,
     chains=4,
     cores=4)
fit_time <- Sys.time() - fit_time
cat("Fit time:", fit_time, "\n")


rstan_variable_check <- stan_glmer(
    formula(form_str),
    data = df,
    family = gaussian(), 
    prior = student_t(7), 
    prior_intercept = student_t(7),
    iter=1,
    chains=1,
    cores=1)

as.matrix(rstan_variable_check, pars="x")

fit <- rstan_fit$stanfit
summary(fit)$summary[, c("mean", "sd", "se_mean", "n_eff")]
#get_variables(fit) # Doesn't really match
draws <- as.matrix(fit)
sigma_pars <- colnames(draws)[str_detect(colnames(draws), "[Ss]igma")]
# It appears that Sigma is the covariance matrix.
print(sigma_pars)
sigma_draws <- as.matrix(fit, pars=sigma_pars)
colMedian <- function(x) { apply(x, median, MARGIN=2) }
colMedian(sigma_draws)
colMedian(sqrt(sigma_draws))
colMedian((sigma_draws)^2)
sqrt(colMedian(sigma_draws))
sqrt(colMeans(sigma_draws)) # Ah this is what they do

vcov(rstan_fit)
vcov(glmer_fit)

VarCorr(rstan_fit)
VarCorr(glmer_fit)

sigma(rstan_fit)
sigma(glmer_fit)

colnames(as.matrix(rstan_fit, pars="(Intercept)", regex_pars="b\\[.*\\]"))
colnames(as.matrix(rstan_fit, regex_pars="b\\[x z:.*\\]"))
colnames(as.matrix(rstan_fit, regex_pars="Sigma\\[.*\\]"))
# colnames(as.matrix(rstan_fit, regex_pars="Sigma\\[(.*):\\1\\]")) # Doesn't work

# This works
grepl("Sigma\\[.*\\]", "Sigma[x:x]")
grepl("Sigma\\[(.*):\\1\\]", "Sigma[x:x]")
grepl("Sigma\\[(.*):\\1\\]", "Sigma[x:y]")
grepl("Sigma\\[(.*):\\1\\]", "Sigma[y:y]")






##############################################
# Automatically simulate from a mermod object.
# sim.glmm does not work with interactions in the random effects.

rstan_fit <- RunRstanArm(model_config, df, chains=4)
glm_fit <- lmer(formula=formula(model_config$formula_str), data=df)

vcov(rstan_fit)

df_sim <-
    sim.glmm(
        mer.fit=rstan_fit,
        design.data=data_df)



##############################################
# Automatically simulate from a mermod object.
# sim.glmm does not work with interactions in the random effects.


# ggplot(df) + 
#   geom_point(aes(x=paste0(z1, z2), y=y))

#rstan_fit <- RunRstanArm(model_config, df, chains=4)

VarCorr(glm_fit)
#VarCorr(rstan_fit)

#design_data <- model.frame(glm_fit, df, fixed.only=FALSE)


glform <- glFormula(formula(form_str), df)
names(glform)
head(glform$fr) # Output of model.matrix I guess

names(glform$reTrms)
dim(glform$reTrms$Zt)
colnames(glform$reTrms$Z)

# ?
glform$reTrms$theta
glform$reTrms$Lind
glform$reTrms$Gp
glform$reTrms$lower
dim(glform$reTrms$Lambdat)

names(glform$reTrms$flist)   # "factor list"?
names(glform$reTrms$cnms)    # "column names"?

names(glform$reTrms$Ztlist)  # Zt for each random effect in the formula?
dim(glform$reTrms$Ztlist[["1 | z1:z2"]])
dim(glform$reTrms$Ztlist[["1 + x | z1"]])

# Doesn't work with interactions in the levels.
#new_df <- sim.glmm(mer.fit=glm_fit, design.data=design_data)

class(glm_fit@flist)
class(getME(glm_fit, "Z"))
class(getME(glm_fit, "mmList"))


getME(glm_fit, "fixef")
fixef(rstan_fit)




