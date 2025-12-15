data {
  int<lower=0> N;
  vector[N] y;
  matrix[N, N] xxt_1;
  matrix[N, N] xxt_2;
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
}
transformed parameters {
  matrix[N, N] y_cov;
  y_cov =
    sigma_eps^2 * id_n +
    sigma1^2 * xxt_1 +
    sigma2^2 * xxt_2;
}
model {
  mu ~ normal(0.0, mu_prior);
  sigma1 ~ exponential(sigma1_prior);
  sigma2 ~ exponential(sigma2_prior);
  sigma_eps ~ exponential(sigma_eps_prior);
  y ~ multi_normal(mu * vec_n, y_cov);
}
