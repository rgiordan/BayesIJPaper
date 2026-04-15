# https://github.com/pcdjohnson/GLMMmisc/
library(GLMMmisc)
library(lme4)

base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"

############################
# test

set.seed(42)
n <- 150
x <- rnorm(n) + 1
z <- rnorm(n) + x^2
true_sigma <- 0.5
y <- rnorm(n, 0, true_sigma) + 0.5 + x + 0.1 * z

lm_result <- lm(y ~ x + z + 1)
summary(lm_result)

lm_result <- lm(y ~ x + 1)
summary(lm_result)

out_filename <- file.path(base_dir, "example-models/ARM/Ch.0/test.data.R")
out_file <- file(out_filename, "w")
CatVar <- function(varname, value) {
    cat(sprintf("%s <- c(%s)", varname, paste(value, collapse=",\n")), "\n", file=out_file)
}
cat('
bayes_ij_config <- list(
  n_var="N",
  samples=NA,
  loglik_var="lp_",
  w_var="w_",
  stan_vars=c("beta", "sigma"),
  num_boots=NA
)
', file=out_file)
cat("N <-", n, "\n", file=out_file)
CatVar("x", x)
CatVar("y", y)
close(out_file)


############################
# rstanarm glmm test

set.seed(42)
num_obs <- 1000
num_groups <- 30
x <- rnorm(num_obs)
z1 <- (sample.int(num_groups, num_obs, replace=TRUE))
#z2 <- as.numeric(as.factor(paste(z1, runif(num_obs) < 0.5)))
z2 <- as.integer(runif(num_obs) < 0.5)
z1_z2 <- as.integer(as.factor(paste(z1, z2, sep="_")))

form_str <- "y ~ x + (1 + x|z1) + (1|z1_z2)"
data_df <- data.frame(x=x, z1=z1, z1_z2=z1_z2)


z1_z2_sd <- sqrt(5)

z1_sd <- sqrt(7)
zx_sd <- sqrt(10)
corr_mat <- matrix(c(1, 0.01, 0.01, 1), 2, 2)
z1_cov <- diag(c(z1_sd, zx_sd)) %*% corr_mat %*% diag(c(z1_sd, zx_sd))
colnames(z1_cov) <- rownames(z1_cov) <- c("intercept", "x")

df <-
  sim.glmm(
    design.data=data_df,
    fixed.eff=list(intercept=0, x=15.0),
    rand.V=list("z1"=z1_cov, "z1_z2"=z1_z2_sd^2),
    distribution="gaussian",
    SD=0.1) %>%
  rename(y=response)

glm_fit <- lmer(formula=form_str, data=df)

model_config <- list(
  formula_str=form_str,
  rstan_fun="stan_glmer",
  prior="student_t(df=7)",
  prior_intercept="student_t(df=7)",
  family="gaussian()",
  num_samples=1000
)



# Write to a file
out_filename <- file.path(base_dir, "example-models/ARM/Ch.0/test_rstanarm.data.R")
out_file <- file(out_filename, "w")
CatVar <- function(varname, value) {
  cat(sprintf("%s <- c(%s)", varname, paste(value, collapse=",\n")), "\n", file=out_file)
}
cat("N <-", nrow(df), "\n", file=out_file)
CatVar("x", df$x)
CatVar("z1", df$z1)
CatVar("z2", df$z2)
CatVar("z1_z2", df$z1_z2)
CatVar("y", df$y)
close(out_file)
