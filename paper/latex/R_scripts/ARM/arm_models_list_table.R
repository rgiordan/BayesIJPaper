
df <- 
  arm_env$combined_df_wide_labeled %>%
  mutate(chapter=str_extract(desc, "^ARM_Ch.[0-9]+")) %>%
  group_by(chapter, model_name, dataset) %>%
  summarize(num_parameters=n(), .groups="drop") %>%
  rename(Chapter=chapter, Model=model_name, Dataset=dataset, `Number of parameters`=num_parameters)

xtable(df)
