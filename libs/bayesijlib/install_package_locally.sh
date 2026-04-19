#!/usr/bin/env Rscript

library(devtools)
git_loc <- system2("git", args=c("rev-parse", "--show-toplevel"), stdout=TRUE)
lib_loc <- file.path(git_loc, "libs")
install_local(file.path(
    lib_loc, "bayesijlib/bayesijlib"),
    force=TRUE, upgrade="never")
