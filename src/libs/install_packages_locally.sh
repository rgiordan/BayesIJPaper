#!/usr/bin/env Rscript

library(devtools)
git_loc <- system2("git", args=c("rev-parse", "--show-toplevel"), stdout=TRUE)
lib_loc <- file.path(git_loc, "src/libs")
install_local(file.path(
    lib_loc, "rstanijlib/rstanijlib"),
    force=TRUE, upgrade="never")
install_local(file.path(
    lib_loc, "rstanarmijlib/rstanarmijlib"),
    force=TRUE, upgrade="never")
install_local(file.path(
    lib_loc, "bayesijlib/bayesijlib"),
    force=TRUE, upgrade="never")
