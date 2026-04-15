#!/usr/bin/env Rscript

library(devtools)
git_loc <- "/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench"
install_local(file.path(
    git_loc, "/src/bayes/libs/rstanarmijlib/rstanarmijlib"),
    force=TRUE, upgrade="never")
