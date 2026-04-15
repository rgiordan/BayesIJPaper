#!/usr/bin/env Rscript
# ./compile_postprocessing.R --base_dir=$(pwd) --file_pattern=bootstrap_data/mrp_bootstrap_seed53487645_samples5000.Rdata --description=test
# ./compile_postprocessing.R --base_dir=$(pwd) --file_pattern=bootstrap_data/mrp_*_samples5000_mrp_postprocessed.Rdata --description=mrp
#
# This takes the files in the file pattern, loads them, and concatenates
# the `result_df` dataframe from each into a single dataframe, and
# saves the result.

library(tidyverse)
library(brms)
library(optparse)

option_list <- list(
  make_option(c("--base_dir"),
              default="./",
              help="The base directory"),
  make_option(c("--file_pattern"),
              default="",
              help="If set, compile subsample results instead of the bootstraps."),
  make_option(c("--description"),
              default="postprocess",
              help="If set, compile subsample results instead of the bootstraps."))
  
opt <- parse_args(OptionParser(option_list=option_list))
print("===================")
print("Options:")
print(opt)
print("===================")

  
load_into_env <- function(filename) {
  load_env <- environment()
  load(filename, envir=load_env)
  return(load_env)
}



date_stamp <- format(Sys.time(), "%Y%m%d_%H%M")
save_filename <- sprintf("mrp_combined_%s_%s.Rdata", opt$description, date_stamp)

output_file <- file.path(opt$base_dir, "bootstrap_data", save_filename)
print(sprintf("Writing to %s", output_file))

postprocessed_files <- Sys.glob(opt$file_pattern)
if (length(postprocessed_files) == 0) {
  stop(sprintf("No files matched the pattern %s", opt$file_pattern))
}

print("Processing these files:")
print(postprocessed_files)

print("==============")
print("Running:")
result_df <- data.frame()
for (filename in postprocessed_files) {
  print(filename)
  load_env <- load_into_env(filename)
  result_df <- bind_rows(
    result_df,
    load_env$result_df %>% mutate(filename=filename))
}

print("Done!")

save(result_df, file=output_file)
