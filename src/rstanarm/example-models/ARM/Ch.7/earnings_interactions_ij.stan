data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] earnings;
  vector[N] height;
  vector[N] sex1;
}
transformed data {
  vector[N] log_earnings;
  vector[N] male;
  vector[N] height_male_inter;

  log_earnings = log(earnings);
  male = 2 - sex1;
  height_male_inter = height .* male;
}
parameters {
  vector[4] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] =
    normal_lpdf(log_earnings[n] |
      beta[1] + beta[2] * height[n] + beta[3] * male[n]
      + beta[4] * height_male_inter[n], sigma);
  }
}
model {
  // log_earnings ~ normal(beta[1] + beta[2] * height + beta[3] * male
  //                            + beta[4] * height_male_inter, sigma);
  target += sum(w_ .* lp_);
}
