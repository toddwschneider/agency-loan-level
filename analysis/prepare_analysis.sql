-- assorted queries to prepare data for analysis.R script

DROP TABLE IF EXISTS default_rates_by_vintage;
CREATE TABLE default_rates_by_vintage AS
SELECT
  vintage,
  COUNT(*) AS loan_count,
  SUM(original_upb) AS original_balance,
  SUM(CASE WHEN first_serious_dq_date IS NOT NULL THEN original_upb ELSE 0 END) AS defaulted_balance,
  SUM(credit_score * original_upb) / SUM(CASE WHEN credit_score IS NOT NULL THEN original_upb END) AS credit_score,
  STDDEV(credit_score) AS credit_score_sd,
  SUM(oltv * original_upb) / SUM(CASE WHEN oltv IS NOT NULL THEN original_upb END) AS original_ltv,
  SUM(ocltv * original_upb) / SUM(CASE WHEN ocltv IS NOT NULL THEN original_upb END) AS original_cltv,
  SUM(dti * original_upb) / SUM(CASE WHEN dti IS NOT NULL THEN original_upb END) AS dti
FROM loans
WHERE vintage >= 1999 AND vintage <= 2013
GROUP BY vintage;

DROP TABLE IF EXISTS monthly_default_rates_by_bucket;
CREATE TABLE monthly_default_rates_by_bucket AS
SELECT
  vintage,
  FLOOR(credit_score / 50) * 50 AS fico_bucket,
  FLOOR(original_interest_rate / 0.5) * 0.5 AS rate_bucket,
  date,
  SUM(CASE WHEN date = first_serious_dq_date THEN previous_weight END) AS defaulted_balance,
  SUM(CASE WHEN date <= COALESCE(first_serious_dq_date, '2050-01-01') THEN previous_weight END) AS denom
FROM loan_monthly
WHERE
  vintage >= 2003
  AND vintage <= 2011
  AND date >= '2006-01-01'
  AND date <= '2013-12-01'
GROUP BY vintage, fico_bucket, rate_bucket, date
ORDER BY vintage, fico_bucket, rate_bucket, date;

DROP TABLE IF EXISTS loan_level_default_rates;
CREATE TABLE loan_level_default_rates AS
SELECT
  loan_id,
  vintage,
  lm.date,
  loan_age,
  credit_score,
  COALESCE(ocltv, oltv) * (previous_weight / original_upb) * (hpi_at_origination / hpi.hpi) AS ccltv,
  dti,
  original_interest_rate - sato AS sato,
  loan_purpose,
  channel,
  CASE WHEN lm.date = first_serious_dq_date THEN 1 ELSE 0 END AS defaulted,
  previous_weight
FROM loan_monthly lm
  INNER JOIN hpi_values hpi ON lm.hpi_index_id = hpi.hpi_index_id AND lm.date = hpi.date
WHERE
  vintage >= 2005
  AND vintage <= 2007
  AND lm.date >= '2009-01-01'
  AND lm.date <= '2010-12-01'
  AND lm.date <= COALESCE(first_serious_dq_date, '2050-01-01')
  AND credit_score IS NOT NULL AND dti IS NOT NULL AND oltv IS NOT NULL;

DROP TABLE IF EXISTS bucketed_default_rates;
CREATE TABLE bucketed_default_rates AS
SELECT
  FLOOR(credit_score / 10) * 10 AS credit_score,
  FLOOR(COALESCE(ocltv, oltv) * (previous_weight / original_upb) * (hpi_at_origination / hpi.hpi) / 5) * 5 AS ccltv,
  FLOOR(dti / 3) * 3 AS dti,
  FLOOR((original_interest_rate - sato) / 0.1) * 0.1 AS sato,
  loan_purpose,
  channel,
  SUM(CASE WHEN lm.date = first_serious_dq_date THEN previous_weight END) AS defaulted_balance,
  SUM(CASE WHEN lm.date <= COALESCE(first_serious_dq_date, '2050-01-01') THEN previous_weight END) AS denom
FROM loan_monthly lm
  INNER JOIN hpi_values hpi ON lm.hpi_index_id = hpi.hpi_index_id AND lm.date = hpi.date
WHERE
  vintage >= 2005
  AND vintage <= 2007
  AND lm.date >= '2009-01-01'
  AND lm.date <= '2011-12-01'
  AND lm.date <= COALESCE(first_serious_dq_date, '2050-01-01')
  AND credit_score IS NOT NULL AND dti IS NOT NULL AND oltv IS NOT NULL
GROUP BY credit_score, ccltv, dti, original_interest_rate, sato, loan_purpose, channel;

DROP TABLE IF EXISTS bubble_defaults_by_servicer;
CREATE TABLE bubble_defaults_by_servicer AS
SELECT
  s.name,
  COUNT(*) AS loan_count,
  SUM(original_upb) AS original_balance,
  SUM(CASE WHEN first_serious_dq_date IS NOT NULL THEN original_upb ELSE 0 END) AS defaulted_balance,
  SUM(credit_score * original_upb) / SUM(CASE WHEN credit_score IS NOT NULL THEN original_upb END) AS fico,
  SUM(oltv * original_upb) / SUM(CASE WHEN oltv IS NOT NULL THEN original_upb END) AS oltv
FROM loans l INNER JOIN servicers s ON l.seller_id = s.id
WHERE vintage IN (2005, 2006, 2007)
GROUP BY s.id;

SELECT
  name,
  loan_count,
  defaulted_balance / original_balance AS default_rate,
  fico,
  oltv
FROM bubble_defaults_by_servicer
WHERE original_balance > 1e10
ORDER BY default_rate DESC;

DROP TABLE IF EXISTS bubble_defaults_by_state;
CREATE TABLE bubble_defaults_by_state AS
SELECT
  property_state,
  COUNT(*) AS loan_count,
  SUM(original_upb) AS balance,
  SUM(CASE WHEN first_serious_dq_date IS NOT NULL THEN original_upb ELSE 0 END) / SUM(original_upb) AS default_rate
FROM loans
WHERE vintage IN (2005, 2006, 2007)
GROUP BY property_state;

DROP TABLE IF EXISTS bubble_defaults_by_msa;
CREATE TABLE bubble_defaults_by_msa AS
SELECT
  msa,
  COUNT(*) AS loan_count,
  SUM(original_upb) AS balance,
  SUM(CASE WHEN first_serious_dq_date IS NOT NULL THEN original_upb ELSE 0 END) / SUM(original_upb) AS default_rate
FROM loans
WHERE vintage IN (2005, 2006, 2007)
GROUP BY msa;

DROP TABLE IF EXISTS msa_names;
CREATE TABLE msa_names AS
SELECT DISTINCT COALESCE(msad_code, cbsa_code) AS msa, COALESCE(msad_name, cbsa_name) AS name 
FROM raw_msa_county_mappings
ORDER BY msa;
CREATE UNIQUE INDEX index_msa_names ON msa_names (msa);
INSERT INTO msa_names SELECT DISTINCT cbsa_code, cbsa_name FROM raw_msa_county_mappings WHERE cbsa_code NOT IN (SELECT msa FROM msa_names);

DROP TABLE IF EXISTS msa_county_mapping;
CREATE TABLE msa_county_mapping AS
SELECT DISTINCT
  cbsa_code AS msa,
  cbsa_name AS msa_name,
  state_fips,
  county_fips,
  county,
  state_abbreviation
FROM raw_msa_county_mappings
ORDER BY cbsa_code, state_fips, county_fips;
CREATE UNIQUE INDEX index_msa_county_mapping ON msa_county_mapping (msa, state_fips, county_fips);
INSERT INTO msa_county_mapping
SELECT
  msad_code,
  msad_name,
  state_fips,
  county_fips,
  county,
  state_abbreviation
FROM raw_msa_county_mappings
WHERE msad_code IS NOT NULL;
