#!/bin/bash

app_dir="/path/to/agency-loan-level/"
base_script="db_scripts/create_loans_and_supporting_tables.sql"

createdb agency-loan-level

psql agency-loan-level -f $app_dir$base_script
