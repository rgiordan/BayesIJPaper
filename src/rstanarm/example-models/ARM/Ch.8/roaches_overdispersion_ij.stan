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
  vector[N] lambda;
  real<lower=0> tau;
}
transformed parameters {
  real<lower=0> sigma;
  vector[N] lp_;

  sigma = 1.0 / sqrt(tau);

  // Log posterior for the IJ
  for (n in 1:N) {
    lp_[n] =
      normal_lpdf(lambda[n] | 0, sigma) +
      poisson_log_lpmf(y[n] |
        lambda[n] + log_expo[n] + beta[1] + beta[2] * roach1[n]
        + beta[3] * senior[n] + beta[4] * treatment[n]);
  }

}
model {
  tau ~ gamma(0.001, 0.001);
  // for (i in 1:N) {
  //   lambda[i] ~ normal(0, sigma);
  //   y[i] ~ poisson_log(lambda[i] + log_expo[i] + beta[1] + beta[2]*roach1[i]
  //                      + beta[3]*senior[i] + beta[4]*treatment[i]);
  // }
  target += sum(w_ .* lp_);
}
