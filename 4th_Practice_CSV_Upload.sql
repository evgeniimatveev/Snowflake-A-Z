/* ===========================================================
SNOWFLAKE PRACTICE - LOADING LOCAL FILES (UI UPLOAD WIZARD)
Dataset: driver_lifetime_trips.csv (Uber portfolio project)
Goal: practice the "Upload local files" ingestion path in
Snowsight - the counterpart to the external S3 stage path
already covered in 2nd_Practice_S3_Ingestion.sql
=========================================================== */

-- -----------------------------------------------------------
-- SETUP - restore session context (role / warehouse / db / schema)
-- -----------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

/* ===========================================================
PART A - THE "UPLOAD LOCAL FILES" WIZARD (done in the UI,
not SQL - this block documents exactly what was clicked so
the steps can be repeated without re-figuring them out)

Use case: the file lives on your own machine, not in an S3
bucket or any external stage. Snowsight's upload wizard skips
writing CREATE TABLE and COPY INTO by hand - it infers the
schema from the file and loads it in one pass.

Steps followed this session:

1. Snowsight Home -> Quick actions -> "Upload local files"
(also reachable from Data -> a schema -> the "Create"
button -> "Table" -> "From File")

2. In the "Load Data into Table" dialog, click Browse (or
drag-and-drop) - this opens the normal Windows file picker,
not a Snowflake screen. Navigate it like Explorer: either
paste the full path in the picker's address bar, or click
through the folders one by one:
C:\Users\GAMING\uber-driver-analytics\data\driver_lifetime_trips.csv
Users -> GAMING -> uber-driver-analytics -> data -> select
the .csv file -> Open.

3. Back in the wizard, pick the destination under "Select or
create a database and schema": clicked the dropdown (not the
"+ Database" button, which creates a brand new one) and chose
the existing SNOWFLAKE_LEARNING_DB . EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3
(same schema as the S3 practice - just reusing an existing
schema, not a requirement).

4. Under "Select or create a table", left it on "Create new
table" and typed the table name: driver_lifetime_trips

5. Next screen ("Edit Schema") shows Snowflake's auto-detected
73 columns with inferred data types (VARCHAR / NUMBER /
BOOLEAN / TIMESTAMP_NTZ), built by sampling the file. Reviewed
them and left the defaults - a couple of always-empty columns
(credits_local, credits_usd) got inferred as VARCHAR instead of
NUMBER since every sampled value was null, which is harmless
for this practice.

6. Clicked "Load" -> the wizard ran the equivalent of CREATE
TABLE + COPY INTO behind the scenes and reported:
"3,745 rows were successfully inserted into the table."
=========================================================== */

-- sanity check: confirm the table exists and see its shape
DESCRIBE TABLE driver_lifetime_trips;

/* ===========================================================
PART B - VERIFY THE LOAD WITH SQL

Use case: never trust a UI success message blindly - the
Database Explorer's row/byte counters can lag behind reality
(metadata cache updates asynchronously), so confirm with a
real query instead of the catalog screen.
=========================================================== */

-- row count must match the wizard's reported insert count
SELECT COUNT(*) AS row_count
FROM driver_lifetime_trips; -- expected: 3745

-- peek at a sample of rows to confirm columns/values look right
SELECT *
FROM driver_lifetime_trips
LIMIT 10;

-- quick aggregate: confirm the data is sensible, not just present
SELECT
city_name,
COUNT(*) AS trip_count,
ROUND(AVG(trip_distance_miles), 2) AS avg_distance_miles,
ROUND(SUM(original_fare_usd), 2) AS total_fare_usd
FROM driver_lifetime_trips
GROUP BY city_name
ORDER BY trip_count DESC;

/* ===========================================================
RECAP
- Upload local files (UI wizard) -> best for one-off loads of
files sitting on your own machine; Snowflake infers the
schema and runs CREATE TABLE + COPY INTO for you.
- External stage + COPY INTO (2nd_Practice_S3_Ingestion.sql)
-> better for repeatable/production loads where the file
already lives in cloud storage (S3/Azure/GCS).
- Either path lands data in an ordinary table - once loaded,
Time Travel, cloning, and everything from
3rd_Practice_TimeTravel_Clone.sql apply the same way,
regardless of how the data got in.
=========================================================== */
