# The Bayesian Infinitesimal Jackknife for Variance

This is a public repository containing the code to reproduce
the experiments for our paper,
"The Bayesian Infinitesimal Jackknife for Variance" (ANONYMOUS).

# Steps to reproduce

## Install the packages

There are four R packages that implement repeatedly-used functionality.  These
packages are found in the `libs` directory, and can be installed
using the `install_packages_locally.sh` script.

The packages required by the various scripts are listed in `r_packages.csv`.

## Rerun the analyses

There are three analyses in the paper, each in its own directory:

- RstanArm (`src/rstanarm`)
- MrP (`src/mrp`)
- Singular simulations (`src/singular_simulations`)

Each folder has its own README.md describing the steps to reproduction.  In each
case, the final script to run, which produces output that can be processed
to produce the final paper, is called `postprocess_for_paper.R`.  The analysis
pipeline runs backwards from that point.


## Generate the figures

Finally, you can generate the paper's tables and figures by running

`paper/latex/make recompile_knitr`

The output will be in figures.pdf.

# AI Assistance acknowledgement

The AI assistant Claude Code v2.1.114 was used to help clean and document the
minimal steps to reproducing the paper.  The key tasks that AI helped with were:

- Identifying files and scripts that had been used for exploratory analysis
  but were not required to produce the final output;
- Identifying references to files or scripts outside the present repository
  in order to make this respository entirely self-contained;
- Identifying bugs or typos, particularly due to functions whose defintion had changed over time;
- Consistently documenting the steps for reproduction, and creating makefiles based on these
  instructions.

With the exception of the makefiles, and minor formatting changes (e.g. changing
the name of an R package), AI was primarily used to make code suggestions that were
checked and implemented by hand.