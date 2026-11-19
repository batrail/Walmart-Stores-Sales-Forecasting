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
# - Chronological split: ~6 months (26 weeks) held out for validation
validation_cutoff <- ymd("2012-05-04")
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

#WEEKLY SALES BY YEAR LAYERED
weekly_sales_layered <- train_clean %>%
  group_by(Date, Year) %>%
  summarise(Total_Sales = sum(Weekly_Sales)) %>%
  mutate(
    Aligned_Date = make_date(year = 2000L, month = month(Date), day = day(Date)),
    Year_Factor = factor(Year)
  )
 
ggplot(weekly_sales_layered, aes(x = Aligned_Date, y = Total_Sales, color = Year_Factor, group = Year_Factor)) +
  geom_line(linewidth = 0.8) +
  scale_x_date(date_breaks = "1 month", date_labels = "%b") +
  scale_y_continuous(labels = scales::dollar) +
  labs(
    title = "Total Weekly Sales by Year",
    x = "Month",
    y = "Total Weekly Sales",
    color = "Year"
  ) +
  theme_minimal()
 
 
# CORRELATION COEFFICIENT
cor_data <- train_clean %>%
  select(Weekly_Sales, Size, CPI, Unemployment, Temperature, Fuel_Price, starts_with("MarkDown"))
cor_matrix <- cor(cor_data, use = "complete.obs")
cor_long <- cor_matrix %>%
  as.data.frame() %>%
  rownames_to_column(var = "Var1") %>%
  pivot_longer(-Var1, names_to = "Var2", values_to = "Correlation")
ggplot(cor_long, aes(x = Var1, y = Var2, fill = Correlation)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(
    low = "blue", high = "red", mid = "white",
    midpoint = 0, limit = c(-1, 1), space = "Lab",
    name = "Correlation"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1, size = 10),
    axis.text.y = element_text(size = 10)
  ) +
  coord_fixed() +
  labs(title = "Feature Correlation Matrix", x = "", y = "")
 
# STORE SIZE VS MEAN OVER YEAR
store_summary <- train_clean %>%
  group_by(Store, Type, Size) %>%
  summarise(mean_sales = mean(Weekly_Sales, na.rm = TRUE), .groups = "drop")
 
ggplot(store_summary, aes(x = Size, y = mean_sales, color = Type)) +
  geom_point(size = 2.5, alpha = 0.85) +
  geom_smooth(method = "lm", se = FALSE, linetype = "dashed", linewidth = 0.7) +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale())) +
  labs(
    title = "Store Size vs. Mean Weekly Sales by Store Type",
    x = "Store Size (sq ft)",
    y = "Mean Weekly Sales",
    color = "Type"
  ) +
  theme_minimal()