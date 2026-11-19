# Generates: figures/avg-weekly-sales-by-size.png
# Input: data/clean/train_merged_clean.rds

library(tidyverse)
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

# Compute store-level mean weekly sales and plot against store size and type
message("Summarizing store-level volume and fitting linear trend by store type...")
store_summary <- train_clean %>%
  group_by(Store, Type, Size) %>%
  summarise(mean_sales = mean(Weekly_Sales, na.rm = TRUE), .groups = "drop")

p_size <- ggplot(store_summary, aes(x = Size, y = mean_sales, color = Type)) +
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

print(p_size)

# Save figure
out_file <- file.path("figures", "avg-weekly-sales-by-size.png")
ggsave(out_file, plot = p_size, width = 8, height = 6, dpi = 300)
message(sprintf("Successfully saved plot to %s", out_file))
