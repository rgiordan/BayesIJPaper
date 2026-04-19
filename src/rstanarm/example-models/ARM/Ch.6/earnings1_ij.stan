data {
  int<lower=0> N;
  vector[N] w_; // Bootstrap weights
  int<lower=0,upper=1> earn_pos[N];
  vector[N] height;
  vector[N] male;
}
parameters {
  vector[3] beta;
  //real<lower=0> sigma;
}
transformed parameters {
  // Log posterior for the IJ
  vector[N] lp_;
  for (n in 1:N) {
    lp_[n] =
      bernoulli_logit_lpmf(
        earn_pos[n] | beta[1] + beta[2] * height[n] + beta[3] * male[n]);

  }
}
model {
  // earn_pos ~ bernoulli_logit(beta[1] + beta[2] * height + beta[3] * male);
  target += sum(w_ .* lp_);
}
