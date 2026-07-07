# ===========================================================
# SNOWFLAKE PRACTICE - SNOWPARK (PYTHON DATAFRAME API)
# Table under test: driver_lifetime_trips
# Goal: show the same operations as 1st_Practice.sql (filter,
# group by, aggregate, window functions) expressed through
# Snowpark's DataFrame API instead of raw SQL text - the
# building block for writing data pipelines in Python that
# still push all computation down into Snowflake's engine.
# ===========================================================
#
# Snowpark files in Snowsight run on a small personal compute
# service (SYSTEM_COMPUTE_POOL_CPU) - separate from the SQL
# warehouse, but get_active_session() below still routes actual
# table reads/writes through the warehouse, exactly like a SQL
# worksheet would.

# -----------------------------------------------------------
# SETUP - get the active Snowpark session (no connection string,
# no credentials - same session you are already logged in as)
# -----------------------------------------------------------
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col, avg, count, sum as sum_, rank
from snowflake.snowpark import Window

session = get_active_session()

TABLE = "SNOWFLAKE_LEARNING_DB.EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3.DRIVER_LIFETIME_TRIPS"
trips = session.table(TABLE)

# -----------------------------------------------------------
# PART A - FILTER + GROUP BY + AGGREGATE (DataFrame API)
#
# Use case: the same "trips per city" rollup from
# 4th_Practice_CSV_Upload.sql, but built by chaining DataFrame
# methods instead of writing a SELECT string. Snowpark is lazy -
# none of this runs in Snowflake until an action like .show()
# or .collect() is called; up to that point it is just building
# a query plan.
# -----------------------------------------------------------

city_summary = (
trips
.group_by("CITY_NAME")
.agg(
count("*").alias("TRIP_COUNT"),
avg("TRIP_DISTANCE_MILES").alias("AVG_DISTANCE_MILES"),
sum_("ORIGINAL_FARE_USD").alias("TOTAL_FARE_USD"),
)
.sort(col("TRIP_COUNT").desc())
)

city_summary.show()

# -----------------------------------------------------------
# PART B - WINDOW FUNCTION (Snowpark Window class)
#
# Use case: the Snowpark equivalent of the RANK() OVER (PARTITION
# BY ... ) QUALIFY pattern from 1st_Practice.sql - rank trips
# within each city by fare, without collapsing detail rows.
# -----------------------------------------------------------

city_window = Window.partition_by("CITY_NAME").order_by(col("ORIGINAL_FARE_USD").desc())

ranked_trips = (
trips
.with_column("FARE_RANK_IN_CITY", rank().over(city_window))
.filter(col("FARE_RANK_IN_CITY") <= 3)
.select("CITY_NAME", "ORIGINAL_FARE_USD", "TRIP_DISTANCE_MILES", "FARE_RANK_IN_CITY")
.sort("CITY_NAME", "FARE_RANK_IN_CITY")
)

ranked_trips.show(20)

# -----------------------------------------------------------
# PART C - INSPECT THE GENERATED SQL BEFORE RUNNING IT
#
# Use case: since every DataFrame method call is lazy, you can
# inspect the SQL Snowpark is about to run via .queries - useful
# for debugging or for proving to a reviewer that no client-side
# processing is happening, only pushed-down SQL.
# -----------------------------------------------------------

print(city_summary.queries["queries"][0])

# ===========================================================
# RECAP
# - get_active_session() gives Python code the same Snowflake
# session as the logged-in user - no connection string, no
# separate credentials, same as the Streamlit capstone.
# - Snowpark DataFrames are lazy: filter/group_by/agg/sort just
# build a query plan; only an action (.show(), .collect(),
# .to_pandas()) actually sends SQL to the warehouse.
# - Window functions in Snowpark (the Window class + .over())
# are the direct equivalent of SQL's RANK() OVER (PARTITION BY
# ... ) QUALIFY pattern from 1st_Practice.sql - same engine,
# different syntax.
# - .queries lets you see the exact SQL Snowpark generated -
# there is no hidden client-side computation, everything still
# runs inside Snowflake.
# ===========================================================
