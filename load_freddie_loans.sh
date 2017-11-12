#!/bin/bash

yq_regex="_Q([0-9])([0-9]{4})$"

non_harp_schema="credit_score,first_payment_date,first_time_homebuyer_flag,maturity_date,msa,mip,number_of_units,occupancy_status,ocltv,dti,original_upb,oltv,original_interest_rate,channel,prepayment_penalty_flag,product_type,property_state,property_type,postal_code,loan_sequence_number,loan_purpose,original_loan_term,number_of_borrowers,seller_name,servicer_name,super_conforming_flag"

harp_schema="${non_harp_schema},pre_harp_loan_sequence_number"

# download raw data from freddie mac's websites:
# http://www.freddiemac.com/news/finance/sf_loanlevel_dataset.html

for directory in data/freddie/historical_data1_Q?????; do
  [[ $directory =~ $yq_regex ]]
  quarter=${BASH_REMATCH[1]}
  year=${BASH_REMATCH[2]}

  freddie_loans_file="${directory}/historical_data1_Q${quarter}${year}.txt"
  freddie_monthly_file="${directory}/historical_data1_time_Q${quarter}${year}.txt"

  echo "`date`: loading loans file ${freddie_loans_file}"
  cat ${freddie_loans_file} | psql agency-loan-level -c "COPY loans_raw_freddie (${non_harp_schema}) FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: loading monthly file ${freddie_monthly_file}"
  sed -E 's/^.{19}/&01/' ${freddie_monthly_file} | psql agency-loan-level -c "COPY monthly_observations_raw_freddie FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: populating Freddie Mac ${year} Q${quarter}"
  psql agency-loan-level -f db_scripts/populate_freddie_from_raw.sql
  echo "`date`: done Freddie Mac ${year} Q${quarter}"
done;

freddie_harp_loans_file="data/freddie/harp_historical_data1/harp_historical_data1.txt"

if [ -f $freddie_harp_loans_file ]; then
  freddie_harp_monthly_file="data/freddie/harp_historical_data1/harp_historical_data1_time.txt"

  echo "`date`: loading HARP loans file ${freddie_harp_loans_file}"
  cat ${freddie_harp_loans_file} | psql agency-loan-level -c "COPY loans_raw_freddie (${harp_schema}) FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: loading HARP monthly file ${freddie_harp_monthly_file}"
  sed -E 's/^.{19}/&01/' ${freddie_harp_monthly_file} | psql agency-loan-level -c "COPY monthly_observations_raw_freddie FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: populating Freddie Mac HARP"
  psql agency-loan-level -f db_scripts/populate_freddie_from_raw.sql
  echo "`date`: done Freddie Mac HARP"
else
   echo "Freddie HARP data not found; skipping"
fi
