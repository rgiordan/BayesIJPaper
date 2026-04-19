# Initialize R for knitr.

library(tidyverse)
library(knitr)
library(xtable)
library(gridExtra)
library(latex2exp)
library(lubridate)
library(ggpubr)


library(ggforce) # For geom_ellipse

# This must be run from within the git repo, obviously.
git_repo_loc <- system("git rev-parse --show-toplevel", intern=TRUE)
paper_directory <- file.path(git_repo_loc, "paper/latex/")
data_path <- file.path(git_repo_loc, "experiment_data")

SourceFile <- function(filename, ...) {
  source(file.path(paper_directory, filename), ...)
}

SourceFile("R_scripts/plot_lib.R")

opts_chunk$set(fig.pos='!h', fig.align='center', dev='png', dpi=300)
opts_chunk$set(echo=knitr_debug, message=knitr_debug, warning=knitr_debug)

# Set the default ggplot theme
theme_set(theme_bw())

# Load into an environment rather than the global space
LoadIntoEnvironment <- function(filename) {
  my_env <- environment()
  load(filename, envir=my_env)
  return(my_env)
}

DefineMacro <- function(macro_name, value, digits=3) {
  value_string <- format(round(value, digits), big.mark="{,}", scientific=FALSE)
  cat("\\newcommand{\\", macro_name, "}{", value_string, "}\n", sep="")
}

# aspect ratio refers to height / width.
base_aspect_ratio <- 6 / (5 * 2)
base_image_width <- 5.5

# aspect ratio refers to height / width.
SetImageSize <- function(aspect_ratio, image_width=base_image_width) {
  ow <- "0.98\\linewidth"
  oh <- sprintf("%0.3f\\linewidth", aspect_ratio * 0.98)
  fw <- image_width
  fh <- image_width * aspect_ratio
  opts_chunk$set(out.width=ow,
                 out.height=oh,
                 fig.width=fw,
                 fig.height=fh)
}


SetFullImageSize <- function() SetImageSize(
    aspect_ratio=base_aspect_ratio, image_width=base_image_width)

SetShortImageSize <- function() SetImageSize(
    aspect_ratio=0.5 * base_aspect_ratio, image_width=base_image_width)

# Default to a full image.
SetFullImageSize()
