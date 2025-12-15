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

base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")
output_dir <- file.path(base_dir, "rstanarm/cluster/output")

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





##################################
# Summaries of the results

names(comb_df)

group_by(comb_df, is_cov, big_n, rstan_fun) %>%
    summarize(ij_boot_err = mean(abs(ij_bootstrap_diff_norm)),
              bayes_boot_err = mean(abs(bayes_bootstrap_diff_norm))
    )

# Filter for models where the Bayesian covariance is different from the IJ,
# both practically and statistically.
# Smaller num_exch_obs just don't work well.
bayes_mismatch <-
    filter(comb_df,
           abs(bayes_ij_diff_norm) > 0.25,
           abs(bayes_ij_z) > 2.0) %>%
    filter(is_diag, num_exch_obs > 100)
table(bayes_mismatch$desc)

if (FALSE) {
    # All of these are worth looking at.
    bayes_mismatch %>%
        select(model_index, desc, formula_str,
               #exchangeable_col,
               num_exch_obs,
               params,
               bayes_ij_z, bayes_cov, ij_cov, bootstrap_cov
        ) %>%
        View()
    
    # Let's look at these; they are a handful of the more complex
    # models on particular datasets, with a range of mis-estimated
    # variances.
    deviant_models <- c(10, 34, 36, 41, 40)
    
    # Also consider 20, 55, and 65, which are where lme4 deviates from rstanarm (see
    # examine_lme4_results).  Though 20 is simulated data.
}


bayes_mismatch$desc <- factor(as.character(bayes_mismatch$desc))
length(unique(bayes_mismatch$desc))
ggplot(bayes_mismatch %>%
           filter(is_diag, num_exch_obs > 100)) +
    geom_segment(aes(x=bootstrap_cov, y=bayes_cov,
                     xend=bootstrap_cov, yend=ij_cov,
                     color=factor(model_index)),
                 arrow=arrow(length = unit(0.01, "npc"))) +
    geom_abline(aes(slope=1, intercept=0)) +
    scale_y_log10() + scale_x_log10()# + facet_grid( ~ big_n)




######################################
# I think what is needed is combined results for LME4, the sandwich covariance,
# standard errors, and everything in SD not variance units.


####################################
# ARM_Ch.13_pilots_independent
#
# Here, Bayes and IJ differ because we're resampling conditional
# on a small number of random effects.  But it's still a nice example
# because (a) LME4 doesn't work and (b) the frequentist variability is
# a reasonable thing to want to know.

i <- 55

filter(combined_df_nore, model_index == i) %>% select(row_variable, column_variable, params)

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

# y actually has some repeats!!!  That is why this is degenerate.
df <- LoadRstanarmDataframe(model_config, stan_examples_dir)

# Group was the amount of experience, scenario the failure scenario
lmer(y ~ 1 + (1|scenario_id) + (1|group_id), df)
summary(df)


res_list <- LoadModelResults(model_config, file_suffix)
res_list$base_results$mcmc_results$fit_time

num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- colnames(draws_mat)
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

df %>% pivot_wider(id_cols=scenario_id, names_from=group_id, values_from=y)

class(rstan_fit)
prior_summary(rstan_fit)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(params=row_variable) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))

# Results
tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot


if (FALSE) {
    plot_df <- 
        this_comb_df %>%
            select(row_variable, bayes_sd, ij_sd, bootstrap_sd) %>%
            pivot_longer(cols=-row_variable, names_to="method")
    ggplot(plot_df) +
        geom_bar(aes(x=row_variable, y=value, fill=method),
                 stat="identity", position="dodge")
    
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
    
    
    
    x_df <-
        as_tibble(model.matrix(rstan_fit)) %>%
        mutate(obs=1:n(), eps=resid(rstan_fit))
    qqnorm(x_df$eps)
    
    # All regressors are binary.
    table(select(x_df, -eps, -obs))
    
    # Some heteroskedasticity
    group_by(x_df, regressor, value) %>%
        summarize(sd_eps=sd(eps))
    
    # Some of the MCMC draws for scale parameters look quite non-normal.  
    # Taking the log helps but doesn't totally fix the non-normality.
    as_tibble(draws_mat[, keep_pars]) %>%
        mutate(draw=1:n()) %>%
        pivot_longer(cols=-draw, names_to="parameter") %>%
        ggplot() +
        geom_qq(aes(sample=value)) +
        facet_grid(parameter ~ ., scales="free", switch = "y") +
        theme(strip.text.y.left = element_text(angle = 0))
    
}

if (FALSE) {
    # Why is this singular?
    
    ng <- max(df$group_id)
    ns <- max(df$scenario_id)
    df$eps <- resid(rstan_fit)

    # umm
    y_mat <- matrix(NA, ns, ng)
    for (g in 1:ng) {
        for (s in 1:ns) {
            y_mat[s, g] <- filter(df, scenario_id == !!s, group_id == !!g) %>% pull(eps)            
        }
    }
    
    df_rand <- df
    df_rand$y <- df_rand$y + rnorm(length(df_rand$y), sd=0)
    table(df_rand$y) %>% table()
    lme4_refit <-
        lmer(formula(model_config$formula_str),
             data=df_rand)
    lme4_refit@optinfo$conv$lme4
    summary(lme4_refit)
    
    # isSingular has some interesting references
    rePCA(lme4_refit)
    rePCA(lme4_fit)
}


#############################################
# ARM_Ch.4_logearn_interaction_independent
# There are differences, but they don't seem all that exciting.
# lme4 is not far from bayes, and the bootstrap is only a little different from the IJ.

i <- 10

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

res_list <- LoadModelResults(model_config, file_suffix)
num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))


tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot



##############################
# ARM_Ch.7_congress_independent
#
# The bootstrap and IJ SEs are considerably larger than the Bayes ones
# Interestingly, the bootstrap is also larger than the lme4 SEs.
# This is because the sandwich covariance does not match the ordinary
# covariance matrix, pointing to misspecification.

i <- 34

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

res_list <- LoadModelResults(model_config, file_suffix)
num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)


draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))

if (FALSE) {
    # Let's make a nice summary plot that can replace a table
    this_comb_df %>%
        select(row_variable, bayes_sd, ij_sd, bootstrap_sd) %>%
        pivot_longer(cols=-row_variable, names_to="method") %>%
        ggplot() +
            geom_bar(aes(x=row_variable, y=value, fill=method),
                     stat="identity", position="dodge")
    
}

tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot

# Note that the heteroskedasticity-robust estimate matches the bootstrap.
diag(sandwich::vcovCL(lme4_fit)) %>% sqrt()
diag(vcov(lme4_fit)) %>% sqrt()


# Look at residual plot.  There's nothing very obvious!
if (FALSE) {
    
    print(model_config$formula_str)
    
    df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
    df$eps <- resid(rstan_fit)
    
    ggplot(df) +
        geom_point(aes(x=vote_86, y=abs(eps))) +
        geom_smooth(aes(x=vote_86, y=abs(eps))) +
        facet_grid(incumbency_88 ~ .)
    
    ggplot(df) + geom_histogram(aes(x=eps, group=factor(incumbency_88)), bins=50) +
        facet_grid(incumbency_88 ~ .)
}



###############################################
# ARM_Ch.7_earnings_interactions_independent
# The estimate of sex1 is quite different between lme4 and bayes,
# though the difference is much less than the standard error.
# Also, the lme4 and IJ variances are different, and not because of
# misspecification (the lme4 and bootstrap and sandwich all match).
# So Bayes is doing something different than lme4 here.
# 
# Note that the IJ covariances improve on Bayes but do not go
# all the way to the bootstrap.  The differences are also small,
# except for the intercept, where the IJ does well.
#
# This model is used on page 142 of the book for no purpose other than
# to illustrate simulation-based approximate Bayesian computation.

i <- 36

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

res_list <- LoadModelResults(model_config, file_suffix)
num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)


draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))

if (FALSE) {
    # Let's make a nice summary plot that can replace a table
    this_comb_df %>%
        select(row_variable, bayes_sd, ij_sd, bootstrap_sd) %>%
        pivot_longer(cols=-row_variable, names_to="method") %>%
        ggplot() +
        geom_bar(aes(x=row_variable, y=value, fill=method),
                 stat="identity", position="dodge")
    
    ggplot(this_comb_df) +
        geom_segment(aes(x=bootstrap_cov, y=bayes_cov,
                         xend=bootstrap_cov, yend=ij_cov,
                         color=factor(params)),
                     arrow=arrow(length = unit(0.01, "npc"))) +
        geom_abline(aes(slope=1, intercept=0)) +
        scale_y_log10() + scale_x_log10()# + facet_grid( ~ big_n)
}

# Results
tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot

# Note that the heteroskedasticity-robust estimate matches the bootstrap.
diag(sandwich::vcovCL(lme4_fit)) %>% sqrt()
diag(vcov(lme4_fit)) %>% sqrt()

# Look at the data
print(model_config$formula_str)
df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
df$eps <- resid(rstan_fit)
# The residuals are pretty non-normal.
qqnorm(df$eps)
summary(df)

# The R2 is low.
var(log(df$earnings))  / var(df$eps)

if (FALSE) {
    # There is some slight non-normality in some of the draws.
    as_tibble(draws_mat) %>%
        mutate(draw=1:n()) %>%
        pivot_longer(cols=-draw, names_to="parameter") %>%
    ggplot() +
        geom_qq(aes(sample=value)) +
        facet_grid(parameter ~ ., scales="free") 
}

if (FALSE) {
    x_df <-
        as_tibble(model.matrix(rstan_fit)) %>%
        mutate(obs=1:n(), eps=df$eps) %>%
        pivot_longer(cols=-c(obs, eps), names_to="regressor")
    
    ggplot(x_df) +
        geom_point(aes(x=value, y=eps, color=regressor)) +
        geom_smooth(aes(x=value, y=eps, color=regressor)) +
        facet_grid( ~ regressor, scales="free")
}


####################################
# ARM_Ch.10_ideo_reparam_independent
#
# Strong evidence of heteroskedasticity in the LME4 result.
# Here the IJ improves some over the bootstrap, but not uniformly.
# 
# Top of page 215 of the book, I'm pretty sure.
# This is a regression discontinuity design.
# We have that
# z1 = z * 1(party == 0) and z2 = z * I(party = 1), where
# z = x - 0.5 and x = proportion of vote received for a republican.
# The outcome, ideo, is a separately computed ideology score based
# on roll-call votes.  I gather that each row is a district.
#
# The point of this is to estimate separate slopes for democrats
# and republicans, assessing whether a district's voting 
# affects a candidates ideology after controlling for party.


i <- 41

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

res_list <- LoadModelResults(model_config, file_suffix)
num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))

# Results
tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot

diag(sandwich::vcovCL(lme4_fit)) %>% sqrt()
diag(vcov(lme4_fit)) %>% sqrt()


if (FALSE) {
    # Let's make a nice summary plot that can replace a table
    this_comb_df %>%
        select(row_variable, bayes_sd, ij_sd, bootstrap_sd) %>%
        pivot_longer(cols=-row_variable, names_to="method") %>%
        ggplot() +
        geom_bar(aes(x=row_variable, y=value, fill=method),
                 stat="identity", position="dodge")
    
    ggplot(this_comb_df) +
        geom_segment(aes(x=bootstrap_cov, y=bayes_cov,
                         xend=bootstrap_cov, yend=ij_cov,
                         color=factor(params)),
                     arrow=arrow(length = unit(0.01, "npc"))) +
        geom_abline(aes(slope=1, intercept=0)) +
        scale_y_log10() + scale_x_log10()# + facet_grid( ~ big_n)

    x_df <-
        as_tibble(model.matrix(rstan_fit)) %>%
        mutate(obs=1:n(), eps=resid(rstan_fit)) %>%
        pivot_longer(cols=-c(obs, eps), names_to="regressor")
    
    ggplot(x_df) +
        geom_point(aes(x=value, y=eps, color=regressor)) +
        geom_smooth(aes(x=value, y=eps, color=regressor)) +
        facet_grid( ~ regressor, scales="free")

    as_tibble(draws_mat) %>%
        mutate(draw=1:n()) %>%
        pivot_longer(cols=-draw, names_to="parameter") %>%
        ggplot() +
            geom_qq(aes(sample=value)) +
            facet_grid(parameter ~ ., scales="free") 
}

df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
head(df)
table(data.frame(party=df$party, z1nz=(df$z1 != 0)))
table(data.frame(party=df$party, z1nz=(df$z2 != 0)))
length(unique(df$score1)) / nrow(df)





####################################
# ARM_Ch.10_sesame_one_pred_b_independent
#
# Super simple model.  Strangely only the sigma uncertainty
# is different, everything else lines up resonably well across the board.

i <- 40

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

res_list <- LoadModelResults(model_config, file_suffix)
num_exch_obs <- ncol(res_list$base_results$mcmc_results$lp_mat)
print(num_exch_obs)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit
lme4_boot <- TidyLME4Bootstrap(res_list$lme4_results$boot_results)

this_comb_df <-
    filter(comb_df, model_index == i, is_diag) %>%
    mutate(bayes_sd=sqrt(bayes_cov / num_exch_obs),
           ij_sd=sqrt(ij_cov / num_exch_obs),
           bootstrap_sd=sqrt(bootstrap_cov / num_exch_obs))

# Results
tidy(rstan_fit)
tidy(lme4_fit)

select(this_comb_df, params, bayes_sd, ij_sd, bootstrap_sd)
lme4_boot

# Note that the heteroskedasticity-robust estimate matches the bootstrap.
diag(sandwich::vcovCL(lme4_fit)) %>% sqrt()
diag(vcov(lme4_fit)) %>% sqrt()


if (FALSE) {
    this_comb_df %>%
        select(row_variable, bayes_sd, ij_sd, bootstrap_sd) %>%
        filter(row_variable == "log_sigma") %>%
        pivot_longer(cols=-row_variable, names_to="method") %>%
        ggplot() +
        geom_bar(aes(x=row_variable, y=value, fill=method),
                 stat="identity", position="dodge")
    
    x_df <-
        as_tibble(model.matrix(rstan_fit)) %>%
        mutate(obs=1:n(), eps=resid(rstan_fit)) %>%
        pivot_longer(cols=-c(obs, eps), names_to="regressor")
    
    # All regressors are binary.
    table(select(x_df, -eps, -obs))
    
    # Some heteroskedasticity
    group_by(x_df, regressor, value) %>%
        summarize(sd_eps=sd(eps))

    as_tibble(draws_mat) %>%
        mutate(draw=1:n()) %>%
        pivot_longer(cols=-draw, names_to="parameter") %>%
        ggplot() +
        geom_qq(aes(sample=value)) +
        facet_grid(parameter ~ ., scales="free") 
}


