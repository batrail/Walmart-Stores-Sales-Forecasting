# Computes Weighted Mean Absolute Error (weight = 5 on holidays, 1 otherwise)

calc_wmae <- function(actual, predicted, is_holiday) {
  weights <- ifelse(is_holiday, 5, 1)
  sum(weights * abs(actual - predicted), na.rm = TRUE) / sum(weights[!is.na(actual) & !is.na(predicted)])
}