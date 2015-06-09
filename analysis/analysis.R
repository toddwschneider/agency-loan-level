library(RPostgreSQL)
library(ggplot2)
library(scales)
library(dplyr)
library(jsonlite)
library(survival)
library(grid)
library(gridExtra)

# some of the code in this file depends on executing queries in prepare_analysis.sql first

setwd("/path/to/agency-loan-level/analysis/")
source("helpers.R")

vintages = query("SELECT * FROM default_rates_by_vintage ORDER BY vintage")
vintages$default_rate = vintages$defaulted_balance / vintages$original_balance

png(filename = "pngs/default_rate_by_vintage.png", height = h, width = w)
ggplot(data = vintages, aes(x = vintage, y = default_rate)) +
  geom_bar(stat = "identity") +
  scale_x_continuous("\nOrigination vintage") +
  scale_y_continuous("Cumulative default rate\n", labels = percent) +
  theme_tws(base_size = 18) +
  title_with_subtitle("Cumulative default rates by vintage", "Fannie Mae/Freddie Mac 30-year fixed-rate mortgages")
  add_credits()
dev.off()

png(filename = "pngs/origination_volume_by_vintage.png", height = h, width = w)
ggplot(data = vintages, aes(x = vintage, y = original_balance / 1e9)) +
  geom_bar(stat = "identity") +
  scale_x_continuous("\nOrigination vintage") +
  scale_y_continuous("Origination volume\n", labels = function(x) { paste(dollar(x), "bn") }) +
  theme_tws(base_size = 18) +
  title_with_subtitle("Origination volume by vintage", "Fannie Mae/Freddie Mac 30-year fixed-rate mortgages")
  add_credits()
dev.off()

vintages$credit_sd_1 = vintages$credit_score + 1 * vintages$credit_score_sd
vintages$credit_sd_2 = vintages$credit_score + 2 * vintages$credit_score_sd
vintages$credit_sd_n1 = vintages$credit_score - 1 * vintages$credit_score_sd
vintages$credit_sd_n2 = vintages$credit_score - 2 * vintages$credit_score_sd

png(filename = "pngs/origination_fico_distribution.png", height = h, width = w)
ggplot(data = vintages, aes(x = vintage, y = credit_score)) +
  geom_line() +
  geom_point() +
  geom_ribbon(aes(fill = "± 1 std dev", ymin = credit_sd_n1, ymax = credit_sd_1), alpha = 0.15) +
  geom_ribbon(aes(fill = "± 2 std dev", ymin = credit_sd_n2, ymax = credit_sd_2), alpha = 0.15) +
  scale_fill_manual("", values = c("#222222", "#555555")) +
  scale_x_continuous("\nOrigination vintage") +
  scale_y_continuous("Credit score\n") +
  theme_tws(base_size = 18) +
  title_with_subtitle("Average credit score by vintage", "Fannie Mae/Freddie Mac 30-year fixed-rate mortgages")
  add_credits()
dev.off()

# generate JSON for state-level and county-level maps
states = query("SELECT * FROM bubble_defaults_by_state ORDER BY property_state")
states = mutate(states,
                "hc-key" = paste("us", tolower(property_state), sep = "-"),
                value = default_rate)
cat(toJSON(states[, c("hc-key", "value")]))

counties = query("
  SELECT
    LOWER(r.state_abbreviation) AS state,
    r.county_fips,
    r.county,
    COALESCE(r.msad_name, r.cbsa_name) AS msa_name,
    b.default_rate,
    b.balance
  FROM
    bubble_defaults_by_msa b
      LEFT JOIN raw_msa_county_mappings r
        ON b.msa = COALESCE(r.msad_code, r.cbsa_code)
  WHERE r.state_abbreviation IN ('CA', 'FL')
  ORDER BY r.state_abbreviation, r.county;
")

counties = mutate(counties,
                  padded_fips = sprintf("%03d", county_fips),
                  "hc-key" = paste("us", state, padded_fips, sep = "-"),
                  value = default_rate)
cat(toJSON(filter(counties, state == "ca")[, c("hc-key", "value", "msa_name")]))
cat(toJSON(filter(counties, state == "fl")[, c("hc-key", "value", "msa_name")]))

# aggregate default rates
fico_agg = query("
  SELECT
    credit_score AS fico_bucket,
    SUM(defaulted_balance) / SUM(denom) AS default_rate,
    SUM(denom) AS balance
  FROM bucketed_default_rates
  GROUP BY fico_bucket
  ORDER BY fico_bucket
")

current_ltv_agg = query("
  SELECT
    ccltv AS current_ltv_bucket,
    SUM(defaulted_balance) / SUM(denom) AS default_rate,
    SUM(denom) AS balance
  FROM bucketed_default_rates
  GROUP BY current_ltv_bucket
  ORDER BY current_ltv_bucket
")

png(filename = "pngs/annualized_default_rate_by_fico.png", height = h, width = w)
ggplot(data = filter(fico_agg, balance > 1e10), aes(x = fico_bucket, y = annualize(default_rate))) +
  geom_line() +
  scale_x_continuous("\nFICO score") +
  scale_y_continuous("Annualized default rate\n", labels = percent) +
  theme_tws(base_size = 18) +
  title_with_subtitle("Annualized default rates by FICO", "Fannie Mae/Freddie Mac 30-year fixed-rate mortgages, observed 2009-2011")
  add_credits()
dev.off()

png(filename = "pngs/annualized_default_rate_by_current_ltv.png", height = h, width = w)
ggplot(data = filter(current_ltv_agg, balance > 1e10), aes(x = current_ltv_bucket, y = annualize(default_rate))) +
  geom_line() +
  scale_x_continuous("\nCurrent LTV\n(adjusted for home prices and amortization)") +
  scale_y_continuous("Annualized default rate\n", labels = percent) +
  theme_tws(base_size = 18) +
  theme(axis.title.x = element_text(size = rel(0.9))) +
  title_with_subtitle("Annualized default rates by current LTV", "Fannie Mae/Freddie Mac 30-year fixed-rate mortgages, observed 2009-2011")
  add_credits()
dev.off()

# Cox proportinal hazards model
monthly_default_data = query("
  SELECT
    loan_age,
    credit_score,
    ccltv,
    dti,
    loan_purpose,
    channel,
    sato,
    defaulted
  FROM loan_level_default_rates
  WHERE
    random() < 0.2
    AND credit_score IS NOT NULL
    AND ccltv IS NOT NULL
    AND dti IS NOT NULL
    AND COALESCE(loan_purpose, 'U') != 'U'
    AND channel IS NOT NULL
")

monthly_default_data = filter(monthly_default_data, loan_purpose != "U")
monthly_default_data$loan_purpose[monthly_default_data$loan_purpose %in% c("C", "N")] = "R"
monthly_default_data$channel[monthly_default_data$channel %in% c("T", "C", "B")] = "TPO"

cox_model = coxph(Surv(loan_age - 1, loan_age, defaulted) ~ credit_score + ccltv + dti + loan_purpose + channel + sato,
                  data = monthly_default_data)

summary(cox_model)

monthly_default_data$cox_risk = predict(cox_model, type = "risk")

hazard_multiplier = function(name) {
  display_name = c(ccltv = "Current loan-to-value ratio",
                   credit_score = "Credit score",
                   dti = "Debt-to-income ratio",
                   sato = "Spread at origination")[name]

  range = quantile(monthly_default_data[, name], c(0.02, 0.98))
  vals = seq(range[1], range[2], length.out = 500)
  ix = match(name, names(cox_model$coefficients))
  coef = cox_model$coefficients[ix]
  mean = cox_model$means[ix]
  haz = data.frame(variable = as.character(display_name),
                   x = vals,
                   y = exp(coef * (vals - mean)))

  return(haz)
}

hazard_rates = do.call(rbind, lapply(c("ccltv", "credit_score", "dti", "sato"), hazard_multiplier))

png(filename = "pngs/hazard_rates.png", height = w, width = w)
ggplot(data = hazard_rates, aes(x = x, y = y)) +
  geom_line() +
  facet_wrap(~variable, ncol = 2, scales = "free_x") +
  scale_x_continuous("") +
  scale_y_continuous("Default rate multiplier\n") +
  labs(title = "Cox model default rate multipliers\n") +
  theme_tws(base_size = 18) +
  theme(strip.text = element_text(size = rel(1)),
        panel.margin = unit(2, "lines"))
  add_credits()
dev.off()

default_rate_by_date = query("
  SELECT
    date,
    SUM(defaulted_balance) / sum(denom) AS default_rate
  FROM monthly_default_rates_by_bucket
  WHERE vintage IN (2003, 2004, 2005, 2006, 2007)
    AND EXTRACT(YEAR FROM date) > vintage
  GROUP BY date
  ORDER BY date
")

png(filename = "pngs/default_rate_by_month.png", width = w, height = h)
ggplot(data = default_rate_by_date, aes(x = date, y = annualize(default_rate))) +
  geom_line() +
  scale_x_date("") +
  scale_y_continuous("Annualized default rate\n", labels = percent) +
  labs(title = "Fannie Mae/Freddie Mac default rate by month\nLoans originated from 2003-2007\n") +
  title_with_subtitle("Fannie Mae/Freddie Mac default rate by month", "30-year fixed-rate mortgages originated 2003-2007") +
  theme_tws(base_size = 18)
  add_credits()
dev.off()
