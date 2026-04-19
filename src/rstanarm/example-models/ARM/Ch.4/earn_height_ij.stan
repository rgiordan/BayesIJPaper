data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] earn;
  vector[N] height;
}
parameters {
  vector[2] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] = normal_lpdf(earn[n] | beta[1] + beta[2] * height[n], sigma);
  }
}
model {
  //earn ~ normal(beta[1] + beta[2] * height, sigma);
  target += sum(w_ .* lp_);
}
