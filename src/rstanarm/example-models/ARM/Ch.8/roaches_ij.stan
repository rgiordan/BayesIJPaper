data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] exposure2;
  vector[N] roach1;
  vector[N] senior;
  vector[N] treatment;
  int y[N];
}
transformed data {
  vector[N] log_expo;

  log_expo = log(exposure2);
}
parameters {
  vector[4] beta;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] =
    poisson_log_lpmf(y[n] |
      log_expo[n] + beta[1] + beta[2] * roach1[n] + beta[3] * treatment[n]
      + beta[4] * senior[n]);
  }
}
model {
  // y ~ poisson_log(log_expo + beta[1] + beta[2] * roach1 + beta[3] * treatment
  //                 + beta[4] * senior);
  target += sum(w_ .* lp_);
}
