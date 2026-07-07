# Snowflake A-Z

Hands-on Snowflake practice covering SQL fundamentals, data ingestion, disaster-recovery mechanics, automation, access control, and a native Streamlit dashboard - built during a 30-day Snowflake trial.

[![Lint](https://github.com/evgeniimatveev/Snowflake-A-Z/actions/workflows/lint.yml/badge.svg)](https://github.com/evgeniimatveev/Snowflake-A-Z/actions/workflows/lint.yml)
![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-FF4B4B?style=for-the-badge&logo=streamlit&logoColor=white)

## Why this repo has no live demo

This was a deliberate 30-day / $400-credit Snowflake trial used purely to learn the platform - not a production account kept running indefinitely. Every script here was executed for real against a live Snowflake account and verified before being committed. Once the trial period ends the account is not renewed, so there is no persistent hosted dashboard to link to - the code and the verified results captured along the way are the proof of work.

## What's covered

| # | File | Topic | Verified result |
|---|------|-------|------------------|
| 1 | [`1st_Practice.sql`](1st_Practice.sql) | SQL basics: filter, join, aggregate, CTE, window functions | 7 queries against TPCH_SF1 sample data (customer/orders/nation) |
| 2 | [`2nd_Practice_S3_Ingestion.sql`](2nd_Practice_S3_Ingestion.sql) | External stage + `COPY INTO` from S3, semi-structured data (`VARIANT`, `LATERAL FLATTEN`) | 100 rows loaded from a public S3 bucket, 0 errors |
| 3 | [`3rd_Practice_TimeTravel_Clone.sql`](3rd_Practice_TimeTravel_Clone.sql) | Time Travel, DROP + UNDROP, zero-copy clone | Restored deleted rows via `AT(OFFSET)`, undropped a table, proved clone independence (90 vs 100 rows) |
| 4 | [`4th_Practice_CSV_Upload.sql`](4th_Practice_CSV_Upload.sql) | Local CSV upload wizard (UI path, not `COPY INTO`) | 3,745 real rows loaded from a personal Uber-trips dataset |
| 5 | [`5th_Practice_Streamlit_Capstone.py`](5th_Practice_Streamlit_Capstone.py) | Native Streamlit-in-Snowflake app build/deploy process | Interactive dashboard built and deployed (see below) |
| 6 | [`6th_Practice_Streams_Tasks.sql`](6th_Practice_Streams_Tasks.sql) | Streams (CDC) + Tasks (scheduled/triggered automation) | Stream captured 2 inserted rows, a task moved them into a change log, stream drained to 0 |
| 7 | [`7th_Practice_RBAC.sql`](7th_Practice_RBAC.sql) | Role-based access control, least privilege | Custom read-only role: `SELECT` succeeded, `INSERT` correctly rejected |

The Streamlit dashboard's actual application code lives in [`streamlit_app/streamlit_app.py`](streamlit_app/streamlit_app.py).

## Dashboard

Built on `driver_lifetime_trips` (3,745 rows, loaded in practice 4): a city filter drives three KPI metrics and two bar charts, backed entirely by `st.connection("snowflake").session().sql(...)` - no external database, no separate auth.

- **All cities:** 3,745 trips · $71,508.53 total fare · 11.52 mi avg distance
- **Filtered to Los Angeles:** 2,155 trips · $42,547.87 · 8.08 mi
- **Filtered to Ventura:** 6 trips · $82.48 · 5.63 mi

## Stack

- Snowflake (Standard Edition, AWS us-east-2)
- SQL (Snowflake dialect)
- Python + Streamlit (native Streamlit-in-Snowflake)
- pandas

## Naming convention

Files are numbered in the order they were completed, each following the same lecture format: a header banner explaining the goal, a `SETUP` block restoring session context, lettered `PART` sections with a "Use case" explanation before every query, and a `RECAP` at the end summarizing the takeaways.
