/* ===========================================================
SNOWFLAKE PRACTICE - STREAMS AND TASKS (CHANGE DATA CAPTURE +
AUTOMATION)
Table under test: driver_lifetime_trips (loaded in
4th_Practice_CSV_Upload.sql)
Goal: capture row-level changes automatically and process them
on a schedule/trigger - the building block behind every
incremental (non-full-refresh) pipeline in Snowflake.
=========================================================== */

-- -----------------------------------------------------------
-- SETUP - restore session context (role / warehouse / db / schema)
-- -----------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

/* ===========================================================
PART A - CREATE A STREAM (the change-tracking object)

Use case: a Stream does not store data itself - it is a pointer
plus metadata that tells Snowflake "give me every row that
changed in this table since I last read from you." Querying a
stream is just a SELECT; it does not consume anything until that
query runs inside a DML statement (INSERT/MERGE reading from it).
=========================================================== */

CREATE OR REPLACE STREAM trips_stream ON TABLE driver_lifetime_trips;

-- sanity check: a brand-new stream is empty (nothing changed yet)
SELECT COUNT(*) AS pending_changes FROM trips_stream; -- expected: 0

/* ===========================================================
PART B - GENERATE SOME CHANGES AND INSPECT THE STREAM

Use case: simulate new trips arriving - this is what a real
ingestion job (the S3 COPY INTO from 2nd_Practice, or the CSV
upload from 4th_Practice) would do continuously in production.
=========================================================== */

INSERT INTO driver_lifetime_trips (city_name, trip_distance_miles, original_fare_usd)
VALUES
('Los Angeles', 5.20, 18.50),
('San Diego', 3.10, 11.00);

-- the stream now shows exactly the 2 new rows, plus metadata
-- columns describing what kind of change happened
SELECT city_name, trip_distance_miles, original_fare_usd,
METADATA$ACTION, METADATA$ISUPDATE
FROM trips_stream;

/* ===========================================================
PART C - CONSUME THE STREAM WITH A TASK

Use case: a Task is scheduled/triggered SQL - the same role a
cron job or an Airflow DAG plays outside of Snowflake, but native
and running on your own warehouse. Reading FROM a stream inside
the task's SQL is what marks those rows as consumed - the stream
only advances its pointer when a DML statement actually reads
from it.
=========================================================== */

CREATE OR REPLACE TABLE trips_change_log (
city_name VARCHAR,
trip_distance_miles NUMBER,
original_fare_usd NUMBER,
change_type VARCHAR,
logged_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TASK log_trip_changes_task
WAREHOUSE = COMPUTE_WH
SCHEDULE = '1440 MINUTE'
WHEN SYSTEM$STREAM_HAS_DATA('trips_stream')
AS
INSERT INTO trips_change_log (city_name, trip_distance_miles, original_fare_usd, change_type)
SELECT city_name, trip_distance_miles, original_fare_usd, METADATA$ACTION
FROM trips_stream;

-- tasks are created SUSPENDED by default - run it once manually
-- instead of resuming it on a schedule (no reason to burn credits
-- for a demo with no continuous stream of new data)
EXECUTE TASK log_trip_changes_task;

-- confirm the change log picked up the rows, and the stream is
-- now empty again (fully consumed by the task's INSERT)
SELECT * FROM trips_change_log;
SELECT COUNT(*) AS pending_changes FROM trips_stream; -- expected: 0

/* ===========================================================
CLEANUP - this task is a one-off demo, not meant to run forever,
so make sure it stays suspended
=========================================================== */
ALTER TASK log_trip_changes_task SUSPEND;

/* ===========================================================
RECAP
- Stream = CDC log for a table: every INSERT/UPDATE/DELETE since
the last consuming read shows up with METADATA$ACTION.
- A stream is only "consumed" (pointer advances) when a DML
statement (INSERT/MERGE/CREATE TABLE AS) actually reads from it
- a plain SELECT for inspection does NOT consume it.
- Task = scheduled or stream-triggered SQL execution - the native
equivalent of a cron job/Airflow DAG, running on a warehouse you
already control.
- Stream + Task together = the standard Snowflake pattern for
incremental pipelines: land raw data -> stream captures what
changed -> task processes just the delta, not a full rescan.
- Tasks are created SUSPENDED; RESUME only when you actually want
it running on a real schedule - here it was executed once
manually and re-suspended to avoid ongoing warehouse usage after
the practice session ends.
=========================================================== */
