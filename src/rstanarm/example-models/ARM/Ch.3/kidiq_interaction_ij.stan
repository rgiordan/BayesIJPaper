data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector<lower=0, upper=200>[N] kid_score;
  vector<lower=0, upper=200>[N] mom_iq;
  vector<lower=0, upper=1>[N] mom_hs;
}
transformed data {           // interaction
  vector[N] inter;
  inter = mom_hs .* mom_iq;
}
parameters {
  vector[4] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  real log_sigma;

  for (n in 1:N) {
    lp_[n] =
      normal_lpdf(kid_score[n] |
        beta[1] + beta[2] * mom_hs[n] + beta[3] * mom_iq[n] + beta[4] * inter[n],
        sigma);
  }

  log_sigma = log(sigma);
}
model {
  sigma ~ cauchy(0, 2.5);
  // kid_score ~ normal(beta[1] + beta[2] * mom_hs + beta[3] * mom_iq
  //                    + beta[4] * inter, sigma);
  target += sum(w_ .* lp_);
}
