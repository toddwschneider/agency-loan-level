INSERT INTO servicers (name)
SELECT DISTINCT servicer_name FROM loans_raw_freddie
WHERE servicer_name IS NOT NULL
AND servicer_name NOT IN (SELECT name FROM servicers WHERE name IS NOT NULL);

INSERT INTO servicers (name)
SELECT DISTINCT seller_name FROM loans_raw_freddie
WHERE seller_name IS NOT NULL
AND seller_name NOT IN (SELECT name FROM servicers WHERE name IS NOT NULL);

CREATE TABLE tmp_months_with_zero_balance_code AS
SELECT
  loan_sequence_number,
  reporting_period,
  NULLIF(trim(zero_balance_code), '')::integer AS zero_balance_code,
  (zero_balance_effective_date || '01')::date AS zero_balance_effective_date,
  (ddlpi || '01')::date AS ddlpi,
  mi_recoveries,
  net_sales_proceeds,
  non_mi_recoveries,
  expenses,
  legal_costs,
  maintenance_costs,
  taxes_and_insurance,
  miscellaneous_expenses,
  actual_loss_calculation,
  modification_cost,
  ROW_NUMBER() OVER (PARTITION BY loan_sequence_number ORDER BY reporting_period ASC) AS row_num
FROM monthly_observations_raw_freddie
WHERE zero_balance_code IS NOT NULL;
CREATE INDEX idx_mz ON tmp_months_with_zero_balance_code (loan_sequence_number);

CREATE TABLE tmp_months_with_dq_status AS
SELECT
  loan_sequence_number,
  MIN(reporting_period) AS first_serious_dq_date
FROM monthly_observations_raw_freddie
WHERE dq_status NOT IN ('0', '1')
GROUP BY loan_sequence_number;

INSERT INTO loans (
  agency_id, credit_score, first_payment_date, first_time_homebuyer_flag,
  maturity_date, msa, mip, number_of_units, occupancy_status, ocltv, dti,
  original_upb, oltv, original_interest_rate, channel, prepayment_penalty_flag,
  product_type, property_state, property_type, postal_code,
  loan_sequence_number, loan_purpose, original_loan_term, number_of_borrowers,
  seller_id, servicer_id, super_conforming_flag, vintage, hpi_index_id,
  hpi_at_origination, final_zero_balance_code, final_zero_balance_date,
  first_serious_dq_date, sato, pre_harp_loan_sequence_number
)
SELECT
  (SELECT id FROM agencies WHERE name = 'Freddie Mac'),
  NULLIF(trim(credit_score), '')::integer,
  (first_payment_date || '01')::date,
  first_time_homebuyer_flag,
  (maturity_date || '01')::date,
  msa,
  NULLIF(trim(mip), '')::integer,
  number_of_units,
  occupancy_status,
  ocltv,
  NULLIF(trim(dti), '')::integer,
  original_upb,
  oltv,
  original_interest_rate,
  channel,
  prepayment_penalty_flag,
  product_type,
  property_state,
  property_type,
  NULLIF(trim(postal_code), '')::integer,
  l.loan_sequence_number,
  loan_purpose,
  original_loan_term,
  number_of_borrowers,
  sel.id,
  ser.id,
  l.super_conforming_flag,
  EXTRACT('year' FROM (first_payment_date || '01')::date),
  COALESCE(COALESCE(hpi_msa.id, hpi_state.id), 0),
  hpi.hpi,
  mz.zero_balance_code,
  mz.zero_balance_effective_date,
  md.first_serious_dq_date,
  original_interest_rate - (CASE WHEN original_loan_term <= 180
                            THEN rates.zero_point_rate_15_year
                            ELSE rates.zero_point_rate_30_year
                            END),
  pre_harp_loan_sequence_number
FROM loans_raw_freddie l
  LEFT JOIN servicers sel
    ON l.seller_name = sel.name
  LEFT JOIN servicers ser
    ON l.servicer_name = ser.name
  LEFT JOIN hpi_indexes hpi_msa
    ON l.msa = hpi_msa.id AND ((first_payment_date || '01')::date - interval '1 month') > hpi_msa.first_date
  LEFT JOIN hpi_indexes hpi_state
    ON l.property_state = hpi_state.name
  LEFT JOIN hpi_values hpi
    ON hpi.hpi_index_id = COALESCE(COALESCE(hpi_msa.id, hpi_state.id), 0)
    AND hpi.date = ((first_payment_date || '01')::date - interval '2 months')
  LEFT JOIN mortgage_rates rates
    ON rates.month = ((first_payment_date || '01')::date - interval '2 months')
  LEFT JOIN tmp_months_with_zero_balance_code mz
    ON l.loan_sequence_number = mz.loan_sequence_number
    AND mz.row_num = 1
  LEFT JOIN tmp_months_with_dq_status md
    ON l.loan_sequence_number = md.loan_sequence_number;

INSERT INTO monthly_observations (
  loan_id, date, current_upb, previous_upb, dq_status, previous_dq_status,
  loan_age, rmm, repurchase_flag, modification_flag, zero_balance_code,
  zero_balance_date, current_interest_rate
)
SELECT
  loan_id,
  date,
  current_upb,
  CASE WHEN previous_date IS NULL OR previous_date = date - '1 month'::interval THEN previous_upb END,
  dq_status,
  CASE WHEN previous_date IS NULL OR previous_date = date - '1 month'::interval THEN previous_dq_status END,
  loan_age,
  rmm,
  repurchase_flag,
  modification_flag,
  zero_balance_code,
  zero_balance_date,
  current_interest_rate
FROM (
  SELECT
    l.id AS loan_id,
    m.reporting_period AS date,
    LAG(m.reporting_period, 1) OVER (PARTITION BY l.id ORDER BY m.reporting_period ASC) AS previous_date,
    COALESCE(m.current_upb, l.original_upb) AS current_upb,
    LAG(m.current_upb, 1) OVER (PARTITION BY l.id ORDER BY m.reporting_period ASC) AS previous_upb,
    NULLIF(CASE m.dq_status WHEN 'R' THEN '999' WHEN 'XX' THEN NULL ELSE m.dq_status END, '')::integer AS dq_status,
    LAG(
      NULLIF(CASE m.dq_status WHEN 'R' THEN '999' WHEN 'XX' THEN NULL ELSE m.dq_status END, '')::integer,
      1
    ) OVER (PARTITION BY l.id ORDER BY m.reporting_period ASC) AS previous_dq_status,
    m.loan_age,
    m.rmm,
    m.repurchase_flag,
    m.modification_flag,
    NULLIF(trim(m.zero_balance_code), '')::integer AS zero_balance_code,
    (m.zero_balance_effective_date || '01')::date AS zero_balance_date,
    m.current_interest_rate
  FROM
    monthly_observations_raw_freddie m
      INNER JOIN loans l
        ON m.loan_sequence_number = l.loan_sequence_number
        AND l.agency_id = 1
) subquery;

INSERT INTO zero_balance_monthly_observations (
  loan_id, date, zero_balance_code, zero_balance_date,
  last_paid_installment_date, net_sales_proceeds, mi_recoveries,
  non_mi_recoveries, expenses, legal_costs, maintenance_costs,
  taxes_and_insurance, miscellaneous_expenses, actual_loss_calculation,
  modification_cost
)
SELECT
  l.id,
  t.reporting_period,
  t.zero_balance_code,
  t.zero_balance_effective_date,
  t.ddlpi,
  (CASE WHEN t.net_sales_proceeds NOT IN ('C', 'U') THEN t.net_sales_proceeds END)::integer,
  t.mi_recoveries,
  t.non_mi_recoveries,
  t.expenses,
  t.legal_costs,
  t.maintenance_costs,
  t.taxes_and_insurance,
  t.miscellaneous_expenses,
  t.actual_loss_calculation,
  t.modification_cost
FROM tmp_months_with_zero_balance_code t
  INNER JOIN loans l
    ON t.loan_sequence_number = l.loan_sequence_number
    AND l.agency_id = 1;

DROP TABLE tmp_months_with_zero_balance_code;
DROP TABLE tmp_months_with_dq_status;
TRUNCATE TABLE loans_raw_freddie;
TRUNCATE TABLE monthly_observations_raw_freddie;
