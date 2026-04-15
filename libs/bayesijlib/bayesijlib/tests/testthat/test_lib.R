library(bayesijlib)
library(tidyverse)

context("bayesijlib")

test_that("bootstrap_by_column_works", {
  ecol <- c(rep(c("a", "b", "c"), each=3), "d")
  df <- data.frame(ecol=ecol, x=runif(length(ecol)))
  df_list <- lapply(unique(ecol), function(v) { df[ ecol == v, , drop=FALSE]})

  expect_equal(
      BootstrapByExchangableColumn(df, ecol, c(0, 2, 0, 0)),
      bind_rows(df_list[[2]], df_list[[2]]))

  expect_equal(
      BootstrapByExchangableColumn(df, ecol, c(1, 1, 1, 1)),
      df)

  expect_equal(
      BootstrapByExchangableColumn(df, ecol, c(3, 0, 1, 2)),
      bind_rows(df_list[[1]], df_list[[1]], df_list[[1]],
                df_list[[3]],
                df_list[[4]], df_list[[4]]))

})
