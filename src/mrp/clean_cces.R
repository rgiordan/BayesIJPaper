#!/usr/bin/env Rscript

# Based on the textbook example from
# https://github.com/JuanLopezMartin/MRPCaseStudy/blob/master/01-mrp.Rmd

library(tidyverse)


cces_all <- read_csv("datasets/cces18_common_vv.csv")
poststrat_raw_df <- read_csv('datasets/poststrat_df.csv')
statelevel_predictors_df <- read_csv('datasets/statelevel_predictors.csv')


# Note that the FIPS codes include the district of Columbia and US territories which
# are not considered in this study, creating some gaps in the numbering system.
state_ab <- datasets::state.abb
state_fips <- c(1,2,4,5,6,8,9,10,12,13,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,
                31,32,33,34,35,36,37,38,39,40,41,42,44,45,46,47,48,49,50,51,53,54,55,56)
recode_fips <- function(column) {
  factor(column, levels=state_fips, labels=state_ab)
}

# Recode CCES
clean_cces <- function(df, remove_nas = TRUE){
  
  ## Abortion -- dichotomous (0 - Oppose / 1 - Support)
  df$abortion <- abs(df$CC18_321d-2)
  
  ## State -- factor
  df$state <- recode_fips(df$inputstate)
  
  ## Gender -- dichotomous (coded as -0.5 Female, +0.5 Male)
  df$male <- abs(df$gender-2)-0.5
  
  ## ethnicity -- factor
  df$eth <- factor(df$race,
                   levels = 1:8,
                   labels = c("White", "Black", "Hispanic", "Asian", "Native American", 
                              "Mixed", "Other", "Middle Eastern"))
  df$eth <- fct_collapse(df$eth, "Other" = c("Asian", "Other", "Middle Eastern", 
                                             "Mixed", "Native American"))
  
  ## Age -- cut into factor
  df$age <- 2018 - df$birthyr
  df$age <- cut(as.integer(df$age), breaks = c(0, 29, 39, 49, 59, 69, 120), 
                labels = c("18-29","30-39","40-49","50-59","60-69","70+"),
                ordered_result = TRUE)
  
  ## Education -- factor
  df$educ <- factor(as.integer(df$educ), 
                    levels = 1:6, 
                    labels = c("No HS", "HS", "Some college", "Associates", 
                               "4-Year College", "Post-grad"), ordered = TRUE)
  df$educ <- fct_collapse(df$educ, "Some college" = c("Some college", "Associates"))  
  
  # Filter out unnecessary columns and remove NAs
  df <- df %>% 
    dplyr::select(abortion, state, eth, male, age, educ) 
  if (remove_nas){
    df <- df %>% drop_na()
  }
  
  return(df)
}


cces_all_df <- 
  clean_cces(cces_all, remove_nas = TRUE) %>%
  left_join(statelevel_predictors_df, by = "state") 

# I think poststrat_df already has state as a string..?
poststrat_df <-
  poststrat_raw_df %>%
  #mutate(state=recode_fips(state)) %>%
  left_join(statelevel_predictors_df, by="state")

save(cces_all_df, poststrat_df, file="cces18_common_vv.Rdata")
