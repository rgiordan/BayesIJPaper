# Use this script to debug and edit the knit graphs without re-compiling in latex.

git_repo_loc <- system("git rev-parse --show-toplevel", intern=TRUE)
base_dir <- file.path(git_repo_loc, "paper/latex")

knitr_debug <- FALSE # Set to true to see error output
simple_cache <- FALSE # Set to true to cache knitr output for this analysis.
single_column <- FALSE
setwd(base_dir)
source(file.path(base_dir, "R_scripts/initialize.R"))

SourceFile("R_scripts/ARM/load_data.R")
SourceFile("R_scripts/singular_example/load_data.R")
SourceFile("R_scripts/mrp/load_data.R")

SourceFile("R_scripts/ARM/define_macros.R")
SourceFile("R_scripts/singular_example/define_macros.R")
SourceFile("R_scripts/mrp/define_macros.R")

SourceFile("R_scripts/singular_example/result_graph.R")
