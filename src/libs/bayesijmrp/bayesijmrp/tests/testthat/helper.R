library(testthat)


AssertNearlyEqual <- function(x, y, tol=1e-9, desc=NULL) {
  diff_norm <- max(abs(x - y))
  if (is.null(desc)) {
    info_str <- sprintf("%e > %e", diff_norm, tol)
  } else {
    info_str <- sprintf("%s: %e > %e", desc, diff_norm, tol)
  }
  expect_true(diff_norm < tol, info=info_str)
}


AssertNearlyZero <- function(x, tol=1e-15, desc=NULL) {
  x_norm <- max(abs(x))
  if (is.null(desc)) {
    info_str <- sprintf("%e > %e", x_norm, tol)
  } else {
    info_str <- sprintf("%s: %e > %e", desc, x_norm, tol)
  }
  expect_true(x_norm < tol, info=info_str)
}
