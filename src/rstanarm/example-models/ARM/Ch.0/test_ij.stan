data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] y;
  vector[N] x;
}
parameters {
  vector[2] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  real log_sigma;
  for (n in 1:N) {
    lp_[n] = normal_lpdf(y[n] | beta[1] + beta[2] * x[n], sigma);
  }
  log_sigma = log(sigma);
}
model {
  sigma ~ cauchy(0, 1);
  beta ~ normal(0, 100);

  //y ~ normal(beta[1] + beta[2] * x, sigma);
  target += sum(w_ .* lp_);
}
