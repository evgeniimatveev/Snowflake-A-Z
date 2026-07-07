/*==============================================================================
  9th Practice -- Query Profile & Warehouse Performance
  Snowflake-A-Z | Practice 9 of 10
  Table: SNOWFLAKE_LEARNING_DB.EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3.driver_lifetime_trips
==============================================================================*/

-- SETUP -----------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

/*==============================================================================
  PART A -- Baseline query + reading its own Query Profile
==============================================================================*/
SELECT
    CITY_NAME,
    COUNT(*)                              AS trip_count,
    SUM(ORIGINAL_FARE_USD)                AS total_fare,
    AVG(TRIP_DISTANCE_MILES)              AS avg_distance,
    RANK() OVER (ORDER BY COUNT(*) DESC)  AS city_rank
FROM driver_lifetime_trips
GROUP BY CITY_NAME
ORDER BY trip_count DESC;

-- After running: open "Query Profile" (top-right of the result pane,
-- or Monitoring > Query History > click this query's ID).
--
-- HOW TO READ THE OPERATOR TREE (data flows bottom -> top, like a kitchen line):
--   TableScan [4]      -- read raw rows from driver_lifetime_trips off disk
--   Aggregate [3]      -- do the GROUP BY CITY_NAME + COUNT/SUM math
--   WindowFunction [2] -- compute RANK() OVER (...)
--   Sort [1]           -- apply ORDER BY on the final small result
--   Result [0]         -- hand the finished rows back to the client
-- Each box shows a % of TOTAL EXECUTION TIME spent in that step -- on a slow
-- production query, that %, not the SQL text, tells you where to optimize.
--
-- STATISTICS PANEL (observed this run):
--   Total execution time: 569ms, but "Initialization: 100%" -- almost all
--   of it was Snowflake compiling the query / assigning a warehouse thread,
--   not actually crunching data. On tiny datasets, startup overhead dwarfs
--   real work -- this is expected, not a performance problem.
--   Bytes scanned: 0.15MB | Percentage scanned from cache: 0%
--   Partitions scanned / total: 1 / 1  <-- key finding, see PART C below.

/*==============================================================================
  PART B -- Warehouse size vs. execution time
==============================================================================*/
-- Same heavy query run twice: once on X-Small, once resized to Small.
-- A CROSS JOIN blows the row count up (~3.7k x 3.7k = ~14M pairs) so there
-- is enough real work for warehouse size to actually matter.

-- Run 1: on the default X-Small warehouse
USE WAREHOUSE COMPUTE_WH;
SELECT COUNT(*) AS pair_count, AVG(a.TRIP_DISTANCE_MILES + b.TRIP_DISTANCE_MILES) AS avg_combined_distance
FROM driver_lifetime_trips a
CROSS JOIN driver_lifetime_trips b;

-- Run 2: resize to Small and run the identical query
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'SMALL';
SELECT COUNT(*) AS pair_count, AVG(a.TRIP_DISTANCE_MILES + b.TRIP_DISTANCE_MILES) AS avg_combined_distance
FROM driver_lifetime_trips a
CROSS JOIN driver_lifetime_trips b;

-- Resize back down immediately -- no reason to pay Small rate for a learning account
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'XSMALL';

-- Pull both runs from history and compare warehouse size vs. elapsed time.
-- IMPORTANT gotcha: filter on something unique to the TARGET query
-- (the "avg_combined_distance" alias), not a generic phrase like
-- "CROSS JOIN driver_lifetime_trips" -- once a diagnostic query containing
-- that phrase has run once, it shows up in its OWN future searches too,
-- polluting the comparison. Learned this the hard way this session.
SELECT query_id, warehouse_size, total_elapsed_time AS elapsed_ms, start_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%avg_combined_distance%' AND total_elapsed_time >= 0
ORDER BY start_time ASC;

-- RESULTS OBSERVED (confirmed twice: once via the on-screen result timer,
-- once via this history query):
--   X-Small warehouse: 864ms
--   Small    warehouse: 117ms  -- ~7.4x faster on 2x the compute
-- Small has 2x the servers of X-Small, so ~2x speedup is the textbook
-- expectation; the extra gain here is warm-cache / parallelism overhead
-- effects on this particular join shape -- real workloads vary.
--
-- TWO GOTCHAS hit live while building this:
--   1) Filtering query_history by a generic text phrase can make a query
--      match ITSELF the next time it runs -- even a phrase inside your own
--      SQL COMMENT counts, since query_text captures the raw source verbatim.
--      Fix: filter on something truly unique to the target query, or better,
--      SET QUERY_TAG on the session and filter by that instead.
--   2) A query that just barely finished can show up in QUERY_HISTORY()
--      with a garbage/negative total_elapsed_time for a moment before its
--      stats are fully written -- Snowflake's history metadata is
--      near-real-time, not synchronous. Filter out negative durations
--      or wait a few seconds before trusting a very-recent row.

/*==============================================================================
  PART C -- Partition pruning: does a WHERE filter actually skip data?
==============================================================================*/
-- PART A already showed partitions_scanned = partitions_total = 1 for the
-- unfiltered GROUP BY. Confirm it stays 1/1 even with a selective WHERE.
SELECT COUNT(*)
FROM driver_lifetime_trips
WHERE CITY_NAME = 'Ventura';

-- Check this exact query's SCAN stats (bytes_scanned) via its unique WHERE
-- clause -- note the columns visible in "Query Profile" (Bytes/Partitions
-- scanned) are NOT all exposed by this table function. partitions_scanned
-- and partitions_total simply don't exist as columns here (confirmed by
-- an "invalid identifier" error while building this) -- they're only
-- readable via the Query Profile UI (used in PART A) or via
-- SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY, which has up to ~45min latency.
SELECT query_id, bytes_scanned, total_elapsed_time
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%CITY_NAME = ''Ventura''%'
ORDER BY start_time DESC
LIMIT 1;

-- RESULT: bytes_scanned = 355,328 (~0.35MB), total_elapsed_time = 1132ms.
-- Since partitions_total = 1 for this whole table (seen in PART A's Query
-- Profile), a WHERE filter here cannot reduce partitions scanned -- there's
-- only one partition to begin with, so Snowflake reads the whole thing
-- either way. This is expected, not a misconfiguration: pruning only pays
-- off once a table is large enough to span many micro-partitions
-- (roughly multi-GB+), which is beyond this trial account's data volume.

/*==============================================================================
  RECAP -- 9th Practice
==============================================================================*/
-- 1) Query Profile turns a black-box query into a readable operator tree
--    (TableScan -> Aggregate -> WindowFunction -> Sort -> Result) with a
--    per-operator % of total time -- that's where to look first on a real
--    slow query, not the SQL text itself.
-- 2) Warehouse size is a real, measurable lever: X-Small vs Small on the
--    same 14M-row CROSS JOIN went 864ms -> 117ms (~7.4x). More servers =
--    faster, at 2x the credit cost -- worth it only when the query is
--    actually compute-bound, which small learning-scale data rarely is.
-- 3) Partition pruning is a function of DATA VOLUME, not query cleverness.
--    A ~3.7k-row table lives in one micro-partition, so no WHERE clause can
--    make Snowflake scan less of it. Pruning shows real gains only on
--    large (multi-GB+) tables split across many micro-partitions.
-- 4) Three practical gotchas hit live while building this file:
--    - INFORMATION_SCHEMA.QUERY_HISTORY() has no partitions_scanned /
--      partitions_total columns -- those live only in the Query Profile UI
--      or in the (delayed) SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY view.
--    - Filtering query_history by a text phrase can match your own query's
--      COMMENTS too, causing it to self-match on a later run.
--    - LAST_QUERY_ID(-1) walks back through ALL queries including failed
--      compilations, not just successful ones -- verify which query you
--      actually got back before trusting its stats.
