data {
  int<lower=0> N;
  vector[N] w_;
  vector<lower=0, upper=200>[N] kid_score;
  vector<lower=0, upper=200>[N] mom_iq;
  vector<lower=0, upper=1>[N] mom_hs;
}
parameters {
  vector[3] beta;
  real<lower=0> sigma;
}
transformed parameters {
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] = normal_lpdf(kid_score[n] |
      beta[1] + beta[2] * mom_hs[n] + beta[3] * mom_iq[n],
      sigma);
  }
}
model {
  sigma ~ cauchy(0, 2.5);
  //kid_score ~ normal(beta[1] + beta[2] * mom_hs + beta[3] * mom_iq, sigma);
  target += sum(w_ .* lp_);
}
