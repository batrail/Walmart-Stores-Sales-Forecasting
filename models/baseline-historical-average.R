library(tidyverse)

set.seed(42)
source("scripts/eval-wmae.R")

clean_path <- file.path("data", "clean", "train_merged_clean.rds")
out_dir <- file.path("models", "outputs")

if (!file.exists(clean_path)) {
  stop("Missing ", clean_path, ". Run scripts/data-cleaning.R first.")
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

train_merged <- readRDS(clean_path)
train_set <- filter(train_merged, split == "train")
valid_set <- filter(train_merged, split == "valid")

# Hierarchical group means (Store+Dept+Holiday -> Store+Dept -> Dept -> Global)
m1 <- train_set %>% 
  group_by(Store, Dept, IsHoliday) %>% 
  summarise(p1 = mean(Weekly_Sales, na.rm = TRUE), .groups = "drop")

m2 <- train_set %>% 
  group_by(Store, Dept) %>% 
  summarise(p2 = mean(Weekly_Sales, na.rm = TRUE), .groups = "drop")

m3 <- train_set %>% 
  group_by(Dept) %>% 
  summarise(p3 = mean(Weekly_Sales, na.rm = TRUE), .groups = "drop")

p4 <- mean(train_set$Weekly_Sales, na.rm = TRUE)

valid_pred <- valid_set %>%
  left_join(m1, by = c("Store", "Dept", "IsHoliday")) %>%
  left_join(m2, by = c("Store", "Dept")) %>%
  left_join(m3, by = "Dept") %>%
  mutate(pred = coalesce(p1, p2, p3, p4))

val_wmae <- calc_wmae(valid_pred$Weekly_Sales, valid_pred$pred, valid_pred$IsHoliday)
val_mae  <- mean(abs(valid_pred$Weekly_Sales - valid_pred$pred), na.rm = TRUE)

message(sprintf("Baseline WMAE: $%.2f | MAE: $%.2f", val_wmae, val_mae))

baseline_preds <- valid_pred %>%
  select(Date, Store, Dept, IsHoliday, Weekly_Sales, pred)

saveRDS(baseline_preds, file.path(out_dir, "baseline_predictions.rds"))