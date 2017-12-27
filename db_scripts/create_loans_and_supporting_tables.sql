CREATE TABLE loans_raw_freddie (
  credit_score text,
  first_payment_date integer,
  first_time_homebuyer_flag text,
  maturity_date integer,
  msa integer,
  mip text,
  number_of_units integer,
  occupancy_status text,
  ocltv numeric,
  dti text,
  original_upb numeric,
  oltv integer,
  original_interest_rate numeric,
  channel text,
  prepayment_penalty_flag text,
  product_type text,
  property_state text,
  property_type text,
  postal_code text,
  loan_sequence_number text,
  loan_purpose text,
  original_loan_term integer,
  number_of_borrowers integer,
  seller_name text,
  servicer_name text,
  super_conforming_flag text,
  pre_harp_loan_sequence_number text
);

CREATE TABLE loans_raw_fannie (
  loan_sequence_number text,
  channel text,
  seller_name text,
  original_interest_rate numeric,
  original_upb numeric,
  original_loan_term integer,
  origination_date text,
  first_payment_date text,
  original_ltv numeric,
  original_cltv numeric,
  number_of_borrowers integer,
  dti numeric,
  credit_score integer,
  first_time_homebuyer_indicator text,
  loan_purpose text,
  property_type text,
  number_of_units text,
  occupancy_status text,
  property_state text,
  zip_code text,
  mip numeric,
  product_type text,
  co_borrower_credit_score integer,
  mortgage_insurance_type integer,
  relocation_mortgage_indicator text
);

CREATE TABLE loans (
  id serial primary key,
  agency_id integer not null,
  credit_score integer,
  first_payment_date date,
  first_time_homebuyer_flag text,
  maturity_date date,
  msa integer,
  mip integer,
  number_of_units integer,
  occupancy_status text,
  ocltv numeric,
  dti integer,
  original_upb numeric,
  oltv numeric,
  original_interest_rate numeric,
  channel text,
  prepayment_penalty_flag text,
  product_type text,
  property_state text,
  property_type text,
  postal_code integer,
  loan_sequence_number text,
  loan_purpose text,
  original_loan_term integer,
  number_of_borrowers integer,
  seller_id integer,
  servicer_id integer,
  super_conforming_flag text,
  pre_harp_loan_sequence_number text,
  vintage integer,
  hpi_index_id integer,
  hpi_at_origination numeric,
  final_zero_balance_code integer,
  final_zero_balance_date date,
  first_serious_dq_date date,
  sato numeric,
  co_borrower_credit_score integer,
  mortgage_insurance_type integer,
  relocation_mortgage_indicator text
);
CREATE UNIQUE INDEX index_loans_on_seq ON loans (loan_sequence_number, agency_id);

CREATE TABLE fannie_harp_mapping (
  pre_harp_loan_sequence_number text primary key,
  post_harp_loan_sequence_number text
);
CREATE UNIQUE INDEX index_fannie_harp ON fannie_harp_mapping (post_harp_loan_sequence_number);

CREATE TABLE agencies (
  id integer primary key,
  name varchar
);

INSERT INTO agencies
VALUES (0, 'Fannie Mae'), (1, 'Freddie Mac');

CREATE TABLE servicers (
  id serial primary key,
  name text
);
CREATE UNIQUE INDEX index_servicers_on_name ON servicers (name);

CREATE TABLE monthly_observations_raw_freddie (
  loan_sequence_number text,
  reporting_period date,
  current_upb numeric,
  dq_status text,
  loan_age integer,
  rmm integer,
  repurchase_flag text,
  modification_flag text,
  zero_balance_code text,
  zero_balance_effective_date integer,
  current_interest_rate numeric,
  current_deferred_upb numeric,
  ddlpi integer,
  mi_recoveries numeric,
  net_sales_proceeds text,
  non_mi_recoveries numeric,
  expenses numeric,
  legal_costs numeric,
  maintenance_costs numeric,
  taxes_and_insurance numeric,
  miscellaneous_expenses numeric,
  actual_loss_calculation numeric,
  modification_cost numeric
);

CREATE TABLE monthly_observations_raw_fannie (
  loan_sequence_number text,
  reporting_period date,
  servicer_name text,
  current_interest_rate numeric,
  current_upb numeric,
  loan_age integer,
  rmm integer,
  adjusted_rmm integer,
  maturity_date text,
  msa integer,
  dq_status text,
  modification_flag text,
  zero_balance_code text,
  zero_balance_date text,
  last_paid_installment_date date,
  foreclosure_date date,
  disposition_date date,
  foreclosure_costs numeric,
  preservation_and_repair_costs numeric,
  asset_recovery_costs numeric,
  miscellaneous_expenses numeric,
  associated_taxes numeric,
  net_sale_proceeds numeric,
  credit_enhancement_proceeds numeric,
  repurchase_make_whole_proceeds numeric,
  other_foreclosure_proceeds numeric,
  non_interest_bearing_upb numeric,
  principal_forgiveness_upb numeric,
  repurchase_make_whole_proceeds_flag text,
  foreclosure_principal_write_off_amount numeric,
  servicing_activity_indicator text
);

CREATE TABLE monthly_observations (
  loan_id integer not null,
  date date not null,
  current_upb numeric,
  previous_upb numeric,
  dq_status integer,
  previous_dq_status integer,
  loan_age integer,
  rmm integer,
  repurchase_flag text,
  modification_flag text,
  zero_balance_code integer,
  zero_balance_date date,
  current_interest_rate numeric
);

CREATE TABLE zero_balance_monthly_observations (
  loan_id integer not null,
  date date not null,
  zero_balance_code integer,
  zero_balance_date date,
  last_paid_installment_date date,
  mi_recoveries numeric,
  net_sales_proceeds numeric,
  non_mi_recoveries numeric,
  expenses numeric,
  legal_costs numeric,
  maintenance_costs numeric,
  taxes_and_insurance numeric,
  miscellaneous_expenses numeric,
  actual_loss_calculation numeric,
  modification_cost numeric,
  foreclosure_date date,
  disposition_date date,
  foreclosure_costs numeric,
  preservation_and_repair_costs numeric,
  asset_recovery_costs numeric,
  associated_taxes numeric,
  net_sale_proceeds numeric,
  credit_enhancement_proceeds numeric,
  repurchase_make_whole_proceeds numeric,
  other_foreclosure_proceeds numeric,
  non_interest_bearing_upb numeric,
  principal_forgiveness_upb numeric,
  repurchase_make_whole_proceeds_flag text,
  foreclosure_principal_write_off_amount numeric,
  servicing_activity_indicator text
);

CREATE VIEW loan_monthly AS
SELECT
  l.*,
  m.loan_id, m.date, m.current_upb, m.previous_upb, m.dq_status, m.previous_dq_status,
  m.loan_age, m.rmm, m.repurchase_flag, m.modification_flag, m.current_interest_rate, m.zero_balance_code,
  COALESCE(m.current_upb, l.original_upb) AS current_weight,
  COALESCE(m.previous_upb, l.original_upb) AS previous_weight
FROM loans l
  INNER JOIN monthly_observations m
    ON l.id = m.loan_id;

CREATE OR REPLACE FUNCTION cpr(numeric) RETURNS numeric
  AS 'SELECT (1.0 - pow(1.0 - $1, 12)) * 100;'
  LANGUAGE SQL
  IMMUTABLE
  RETURNS NULL ON NULL INPUT;

CREATE TABLE hpi_indexes (
  id integer primary key,
  name varchar not null,
  type varchar not null,
  first_date date not null
);

CREATE TABLE hpi_values (
  hpi_index_id integer not null,
  date date not null,
  hpi numeric not null,
  primary key (hpi_index_id, date)
);

CREATE TABLE mortgage_rates (
  month date primary key,
  rate_30_year numeric,
  points_30_year numeric,
  zero_point_rate_30_year numeric,
  rate_15_year numeric,
  points_15_year numeric,
  zero_point_rate_15_year numeric
);

CREATE TABLE raw_msa_county_mappings (
  cbsa_code integer,
  msad_code integer,
  csa_code integer,
  cbsa_name varchar,
  msa_type varchar,
  msad_name varchar,
  csa_name varchar,
  county varchar,
  state varchar,
  state_fips integer,
  county_fips integer,
  county_type varchar,
  state_abbreviation varchar
);
CREATE UNIQUE INDEX idx_raw_msa_mapping ON raw_msa_county_mappings (cbsa_code, msad_code, state_fips, county_fips);
