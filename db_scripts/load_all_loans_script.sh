#!/bin/bash

app_dir="/path/to/agency-loan-level/"
freddie_script="db_scripts/populate_freddie_from_raw.sql"
fannie_script="db_scripts/populate_fannie_from_raw.sql"

# download raw data from fannie mae and freddie mac's websites:
# http://www.fanniemae.com/portal/funding-the-market/data/loan-performance-data.html
# http://www.freddiemac.com/news/finance/sf_loanlevel_dataset.html

base_data_dir="/path/to/raw/data/files/"

for y in $(seq 2013 1999)
do
  for q in $(seq 4 1)
  do
    if (($y < 2013 || $q < 4)); then
      echo "`date`: beginning freddie load for $y Q$q"

      freddie_loans_file="freddie/historical_data1_Q$q$y/historical_data1_Q$q$y.txt"
      cat $base_data_dir$freddie_loans_file | psql agency-loan-level -c "COPY loans_raw_freddie FROM stdin DELIMITER '|' NULL '';"
      echo "`date`: loaded freddie raw loans for $y Q$q"

      freddie_monthly_file="freddie/historical_data1_Q$q$y/historical_data1_time_Q$q$y.txt"
      cat $base_data_dir$freddie_monthly_file | psql agency-loan-level -c "COPY monthly_observations_raw_freddie FROM stdin DELIMITER '|' NULL '';"
      echo "`date`: loaded freddie raw monthly observations for $y Q$q"

      psql agency-loan-level -f $app_dir$freddie_script
      echo "`date`: finished freddie loans and monthly observations for $y Q$q"
    fi

    if (($y > 1999)); then
      echo "`date`: beginning fannie load for $y Q$q"

      fannie_loans_file="fannie/Acquisition_$y"
      fannie_loans_file+="Q$q.txt"
      cat $base_data_dir$fannie_loans_file | psql agency-loan-level -c "COPY loans_raw_fannie FROM stdin DELIMITER '|' NULL '';"
      echo "`date`: loaded fannie raw loans for $y Q$q"

      fannie_monthly_file="fannie/Performance_$y"
      fannie_monthly_file+="Q$q.txt"
      cat $base_data_dir$fannie_monthly_file | psql agency-loan-level -c "COPY monthly_observations_raw_fannie FROM stdin DELIMITER '|' NULL '';"
      echo "`date`: loaded fannie raw monthly observations for $y Q$q"

      psql agency-loan-level -f $app_dir$fannie_script
      echo "`date`: finished fannie loans and monthly observations for $y Q$q"
    fi
  done
done;
