/*--
Tasty Bytes is a fictitious, global food truck network, that is on a mission to serve unique food options with high
quality items in a safe, convenient and cost effective way. In order to drive forward on their mission, Tasty Bytes
is beginning to leverage the Snowflake Data Cloud.

Within this Worksheet, we will walk through the end to end process required to load a CSV file containing Menu specific data
that is currently hosted in Blob Storage.
--*/

-------------------------------------------------------------------------------------------
    -- Step 1: To start, let's set the Role and Warehouse context
        -- USE ROLE: https://docs.snowflake.com/en/sql-reference/sql/use-role
        -- USE WAREHOUSE: https://docs.snowflake.com/en/sql-reference/sql/use-warehouse
-------------------------------------------------------------------------------------------

/*--
    - To run a single query, place your cursor in the query editor and select the Run button.
    - To run the entire worksheet, select 'Run All' from the dropdown next to the Run button.
--*/

---> set the Role
USE ROLE SNOWFLAKE_LEARNING_ROLE;

---> set the Warehouse
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

---> set the Database
USE DATABASE SNOWFLAKE_LEARNING_DB;

---> set the Schema
SET schema_name = CONCAT(current_user(), '_LOAD_SAMPLE_DATA_FROM_S3');
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($schema_name);
USE SCHEMA IDENTIFIER($schema_name);

-------------------------------------------------------------------------------------------
    -- Step 2: With context in place, let's now create a Table
        -- CREATE TABLE: https://docs.snowflake.com/en/sql-reference/sql/create-table
-----------------------------------------------------------------------------------------

---> create the Raw Menu Table
CREATE OR REPLACE TABLE MENU
(
    menu_id NUMBER(19,0),
    menu_type_id NUMBER(38,0),
    menu_type VARCHAR(16777216),
    truck_brand_name VARCHAR(16777216),
    menu_item_id NUMBER(38,0),
    menu_item_name VARCHAR(16777216),
    item_category VARCHAR(16777216),
    item_subcategory VARCHAR(16777216),
    cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4),
    menu_item_health_metrics_obj VARIANT
);

---> confirm the empty Menu table exists
SELECT * FROM menu;


-------------------------------------------------------------------------------------------
    -- Step 3: To connect to the Blob Storage, let's create a Stage
        -- Creating an S3 Stage: https://docs.snowflake.com/en/user-guide/data-load-s3-create-stage
-------------------------------------------------------------------------------------------

CREATE OR REPLACE STAGE blob_stage
url = 's3://sfquickstarts/tastybytes/'
file_format = (type = csv);

---> query the Stage to find the Menu CSV file
LIST @blob_stage/raw_pos/menu/;


-------------------------------------------------------------------------------------------
    -- Step 4: Now let's Load the Menu CSV file from the Stage
        -- COPY INTO <table>: https://docs.snowflake.com/en/sql-reference/sql/copy-into-table
-------------------------------------------------------------------------------------------

---> copy the Menu file into the Menu table
COPY INTO menu
FROM @blob_stage/raw_pos/menu/;


-------------------------------------------------------------------------------------------
    -- Step 5: Query the Menu table
        -- SELECT: https://docs.snowflake.com/en/sql-reference/sql/select
        -- TOP <n>: https://docs.snowflake.com/en/sql-reference/constructs/top_n
        -- FLATTEN: https://docs.snowflake.com/en/sql-reference/functions/flatten
-------------------------------------------------------------------------------------------

---> how many rows are in the table?
SELECT COUNT(*) AS row_count FROM menu;

---> what do the top 10 rows look like?
SELECT TOP 10 * FROM menu;

---> what menu items does the Freezing Point brand sell?
SELECT
   menu_item_name
FROM menu
WHERE truck_brand_name = 'Freezing Point';

---> what is the profit on Mango Sticky Rice?
SELECT
   menu_item_name,
   (sale_price_usd - cost_of_goods_usd) AS profit_usd
FROM menu
WHERE TRUE
AND truck_brand_name = 'Freezing Point'
AND menu_item_name = 'Mango Sticky Rice';

---> to finish, let's extract the Mango Sticky Rice ingredients from the semi-structured column
SELECT
    m.menu_item_name,
    obj.value:"ingredients"::ARRAY AS ingredients
FROM menu m,
    LATERAL FLATTEN (input => m.menu_item_health_metrics_obj:menu_item_health_metrics) obj
WHERE TRUE
AND truck_brand_name = 'Freezing Point'
AND menu_item_name = 'Mango Sticky Rice';
