#!/usr/bin/env Rscript

library(devtools)
#devtools::load_all()
library(testthat)
library(bayesijmrp)

test_check("bayesijmrp")
#test_file("testthat/test_bayesijmrp.R")
