#!/bin/bash

createdb agency-loan-level

psql agency-loan-level -f db_scripts/create_loans_and_supporting_tables.sql

cat data/hpi_index_codes.txt | psql agency-loan-level -c "COPY hpi_indexes FROM stdin DELIMITER '|' NULL '';"
cat data/interpolated_hpi_values.txt | psql agency-loan-level -c "COPY hpi_values FROM stdin DELIMITER '|' NULL '';"
cat data/pmms.csv | psql agency-loan-level -c "COPY mortgage_rates FROM stdin NULL '' CSV HEADER;"
cat data/msa_county_mapping.csv | psql agency-loan-level -c "COPY raw_msa_county_mappings FROM stdin NULL '' CSV HEADER;"
