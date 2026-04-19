data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  int<lower=1,upper=85> county[N];
  vector[N] x;
  vector[N] y;
}
parameters {
  vector[85] eta1;
  vector[85] eta2;
  real mu_a1;
  real mu_a2;
  real<lower=0,upper=100> sigma_a1;
  real<lower=0,upper=100> sigma_a2;
  real<lower=0,upper=100> sigma_y;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  vector[85] a1;
  vector[85] a2;
  vector[N] y_hat;
  real log_sigma_a1;
  real log_sigma_a2;
  real log_sigma_y;

  log_sigma_a1 = log(sigma_a1);
  log_sigma_a2 = log(sigma_a2);
  log_sigma_y = log(sigma_y);

  a1 = mu_a1 + sigma_a1 * eta1;
  a2 = 0.1 * mu_a2 + sigma_a2 * eta2;

  for (i in 1:N) {
    y_hat[i] = a1[county[i]] + a2[county[i]] * x[i];
    lp_[i] = normal_lpdf(y[i] | y_hat[i], sigma_y);
  }
}
model {
  mu_a1 ~ normal(0, 1);
  mu_a2 ~ normal(0, 1);
  eta1 ~ normal(0, 1);
  eta2 ~ normal(0, 1);
  // y ~ normal(y_hat, sigma_y);
  target += sum(w_ .* lp_);
}
