library(testthat)
library(rstansensitivity)
library(rstanarm)
library(sandwich)

library(bayesijlib)
library(rstanarmijlib)

library(broom)

options(mc.cores=4)


base_dir <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes"
stan_examples_dir <- file.path(base_dir, "example-models")
output_dir <- file.path(base_dir, "rstanarm/cluster/output")

model_loc <- file.path(stan_examples_dir, "ARM/Ch.5")
nes_files <- list.files(path=model_loc, pattern="nes...._vote.data.R")
nes_files

nes_df <- tibble()

nes_file <- nes_files[1]

for (nes_file in nes_files) {
    nes_file_date <-
        nes_file %>%
        str_replace("^nes", "") %>%
        str_replace("_vote\\.data\\.R", "")
    
    source(file.path(model_loc, nes_file), echo=TRUE)
    
    nes_df <-
        nes_df %>%
        bind_rows(tibble(vote=vote, income=income, date=nes_file_date))
}

nes_df

# rstan_fit <- rstanarm::stan_glmer(
#     vote ~ 1 + income + (1 | date),
#     data=nes_df,
#     family=binomial(link="logit"))


lme4_fit <- lme4::glmer(
    vote ~ 1 + income + (1 + income | date),
    data=nes_df,
    family=binomial(link="logit"))

re <-
    ranef(lme4_fit)$date %>%
    rename(Intercept=`(Intercept)`)
re$date <- as.numeric(rownames(re))

ggplot(re) + 
    geom_line(aes(x=date, y=income, color="income")) +
    geom_line(aes(x=date, y=Intercept, color="intercept"))

ggplot(re) + 
    geom_line(aes(x=date, y=income, color="income"))


#################

library(foreign)
dta_df <- read.dta("~/Downloads/ARM_Data/nes/nes5200_processed_voters_realideo.dta")
head(dta_df)
if (FALSE) {
    View(dta_df)    
}


# Encode income quantile (cf section 4.7)
levels(dta_df$income)
dta_df$numeric_income <- as.numeric(dta_df$income) - 1
table(dta_df$numeric_income)

# Encode republican voting as 1, democratic voting as 0 (cf section 5.1)
levels(dta_df$presvote)
dta_df <- dta_df %>%
    filter(!is.na(presvote)) %>%
    filter(as.numeric(presvote) != 1) %>%
    filter(as.numeric(presvote) != 4)
table(as.numeric(dta_df$presvote))

dta_df$presvote_numeric <-
    case_when(as.numeric(dta_df$presvote) == 2 ~ 0,
              as.numeric(dta_df$presvote) == 3 ~ 1,
              TRUE ~ -1)
summary(dta_df$presvote_numeric)
summary(dta_df$numeric_income)


# At least close to the section 5.1 example
glm(formula = presvote_numeric ~ numeric_income,
    family=binomial(link="logit"),
    data=filter(dta_df, year == 1992))

# Exercise 5.11
glm_fit_1960 <- glm(formula = presvote_numeric ~ female + black + numeric_income,
    family=binomial(link="logit"),
    data=filter(dta_df, year == 1960))

glm_fit_1964 <- glm(formula = presvote_numeric ~ female + black + numeric_income,
    family=binomial(link="logit"), subset=(year==1964),
    data=dta_df,
    control=list(trace=TRUE))
glm_fit_1964$converged

rstan_fit_1960 <-
    stan_glm(formula = presvote_numeric ~ female + black + numeric_income,
             family=binomial(link="logit"), subset=(year==1960),
             data=dta_df)

rstan_fit_time <- Sys.time()
rstan_fit_1964 <-
    stan_glm(formula = presvote_numeric ~ female + black + numeric_income,
        family=binomial(link="logit"), subset=(year==1964),
        data=dta_df)
rstan_fit_time <- Sys.time() - rstan_fit_time
print(rstan_fit_time)

tidy(rstan_fit_1960)
tidy(glm_fit_1960)
tidy(rstan_fit_1964)
tidy(glm_fit_1964)

mdf <- rstan_fit_1964$model
mdf$vpred <- fitted.values(rstan_fit_1964)

ggplot(mdf) +
    geom_point(aes(x=vpred, y=black))
summary(filter(mdf, black == 1)$vpred)

summary(filter(mdf, black == 1)$presvote_numeric)
summary(filter(mdf, black == 0)$presvote_numeric)

# Perfect separation in 1964
table(filter(dta_df, black == 1, year == 1960)$presvote_numeric)
table(filter(dta_df, black == 0, year == 1960)$presvote_numeric)
table(filter(dta_df, black == 1, year == 1964)$presvote_numeric)
table(filter(dta_df, black == 0, year == 1964)$presvote_numeric)


ll_1960 <- log_lik(rstan_fit_1960)
ll_1964 <- log_lik(rstan_fit_1964)

df_1960 <- rstan_fit_1960$model
df_1964 <- rstan_fit_1964$model

pars_1960 <- as.matrix(rstan_fit_1960)
pars_1964 <- as.matrix(rstan_fit_1964)

# Pretty similar covariances
num_obs <- nrow(df_1960)
ij_cov <- ComputeIJCovariance(ll_1960, pars_1960)
bayes_cov <- num_obs * cov(pars_1960, pars_1960)
ij_cov
bayes_cov

# Pretty different covariances!  This might be an interesting example.
num_obs <- nrow(df_1964)
ij_cov <- ComputeIJCovariance(ll_1964, pars_1964)
bayes_cov <- num_obs * cov(pars_1964, pars_1964)
ij_cov
bayes_cov
se_results <- bayesijlib::ComputeIJStandardErrors(
    ll_1964, pars_1964, 100, 100)



if (FALSE) {
    # bootstrap
    library(doParallel)
    registerDoParallel(cores=6)
    options(mc.cores=1) # Don't do parallel within parallel

    ###############
    ###############################
    # Load the data
    df <- df_1964
    ecol <- 1:nrow(df)
    ecol_vals <- unique(ecol)
    ecol_n <- length(ecol_vals)
    
    # stan_glm(formula = presvote_numeric ~ female + black + numeric_income,
    #          family=binomial(link="logit"), subset=(year==1960),
    #          data=dta_df)
    
    rstanarm_ij_config <- list()
    rstanarm_ij_config$num_boots <- 50
    rstanarm_ij_config$formula_str <- "presvote_numeric ~ female + black + numeric_income"
    rstanarm_ij_config$rstan_fun <- "stan_glm"
    rstanarm_ij_config$family <- "family=binomial(link=\"logit\")"
    rstanarm_ij_config$num_samples <- 2000
    num_mcmc_chains <- 4
    
    foo <- RunRstanArm(rstanarm_ij_config, df, chains=num_mcmc_chains)
    
    #model_list[[1]]
    
    
    ###############################
    # Compute the summary statistics
    
    boot_time <- do.call(sum, lapply(
        boot_results, function(x) { x$sampling_time } ))
    cat("Bootstrap time: ", boot_time, "\n")
    
    boot_means <- as.matrix(do.call(
        bind_rows, lapply(boot_results, function(x) { x$boot_means } )))
    boot_cov <- cov(boot_means, boot_means)
    
    boot_w <- as.matrix(do.call(
        rbind, lapply(boot_results, function(x) { x$w } )))
    
    boot_cov_se <- GetCovarianceMatrixSE(
        boot_means, boot_means, correlated_samples=FALSE)

    ecol_n * boot_cov    
    ij_cov
    bayes_cov
    
    # It's not perfect but it is promising.
    diff_se <- sqrt(se_results$ij_cov_se ^ 2 + (ecol_n * boot_cov_se)^2)
    (ecol_n * boot_cov - ij_cov) / diff_se
 
    if (FALSE) {
        ggplot() + geom_histogram(aes(x=pars_1964[, "black"]), bins=30) # not normal
        ggplot() + geom_histogram(aes(x=pars_1964[, "female"]), bins=30) # pretty normal
    }
}




dim(ll_1960)
dim(pars_1960)

infl_1960 <- cov(ll_1960, pars_1960)
colnames(infl_1960) <- paste0("par_", colnames(pars_1960))
rownames(infl_1960) <- 1:nrow(df_1960)

infl_1964 <- cov(ll_1964, pars_1964)
colnames(infl_1964) <- paste0("par_", colnames(pars_1964))
rownames(infl_1964) <- 1:nrow(df_1964)

dim(infl_1960)
dim(infl_1964)

infl_1960_df <-
    as_tibble(infl_1960) %>%
    mutate(row=1:n()) %>%
    bind_cols(df_1960)

infl_1964_df <-
    as_tibble(infl_1964) %>%
    mutate(row=1:n()) %>%
    bind_cols(df_1964)

# let's flail a little

ggplot(infl_1960_df) +
    geom_histogram(aes(x=par_black, fill=factor(black)), alpha=0.9)

ggplot(infl_1964_df) +
    geom_histogram(aes(x=par_black, fill=factor(black)), alpha=0.9)


# Cumulative plots
GetInflVec <- function(phi) {
    return(cumsum(sort(phi)))
}
grid.arrange(
    ggplot(infl_1960_df) +
        geom_line(aes(x=1:length(par_black), y=cumsum(sort(par_black)))) +
        ggtitle(1960)
    ,
    ggplot(infl_1964_df) +
        geom_line(aes(x=1:length(par_black), y=cumsum(sort(par_black)))) +
        ggtitle(1964)
    , ncol=2
)

tidy(rstan_fit_1960)
tidy(rstan_fit_1964)



if (FALSE) {
    # These things are useless.
    library(rpart)
    library(rpart.plot)
    
    rtree <- rpart(par_black ~ presvote_numeric + female + black + numeric_income,
                   data=infl_1960_df, method="anova")
    rpart.plot(rtree)
    
    cart_df <- infl_1964_df %>%
        arrange(desc(abs(par_black)))
    
    cart_df$top <- 0
    cart_df[1:100, "top"] <- 1
    table(cart_df$top)
    
    rtree <- rpart(top ~ presvote_numeric + female + black + numeric_income,
                   data=cart_df,
                   method="class")
    rpart.plot(rtree)
}

