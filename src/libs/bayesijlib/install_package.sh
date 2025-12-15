#!/usr/bin/env Rscript

# Note that to install mcmcse you may need to install the FFTW3 libraries.
#  sudo apt-get install libfftw3-dev libfftw3-doc

library(devtools)
install_local("/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/libs/bayesijlib/bayesijlib", force=TRUE, upgrade="never")
