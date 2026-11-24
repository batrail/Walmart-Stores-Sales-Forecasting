library(tidyverse)
library(tidymodels)

set.seed(42)
source("scripts/eval-wmae.R")

clean_path <- file.path("data", "clean", "train_merged_clean.rds")
test_path  <- file.path("data", "clean", "test_merged_clean.rds")
out_dir    <- file.path("models", "outputs")

if (!file.exists(clean_path)) {
  stop("Missing ", clean_path, ". Run scripts/data-cleaning.R first.")
}
if (!file.exists(test_path)) {
  stop("Missing ", test_path, ". Run scripts/data-cleaning.R first.")
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

train_merged <- readRDS(clean_path)
test_data    <- readRDS(test_path)

# Split into train and validation sets, then drop `split` so hardhat doesn't require it at prediction time
train_set <- train_merged |>
  filter(split == "train") |>
  select(-any_of("split"))

valid_set <- train_merged |>
  filter(split == "valid") |>
  select(-any_of("split"))

test_clean <- test_data |>
  select(-any_of("split"))

# Define Random Forest model
rf_model <- rand_forest(trees = 500) |>
  set_engine("ranger") |>
  set_mode("regression")

# Define recipe
  step_date(Date, features = c("year", "month", "week", "dow"))

# Assemble and fit workflow on train_set
rf_workflow <- workflow() |>
  add_model(rf_model) |>
  add_recipe(rf_recipe)

rf_fit <- fit(rf_workflow, data = train_set)

# Evaluate on validation set using WMAE and MAE
valid_pred <- valid_set |>
  mutate(pred = predict(rf_fit, new_data = valid_set)$.pred)

val_wmae <- calc_wmae(valid_pred$Weekly_Sales, valid_pred$pred, valid_pred$IsHoliday)
val_mae  <- mean(abs(valid_pred$Weekly_Sales - valid_pred$pred), na.rm = TRUE)

message(sprintf("Random Forest WMAE: $%.2f | MAE: $%.2f", val_wmae, val_mae))

# Generate test predictions formatted as date, store, dept, sales
test_preds <- predict(rf_fit, new_data = test_clean)

rf_output <- test_clean |>
  mutate(sales = test_preds$.pred) |>
  select(
    date = Date,
    store = Store,
    dept = Dept,
    sales
  )

saveRDS(rf_output, file.path(out_dir, "random_forests_predictions.rds"))