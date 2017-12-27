# Create a PostgreSQL database with loan-level data from Fannie Mae and Freddie Mac

Scripts used in support of this post: [Mortgages Are About Math: Open-Source Loan-Level Analysis of Fannie and Freddie](http://toddwschneider.com/posts/mortgages-are-about-math-open-source-loan-level-analysis-of-fannie-and-freddie/)

## Usage

0. Make sure you have [PostgreSQL](https://www.postgresql.org/download/) installed locally. If you want to use R, [install it too](https://cran.rstudio.com/)
1. Download data from [Fannie Mae](http://www.fanniemae.com/portal/funding-the-market/data/loan-performance-data.html) and/or [Freddie Mac](http://www.freddiemac.com/news/finance/sf_loanlevel_dataset.html) and unzip all files into the `data/fannie/` and `data/freddie/` subdirectories
2. `./initialize_database.sh` creates a Postgres database called `agency-loan-level`, creates some tables, and imports supporting data including [FHFA home price data](https://www.fhfa.gov/DataTools/Downloads/Pages/House-Price-Index.aspx) and [Freddie Mac mortgage rate data](http://www.freddiemac.com/pmms/)
3. `./load_fannie_loans.sh` and `./load_freddie_loans.sh` import data for Fannie and Freddie, respectively. This might take a very long time (~2 days), so you could consider loading the data in chunks

## Analysis

The `analysis/` folder has additional SQL and R scripts used to analyze the data, see more in [the full post](http://toddwschneider.com/posts/mortgages-are-about-math-open-source-loan-level-analysis-of-fannie-and-freddie/)
