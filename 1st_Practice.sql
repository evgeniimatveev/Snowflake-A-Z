/* ===========================================================
   SNOWFLAKE PRACTICE - SQL BASICS: FILTER, JOIN, AGGREGATE,
   CTE, WINDOW FUNCTIONS
   Tables under test: SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER,
                       ORDERS, NATION
   Goal: warm up core SQL patterns on real-sized sample data
   before moving on to more advanced Snowflake features
   =========================================================== */

-- -----------------------------------------------------------
-- SETUP - restore session context (role / warehouse / db / schema)
-- -----------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;
USE DATABASE SNOWFLAKE_SAMPLE_DATA;
USE SCHEMA TPCH_SF1;

-- sanity check: confirm the tables exist and see their shape before querying
DESCRIBE TABLE customer;
DESCRIBE TABLE orders;
DESCRIBE TABLE nation;


/* ===========================================================
   PART A - BASIC SELECT
   Use case: the first thing you always do with an unfamiliar
   table - peek at raw rows to see real column values, not just
   the schema, before writing any real query against it.
   =========================================================== */

-- 1. Preview the table as-is, no filtering, no sorting
SELECT * FROM customer LIMIT 20;


/* ===========================================================
   PART B - WHERE + ORDER BY + LIMIT
   Use case: narrow down to the rows you actually care about
   (customers above a balance threshold) and rank them, instead
   of scanning the whole table.
   =========================================================== */

-- 1. Wealthiest customers with a positive balance filter applied
SELECT C_NAME, C_ACCTBAL, C_NATIONKEY
FROM customer
WHERE C_ACCTBAL > 5000
ORDER BY C_ACCTBAL DESC
LIMIT 10;


/* ===========================================================
   PART C - JOIN
   Use case: CUSTOMER and ORDERS are two separate tables linked
   by a foreign key (O_CUSTKEY -> C_CUSTKEY). A JOIN lets you
   ask questions that span both - e.g. "whose order is this?" -
   without denormalizing the data ahead of time.
   =========================================================== */

-- 1. Attach the customer's name to each order
SELECT o.O_ORDERKEY, o.O_TOTALPRICE, c.C_NAME
FROM orders o
JOIN customer c ON o.O_CUSTKEY = c.C_CUSTKEY
LIMIT 10;


/* ===========================================================
   PART D - GROUP BY + AGGREGATE FUNCTIONS
   Use case: move from row-level detail to summary statistics -
   how many customers per nation, and what's their average
   balance. This is the standard "roll it up" pattern.
   =========================================================== */

-- 1. Customer count and average balance, one row per nation key
SELECT c.C_NATIONKEY, COUNT(*) AS total_customers, AVG(c.C_ACCTBAL) AS avg_balance
FROM customer c
GROUP BY c.C_NATIONKEY
ORDER BY total_customers DESC;


/* ===========================================================
   PART E - JOIN + GROUP BY + HAVING
   Use case: two upgrades over Part D at once - (1) join to
   NATION so the output shows human-readable country names
   instead of raw keys, and (2) HAVING filters on the AGGREGATE
   result itself (total_customers), which WHERE cannot do since
   WHERE only sees pre-aggregation rows.
   =========================================================== */

-- 1. Nations with more than 6000 customers, ranked by wealth
SELECT n.N_NAME AS nation, COUNT(*) AS total_customers, AVG(c.C_ACCTBAL) AS avg_balance
FROM customer c
JOIN nation n ON c.C_NATIONKEY = n.N_NATIONKEY
GROUP BY n.N_NAME
HAVING COUNT(*) > 6000
ORDER BY avg_balance DESC;


/* ===========================================================
   PART F - CTE + SUBQUERY
   Use case: compare each row against a single aggregate value
   (the overall average balance) computed once in a WITH clause.
   The CTE keeps the average balance readable and reusable,
   instead of repeating a subquery inline.
   =========================================================== */

-- 1. Customers whose balance sits above the company-wide average
WITH avg_balance AS (
    SELECT AVG(C_ACCTBAL) AS avg_bal FROM customer
)
SELECT C_NAME, C_ACCTBAL
FROM customer, avg_balance
WHERE C_ACCTBAL > avg_bal
ORDER BY C_ACCTBAL DESC
LIMIT 10;


/* ===========================================================
   PART G - WINDOW FUNCTION + QUALIFY
   Use case: rank rows WITHIN groups (top 3 balances per nation)
   without collapsing the detail rows the way GROUP BY would.
   QUALIFY is Snowflake's shortcut to filter on a window function
   result directly, avoiding a wrapping subquery + WHERE.
   =========================================================== */

-- 1. Top 3 customers by balance, per nation
SELECT C_NAME, C_NATIONKEY, C_ACCTBAL,
       RANK() OVER (PARTITION BY C_NATIONKEY ORDER BY C_ACCTBAL DESC) AS rank_in_nation
FROM customer
QUALIFY rank_in_nation <= 3
ORDER BY C_NATIONKEY, rank_in_nation;


/* ===========================================================
   RECAP
   - SELECT + LIMIT         -> quick raw preview of an
     unfamiliar table.
   - WHERE + ORDER BY       -> filter rows, then sort the
     survivors.
   - JOIN                   -> combine rows across tables that
     share a key.
   - GROUP BY + aggregates  -> collapse rows into per-group
     summary stats.
   - HAVING                 -> filter on the aggregate result,
     not the pre-aggregation rows (WHERE can't do this).
   - CTE (WITH)             -> name and reuse a computed value
     (like an overall average) instead of a repeated subquery.
   - Window function + QUALIFY -> rank/compare rows within a
     partition while keeping row-level detail intact.
   =========================================================== */
