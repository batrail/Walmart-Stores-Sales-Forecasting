# Generates: figures/weekly-sales-YoY.png
# Input: data/clean/train_merged_clean.rds

library(tidyverse)
library(lubridate)
library(scales)

# Load pre-cleaned training data
clean_path <- file.path("data", "clean", "train_merged_clean.rds")
if (!file.exists(clean_path)) {
  stop("Cleaned data not found. Please run scripts/data-cleaning.R first.")
}

message("Loading cleaned training data...")
train_clean <- readRDS(clean_path)

# Ensure figures directory exists
if (!dir.exists("figures")) {
  dir.create("figures", recursive = TRUE)
}

# Aggregate weekly sales by Year and align calendar dates to compare cycles
message("Aggregating sales and building Year-over-Year visualization...")
weekly_sales_layered <- train_clean %>%
  group_by(Date, Year) %>%
  summarise(Total_Sales = sum(Weekly_Sales), .groups = "drop") %>%
  mutate(
    Aligned_Date = make_date(year = 2000L, month = month(Date), day = day(Date)),
    Year_Factor  = factor(Year)
  )

p_yoy <- ggplot(weekly_sales_layered, aes(x = Aligned_Date, y = Total_Sales, color = Year_Factor, group = Year_Factor)) +
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

print(p_yoy)

# Save figure
out_file <- file.path("figures", "weekly-sales-YoY.png")
ggsave(out_file, plot = p_yoy, width = 8, height = 6, dpi = 300)
message(sprintf("Successfully saved plot to %s", out_file))
