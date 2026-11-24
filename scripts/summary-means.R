# Creates a df of feature means for exploration
# This is for use in R-Studio, not a command prompt script!!!
# Compare to model output
val <- readRDS("data/clean/train_merged_clean.rds") %>%
  filter(split == "valid")

feature_summary_df <- bind_rows(
  val %>% group_by(segment = ifelse(IsHoliday, "holiday", "non_holiday")),
  val %>% mutate(segment = "overall")
) %>%
  group_by(segment) %>%
  summarise(n = n(), across(where(is.numeric), ~ mean(., na.rm = TRUE)), .groups = "drop") %>%
  as.data.frame()