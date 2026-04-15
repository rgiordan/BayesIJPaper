data {
  int<lower=0> N;
  int<lower=0> D1;
  int<lower=0> D2;
  vector[N] y;
  matrix[N, D1] x1;
  matrix[N, D2] x2;
  real<lower=0> sigma1_prior;
  real<lower=0> sigma2_prior;
  real<lower=0> sigma_eps_prior;
  real mu_prior;
}
transformed data {
  matrix[N, N] id_n;
  vector[N] vec_n;
  for (i in 1:N) {
    vec_n[i] = 1.0;
    for (j in 1:N) {
      if (i == j) {
        id_n[i, j] = 1.0;
      } else {
        id_n[i, j] = 0.0;
      }
    }
  }
}
parameters {
  real mu;
  real<lower=0> sigma_eps;
  real<lower=0> sigma1;
  real<lower=0> sigma2;
  vector[D1] eta1;
  vector[D2] eta2;
}
transformed parameters {
  vector[N] y_mean;
  y_mean = vec_n * mu + x1 * eta1 + x2 * eta2;
}
model {
  mu ~ normal(0.0, mu_prior);
  sigma1 ~ exponential(sigma1_prior);
  sigma2 ~ exponential(sigma2_prior);
  sigma_eps ~ exponential(sigma_eps_prior);
  eta1 ~ normal(0., sigma1);
  eta2 ~ normal(0., sigma2);
  y ~ normal(y_mean, sigma_eps);
}
