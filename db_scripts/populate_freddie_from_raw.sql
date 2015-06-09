INSERT INTO servicers (name)
SELECT DISTINCT servicer_name FROM loans_raw_freddie
WHERE servicer_name IS NOT NULL
AND servicer_name NOT IN (SELECT name FROM servicers WHERE name IS NOT NULL);

INSERT INTO servicers (name)
SELECT DISTINCT seller_name FROM loans_raw_freddie
WHERE seller_name IS NOT NULL
AND seller_name NOT IN (SELECT name FROM servicers WHERE name IS NOT NULL);

INSERT INTO loans
  (agency, credit_score, first_payment_date, first_time_homebuyer_flag, maturity_date, msa, mip, number_of_units, 
    occupancy_status, ocltv, dti, original_upb, oltv, original_interest_rate, channel, prepayment_penalty_flag, 
    product_type, property_state, property_type, postal_code, loan_sequence_number, loan_purpose, 
    original_loan_term, number_of_borrowers, seller_id, servicer_id, vintage, hpi_index_id, hpi_at_origination,
    final_zero_balance_code, final_zero_balance_date, first_serious_dq_date, sato,
    net_sales_proceeds, mi_recoveries, non_mi_recoveries, expenses)
SELECT
  1, -- freddie = 1
  NULLIF(credit_score, '')::integer,
  (first_payment_date || '01')::date,
  first_time_homebuyer_flag,
  (maturity_date || '01')::date,
  msa,
  NULLIF(mip, '')::integer,
  number_of_units, occupancy_status, ocltv,
  NULLIF(dti, '')::integer,
  original_upb, oltv, original_interest_rate,
  channel, prepayment_penalty_flag, product_type, property_state, property_type,
  NULLIF(postal_code, '')::integer,
  l.loan_sequence_number, loan_purpose, original_loan_term, number_of_borrowers,
  sel.id, ser.id,
  EXTRACT('year' FROM (first_payment_date || '01')::date),
  COALESCE(COALESCE(hpi_msa.id, hpi_state.id), 0),
  hpi.hpi,
  NULLIF(mz.zero_balance_code, '')::integer,
  (mz.zero_balance_effective_date || '01')::date,
  (md.first_serious_dq_date || '01')::date,
  original_interest_rate - rates.zero_point_rate,
  (CASE WHEN mz.net_sales_proceeds NOT IN ('C', 'U') THEN mz.net_sales_proceeds END)::integer,
  mz.mi_recoveries,
  mz.non_mi_recoveries,
  mz.expenses
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
  LEFT JOIN (SELECT
               loan_sequence_number,
               reporting_period,
               zero_balance_code,
               zero_balance_effective_date,
               net_sales_proceeds,
               mi_recoveries,
               non_mi_recoveries,
               expenses,
               ROW_NUMBER() OVER (PARTITION BY loan_sequence_number ORDER BY reporting_period ASC) AS row_num
             FROM monthly_observations_raw_freddie
             WHERE zero_balance_code IS NOT NULL) mz
    ON l.loan_sequence_number = mz.loan_sequence_number
    AND mz.row_num = 1
  LEFT JOIN (SELECT
               loan_sequence_number,
               MIN(reporting_period) AS first_serious_dq_date
             FROM monthly_observations_raw_freddie
             WHERE dq_status NOT IN ('0', '1')
             GROUP BY loan_sequence_number) md
    ON l.loan_sequence_number = md.loan_sequence_number;

INSERT INTO monthly_observations
SELECT
  l.id,
  (m.reporting_period || '01')::date,
  COALESCE(m.current_upb, l.original_upb),
  m_prev.current_upb AS previous_upb,
  NULLIF(CASE WHEN m.dq_status = 'R' THEN '999' ELSE m.dq_status END, '')::integer,
  NULLIF(CASE WHEN m_prev.dq_status = 'R' THEN '999' ELSE m_prev.dq_status END, '')::integer AS previous_dq_status,
  m.loan_age,
  m.rmm,
  m.repurchase_flag,
  m.modification_flag,
  NULLIF(m.zero_balance_code, '')::integer,
  (m.zero_balance_effective_date || '01')::date,
  m.current_interest_rate
FROM
  monthly_observations_raw_freddie m
    INNER JOIN loans l
      ON m.loan_sequence_number = l.loan_sequence_number
      AND l.agency = 1
    LEFT JOIN monthly_observations_raw_freddie m_prev
      ON m.loan_sequence_number = m_prev.loan_sequence_number
        AND (m.reporting_period || '01')::date = ((m_prev.reporting_period || '01')::date + interval '1 month')::date;

TRUNCATE TABLE loans_raw_freddie;
TRUNCATE TABLE monthly_observations_raw_freddie;
