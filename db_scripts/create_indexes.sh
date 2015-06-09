#!/bin/bash

echo "`date`: indexing monthly_observations on loan_id"
psql agency-loan-level -c "CREATE INDEX index_monthly_on_loan_id ON monthly_observations (loan_id);"

echo "`date`: indexing monthly_observations on date"
psql agency-loan-level -c "CREATE INDEX index_monthly_on_date ON monthly_observations (date);"

echo "`date`: done"
