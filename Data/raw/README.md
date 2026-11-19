# Raw Data Dictionary

This directory contains raw datasets sourced from the [Walmart Recruiting – Store Sales Forecasting](https://www.kaggle.com/competitions/walmart-recruiting-store-sales-forecasting/data) competition on Kaggle.

---

## Files Overview

| File | Rows | Columns | Description |
| :--- | :--- | :--- | :--- |
| `train.csv` | 421,570 | 5 | Historical weekly sales records from 2010-02-05 to 2012-10-26 across 45 stores and 99 departments. |
| `test.csv` | 115,064 | 4 | Target prediction timeframe from 2012-11-02 to 2013-07-26 (identical to `train.csv` without `Weekly_Sales`). |
| `stores.csv` | 45 | 3 | Static metadata describing the 45 physical store locations. |
| `features.csv` | 8,190 | 12 | Weekly regional covariates and macroeconomic indicators per store from 2010 to 2013. |
| `sampleSubmission.csv` | 115,064 | 2 | Kaggle submission format template (`Id`, `Weekly_Sales`). |

---

## Variable Descriptions

### 1. `train.csv` & `test.csv`
- **`Store`** *(integer 1–45)*: Unique store number.
- **`Dept`** *(integer 1–99)*: Department identifier within each store.
- **`Date`** *(YYYY-MM-DD)*: Week-ending date (all records fall on Fridays).
- **`Weekly_Sales`** *(numeric, train only)*: Total weekly sales volume in USD. Negative values correspond to net returns/refunds.
- **`IsHoliday`** *(logical)*: Boolean flag (`TRUE`/`FALSE`) indicating whether the week contains a major holiday.

### 2. `stores.csv`
- **`Store`** *(integer 1–45)*: Unique store number.
- **`Type`** *(categorical)*: Store classification (`A`, `B`, or `C` based on store size/format).
- **`Size`** *(numeric)*: Physical store floor area in square feet.

### 3. `features.csv`
- **`Store`** *(integer 1–45)*: Store identifier.
- **`Date`** *(YYYY-MM-DD)*: Week-ending Friday date.
- **`Temperature`** *(numeric)*: Average weekly temperature in the store's geographic region (°F).
- **`Fuel_Price`** *(numeric)*: Regional cost of consumer fuel per gallon (USD).
- **`MarkDown1` - `MarkDown5`** *(numeric)*: Anonymized promotional discount and promotional markdown expenditures. Unavailable prior to November 2011 (handled during data cleaning).
- **`CPI`** *(numeric)*: Regional Consumer Price Index.
- **`Unemployment`** *(numeric)*: Dominant regional unemployment rate (percentage).
- **`IsHoliday`** *(logical)*: Boolean flag for holiday weeks.

---

## Holidays Defined
The dataset flags four specific annual holiday weeks:
1. **Super Bowl**: Early February (e.g., 2010-02-12, 2011-02-11, 2012-02-10, 2013-02-08)
2. **Labor Day**: Early September (e.g., 2010-09-10, 2011-09-09, 2012-09-07)
3. **Thanksgiving**: Late November (e.g., 2010-11-26, 2011-11-25, 2012-11-23)
4. **Christmas**: Late December (e.g., 2010-12-31, 2011-12-30, 2012-12-28)

Holiday weeks are weighted **5×** compared to normal weeks (weight = 1) in the competition evaluation metric (WMAE).
