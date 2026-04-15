# The Bayesian Infinitesimal Jackknife for Variance

This is a public repository containing the code to reproduce
the experiments for our paper,
"The Bayesian Infinitesimal Jackknife for Variance" (ANONYMOUS).

# Steps to reproduce

## Install the packages

There are three R packages that implement repeatedly-used functionality.  These
packages are found in the `lib` directory, and can be installed
using the `install_packages_locally.sh` script.

## Rerun the analyses

There are three analyses in the paper, each in its own directory:

- RstanArm (`src/rstanarm`)
- MrP (`src/mrp`)
- Singular simulations (`src/singular_simulations`)

Each folder has its own README.md describing the steps to reproduction.