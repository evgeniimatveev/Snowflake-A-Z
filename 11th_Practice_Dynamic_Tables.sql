/*==============================================================================
  11th Practice -- Dynamic Tables
  Snowflake-A-Z | Practice 11
  Declarative, incrementally-refreshed pipelines -- a simpler alternative
  to the manual Stream + Task pattern from the 6th practice.
==============================================================================*/

-- SETUP -----------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

/*==============================================================================
  PART A -- Create a Dynamic Table on top of driver_lifetime_trips
==============================================================================*/
-- A Dynamic Table is defined by a query, not by INSERT/MERGE logic like the
-- Task in practice 6 -- Snowflake figures out how to keep it current itself.
CREATE OR REPLACE DYNAMIC TABLE city_trip_rollup_dt
    TARGET_LAG = '1 minute'
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    CITY_NAME,
    COUNT(*)                 AS trip_count,
    SUM(ORIGINAL_FARE_USD)   AS total_fare,
    AVG(TRIP_DISTANCE_MILES) AS avg_distance
FROM driver_lifetime_trips
GROUP BY CITY_NAME;

SELECT * FROM city_trip_rollup_dt ORDER BY trip_count DESC;

-- RESULT: 6 rows, matching the same city rollup numbers seen in earlier
-- practices (LA 2157 trips/$42,584.87, confirming the Dynamic Table's
-- initial full refresh computed the same result a plain SELECT would).

/*==============================================================================
  PART B -- Does it actually auto-refresh when the base table changes?
==============================================================================*/
-- Insert a disposable test city, force a refresh, confirm it shows up.
INSERT INTO driver_lifetime_trips (CITY_NAME, ORIGINAL_FARE_USD, TRIP_DISTANCE_MILES)
SELECT 'Dynamictown', 999.99, 42.0
UNION ALL
SELECT 'Dynamictown', 111.11, 10.0;

-- TARGET_LAG='1 minute' means it would pick this up on its own within a
-- minute, but forcing a manual refresh makes the demo deterministic instead
-- of waiting on a timer.
ALTER DYNAMIC TABLE city_trip_rollup_dt REFRESH;

SELECT * FROM city_trip_rollup_dt WHERE CITY_NAME = 'Dynamictown';

-- RESULT: 2 trips, $1,111.10, 26.0 mi avg -- exactly the inserted rows.
-- The manual REFRESH reported "No new data": the automatic background
-- refresh (driven by TARGET_LAG='1 minute') had already picked up the
-- INSERT by the time this statement ran a few seconds later. The Dynamic
-- Table was current before we even asked -- that's the whole point of it.

-- Clean up the disposable test city.
DELETE FROM driver_lifetime_trips WHERE CITY_NAME = 'Dynamictown';
ALTER DYNAMIC TABLE city_trip_rollup_dt REFRESH;
SELECT * FROM city_trip_rollup_dt WHERE CITY_NAME = 'Dynamictown';
-- RESULT: 0 rows -- the delete propagated through too, confirmed clean.

/*==============================================================================
  PART C -- Inspecting refresh behavior
==============================================================================*/
SHOW DYNAMIC TABLES LIKE 'city_trip_rollup_dt';

SELECT name, state, target_lag_sec, refresh_action, refresh_trigger,
       data_timestamp, refresh_start_time, refresh_end_time
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME => 'city_trip_rollup_dt'
))
ORDER BY refresh_start_time DESC;

-- RESULT: 88 refresh-history rows already logged after ~14 minutes.
-- REFRESH_ACTION: NO_DATA 96.6%, INCREMENTAL 3.4% (our insert + delete).
-- REFRESH_TRIGGER: SCHEDULED 96.6%, MANUAL 2.3%, +1 more.
-- Snowflake checks this Dynamic Table roughly every ~48 seconds (close to
-- the 1-minute TARGET_LAG) regardless of whether the base table changed --
-- most of those checks are cheap "nothing to do" no-ops, but they still
-- count as scheduled activity. A very aggressive TARGET_LAG on a table
-- that rarely changes means lots of no-op checks for no benefit -- the
-- same "match the tool to the actual change rate" lesson as warehouse
-- sizing in practice 9.

-- Suspend it now -- no reason to keep polling every minute on a learning
-- account once the demo is done.
ALTER DYNAMIC TABLE city_trip_rollup_dt SUSPEND;

/*==============================================================================
  RECAP -- 11th Practice
==============================================================================*/
-- 1) A Dynamic Table replaces the Stream + Task pair from practice 6 with a
--    single declarative CREATE ... AS SELECT. Snowflake decides whether a
--    refresh can be INCREMENTAL (cheap, just processes the delta) or needs
--    to be FULL, instead of the developer writing that MERGE logic by hand.
-- 2) TARGET_LAG is a promise, not a guarantee of immediacy -- Snowflake ran
--    a real background refresh on its own schedule and had already applied
--    both our INSERT and our DELETE before a manual REFRESH ran seconds
--    later, which is exactly the point: the table is meant to just stay
--    current without being asked.
-- 3) SHOW DYNAMIC TABLES + INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY
--    is the SQL-native way to inspect one, the same "verify with a query,
--    don't just trust the UI" instinct as practices 9 and 10.
-- 4) Cost angle: most scheduled refresh checks came back NO_DATA (nothing
--    changed) -- a reminder that TARGET_LAG should match how often the
--    source data actually changes, not be set aggressively "just in case."
-- 5) Suspended the table when done, same instinct as resizing the warehouse
--    back down in practice 9 -- a demo object shouldn't keep polling
--    forever on a trial account.
