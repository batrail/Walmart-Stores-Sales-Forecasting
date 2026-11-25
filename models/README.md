# Models & Evaluation Results

This directory contains model training scripts, validation pipelines, and benchmark results for forecasting weekly Walmart department sales.

---

## Model Benchmark Comparison

All models are evaluated on the identical 52-week chronological validation split (`Date >= 2011-11-04`, 154,386 records) using `scripts/eval-wmae.R` with seed `set.seed(42)`.

| Model | Validation WMAE | Validation MAE | Script |
| :--- | :---: | :---: | :--- |
| **Historical Group Average (Baseline)** | **$3,275.77** | **$2,968.86** | [`baseline-historical-average.R`](baseline-historical-average.R) |
| **Linear Regression** | **$3,527.71** | **$3,167.86** | [`linearRegression.R`](linearRegression.R) |
| **Decision Tree** | *TBD* | *TBD* | *Pending* |
| **Random Forest** | **$3,177.41** | **$2,749.69** | [`random-forests.R`](random-forests.R) |

---

## Baseline Model Breakdown: Historical Group Average

The historical group average establishes the benchmark floor. It computes historical average sales on the training set (`Date < 2011-11-04`, 267,184 records) using hierarchical grouping:
1. **Level 1 (Primary)**: Historical mean by `Store`, `Dept`, and `IsHoliday`.
2. **Level 2 (Store Fallback)**: Historical mean by `Store` and `Dept`.
3. **Level 3 (Dept Fallback)**: Historical mean by `Dept` across all stores.
4. **Level 4 (Global Fallback)**: Overall training set average sales.

### Error Breakdown: Routine vs. Holiday Weeks

| Segment | Records | Share of Validation | Mean Weekly Sales | Mean Predicted Sales | Mean Absolute Error (MAE) | Metric Weight |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Non-Holiday Weeks** (`IsHoliday == FALSE`) | 142,395 | 92.2% | **$16,063.75** | $15,686.11 | **$2,859.98** | 1× |
| **Holiday Weeks** (`IsHoliday == TRUE`) | 11,991 | 7.8% | **$17,594.49** | $16,394.37 | **$4,264.12** | 5× |
| **Overall / Weighted** | **154,386** | **100.0%** | **$16,182.64** | **$15,741.12** | **$3,275.77 (WMAE)** | — |

### Key Observations
- **Holiday Sales Lift**: Actual average weekly sales surge from **$16,063.75** (routine weeks) to **$17,594.49** (holiday weeks), a +**$1,530.74** (+9.5%) lift.
- **Holiday Surge Penalty**: The average error during holiday weeks (\$4,264.12) is nearly **49% higher** than during non-holiday weeks (\$2,859.98). A static mean cannot capture sharp year-over-year fluctuations during major promotional peaks (predicting a mean of only **$16,394.37** on holiday weeks, underpredicting holiday volume by ~$1,200 on average).
- **WMAE Impact**: Because holiday errors are weighted 5×, they inflate the overall WMAE by **+$306.91** relative to unweighted MAE (\$3,275.77 vs. \$2,968.86).
- **Baseline Role**: The baseline successfully captures persistent department and store volume scales, but leaves significant variance unexplained from macro indicators, promotional markdowns, and non-linear holiday interactions. Subsequent machine learning models must beat **$3,275.77** to demonstrate value.

---

## Linear Regression Model Breakdown

Implemented in [`linearRegression.R`](linearRegression.R) using `fixest::feols`, this model incorporates two-way high-dimensional fixed effects (`Store^Dept` and `Dept^IsHoliday`) alongside linear macroeconomic and promotional markdown features.

### Error Breakdown: Routine vs. Holiday Weeks

| Segment | Records | Share of Validation | Mean Absolute Error (MAE) | Metric Weight |
| :--- | :---: | :---: | :---: | :---: |
| **Non-Holiday Weeks** (`IsHoliday == FALSE`) | 142,395 | 92.2% | **$3,040.01** | 1× |
| **Holiday Weeks** (`IsHoliday == TRUE`) | 11,991 | 7.8% | **$4,686.02** | 5× |
| **Overall Weighted (WMAE)** | **154,386** | **100.0%** | **$3,527.71** | — |

### Key Observations & Comparison to Baseline
- **Underperformed Baseline**: Yielded a validation WMAE of **$3,527.71** (+$251.94 worse than baseline) and MAE of **$3,167.86** (+$199.00 worse than baseline).
- **Severe Holiday Error**: Non-holiday MAE reached **$3,040.01** (+$180.03 over baseline), while holiday MAE expanded to **$4,686.02** (+$421.90 over baseline).
- **Linear Constraint**: Constraining macroeconomic indicators, markdowns, and trend features to additive linear slopes failed to capture seasonal holiday multipliers and non-linear interactions across store formats, causing regression estimates to overshoot or underfit during extreme retail surge periods.

---

## Random Forest Model Breakdown

Implemented in [`random-forests.R`](random-forests.R) using `tidymodels` with the `ranger` engine (`trees = 500`, `mtry = 10L`, `min_n = 1L`, multi-threaded via `parallel::detectCores()`).

### Error Breakdown: Routine vs. Holiday Weeks

| Segment | Records | Share of Validation | Mean Absolute Error (MAE) | Metric Weight |
| :--- | :---: | :---: | :---: | :---: |
| **Non-Holiday Weeks** (`IsHoliday == FALSE`) | 142,395 | 92.2% | **$2,597.74** | 1× |
| **Holiday Weeks** (`IsHoliday == TRUE`) | 11,991 | 7.8% | **$4,554.15** | 5× |
| **Overall Weighted (WMAE)** | **154,386** | **100.0%** | **$3,177.41** | — |

### Key Observations & Comparison to Baseline
- **Top Performer**: Achieved the lowest overall error among evaluated models (pre-decision tree implementation and testing) with a validation WMAE of **$3,177.41** (-$98.36 improvement over baseline) and unweighted MAE of **$2,749.69** (-$219.17 improvement over baseline).
- **Routine Week Strength**: Drove substantial accuracy gains during non-holiday periods, reducing MAE to **$2,597.74** (-$262.24 vs. baseline $2,859.98).
- **Holiday Extrapolation Limit**: Holiday MAE remained elevated at **$4,554.15** (+290.03 over baseline holiday error), as tree ensembles cannot extrapolate sales volume beyond historical partition boundaries during unprecedented peak surges. Strong non-holiday performance compensated to achieve the best overall WMAE.

---

## How to Run

From the repository root folder in RStudio or R console:

```r
# Historical Group Average Baseline
source("models/baseline-historical-average.R")

# Fixed-Effects Linear Regression (requires fixest)
source("models/linearRegression.R")

# Random Forest (requires tidymodels, ranger)
source("models/random-forests.R")
```

The scripts train each model, print validation metrics (WMAE and MAE), and write prediction outputs to `models/outputs/`:
- `models/outputs/baseline_predictions.rds`: Baseline validation predictions.
- `models/outputs/lm_predictions.rds`: Linear regression validation predictions.
- `models/outputs/random_forests_predictions.rds`: Random forest test set predictions.

> **Note on Package Dependencies**: `linearRegression.R` requires `fixest`. `random-forests.R` requires `tidymodels` and `ranger` (utilizing `parallel` for multi-threading). All model scripts set `set.seed(42)` for deterministic execution.