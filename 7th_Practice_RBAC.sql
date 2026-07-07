/* ===========================================================
SNOWFLAKE PRACTICE - RBAC (ROLE-BASED ACCESS CONTROL)
Table under test: driver_lifetime_trips
Goal: prove least-privilege access actually works, not just
"looks correct" - grant a custom role read-only access and
confirm writes get rejected while reads succeed.
=========================================================== */

-- -----------------------------------------------------------
-- SETUP - restore session context (role / warehouse / db / schema)
-- -----------------------------------------------------------
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SNOWFLAKE_LEARNING_DB;
USE SCHEMA EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3;

-- confirm the current username - needed for the GRANT ROLE step below
SELECT CURRENT_USER();

/* ===========================================================
PART A - CREATE A CUSTOM ROLE

Use case: Snowflake grants privileges to ROLES, never directly
to users. A user can hold many roles; a role can be granted to
many users. This is what makes access manageable at scale -
define "what an analyst can do" once, then hand that bundle of
privileges to every analyst who needs it.
=========================================================== */

CREATE ROLE IF NOT EXISTS TRIPS_ANALYST_ROLE;

-- a role needs USAGE on the warehouse/db/schema just to "see" them,
-- separate from what it can actually do to objects inside
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE TRIPS_ANALYST_ROLE;
GRANT USAGE ON DATABASE SNOWFLAKE_LEARNING_DB TO ROLE TRIPS_ANALYST_ROLE;
GRANT USAGE ON SCHEMA SNOWFLAKE_LEARNING_DB.EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3 TO ROLE TRIPS_ANALYST_ROLE;

/* ===========================================================
PART B - GRANT THE MINIMUM PRIVILEGE NEEDED

Use case: this role only ever needs to read trip data for
analysis - it should never modify or delete rows, and it has
no business touching any other table in the schema.
=========================================================== */

GRANT SELECT ON TABLE driver_lifetime_trips TO ROLE TRIPS_ANALYST_ROLE;

-- grant the role to the current user so it can actually be tested
-- (replace EVGENIIMATVEEV with whatever CURRENT_USER() printed above,
-- if different)
GRANT ROLE TRIPS_ANALYST_ROLE TO USER EVGENIIMATVEEV;

/* ===========================================================
PART C - SWITCH ROLE AND PROVE THE RESTRICTION IS REAL

Use case: a privilege that is only declared but never tested is
a guess, not a guarantee. Switching into the role and attempting
both an allowed and a disallowed action is the only way to be
sure least-privilege actually holds. The disallowed action below
is an INSERT of one throwaway test row rather than a DELETE - if
the grants were somehow wrong, an unexpected insert is a harmless
row to clean up, unlike an unexpected delete of real trip data.
=========================================================== */

USE ROLE TRIPS_ANALYST_ROLE;
USE WAREHOUSE COMPUTE_WH;

-- allowed: SELECT works fine under the read-only role
SELECT COUNT(*) AS visible_rows
FROM SNOWFLAKE_LEARNING_DB.EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3.driver_lifetime_trips;

-- blocked: expected to fail with "insufficient privileges" - proof
-- the role can read but not write
INSERT INTO SNOWFLAKE_LEARNING_DB.EVGENIIMATVEEV_LOAD_SAMPLE_DATA_FROM_S3.driver_lifetime_trips (city_name)
VALUES ('RBAC_TEST_SHOULD_FAIL');

-- switch back to the admin role to keep working in this session
USE ROLE ACCOUNTADMIN;

/* ===========================================================
RECAP
- Privileges are granted to ROLES, never directly to users - a
role is a reusable bundle of "what you are allowed to do."
- USAGE grants let a role "see" a warehouse/database/schema;
object-level grants (SELECT, INSERT, ...) control what it can
actually do once inside.
- Never trust a privilege model until it has been tested from
inside the restricted role - SELECT succeeding and INSERT
failing is the actual proof, not the GRANT statements alone.
- This is exactly the pattern real teams use: a BI/analyst role
with SELECT-only access to reporting tables, kept separate from
the engineering role that owns ingestion/transformation and
needs write access.
=========================================================== */
