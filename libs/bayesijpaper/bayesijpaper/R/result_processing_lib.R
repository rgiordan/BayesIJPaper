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



#' Convert a covariance matrix to a dataframe.
#'
#' @param cov_mat The covariance matrix.
#' @param remove_repeats Optional.  If TRUE, and if cov_mat
#' is symmetric, include only the upper triangular part of cov_mat.
#' Default value = FALSE.
#' @return A data frame with columns row_variable, column_variable, and
#' value, where value is the specificed covariance.
#' @export
CovarianceMatrixToDataframe <- function(cov_mat, remove_repeats=FALSE) {
  if (is.null(colnames(cov_mat))) {
    colnames(cov_mat) <- paste0("col", 1:ncol(cov_mat))
  }
  column_names <- colnames(cov_mat)

  if (is.null(rownames(cov_mat))) {
    rownames(cov_mat) <- paste0("row", 1:nrow(cov_mat))
  }
  row_names <- rownames(cov_mat)

  cov_df <- data.frame(cov_mat, stringsAsFactors=FALSE)
  names(cov_df) <- column_names
  row_df <- data.frame(row_variable=row_names, row=1:length(row_names),
                       stringsAsFactors=FALSE)
  col_df <- data.frame(column_variable=column_names, col=1:length(column_names),
                       stringsAsFactors=FALSE)
  cov_df <- cov_df %>%
           mutate(row_variable=row_names) %>%
           melt(id.var="row_variable") %>%
           rename(column_variable=variable)
  if (remove_repeats) {
    if (length(row_names) != length(column_names)) {
      stop(paste0("To use remove_repeats, the row names and column names ",
                  "must be the same length."))
    }
    if (any(row_names != column_names)) {
      stop(paste0("To use remove_repeats, the row names and column names must ",
                  "be identical"))
    }
    if (max(abs(cov_mat - t(cov_mat)), na.rm=TRUE) > 1e-8) {
      stop("To use remove_repeats, cov_mat must be symmetric.")
    }
    cov_df <-
      cov_df %>%
      inner_join(row_df, by="row_variable") %>%
      inner_join(col_df, by="column_variable") %>%
      filter(row <= col) %>%
      select(-row, -col)
  }
  return(cov_df)
}
