data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  int<lower=0,upper=1> switched[N];
  vector[N] dist;
  vector[N] arsenic;
  vector[N] educ;
}
transformed data {
  vector[N] c_dist100;
  vector[N] c_arsenic;
  vector[N] c_educ4;
  vector[N] da_inter;
  vector[N] de_inter;
  vector[N] ae_inter;
  c_dist100 = (dist - mean(dist)) / 100.0;
  c_arsenic = log(arsenic) - mean(log(arsenic));
  c_educ4   = (educ - mean(educ)) / 4.0;
  da_inter  = c_dist100 .* c_arsenic;
  de_inter  = c_dist100 .* c_educ4;
  ae_inter  = c_arsenic .* c_educ4;
}
parameters {
  vector[7] beta;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] =
    bernoulli_logit_lpmf(switched[n] |
      beta[1] + beta[2] * c_dist100[n] + beta[3] * c_arsenic[n]
      + beta[4] * c_educ4[n] + beta[5] * da_inter[n]
      + beta[6] * de_inter[n] + beta[7] * ae_inter[n]);

  }
}
model {
  // switched ~ bernoulli_logit(beta[1] + beta[2] * c_dist100 + beta[3] * c_arsenic
  //                             + beta[4] * c_educ4 + beta[5] * da_inter
  //                             + beta[6] * de_inter + beta[7] * ae_inter);
  target += sum(w_ .* lp_);
}
generated quantities {
  vector[N] pred;
  for (i in 1:N)
    pred[i] = inv_logit(beta[1] + beta[2] * c_dist100[i] + beta[3] * c_arsenic[i]
                         + beta[4] * c_educ4[i] + beta[5] * da_inter[i]
                         + beta[6] * de_inter[i] + beta[7] * ae_inter[i]);
}
