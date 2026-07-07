/* ===========================================================
   SNOWFLAKE PRACTICE - TIME TRAVEL, UNDROP & ZERO-COPY CLONE
   Table under test: SNOWFLAKE_LEARNING_DB.<schema>.MENU
   Goal: learn 3 independent recovery/copy mechanisms hands-on
   =========================================================== */

-- -----------------------------------------------------------
-- SETUP - restore session context (role / warehouse / db / schema)
-- -----------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;

-- schema name is dynamic (created per-user by the tutorial), confirm it here
SHOW SCHEMAS IN DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

-- sanity check: confirm the table structure and baseline row count before touching anything
DESCRIBE TABLE menu;
SELECT * FROM menu ORDER BY menu_item_id LIMIT 10;
SELECT COUNT(*) AS total_rows FROM menu;   -- expected: 100


/* ===========================================================
   PART A - TIME TRAVEL
   Use case: someone (or something) deletes/updates rows by
   mistake. Time Travel lets you query the table's PAST state
   and selectively pull back exactly what was lost - no full
   restore, no backup file needed.
   =========================================================== */

-- 1. Simulate an accidental delete
DELETE FROM menu WHERE menu_id BETWEEN 10001 AND 10005;

-- 2. Look at the table as it was BEFORE the delete, using AT(OFFSET => seconds_ago)
--    Note: the offset must be larger than how long ago the DELETE actually happened,
--    otherwise Snowflake has no matching historical version to show you yet.
SELECT * FROM menu AT(OFFSET => -600)
WHERE menu_id BETWEEN 10001 AND 10005;

-- 3. Actually restore the missing rows - insert straight from the historical snapshot
INSERT INTO menu
SELECT * FROM menu AT(OFFSET => -600)
WHERE menu_id BETWEEN 10001 AND 10005;

-- 4. Confirm the restore worked
SELECT COUNT(*) AS total_rows FROM menu;   -- expected: back to 100
SELECT * FROM menu WHERE menu_id BETWEEN 10001 AND 10005 ORDER BY menu_id;


/* ===========================================================
   PART B - DROP TABLE + UNDROP
   Use case: this time the whole OBJECT is gone (dropped table,
   not just some rows). Time Travel's AT/BEFORE syntax queries
   data inside a table that still exists - it can't bring back
   an object that no longer exists in the namespace. UNDROP is
   the separate command for that scenario.
   =========================================================== */

-- 1. Create a disposable test table so we don't risk the real `menu` table
CREATE TABLE menu_test_drop AS SELECT * FROM menu LIMIT 5;
SELECT COUNT(*) FROM menu_test_drop;       -- expected: 5

-- 2. Drop it entirely
DROP TABLE menu_test_drop;

-- 3. Prove it's really gone - this SHOULD error with "does not exist"
SELECT COUNT(*) FROM menu_test_drop;

-- 4. Bring the whole object back, exactly as it was at drop time
UNDROP TABLE menu_test_drop;
SELECT COUNT(*) FROM menu_test_drop;       -- expected: 5 again

-- cleanup - done with this scratch table
DROP TABLE menu_test_drop;


/* ===========================================================
   PART C - ZERO-COPY CLONE
   Use case: instant, storage-free copies for dev/test/staging.
   CREATE TABLE ... CLONE doesn't physically duplicate data -
   the clone just points at the same micro-partitions as the
   source (copy-on-write). Storage cost only appears once you
   start MODIFYING the clone, and only for the changed parts.
   =========================================================== */

-- 1. Clone the live table - instant, regardless of table size
CREATE TABLE menu_clone CLONE menu;
SELECT COUNT(*) FROM menu_clone;           -- expected: 100 (same as source)

-- 2. Modify ONLY the clone
DELETE FROM menu_clone WHERE menu_id BETWEEN 10001 AND 10010;

-- 3. Prove the two tables are now independent
SELECT COUNT(*) FROM menu_clone;           -- expected: 90
SELECT COUNT(*) FROM menu;                 -- expected: 100 - untouched
SELECT * FROM menu_clone ORDER BY menu_item_id LIMIT 10;

-- cleanup - done with the clone
DROP TABLE menu_clone;


/* ===========================================================
   RECAP
   - Time Travel (AT/BEFORE)  -> point-in-time query on an
     EXISTING table; use it for row-level "oops" recovery.
   - DROP + UNDROP            -> whole-object recovery, for
     when the table/schema/db itself was deleted.
   - Zero-Copy Clone           -> instant, free-until-modified
     copy of a table; the backbone of cheap dev/staging
     environments in real Snowflake setups.
   =========================================================== */
