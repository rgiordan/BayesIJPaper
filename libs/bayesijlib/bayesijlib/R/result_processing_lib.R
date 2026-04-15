library(jsonlite)


TidyCovarianceFrame <- function(cov_mat, cov_mat_se, method) {
    param_names <- colnames(cov_mat)
    tidy_result <- bind_rows(
        CovarianceMatrixToDataframe(cov_mat, remove_repeats=TRUE) %>%
            mutate(method=!!method, metric="cov"),
        CovarianceMatrixToDataframe(cov_mat_se, remove_repeats=TRUE) %>%
            mutate(method=!!method, metric="se")
    ) %>%
        pivot_wider(names_from=c("method", "metric")) %>%
        mutate(row_variable_name=gsub("\\[.*\\]", "", row_variable),
               column_variable_name=gsub("\\[.*\\]", "", column_variable)) %>%
        mutate(params=paste(row_variable_name, column_variable_name))
    return(tidy_result)
}




FilterVariableName <- function(tidy_results, variable_name) {
  filter(tidy_results,
         column_variable_name != !!variable_name,
         row_variable_name != !!variable_name)
}


