data {
  int<lower=0> N;
  vector[N] y;
  vector[N] x;
}
parameters {
  vector[2] beta;
  real<lower=0> sigma;
}transformed parameters {
  real log_sigma;
  log_sigma = log(sigma);
}
model {
  sigma ~ cauchy(0, 1);
  beta ~ normal(0, 100);
  y ~ normal(beta[1] + beta[2] * x, sigma);
}
