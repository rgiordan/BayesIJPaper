#!/usr/bin/env Rscript

library(tidyverse)
library(lme4)

load("datasets/cces18_common_vv.Rdata")
seed <- 1010
set.seed(seed)

# we will call the full survey with 60,000 respondents cces_all_df,
# while the 5,000 person sample will be called cces_df.
sample_size <- 5000

survey_df <- cces_all_df %>% sample_n(sample_size)

regressor_cols <- c("state", "eth", "educ", "male", "age", "repvote", "region")
pop_agg_df <- cces_all_df %>%
  group_by(pick(all_of(regressor_cols))) %>%
  summarize(ybar=mean(abortion), n=n(), .groups="drop") %>%
  mutate(w=n / sum(n))
  
save(cces_all_df, pop_agg_df, survey_df, seed, file="datasets/cces18_subset.Rdata")
