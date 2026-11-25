# Linear Regression Model for Walmart Sales Forecasting.

library(tidyverse)
library(fixest) # Fast fixed-effects linear regression 

set.seed(42)
source("scripts/eval-wmae.R")

clean_path <- file.path("data", "clean", "train_merged_clean.rds")
out_dir <- file.path("models", "outputs")

if (!file.exists(clean_path)) {
  stop("Missing ", clean_path, ". Run scripts/data-cleaning.R first.")
}

# Create output directory recursively if it doesn't already exist
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

# Load cleaned dataset and standardize column types across the full dataset first
# so train and validation splits share identical factor levels. Keep IsHoliday
# logical because calc_wmae() wants a logical vector.
train_merged <- readRDS(clean_path) %>%
  mutate(
    Store     = as.factor(Store),
    Dept      = as.factor(Dept),
    Type      = as.factor(Type),
    Month     = as.factor(Month),
    Week      = as.factor(Week),
    IsHoliday = as.logical(IsHoliday)
  )

train_set <- filter(train_merged, split == "train")
valid_set <- filter(train_merged, split == "valid")
rm(train_merged)
gc() # Clears unused memory, helps it run faster

# Dynamically detect any MarkDown1..MarkDown5 columns present in the data
markdown_cols <- grep("^MarkDown[1-5]$", names(train_set), value = TRUE)

# Numeric and markdown features with linear effects (group features are handled below)
linear_terms <- intersect(
  c(
    "CPI", "Unemployment", "Temperature", "Fuel_Price",
    markdown_cols, "reported_markdown_count", "has_any_markdown"
  ),
  names(train_set)
)

# Group interactions to include as fixed effects ('^' adds main terms + interaction)
fe_candidates <- c("Store^Dept", "Dept^IsHoliday")

# Only keep fixed effects whose columns exist in the training data
fe_terms <- fe_candidates[
  vapply(
    strsplit(fe_candidates, "\\^"),
    function(vars) all(vars %in% names(train_set)),
    logical(1)
  )
]

# Put together the fixest formula: target ~ linear features | fixed effects
rhs_linear <- if (length(linear_terms) > 0) paste(linear_terms, collapse = " + ") else "1"
rhs_fe <- if (length(fe_terms) > 0) paste("|", paste(fe_terms, collapse = " + ")) else ""
fe_formula <- as.formula(paste("Weekly_Sales ~", rhs_linear, rhs_fe))

# Fit the model on training data (notes = FALSE hides extra messages)
fe_model <- feols(fe_formula, data = train_set, notes = FALSE)

# Overall training average used as a backup if a prediction is missing
fallback_pred <- mean(train_set$Weekly_Sales, na.rm = TRUE)

# Predict on validation data and fill any missing values with the fallback average
valid_pred <- valid_set %>%
  mutate(
    pred = as.numeric(predict(fe_model, newdata = valid_set)),
    pred = coalesce(pred, fallback_pred)
  )

# Calculate holiday-weighted error (WMAE) and regular error (MAE)
val_wmae <- calc_wmae(valid_pred$Weekly_Sales, valid_pred$pred, valid_pred$IsHoliday)
val_mae  <- mean(abs(valid_pred$Weekly_Sales - valid_pred$pred), na.rm = TRUE)

# Print validation scores
message(sprintf("Linear Regression WMAE: $%.2f | MAE: $%.2f", val_wmae, val_mae))

# Keep only the columns needed for comparing models later
lm_preds <- valid_pred %>%
  select(Date, Store, Dept, IsHoliday, Weekly_Sales, pred)

# Save predictions to disk
saveRDS(lm_preds, file.path(out_dir, "lm_predictions.rds"))