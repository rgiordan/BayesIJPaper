library(rstanarm)
library(tidyverse)
library(gridExtra)
library(rstansensitivity)

opt <- list()
opt$num_cores <- 4
opt$num_mcmc_chains <- 4

base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
source(file.path(base_dir, "rstanarm_lib.R"))
stan_examples_dir <- file.path(base_dir, "example-models")

# The random effects will be distributed according to a bimodal distribution.
set.seed(42)

#num_re <- 200  # TODO: this should be saved in the data file in the future.
#load(file=file.path(stan_examples_dir, "kernel", "kernel_fit_obs_per_re100.Rdata"))
load(file=file.path(stan_examples_dir, "kernel", "kernel_fit_obs_per_re25.Rdata"))

num_sims <- length(rstan_fits)


###########################################
# Get draws

lambda_draws_list <- list()
par_draws_list <- list()
for (sim in 1:num_sims) {
    rstan_fit <- rstan_fits[[sim]]$rstan_fit
    
    all_draws <- as.matrix(rstan_fit)
    lambda_cols <- sprintf("b[(Intercept) z:%d]", 1:num_re)
    lambda_draws <- all_draws[, lambda_cols]
    par_draws <- all_draws[, setdiff(colnames(all_draws), lambda_cols)]
    colnames(lambda_draws) <- sprintf("lambda_%d", 1:num_re)
    
    lambda_draws_list[[sim]] <- lambda_draws
    par_draws_list[[sim]] <- par_draws
}


num_draws <- nrow(lambda_draws_list[[1]])
  



################################################
################################################
# A simple analysis

loglik_mat <- rstan_fits[[1]]$loglik_mat
par_draws <- par_draws_list[[1]]

ij_cov <- num_re * ComputeIJCovariance(loglik_mat, par_draws)
bayes_cov <- cov(par_draws, par_draws)

sim_means <- do.call(rbind, lapply(1:num_sims, function(sim) { colMeans(par_draws_list[[sim]]) }))
sim_cov <- cov(sim_means, sim_means)

# Works as expected.
rbind(
    sqrt(diag(bayes_cov)),
    sqrt(diag(ij_cov)),
    sqrt(diag(sim_cov)))



################################################
################################################
# Non-central moments

GetMomentDraws <- function(sim, moment_order) {
    # Compute the sample central moment within each row, i.e., within each draw.
    offset_draws <- par_draws_list[[sim]][, "(Intercept)"]
    lambda_draws <- lambda_draws_list[[sim]]
    lambda_draws <- lambda_draws - rowMeans(lambda_draws)
    #lambda_draws <- lambda_draws - offset_draws
    return(rowMeans(lambda_draws^moment_order))
}

lambda_center <- matrix(NA, num_draws, num_sims)
lambda_var <- matrix(NA, num_draws, num_sims)
lambda_skew <- matrix(NA, num_draws, num_sims)
lambda_kurt <- matrix(NA, num_draws, num_sims)
for (sim in 1:num_sims) {
    lambda_center[, sim] <- rowMeans(lambda_draws_list[[sim]])
    lambda_var[, sim] <- GetMomentDraws(sim, 2)
    lambda_skew[, sim] <- GetMomentDraws(sim, 3)
    lambda_kurt[, sim] <- GetMomentDraws(sim, 4)
}
dim(lambda_var)


#######################################
# Sanity check

# I would expect the posterior variance to be highly correlated
# with the sample variance of the lambdas within a draw.
# plot(lambda_var[, 1], 
#      par_draws_list[[1]][, "Sigma[z:(Intercept),(Intercept)]"],
#      abline(0, 1))


if (FALSE) {
    sigma2_draws <- par_draws_list[[1]][, "Sigma[z:(Intercept),(Intercept)]"]
    cor(lambda_var[, 1], sigma2_draws)
    plot(lambda_var[, 1], sigma2_draws)
    
    cond_draws <- abs(lambda_var[, 1] - 1.1) < 0.02
    sum(cond_draws)
    mean(sigma2_draws[cond_draws])
    sd(sigma2_draws[cond_draws])
    1 / sqrt(200)
    
    offset_draws <- par_draws_list[[1]][, "(Intercept)"]
    cor(lambda_center[, 1], offset_draws)
    plot(lambda_center[, 1], offset_draws)

}

########################################
# Compare to normality implied estimate

colnames(par_draws_list[[1]])
sigma2_mean <- mean(par_draws_list[[1]][, "Sigma[z:(Intercept),(Intercept)]"])

var_normal <- sigma2_mean
skew_normal <- 0
kurt_normal <- 3 * (sigma2_mean^2)

var_normal
median(colMeans(lambda_var))
median(apply(lambda_var, MARGIN=2, sd))

skew_normal
median(colMeans(lambda_skew))
median(apply(lambda_skew, MARGIN=2, sd))

kurt_normal
median(colMeans(lambda_kurt))
median(apply(lambda_kurt, MARGIN=2, sd))


########################
# Simulation variance

expectation_sims <- rbind(colMeans(lambda_var), colMeans(lambda_skew), colMeans(lambda_kurt))
sim_cov <- cov(t(expectation_sims))
colnames(sim_cov) <- c("var", "skew", "kurtosis")
sqrt(diag(sim_cov))


#######################################
# IJ Covariances

moment_draws <- cbind(lambda_var[, 1], lambda_skew[, 1], lambda_kurt[, 1])
colnames(moment_draws) <- c("var", "skew", "kurtosis")
loglik_mat <- rstan_fits[[1]]$loglik_mat

ij_cov <- num_re * ComputeIJCovariance(loglik_mat, moment_draws)
ij_cov

bayes_cov <- cov(moment_draws, moment_draws)

rbind(sqrt(diag(bayes_cov)),
      sqrt(diag(ij_cov)),
      sqrt(diag(sim_cov)))

se_envr <- GetBlockBootstrapStandardErrors(
    loglik_mat, moment_draws, num_blocks=100, num_draws=50)

rbind(2 * diag(se_envr$draw_bayes_cov_se),
      2 * diag(se_envr$draw_ij_cov_se))

rbind((sqrt(diag(bayes_cov)) - sqrt(diag(sim_cov))) / diag(se_envr$draw_bayes_cov_se),
      (sqrt(diag(ij_cov))  - sqrt(diag(sim_cov))) / diag(se_envr$draw_ij_cov_se))


# Look at influence scores

obs_infl <- cov(loglik_mat, moment_draws)
colnames(obs_infl) <- colnames(moment_draws)
obs_infl <- data.frame(obs_infl) %>% mutate(n=1:n()) %>% pivot_longer(cols=-n)

obs_n <- obs_infl %>%
  filter(name == "var") %>%
  filter(value == max(value)) %>%
  `[[`("n")

ggplot() + 
  geom_point(aes(x=loglik_mat[, obs_n], moment_draws[, "var"]))

grid.arrange(
  qplot(sample=moment_draws[, "var"], geom="qq"),
  qplot(sample=moment_draws[, "skew"], geom="qq"),
  qplot(sample=moment_draws[, "kurtosis"], geom="qq"),
  ncol=3
)

grid.arrange(
  qplot(sample=loglik_mat[, 1], geom="qq"),
  qplot(sample=loglik_mat[, 2], geom="qq"),
  qplot(sample=loglik_mat[, 3], geom="qq"),
  qplot(sample=loglik_mat[, 4], geom="qq"),
  qplot(sample=loglik_mat[, obs_n], geom="qq"),
  ncol=5
)

ggplot(obs_infl) +
  geom_histogram(aes(x=value, fill=name), bins=100) +
  facet_grid(. ~ name)

# Why is the log lik so bad?


lambda_draws <- lambda_draws_list[[1]]
ld <- lambda_draws[, 1]
grid.arrange(
  qplot(sample=loglik_mat[, 1], geom="qq"),
  qplot(sample=ld, geom="qq"),
  qplot(sample=ld + log(1 + exp(ld) / (1 + exp(ld))), geom="qq")
)


#################################
# *******************************
# THIS IS WHY NONE OF THIS WORKS

df <- data.frame(par_draws)
colnames(df) <- c("offset", "x", "sigma")
df$lambda <- lambda_draws[, 1]
df$ll <- loglik_mat[, 1]
df$n <- 1:nrow(df)
df <- df %>% pivot_longer(cols=c(-n, -ll))
head(df)
ggplot(df) +
  geom_point(aes(x=ll, y=value)) +
  facet_grid(~name)


qplot(df$ll, geom="histogram")

# If I'm right you should see a similar pattern with the
# full log likelihood and the global parameters.

# ... seems I am not right?

df <- data.frame(par_draws)
colnames(df) <- c("offset", "x", "sigma")
df$ll <- rowSums(loglik_mat)
df$n <- 1:nrow(df)
df <- df %>% pivot_longer(cols=c(-n, -ll))
head(df)

qplot(sample=df$ll, geom="qq")

ggplot(df) +
  geom_point(aes(x=ll, y=value)) +
  facet_grid(~name)







################################################
################################################
# KDEs don't work.  Why?

#############################################
# Let's define a Kernel density estimator.

BaseKern <- function(x1, x2, width) {
    return(dnorm(x1 - x2, sd=width))
}

GetKern <- function(loc, grid_n, width) {
    return(function(x) { BaseKern(loc, x, width) / grid_n})
}


# Fix a grid.
grid_n <- 15
lambda_draws <- lambda_draws_list[[1]]
lambda_min <- quantile(lambda_draws, 0.01)
lambda_max <- quantile(lambda_draws, 0.99)
lambda_grid <- seq(lambda_min, lambda_max, length.out=grid_n)
width <- max(diff(lambda_grid))

kern_draws_list <- list()
for (sim in 1:num_sims) {
    cat("Simulation ", sim, "\n")
    
    lambda_draws <- lambda_draws_list[[sim]]
    num_mcmc_draws <- dim(lambda_draws)[1]
    kern_draws <- matrix(NA, num_mcmc_draws, grid_n)
    pb <- txtProgressBar(min=1, max=grid_n, style = 3)
    for (i in 1:grid_n) {
        setTxtProgressBar(pb, i)
        ThisKern <- GetKern(lambda_grid[i], grid_n, width)
        kern_w <- ThisKern(lambda_draws)
        # A single draw of the kernel weight is the averge over observed lambda in that draw.
        kern_draws[, i] <- rowMeans(kern_w)
    }
    close(pb)
    kern_draws_list[[sim]] <- kern_draws
}


#############################
# Frequentist cov by simulation

e_kern <- matrix(NA, num_sims, grid_n)
for (sim in 1:num_sims) {
    e_kern[sim, ] <- colMeans(kern_draws_list[[sim]])
}
sim_cov <- cov(e_kern, e_kern) * num_re

if (FALSE) {
    plot(lambda_grid, e_kern[1, ], "b")
}

#############################
# IJ cov

kern_draws <- kern_draws_list[[1]]
loglik_mat <- rstan_fits[[1]]$loglik_mat

kern_colnames <- sprintf("k%d", 1:ncol(kern_draws))
colnames(kern_draws) <- kern_colnames
colnames(sim_cov) <- kern_colnames
ij_cov <- ComputeIJCovariance(loglik_mat, kern_draws)
bayes_cov <- cov(kern_draws, kern_draws)

se_envr <- GetBlockBootstrapStandardErrors(
    loglik_mat, kern_draws, num_blocks=100, num_draws=50)

plot(num_re * diag(bayes_cov), diag(ij_cov)); abline(0, 1)

ij_df <- TidyCovarianceFrame(ij_cov * num_re, se_envr$draw_ij_cov_se * num_re, method="ij")
bayes_df <- TidyCovarianceFrame(bayes_cov, se_envr$draw_bayes_cov_se, "bayes")
sim_df <- TidyCovarianceFrame(sim_cov, matrix(0, dim(sim_cov)[1], dim(sim_cov)[2]), "sim")

join_cols <- c("row_variable", "column_variable", "row_variable_name", "column_variable_name", "params")
tidy_result <-
    ij_df %>%
    inner_join(bayes_df, by=join_cols) %>%
    inner_join(sim_df, by=join_cols) %>%
    mutate(is_diag=(column_variable == row_variable))


ggplot(tidy_result %>% filter(is_diag)) +
    geom_point(aes(x=sim_cov, y=bayes_cov, color="bayes")) +
    geom_point(aes(x=sim_cov, y=ij_cov, color="IJ")) +
    geom_abline(aes(slope=1, intercept=0))

ggplot(tidy_result %>% filter(is_diag)) +
    geom_point(aes(x=ij_cov, y=bayes_cov)) +
    geom_abline(aes(slope=1, intercept=0))



#########################
#########################
# Other stuff



##########################
# Let's make sure the kernel density estimator works for the actual lambdas.

lambda_grid <- seq(min(lambda), max(lambda), length.out=grid_n)
width <- max(diff(lambda_grid))
kern_w <- sapply(lambda_grid, function(x) { mean(GetKern(x, grid_n, width)(lambda))})
plot(lambda_grid, kern_w, "b")


##########################
# Look at one

z <- 110
hist(lambda_draws[, z], 100)
abline(v=lambda[z], col="red")



######################
# Old 

if (FALSE) {
    # For a gamma
    GetGammaShapeRate <- function(mean, var) {
        shape <- (mean^2) / var
        rate <- shape / mean
        return(c(shape, rate))
    }
    shape_rate1 <- GetGammaShapeRate(mean1, var1)
    shape_rate2 <- GetGammaShapeRate(mean2, var2)
    lambda1 <- rgamma(num_re, shape=shape_rate1[1], rate=shape_rate1[2])
    lambda2 <- rgamma(num_re, shape=shape_rate2[1], rate=shape_rate2[2])
}
