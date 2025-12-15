library(jsonlite)


LoadIJResults <- function(chapter, model_name, suffix="_boot_result") {
    stan_examples_dir <- file.path(base_dir, "example-models/ARM")
    model_loc <- file.path(stan_examples_dir, chapter)
    load_filename <- sprintf("%s_%s.Rdata", model_name, suffix)
    ij_results <- new.env()
    load(file.path(model_loc, load_filename), envir=ij_results)
    ij_results <- as.list(ij_results)
    return(ij_results)
}
