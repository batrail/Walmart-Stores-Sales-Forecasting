library(tidyverse)
library(tidymodels)

#this file requires the use of the "ranger" engine for faster computing
#do "install.package("ranger") to run properly

set.seed(42)
source("scripts/eval-wmae.R")
#set paths for later use
clean_path <- file.path("data", "clean", "train_merged_clean.rds")
test_path  <- file.path("data", "clean", "test_merged_clean.rds")
out_dir    <- file.path("models", "outputs")

#checking of directory existence/file existence
if (!file.exists(clean_path)) {
  stop("Missing ", clean_path, ". Run scripts/data-cleaning.R first.")
}
if (!file.exists(test_path)) {
  stop("Missing ", test_path, ". Run scripts/data-cleaning.R first.")
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

#read-only load
train_merged <- readRDS(clean_path)
test_raw     <- readRDS(test_path)

#removes split to be able to properly predict
prep_df <- function(df) {
  df |>
    select(-any_of(c("split", "Date")))
}
#establishing variables to use for model
train_set  <- train_merged |> filter(split == "train") |> prep_df()
valid_set  <- train_merged |> filter(split == "valid") |> prep_df()
test_clean <- test_raw |> prep_df()

#random forest setup
#ranger allows for faster model operation since it uses multi threading
rf_model <- rand_forest(trees = 500, mtry = 10L, min_n = 1L) |>
  set_engine("ranger", num.threads = max(1L, parallel::detectCores() - 1L)) |>
  set_mode("regression")

rf_recipe <- recipe(Weekly_Sales ~ ., data = train_set)

rf_workflow <- workflow() |>
  add_model(rf_model) |>
  add_recipe(rf_recipe)

rf_fit <- fit(rf_workflow, data = train_set)

#evaluate on validation set using WMAE and MAE
valid_pred <- valid_set |>
  mutate(pred = predict(rf_fit, new_data = valid_set)$.pred)

val_wmae <- calc_wmae(valid_pred$Weekly_Sales, valid_pred$pred, valid_pred$IsHoliday)
val_mae  <- mean(abs(valid_pred$Weekly_Sales - valid_pred$pred), na.rm = TRUE)

message(sprintf("Random Forest WMAE: $%.2f | MAE: $%.2f", val_wmae, val_mae))

#generate test predictions formatted as date, store, dept, sales
test_preds <- predict(rf_fit, new_data = test_clean)

#output setup for output file
rf_output <- test_raw |>
  mutate(sales = test_preds$.pred) |>
  select(
    date = Date,
    store = Store,
    dept = Dept,
    sales
  )

saveRDS(rf_output, file.path(out_dir, "random_forests_predictions.rds"))