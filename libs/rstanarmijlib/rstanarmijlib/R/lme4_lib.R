library(broom)
library(broom.mixed)

RunLME4 <- function(rstanarm_ij_config, df) {
  GetLME4Function <- function(rstan_fun) {
      if (rstan_fun == "stan_glmer") {
          return(glmer)
      } else if (rstan_fun == "stan_glm") {
          return(glm)
      } else {
          stop("Unknown function.")
      }
  }

  lme4_fit <- with(
      rstanarm_ij_config,
      GetLME4Function(rstan_fun)(
          formula(formula_str),
          data=df,
          family=eval(parse(text=family))))
    return(lme4_fit)
}


TidyLME4Results <- function(lme4_fit) {
    AppendLME4DfRow <- function(par, mean, sd) {
        lme4_df <<- bind_rows(lme4_df, tibble(par=par, mean=mean, sd=sd))
    }
    if (class(lme4_fit)[1] != "lmerMod") {
        lme4_df <-
            tidy(lme4_fit) %>%
            rename(mean=estimate, sd=std.error, par=term)
        AppendLME4DfRow("sigma", sigma(lme4_fit), NA)
        AppendLME4DfRow("log_sigma", log(sigma(lme4_fit)), NA)
        return(lme4_df)
    }

    lme4_df <-
        tidy(lme4_fit) %>%
        filter(group == "fixed") %>%
        rename(mean=estimate, sd=std.error, par=term)

    vc <- VarCorr(lme4_fit)

    AppendLME4DfRow("sigma", attr(vc, "sc"), NA)
    AppendLME4DfRow("log_sigma", log(attr(vc, "sc")), NA)

    for (group in names(vc)) {
        covmat <- vc[[group]]
        terms <- rownames(covmat)
        stopifnot(all(terms == colnames(covmat)))
        for (trow in terms) {
            for (tcol in terms) {
                AppendLME4DfRow(
                    sprintf("Sigma[%s:%s,%s]", group, trow, tcol),
                    covmat[trow, tcol], NA)
                if (trow == tcol) {
                    AppendLME4DfRow(
                        sprintf("log_Sigma[%s:%s,%s]", group, trow, tcol),
                        log(covmat[trow, tcol]), NA)
                }
            }
        }
    }
    return(lme4_df)
}

# boot_results should be the list retunred in the bootstrap dopar loop of
# run_lme4.R
TidyLME4Bootstrap <- function(boot_results) {
  lme4_boot <- do.call(
    rbind,
    lapply(boot_results,
           function(boot_result) {
               TidyLME4Results(boot_result$lme4_fit) %>%
                   select(par, mean) %>%
                   mutate(b=boot_result$b)
           }))

lme4_boot_agg <-
    lme4_boot %>%
    group_by(par) %>%
    rename(value=mean) %>%
    summarize(mean=mean(value),
              sd=sd(value))

  return(lme4_boot_agg)
}
