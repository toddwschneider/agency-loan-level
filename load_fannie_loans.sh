#!/bin/bash

yq_regex="([0-9]{4})Q([0-9])$"

# download raw data from fannie mae's website:
# http://www.fanniemae.com/portal/funding-the-market/data/loan-performance-data.html

for directory in data/fannie/????Q?; do
  [[ $directory =~ $yq_regex ]]
  year=${BASH_REMATCH[1]}
  quarter=${BASH_REMATCH[2]}

  fannie_loans_file="${directory}/Acquisition_${year}Q${quarter}.txt"
  fannie_monthly_file="${directory}/Performance_${year}Q${quarter}.txt"

  echo "`date`: loading loans file ${fannie_loans_file}"
  cat ${fannie_loans_file} | psql agency-loan-level -c "COPY loans_raw_fannie FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: loading monthly file ${fannie_monthly_file}"
  cat ${fannie_monthly_file} | psql agency-loan-level -c "SET datestyle = 'ISO, MDY'; COPY monthly_observations_raw_fannie FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: populating Fannie Mae ${year} Q${quarter}"
  psql agency-loan-level -f db_scripts/populate_fannie_from_raw.sql
  echo "`date`: done Fannie Mae ${year} Q${quarter}"
done;

fannie_mapping_file="data/fannie/HARP_Files/Loan_Mapping.txt"

if [ -f $fannie_mapping_file ]; then
  echo "`date`: loading Fannie HARP mapping"
  cat ${fannie_mapping_file} | psql agency-loan-level -c "COPY fannie_harp_mapping FROM stdin CSV"

  fannie_loans_file="data/fannie/HARP_Files/Acquisition_HARP.txt"
  fannie_monthly_file="data/fannie/HARP_Files/Performance_HARP.txt"

  echo "`date`: loading HARP loans file ${fannie_loans_file}"
  cat ${fannie_loans_file} | psql agency-loan-level -c "COPY loans_raw_fannie FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: loading HARP monthly file ${fannie_monthly_file}"
  cat ${fannie_monthly_file} | psql agency-loan-level -c "SET datestyle = 'ISO, MDY'; COPY monthly_observations_raw_fannie FROM stdin DELIMITER '|' NULL '';"

  echo "`date`: populating Fannie Mae HARP"
  psql agency-loan-level -f db_scripts/populate_fannie_from_raw.sql
  echo "`date`: done Fannie Mae HARP"
else
  echo "Fannie HARP data not found; skipping"
fi
