data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] y;
  vector[N] y_lag;
}
parameters {
  vector[2] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] =
    normal_lpdf(y[n] | beta[1] + beta[2] * y_lag[n], sigma);
  }
}
model {
  // y ~ normal(beta[1] + beta[2] * y_lag,sigma);
  target += sum(w_ .* lp_);
}
