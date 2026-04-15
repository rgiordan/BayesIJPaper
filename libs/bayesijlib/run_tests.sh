#!/usr/bin/env Rscript

# It is so annoying to me that this must be run from within this directory.

library(testthat)
getwd()
test_dir("./bayesijlib/tests/testthat/")
