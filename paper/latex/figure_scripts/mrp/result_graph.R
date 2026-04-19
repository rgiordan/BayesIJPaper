ggplot(mrp_env$compiled_df) +
  geom_boxplot(aes(x="IJ", y=(ij_var))) +
  geom_boxplot(aes(x="Bayes", y=(bayes_var))) +
  geom_point(aes(x="IJ", y=(ij_var_orig))) +
  geom_point(aes(x="Bayes", y=(bayes_var_orig))) +
  geom_point(aes(x="Bootstrap", y=(boot_var))) +
  geom_hline(aes(yintercept=(true_var))) +
  geom_text(aes(x="Bootstrap", y=4.9e-5, 
                 label="Horizontal line shows estimated true variance"),
            size=3) +
  xlab("")
