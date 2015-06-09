INSERT INTO servicers (name)
SELECT DISTINCT servicer_name FROM monthly_observations_raw_fannie
WHERE servicer_name IS NOT NULL
AND servicer_name NOT IN (SELECT name FROM servicers WHERE name IS NOT NULL);

INSERT INTO servicers (name)
SELECT DISTINCT seller_name FROM loans_raw_fannie
WHERE seller_name IS NOT NULL
AND seller_name NOT IN (SELECT name FROM servicers WHERE name IS NOT NULL);

INSERT INTO loans
  (agency, credit_score, first_payment_date, first_time_homebuyer_flag, maturity_date, msa, mip, number_of_units, 
    occupancy_status, ocltv, dti, original_upb, oltv, original_interest_rate, channel, prepayment_penalty_flag, 
    product_type, property_state, property_type, postal_code, loan_sequence_number, loan_purpose, 
    original_loan_term, number_of_borrowers, seller_id, servicer_id, vintage, hpi_index_id, hpi_at_origination,
    final_zero_balance_code, final_zero_balance_date, first_serious_dq_date, sato,
    co_borrower_credit_score)
SELECT
  0, -- fannie = 0
  credit_score,
  to_date(first_payment_date, 'MM/YYYY'),
  first_time_homebuyer_indicator,
  (to_date(first_payment_date, 'MM/YYYY') + original_loan_term * '1 month'::interval)::date,
  mf.msa,
  mip,
  number_of_units::integer,
  CASE occupancy_status WHEN 'P' THEN 'O' WHEN 'S' THEN 'S' WHEN 'I' THEN 'I' END,
  original_cltv,
  dti,
  original_upb,
  original_ltv,
  original_interest_rate,
  channel,
  'N', -- fannie data excludes loans with prepayment penalty
  product_type,
  property_state,
  property_type,
  (zip_code || '00')::integer,
  l.loan_sequence_number,
  CASE loan_purpose WHEN 'P' THEN 'P' WHEN 'C' THEN 'C' WHEN 'R' THEN 'N' WHEN 'U' THEN 'U' END,
  original_loan_term,
  number_of_borrowers,
  sel.id,
  NULL, -- fannie includes servicer in monthly data
  EXTRACT('year' FROM to_date(first_payment_date, 'MM/YYYY')),
  COALESCE(COALESCE(hpi_msa.id, hpi_state.id), 0),
  hpi.hpi,
  NULLIF(mz.zero_balance_code, '')::integer,
  to_date(mz.zero_balance_date, 'MM/YYYY'),
  to_date(md.first_serious_dq_date, 'MM/DD/YYYY'),
  original_interest_rate - rates.zero_point_rate,
  co_borrower_credit_score
FROM loans_raw_fannie l
  LEFT JOIN servicers sel
    ON l.seller_name = sel.name
  LEFT JOIN (SELECT
               loan_sequence_number,
               servicer_name,
               NULLIF(msa, 0) AS msa,
               ROW_NUMBER() OVER (PARTITION BY loan_sequence_number ORDER BY to_date(reporting_period, 'MM/DD/YYYY') ASC) AS row_num
             FROM monthly_observations_raw_fannie) mf
    ON l.loan_sequence_number = mf.loan_sequence_number
    AND mf.row_num = 1
  LEFT JOIN (SELECT
               loan_sequence_number,
               reporting_period,
               zero_balance_code,
               zero_balance_date,
               ROW_NUMBER() OVER (PARTITION BY loan_sequence_number ORDER BY to_date(reporting_period, 'MM/DD/YYYY') ASC) AS row_num
             FROM monthly_observations_raw_fannie
             WHERE zero_balance_code IS NOT NULL) mz
    ON l.loan_sequence_number = mz.loan_sequence_number
    AND mz.row_num = 1
  LEFT JOIN (SELECT
               loan_sequence_number,
               reporting_period AS first_serious_dq_date,
               ROW_NUMBER() OVER (PARTITION BY loan_sequence_number ORDER BY to_date(reporting_period, 'MM/DD/YYYY') ASC) AS row_num
             FROM monthly_observations_raw_fannie
             WHERE dq_status IN ('2','3','4','5','6')) md
    ON l.loan_sequence_number = md.loan_sequence_number
    AND md.row_num = 1
  LEFT JOIN hpi_indexes hpi_msa
    ON mf.msa = hpi_msa.id AND (to_date(first_payment_date, 'MM/YYYY') - interval '1 month') > hpi_msa.first_date
  LEFT JOIN hpi_indexes hpi_state
    ON l.property_state = hpi_state.name
  LEFT JOIN hpi_values hpi
    ON hpi.hpi_index_id = COALESCE(COALESCE(hpi_msa.id, hpi_state.id), 0)
    AND hpi.date = (to_date(first_payment_date, 'MM/YYYY') - interval '2 months')
  LEFT JOIN mortgage_rates rates
    ON rates.month = (to_date(first_payment_date, 'MM/YYYY') - interval '2 months');

INSERT INTO monthly_observations
SELECT
  l.id,
  to_date(m.reporting_period, 'MM/DD/YYYY'),
  m.current_upb,
  m_prev.current_upb,
  NULLIF(m.dq_status, 'X')::integer,
  NULLIF(m_prev.dq_status, 'X')::integer,
  m.loan_age,
  m.rmm,
  CASE WHEN m.repurchase_date IS NOT NULL THEN 'Y' END,
  m.modification_flag,
  m.zero_balance_code::integer,
  to_date(m.zero_balance_date, 'MM/YYYY'),
  m.current_interest_rate
FROM monthly_observations_raw_fannie m
  INNER JOIN loans l
    ON m.loan_sequence_number = l.loan_sequence_number
    AND l.agency = 0
  LEFT JOIN monthly_observations_raw_fannie m_prev
    ON m.loan_sequence_number = m_prev.loan_sequence_number
    AND to_date(m.reporting_period, 'MM/DD/YYYY') = (to_date(m_prev.reporting_period, 'MM/DD/YYYY') + interval '1 month')::date;

TRUNCATE TABLE loans_raw_fannie;
TRUNCATE TABLE monthly_observations_raw_fannie;
