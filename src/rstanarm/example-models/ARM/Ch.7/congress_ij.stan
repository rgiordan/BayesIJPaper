data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  vector[N] incumbency_88;
  vector[N] vote_86;
  vector[N] vote_88;
}
parameters {
  vector[3] beta;
  real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] =
    normal_lpdf(vote_88[n] |
           beta[1] + beta[2] * vote_86[n]
           + beta[3] * incumbency_88[n], sigma);
  }
}
model {
    // vote_88 ~ normal(beta[1] + beta[2] * vote_86
    //                  + beta[3] * incumbency_88,sigma);
    target += sum(w_ .* lp_);
}
