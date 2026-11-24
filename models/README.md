# Models & Evaluation Results

This directory contains model training scripts, validation pipelines, and benchmark results for forecasting weekly Walmart department sales.

---

## Model Benchmark Comparison

All models are evaluated on the identical 52-week chronological validation split (`Date >= 2011-11-04`, 154,386 records) using `scripts/eval-wmae.R` with seed `set.seed(42)`.

| Model | Validation WMAE | Validation MAE | Script |
| :--- | :---: | :---: | :--- |
| **Historical Group Average (Baseline)** | **$3,275.77** | **$2,968.86** | [`baseline-historical-average.R`](baseline-historical-average.R) |
| **Linear Regression** | *TBD* | *TBD* | *Pending* |
| **Decision Tree** | *TBD* | *TBD* | *Pending* |
| **Random Forest** | *TBD* | *TBD* | *Pending* |

---

## Baseline Model Breakdown: Historical Group Average

The historical group average establishes the benchmark floor. It computes historical average sales on the training set (`Date < 2011-11-04`, 267,184 records) using hierarchical grouping:
1. **Level 1 (Primary)**: Historical mean by `Store`, `Dept`, and `IsHoliday`.
2. **Level 2 (Store Fallback)**: Historical mean by `Store` and `Dept`.
3. **Level 3 (Dept Fallback)**: Historical mean by `Dept` across all stores.
4. **Level 4 (Global Fallback)**: Overall training set average sales.

### Error Breakdown: Routine vs. Holiday Weeks

| Segment | Records | Share of Validation | Mean Absolute Error (MAE) | Metric Weight |
| :--- | :---: | :---: | :---: | :---: |
| **Non-Holiday Weeks** (`IsHoliday == FALSE`) | 142,395 | 92.2% | **$2,859.98** | 1× |
| **Holiday Weeks** (`IsHoliday == TRUE`) | 11,991 | 7.8% | **$4,264.12** | 5× |
| **Overall Weighted (WMAE)** | **154,386** | **100.0%** | **$3,275.77** | — |

### Key Observations
- **Holiday Surge Penalty**: The average error during holiday weeks (\$4,264.12) is nearly **49% higher** than during non-holiday weeks (\$2,859.98). A static mean cannot capture sharp year-over-year fluctuations during major promotional peaks (Thanksgiving, Christmas, Super Bowl).
- **WMAE Impact**: Because holiday errors are weighted 5×, they inflate the overall WMAE by **+$306.91** relative to unweighted MAE (\$3,275.77 vs. \$2,968.86).
- **Baseline Role**: The baseline successfully captures persistent department and store volume scales, but leaves significant variance unexplained from macro indicators, promotional markdowns, and non-linear holiday interactions. Subsequent machine learning models must beat **$3,275.77** to demonstrate value.

---

## How to Run

From the repository root folder in RStudio or R console:

```r
source("models/baseline-historical-average.R")
```

The script trains the model, prints validation metrics, and writes validation predictions to `models/outputs/`.