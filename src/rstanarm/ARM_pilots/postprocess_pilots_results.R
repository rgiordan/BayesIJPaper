# Load and process results produced by model_script.R.

library(broom)
library(broom.mixed)


library(tidyverse)
library(rstan)
library(rstansensitivity)
library(gridExtra)

library(bayesijlib)
library(rstanarmijlib)

library(sandwich)

rstan_options(auto_write=TRUE)

repo_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/"
base_dir <- file.path(repo_dir, "src/bayes")
stan_examples_dir <- file.path(base_dir, "example-models")
output_dir <- file.path(base_dir, "rstanarm/cluster/output")
paper_dir <- file.path(repo_dir, "writing/bayes/R_scripts/ARM_pilots")
    
model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, "rstanarm/configs/", model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

output_filename <- sprintf("compiled_results_%s.Rdata", "0924")
load(file=file.path(output_dir, output_filename))

file_suffix <- "0924_cluster"


######################################
# Derive more convenient versions

model_df <-
    do.call(bind_rows, lapply(model_list, function(x) {
        data.frame(desc=x$desc,
                   family=x$family,
                   rstan_fun=x$rstan_fun,
                   exchangeable_col=x$exchangeable_col,
                   formula_str=x$formula_str)
    })) %>%
    mutate(model_index=1:n())

nrow(model_df)
length(model_list)

# Models 7 and 13, something went wrong, the variances are very large

comb_df <- 
    combined_df_nore %>%
    filter(model_index != 7) %>%
    filter(model_index != 13) %>%
    mutate(has_sigma=ifelse(grepl("[Ss]igma", params), "Scale", "Location"),
           big_n=ifelse(num_exch_obs >= 240, "N >= 240", "N < 240"),
           is_cov=ifelse(is_diag, "Variance", "Covariance")) %>%
    inner_join(model_df, by=c("model_index", "desc"))





####################################
# ARM_Ch.13_pilots_independent
#
# Here, Bayes and IJ differ because we're resampling conditional
# on a small number of random effects.  But it's still a nice example
# because (a) LME4 doesn't work and (b) the frequentist variability is
# a reasonable thing to want to know.

i <- 55

filter(comb_df, model_index == i) %>% colnames()
filter(comb_df, model_index == i) %>%
    filter(is_cov == "Variance") %>%
    select(row_variable, ij_cov, bayes_cov, bootstrap_cov)

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

# y actually has some repeats!!!  That is why this is degenerate.
df <- LoadRstanarmDataframe(model_config, stan_examples_dir)

res_list <- LoadModelResults(model_config, file_suffix)
res_list$base_results$mcmc_results$fit_time

num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- colnames(draws_mat)
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit  # We may overwrite this below
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(params=row_variable) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))

# Results
rstan_fit
tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot


plot_se_df <- 
    this_comb_df %>%
    select(row_variable,
           bayes_se, ij_se, bootstrap_se) %>%
    pivot_longer(cols=-row_variable, names_to="method", values_to="cov_se") %>%
    mutate(method=str_replace(method, "_se$", ""))


plot_df <- 
    this_comb_df %>%
    select(row_variable,
           bayes_cov, ij_cov, bootstrap_cov) %>%
    pivot_longer(cols=-row_variable, names_to="method", values_to="cov") %>%
    mutate(method=str_replace(method, "_cov$", "")) %>%
    inner_join(plot_se_df, by=c("row_variable", "method"))


ggplot(plot_df) +
    geom_bar(aes(y=cov, x=method, fill=method),
             stat="identity", position="dodge") +
    geom_errorbar(aes(x=method, ymin=cov - 2 * cov_se, ymax=cov + 2 * cov_se),
                  stat="identity", position=position_dodge(0.9), width=0.2) +
    facet_grid(row_variable ~ ., scales="free")

###########################################################
###########################################################
# What if we fit the marginal model directly?

model_config$formula_str

model <- stan_model(file.path(paper_dir, "pilots_marginal.stan"))
model_z <- stan_model(file.path(paper_dir, "pilots_full.stan"))
#model_logparam <- stan_model(file.path(paper_dir, "pilots_marginal_logparam.stan"))

x1 <- model.matrix(y ~ -1 + factor(group_id), df) %>% scale(scale=FALSE)
x2 <- model.matrix(y ~ -1 + factor(scenario_id), df) %>% scale(scale=FALSE)

#rstan_fit <- stan_glmer(formula(model_config$formula_str), data=df)
prior_summary(rstan_fit)
prior_summary(rstan_fit)$prior_covariance
# Note that the shape and scale of the decov give gamma parameters for the random effect variances

# Here I'm trying to match the (original) rstan fit output
#priors <- c(mu_prior=3.7, sigma1_prior=2.7, sigma2_prior=2.7, sigma_eps_prior=2.7)
#priors <- c(mu_prior=3.7, sigma1_prior=1, sigma2_prior=1, sigma_eps_prior=2.7)
#priors <- c(mu_prior=3.7, sigma1_prior=1 / 0.373, sigma2_prior=1 / 0.373, sigma_eps_prior=2.7)

# x1_sd <- apply(x1, MARGIN=2, sd) %>% mean()
# x2_sd <- apply(x2, MARGIN=2, sd) %>% mean( )
# priors <- c(mu_prior=3.7, sigma1_prior=x1_sd^2, sigma2_prior=x2_sd^2, sigma_eps_prior=2.7)

stan_data <- c(priors, list(N=nrow(df), y=df$y, xxt_1=x1 %*% t(x1), xxt_2=x2 %*% t(x2)))
stan_data_z <- c(priors, list(N=nrow(df), y=df$y, D1=ncol(x1), D2=ncol(x2), x1=x1, x2=x2))
marg_stan <- sampling(model, data=stan_data,
                      pars=c("mu", "sigma_eps", "sigma1", "sigma2"))
joint_stan <- sampling(model_z, data=stan_data_z,
                       pars=c("mu", "sigma_eps", "sigma1", "sigma2"), iter=10000)
opt_stan <- optimizing(model, data=stan_data)
opt_joint_stan <- optimizing(model_z, data=stan_data_z)

# Rstan is slighltly different than we are probably because of the priors

# x1 is group
# x2 is scenario
tidy(marg_stan)
tidy(joint_stan)
rstan_fit

print("--------------------")
extract(marg_stan, "sigma1")$sigma1 %>% median()
extract(marg_stan, "sigma1")$sigma1 %>% mean()
as.matrix(rstan_fit)[, "Sigma[group_id:(Intercept),(Intercept)]"] %>% sqrt() %>% median()
as.matrix(rstan_fit)[, "Sigma[group_id:(Intercept),(Intercept)]"] %>% sqrt() %>% mean()

print("--------------------")
extract(marg_stan, "sigma2")$sigma2 %>% median()
extract(marg_stan, "sigma2")$sigma2 %>% mean()
as.matrix(rstan_fit)[, "Sigma[scenario_id:(Intercept),(Intercept)]"] %>% sqrt() %>% median()
as.matrix(rstan_fit)[, "Sigma[scenario_id:(Intercept),(Intercept)]"] %>% sqrt() %>% mean()

#extract(marg_stan, "sigma1")$sigma1 %>% qqnorm()
#opt_stan_logparam$theta_tilde[, c("mu", "sigma_eps", "sigma1", "sigma2")]

###############
# Example for discourse

rstan_fit <- stan_glmer(y ~ 1 + (1 | group_id) + (1 | scenario_id), df)
print(rstan_fit)
rstan_draws <- as.matrix(rstan_fit)
group_id_col <- "Sigma[group_id:(Intercept),(Intercept)]"
scenario_id_col <- "Sigma[scenario_id:(Intercept),(Intercept)]"

median(sqrt(rstan_draws[, group_id_col]))
mean(sqrt(rstan_draws[, group_id_col]))

median(sqrt(rstan_draws[, scenario_id_col]))
mean(sqrt(rstan_draws[, scenario_id_col]))



# Compare marginal optimization to lme4:
opt_stan$theta_tilde[, c("mu", "sigma_eps", "sigma1", "sigma2")]
tidy(lme4_fit)

# Comare the marginal to the joint optima
rbind(
    opt_stan$theta_tilde[, c("mu", "sigma_eps", "sigma1", "sigma2")],
    opt_joint_stan$theta_tilde[, c("mu", "sigma_eps", "sigma1", "sigma2")])
sd(df$y)


# Compare random effects
ranef(rstan_fit)$group_id
data.frame(opt_joint_stan$theta_tilde) %>%
    pivot_longer(cols=matches(".*")) %>%
    filter(str_detect(name, "^eta1"))

ranef(rstan_fit)$scenario_id
data.frame(opt_joint_stan$theta_tilde) %>%
    pivot_longer(cols=matches(".*")) %>%
    filter(str_detect(name, "^eta2"))


#######################################

# Let's plot the marginal probability with the mu and sigma_eps fixed, since these are
# well estimated in both cases


sigma1_grid <- seq(1e-3, 0.2, length.out=60)
sigma2_grid <- seq(0.1, 0.6, length.out=60)

par_list <- get_inits(marg_stan)[[1]]
par_list$y_cov <- NULL
par_list$mu <- tidy(marg_stan) %>% filter(term == "mu") %>% pull(estimate)
par_list$sigma_eps <- tidy(marg_stan) %>% filter(term == "sigma_eps") %>% pull(estimate)

# upars <- unconstrain_pars(marg_stan, par_list)
# log_prob(marg_stan, upars, adjust_transform=FALSE, grad=TRUE)
# grad_log_prob(marg_stan, upars, adjust_transform=FALSE)

marg_lp_df <- data.frame()
for (i1 in 1:length(sigma1_grid)) {
for (i2 in 1:length(sigma2_grid)) {
    par_list$sigma1 <- sigma1_grid[i1]
    par_list$sigma2 <- sigma2_grid[i2]
    upars <- unconstrain_pars(marg_stan, par_list)
    # WTF, if you don't set grad=TRUE, log_prob returns 0 with adjust_transform=FALSE
    lp_nojac <- log_prob(marg_stan, upars, adjust_transform=FALSE, grad=TRUE)
    lp <- log_prob(marg_stan, upars)
    marg_lp_df <- marg_lp_df %>%
        bind_rows(data.frame(
            sigma1=par_list$sigma1,
            sigma2=par_list$sigma2,
            lp=lp,
            lp_nojac=lp_nojac))
}}


grid.arrange(
    ggplot(marg_lp_df) +
        geom_contour_filled(aes(x=log(sigma1), y=log(sigma2), z=lp), bins=50) +
        theme(legend.position="none")
,    
    ggplot(marg_lp_df) +
        geom_contour_filled(aes(x=sigma1, y=sigma2, z=lp_nojac), bins=50) +
        theme(legend.position="none")
,ncol=1   
)

grid.arrange(
    ggplot(marg_lp_df) +
        geom_line(aes(x=log(sigma1), color=log(sigma2), group=sigma2, y=lp))
,    
    ggplot(marg_lp_df) +
        geom_line(aes(x=sigma1, color=sigma2, group=sigma2, y=lp_nojac))
, ncol=1   
)


sigma1_hat_jac <- marg_lp_df[which.max(marg_lp_df$lp), ] %>% pull(sigma1)
sigma2_hat_jac <- marg_lp_df[which.max(marg_lp_df$lp), ] %>% pull(sigma2)

sigma1_hat <- marg_lp_df[which.max(marg_lp_df$lp_nojac), ] %>% pull(sigma1)
sigma2_hat <- marg_lp_df[which.max(marg_lp_df$lp_nojac), ] %>% pull(sigma2)


# Actually if you include the Jacobian it works fine.
sigma1_hat_jac
sigma2_hat_jac
tidy(marg_stan)
