# Create a PostgreSQL database with loan-level data from Fannie Mae and Freddie Mac

Scripts used in support of this post: [Mortgages Are About Math: Open-Source Loan-Level Analysis of Fannie and Freddie](http://toddwschneider.com/posts/mortgages-are-about-math-open-source-loan-level-analysis-of-fannie-and-freddie/)

## Usage

0. Make sure you have [PostgreSQL](http://www.postgresql.org/download/) installed locally. If you want to use R, [install it too](http://cran.rstudio.com/)
1. Download data from [Fannie Mae](http://www.fanniemae.com/portal/funding-the-market/data/loan-performance-data.html) and/or [Freddie Mac](http://www.freddiemac.com/news/finance/sf_loanlevel_dataset.html) and unzip all files into a directory with `fannie/` and `freddie/` subdirectories
2. Make sure to update the proper `/path/to/` paths in `initialize_database.sh`, `create_loans_and_supporting_tables.sql`, and `load_all_loans_script.sh`
3. `./initialize_database.sh` creates a Postgres database called `agency-loan-level`, creates some tables, and imports supporting data including [FHFA home price data](http://www.fhfa.gov/DataTools/Downloads/Pages/House-Price-Index.aspx) and [Freddie Mac mortgage rate data](http://www.freddiemac.com/pmms/)
4. `./db_scripts/load_all_loans.sh` to import the data files. This might take a very long time (~2 days), so you could consider loading the data in chunks. The total database takes up around 215 GB on disk

## Analysis

The `analysis/` folder has additional SQL and R scripts used to analyze the data, see more in [the full post](http://toddwschneider.com/posts/mortgages-are-about-math-open-source-loan-level-analysis-of-fannie-and-freddie/)
