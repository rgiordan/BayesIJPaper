# Load and process results produced by model_script.R.

library(tidyverse)
library(rstansensitivity)
library(gridExtra)

library(bayesijlib)
library(rstanarmijlib)

rstan_options(auto_write=TRUE)

# If TRUE do not run all the bootstraps and do not save.
base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
output_dir <- file.path(base_dir, "rstanarm/cluster/output")
stan_examples_dir <- file.path(base_dir, "example-models")

model_list_filename <- "rstanarm_ij_model_list.json"
model_list_file <- file(file.path(base_dir, "rstanarm/configs/", model_list_filename), "rb")
model_list <- jsonlite::fromJSON(model_list_file, simplifyDataFrame=FALSE)
close(model_list_file)

file_date <- "0924"
file_suffix <- "0924_cluster"
output_filename <- sprintf("point_estimate_results_%s.Rdata", file_date)
load(file=file.path(output_dir, output_filename))


############

pe_wide_df <-
    point_estimate_df %>%
    pivot_longer(cols=c(-par, -metric, -desc, -model_index)) %>%
    pivot_wider(id_cols=c(par, metric, desc, model_index),
                names_from=c(name, metric),
                values_from=value) %>%
    select(-ij_mean, -mcmc_boot_mean)

head(pe_wide_df)

###############################################
# Get models where lme4 and bayes mismatch

deviant_indices <-
    pe_wide_df %>%
    filter(abs(mcmc_mean - lme4_mean) > 1.5 * mcmc_sd) %>%
    `[[`("model_index") %>%
    unique()
# 20 55 65

pe_wide_df %>%
    filter(model_index %in% deviant_indices) %>%
    `[[`("desc") %>% unique

sorted_differences <-
    pe_wide_df %>%
    ungroup() %>%
    group_by(model_index, desc) %>%
    summarize(max_rel_diff=max(abs(mcmc_mean - lme4_mean) / mcmc_sd)) %>%
    arrange(desc(max_rel_diff))

if (FALSE) {
    View(sorted_differences)
}


##############################
# ARM_Ch.13_radon_inter_vary_county
# Mild mismatch

i <- 52

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

this_pe_wide_df <- filter(pe_wide_df, model_index == i)
select(this_pe_wide_df, par, lme4_mean, mcmc_mean, mcmc_sd, ij_sd, mcmc_boot_sd)

res_list <- LoadModelResults(model_config, file_suffix)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit

# summary(rstan_fit, pars=keep_pars)
# lme4_fit
# Successful convergence
attr(lme4_fit, "optinfo")$conv$opt


##############################
# ARM_Ch.23_electric_1a_pair

# A non-nested model which failed to converge.  Still, lme4 and Bayes are close for
# a lot of the parameters.

i <- 63

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

this_pe_wide_df <- filter(pe_wide_df, model_index == i)
select(this_pe_wide_df, par, lme4_mean, mcmc_mean, mcmc_sd, ij_sd, mcmc_boot_sd)

res_list <- LoadModelResults(model_config, file_suffix)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit

# summary(rstan_fit, pars=keep_pars)
# lme4_fit
attr(lme4_fit, "optinfo")$conv$lme4$messages


####################################
# ARM_Ch.23_electric_1c_pair

# Big differences.
# Singular fit in LME4.  Again, IJ and boot differ from MCMC
# probably because it's a non-nested model and we're treating only
# one of the random effects as exchangeable.

i <- 65

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
length(unique(df$pair))
length(unique(df$grade))

res_list <- LoadModelResults(model_config, file_suffix)

draws_mat <- res_list$base_results$mcmc_results$draws_mat
keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit

summary(rstan_fit, pars=keep_pars)
lme4_fit
attr(lme4_fit, "optinfo")$conv$lme4$messages

# The intercept is particularly different between the MCMC and IJ sd.
this_pe_wide_df <- filter(pe_wide_df, model_index == i)
select(this_pe_wide_df, par, lme4_mean, mcmc_mean, mcmc_sd, ij_sd, mcmc_boot_sd)



####################################
# ARM_Ch.13_pilots_independent
#
# Big differences.
#
# The LME4 fit is singular with a zero-esitmated group_id variance.
# The Bayesian and frequentist variances differ, probably in no small
# part because we are treating each observation as independent because
# there are only 8 scenarios and 5 groups.

# See section 13.5, page 289 of the book.  The "scenario" is actually
# an airport, and the "group" is actually a treatment condition.
# The data comes from Gawron et al (2003).

i <- 55

model_config <- model_list[[i]]
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)
print(model_config$exchangeable_col)

df <- LoadRstanarmDataframe(model_config, stan_examples_dir)
head(df)
length(unique(df$scenario_id))
length(unique(df$group_id))


res_list <- LoadModelResults(model_config, file_suffix)


keep_pars <- model_config$keep_pars
keep_pars <- keep_pars[!grepl("^b\\[", keep_pars)]
rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
lme4_fit <- res_list$lme4_results$lme4_fit

summary(rstan_fit, pars=keep_pars)
lme4_fit
attr(lme4_fit, "optinfo")$conv$lme4$messages

# The intercept is particularly different between the MCMC and IJ sd.
this_pe_wide_df <- filter(pe_wide_df, model_index == i)
select(this_pe_wide_df, par, lme4_mean, mcmc_mean, mcmc_sd, ij_sd, mcmc_boot_sd)
draws_mat <- res_list$base_results$mcmc_results$draws_mat
intercept_draws <- draws_mat[, "(Intercept)"]
ggplot() + geom_qq(aes(sample=intercept_draws))


####################################
# ARM_Ch.5_separation_independent
# Big differences.

# I'm pretty sure this is simulated data.  It exhibits complete
# separation, which is why lme4 fails.  The IJ is a better match to
# the bootstrap than the Bayesian covariance.

# See section 5.8 of the textbook, page 104.

i <- 20
this_pe_wide_df <- filter(pe_wide_df, model_index == i)

select(this_pe_wide_df, par, mcmc_mean, mcmc_sd, ij_sd, mcmc_boot_sd)

model_config <- model_list[[i]] %>% SetConfigDefaults()
print(model_config$desc)
print(model_config$formula_str)
print(model_config$family)

df <- LoadRstanarmDataframe(model_config, stan_examples_dir)



res_list <- LoadModelResults(model_config, file_suffix)

rstan_fit <- res_list$base_results$mcmc_results$rstan_fit
summary(rstan_fit)
summary(res_list$lme4_results$lme4_fit)
res_list$lme4_results$lme4_fit$converged


# There is an error optimizing
lme4_newfit <-
    with(model_config,
         glm(
            formula(formula_str),
            data=df,
            family=eval(parse(text=family))))

# The MAP is well-behaved, though.
rstan_map_fit <-
    with(model_config,
         stan_glm(
             formula(formula_str),
             data = df,
             family = eval(parse(text=family)),
             algorithm="optimizing",
             iter = num_samples))

summary(rstan_map_fit)
summary(rstan_fit)

# Ah there is complete separation
# plot(df$x, df$y)
min(df$x[df$y == 0])
max(df$x[df$y == 0])
min(df$x[df$y == 1])
max(df$x[df$y == 1])

# It makes sense that the Bayesian fit does not put all its
# posterior mass in the complete separation region, unlike MMLE.

xl <- max(df$x[df$y == 0])
xu <- min(df$x[df$y == 1])

draws_mat <- res_list$base_results$mcmc_results$draws_mat
bound_l_draws <- draws_mat[, "(Intercept)"] + draws_mat[, "x"] * xl
bound_u_draws <- draws_mat[, "(Intercept)"] + draws_mat[, "x"] * xu
ggplot() +
    geom_histogram(aes(x=bound_l_draws), fill="red", alpha=0.2) +
    geom_histogram(aes(x=bound_u_draws), fill="blue", alpha=0.2) +
    geom_vline(aes(xintercept=0))

ggplot() +
    geom_point(aes(x=bound_l_draws, y=bound_u_draws))
