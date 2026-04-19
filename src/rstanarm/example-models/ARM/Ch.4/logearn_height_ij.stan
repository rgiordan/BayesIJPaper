data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] earn;
  vector[N] height;
}
transformed data {           // log transformation
  vector[N] log_earn;
  log_earn = log(earn);
}
parameters {
  vector[2] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] = normal_lpdf(log_earn[n] | beta[1] + beta[2] * height[n], sigma);
  }
}
model {
  // log_earn ~ normal(beta[1] + beta[2] * height, sigma);
  target += sum(w_ .* lp_);
}
