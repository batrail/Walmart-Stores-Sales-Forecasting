library(tidyverse)
library(lubridate)

message("Starting data loading and cleaning pipeline...")

# Relative file paths from repository root
raw_dir   <- file.path("data", "raw")
clean_dir <- file.path("data", "clean")

if (!dir.exists(clean_dir)) {
  dir.create(clean_dir, recursive = TRUE)
}

# Load Raw Datasets
message("Loading raw datasets...")
train <- read_csv(file.path(raw_dir, "train.csv"), show_col_types = FALSE)
test <- read_csv(file.path(raw_dir, "test.csv"), show_col_types = FALSE)
stores <- read_csv(file.path(raw_dir, "stores.csv"), show_col_types = FALSE)
features <- read_csv(file.path(raw_dir, "features.csv"), show_col_types = FALSE)

message(sprintf("Loaded Train: %d rows | Test: %d rows | Stores: %d rows | Features: %d rows",
                nrow(train), nrow(test), nrow(stores), nrow(features)))

# Clean and Impute Features
# - Format Date using lubridate::ymd()
# - Replace missing promotional markdowns with 0 and clamp negative accounting corrections to 0
# - Trend imputation for slow-moving macroeconomic indicators (CPI & Unemployment) per Store
message("Cleaning features and performing store-level linear trend imputation...")

features_clean <- features %>%
  mutate(
    Date = ymd(Date),
    # Count non-missing MarkDown columns before zero-filling so we know how many were reported
    reported_markdown_count = rowSums(!is.na(pick(starts_with("MarkDown")))),
    has_any_markdown = reported_markdown_count > 0
  ) %>%
  
  # Markdowns: missing values assumed 0 lift; negative corrections clamped to 0
  mutate(across(starts_with("MarkDown"), ~ replace_na(., 0))) %>%
  mutate(across(starts_with("MarkDown"), ~ ifelse(. < 0, 0, .))) %>%
  
  # Group by store to preserve localized regional economic trends
  group_by(Store) %>%
  mutate(
    time_num = as.numeric(Date),
    
    # Linear projection for CPI
    CPI_trend = predict(
      lm(CPI ~ time_num, data = pick(everything()), na.action = na.exclude),
      newdata = pick(everything())
    ),
    CPI = ifelse(is.na(CPI), CPI_trend, CPI),
    
    # Linear projection for Unemployment
    Unemp_trend = predict(
      lm(Unemployment ~ time_num, data = pick(everything()), na.action = na.exclude),
      newdata = pick(everything())
    ),
    Unemployment = ifelse(is.na(Unemployment), Unemp_trend, Unemployment)
  ) %>%
  select(-time_num, -CPI_trend, -Unemp_trend) %>%
  ungroup()

# Clean and Merge Training Dataset
# - Note: Negative Weekly_Sales values (<0.3% of rows) are preserved
# - Chronological split: ~12 months (52 weeks) held out for validation
validation_cutoff <- ymd("2011-11-04")
message("Merging training data with features and store metadata...")

train_clean <- train %>%
  mutate(Date = ymd(Date)) %>%
  left_join(features_clean, by = c("Store", "Date", "IsHoliday")) %>%
  left_join(stores, by = "Store") %>%
  mutate(
    Year = year(Date),
    Month = month(Date),
    Week = week(Date),
    split = ifelse(Date < validation_cutoff, "train", "valid")
  )

#  Clean and Merge Test Dataset
message("Merging test dataset with features and store metadata...")

test_clean <- test %>%
  mutate(Date = ymd(Date)) %>%
  left_join(features_clean, by = c("Store", "Date", "IsHoliday")) %>%
  left_join(stores, by = "Store") %>%
  mutate(
    Year = year(Date),
    Month = month(Date),
    Week = week(Date)
  )

# Export Clean Datasets
message("Exporting cleaned datasets to data/clean/...")

saveRDS(features_clean, file.path(clean_dir, "features_clean.rds"))
saveRDS(train_clean, file.path(clean_dir, "train_merged_clean.rds"))
saveRDS(test_clean, file.path(clean_dir, "test_merged_clean.rds"))

message("Data cleaning pipeline completed successfully!")