# The Bayesian Infinitesimal Jackknife for Variance

This is a public repository containing the code to reproduce
the experiments for our paper,
"The Bayesian Infinitesimal Jackknife for Variance" (ANONYMOUS).

# Steps to reproduce

## Install the packages

There are four R packages that implement repeatedly-used functionality.  These
packages are found in the `libs` directory, and can be installed
using the `install_packages_locally.sh` script.

## Rerun the analyses

There are three analyses in the paper, each in its own directory:

- RstanArm (`src/rstanarm`)
- MrP (`src/mrp`)
- Singular simulations (`src/singular_simulations`)

Each folder has its own README.md describing the steps to reproduction.  In each
case, the final script to run, which produces output that can be processed
to produce the final paper, is called `postprocess_for_paper.R`.  The analysis
pipeline runs backwards from that point.