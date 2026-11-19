# Generates: figures/feature-correlation-matrix.png
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

# Select numeric variables and calculate correlation matrix
message("Computing correlation matrix across numerical features and sales...")
cor_data <- train_clean %>%
  select(Weekly_Sales, Size, CPI, Unemployment, Temperature, Fuel_Price, starts_with("MarkDown"))

cor_matrix <- cor(cor_data, use = "complete.obs")

cor_long <- cor_matrix %>%
  as.data.frame() %>%
  rownames_to_column(var = "Var1") %>%
  pivot_longer(-Var1, names_to = "Var2", values_to = "Correlation")

p_cor <- ggplot(cor_long, aes(x = Var1, y = Var2, fill = Correlation)) +
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

print(p_cor)

# Save figure
out_file <- file.path("figures", "feature-correlation-matrix.png")
ggsave(out_file, plot = p_cor, width = 8, height = 6, dpi = 300)
message(sprintf("Successfully saved plot to %s", out_file))
