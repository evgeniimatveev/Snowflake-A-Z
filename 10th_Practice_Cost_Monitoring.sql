/*==============================================================================
  10th Practice -- Cost & Usage Monitoring
  Snowflake-A-Z | Practice 10 of 10
  Closes the story that started Day 1: back then we just set up cost
  guardrails (X-Small warehouses, LEARNING_MONITOR resource monitor) without
  being able to see the numbers behind them. This practice queries those
  same guardrails from SQL.
==============================================================================*/

-- SETUP -----------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

/*==============================================================================
  PART A -- Daily credit burn per warehouse (WAREHOUSE_METERING_HISTORY)
==============================================================================*/
-- Lives in SNOWFLAKE.ACCOUNT_USAGE (not INFORMATION_SCHEMA) -- account-wide,
-- 365-day retention, but up to ~45min-3hr latency vs. real-time.
SELECT
    warehouse_name,
    DATE_TRUNC('day', start_time)     AS usage_day,
    SUM(credits_used)                 AS credits_used,
    SUM(credits_used_compute)         AS credits_compute,
    SUM(credits_used_cloud_services)  AS credits_cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name, usage_day
ORDER BY usage_day DESC, warehouse_name;

-- RESULT: real per-day, per-warehouse credit burn, e.g. COMPUTE_WH used
-- 0.69 credits on 2026-07-06 and 0.44 on 2026-07-07. CLOUD_SERVICES_ONLY
-- is a virtual row Snowflake uses to bucket cloud-services credits that
-- aren't tied to a warehouse's actual compute (metadata ops, etc.).

/*==============================================================================
  PART B -- The resource monitor set up on Day 1: still doing its job?
==============================================================================*/
-- Resource monitors aren't a queryable table -- they're account objects,
-- read via SHOW then RESULT_SCAN(LAST_QUERY_ID()) to turn the SHOW output
-- into a normal result set.
SHOW RESOURCE MONITORS;

SELECT "name", "credit_quota", "used_credits", "level",
       "notify_at", "suspend_at", "suspend_immediately_at"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- RESULT: notify_at=50%, suspend_at=75%, suspend_immediately_at=100% of the
-- 50-credit quota -- exactly the guardrails set on Day 1, confirmed still
-- in force. used_credits=2.01 of 50 after ~4 days of learning -- pace is
-- nowhere near the notify threshold.

/*==============================================================================
  PART C -- Most expensive queries in this account (ACCOUNT_USAGE.QUERY_HISTORY)
==============================================================================*/
-- Same idea as PART B of the 9th practice, but account-wide and with the
-- pruning/cost columns INFORMATION_SCHEMA.QUERY_HISTORY() doesn't expose.
SELECT
    query_id,
    query_type,
    warehouse_name,
    warehouse_size,
    total_elapsed_time AS elapsed_ms,
    bytes_scanned,
    partitions_scanned,
    partitions_total,
    start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
ORDER BY total_elapsed_time DESC
LIMIT 10;

-- HONEST FINDING: the top rows by elapsed_ms are CALL / EXECUTE_STREAMLIT
-- entries against COMPUTE_SERVICE_WH_USER_TASKS_POOL_XSMALL_0 (the Snowpark
-- container service from the 8th practice) and COMPUTE_WH, running
-- 200,000-600,000+ ms (3-10+ minutes). These are session/container
-- lifetimes (idle browser tab, open Streamlit session), not continuous
-- compute -- total_elapsed_time for CALL/EXECUTE_STREAMLIT includes wait
-- time, so it's a poor proxy for cost. Credits from PART A's
-- WAREHOUSE_METERING_HISTORY are the real cost signal; elapsed_time here
-- is better read as "what ran recently," not "what's expensive."

/*==============================================================================
  RECAP -- 10th Practice (closes the Snowflake-A-Z learning plan)
==============================================================================*/
-- 1) WAREHOUSE_METERING_HISTORY (ACCOUNT_USAGE) gives real per-day,
--    per-warehouse credit burn -- the ground truth for "what did this cost."
-- 2) Resource monitors are account objects, not tables -- SHOW + RESULT_SCAN
--    is the pattern to query them with SQL. The Day-1 LEARNING_MONITOR
--    guardrails (50 credit quota, notify/suspend at 50%/75%/100%) are
--    confirmed still active, at 2.01 of 50 credits used after ~4 days.
-- 3) QUERY_HISTORY's total_elapsed_time is NOT the same as cost. Long-lived
--    session types (CALL, EXECUTE_STREAMLIT) can dominate an elapsed-time
--    ranking just by sitting open, while barely touching compute credits.
--    Always cross-check an "expensive" query against actual credits, not
--    just its duration.
-- 4) Full-circle moment: Day 1 we set guardrails blind, trusting the UI.
--    Practice 10 is the first time we've verified them with SQL instead of
--    just reading the Snowsight screen -- the same instinct as PART A/B/C
--    of the 9th practice (verify a suspicious number with a second query).
