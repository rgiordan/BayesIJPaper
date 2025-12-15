library(reticulate)
reticulate::use_python("/usr/bin/python3")
py_main <- reticulate::import_main()

#'@export
PyPrint <- function(ex) {
    reticulate::py_run_string(sprintf("msg = %s", ex))
    print(py_main$msg)
}


PythonSetup <- function() {
  reticulate::py_run_string("
import numpy as np
import scipy as sp
import sys
from copy import deepcopy
sys.path.append('/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/libs//deconvolution')
import deconvolution_v3_lib as deconvolution_lib
")
}


#'@export
Deconvolve <- function(x, x_se, mu0_grid, sd0_grid,
                       pi_prior=1.0, tol=1e-8, max_iter=2000) {

  py_main <- reticulate::import_main()
  PyNum <- function(num) {
    return(as.array(as.numeric(num)))
  }
  py_main$x <- PyNum(x)
  py_main$x_cov <- PyNum(x_se^2)
  py_main$mu0_grid <- PyNum(mu0_grid)
  py_main$cov0_grid <- PyNum(sd0_grid^2)
  py_main$pi_prior <- pi_prior
  py_main$tol <- tol
  py_main$max_iter <- max_iter

  reticulate::py_run_string("
x = np.array(x)
x_cov = np.array(x_cov)
grid_len = len(mu0_grid)

data = {
    'x': x,
    'x_info': 1 / x_cov,
    'x_cov': x_cov,
    'grid_len': grid_len,
    'mu0_grid': mu0_grid,
    'info0_grid': 1.0 / np.array(cov0_grid),
    'cov0_grid': cov0_grid,
    'pi_prior': np.full(grid_len, pi_prior) }
  ")


  em_time <- Sys.time()
  reticulate::py_run_string("
pi_opt, e_z_opt = deconvolution_lib.run_em(data, print_every=10, tol=tol, max_iter=max_iter)
")
  em_time <- Sys.time() - em_time
  cat("EM time: ", em_time, "\n")

  reticulate::py_run_string("
e_mu_z, e_mu2_z = deconvolution_lib.get_conditional_mu_moments(**data)
e_mu = np.sum(e_z_opt * e_mu_z, axis=1)
e_mu2 = np.sum(e_z_opt * e_mu2_z, axis=1)
")

  return(list(
    pi_opt=py_main$pi_opt,
    e_z_opt=py_main$e_z_opt,
    e_mu=py_main$e_mu,
    e_mu2=py_main$e_mu2
  ))
}
