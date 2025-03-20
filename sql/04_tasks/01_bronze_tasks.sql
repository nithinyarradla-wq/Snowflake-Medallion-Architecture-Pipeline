-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Pipeline Tasks: Bronze Layer Tasks
-- ============================================================================
-- This script creates Snowflake Tasks for automating Bronze layer data loading
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA BRONZE;
USE WAREHOUSE MEDALLION_TASK_WH;

-- ============================================================================
-- TASK: Load Orders from Stage (Every 15 minutes)
-- ============================================================================

CREATE OR REPLACE TASK TASK_LOAD_RAW_ORDERS
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '15 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Load order data from JSON stage into Bronze layer'
AS
    CALL SP_LOAD_RAW_ORDERS(NULL);

-- ============================================================================
-- TASK: Load Customers from Stage (Every hour)
-- ============================================================================

CREATE OR REPLACE TASK TASK_LOAD_RAW_CUSTOMERS
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '60 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Load customer data from CSV stage into Bronze layer'
AS
    CALL SP_LOAD_RAW_CUSTOMERS(NULL);

-- ============================================================================
-- TASK: Load Products from Stage (Every hour)
-- ============================================================================

CREATE OR REPLACE TASK TASK_LOAD_RAW_PRODUCTS
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '60 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Load product data from CSV stage into Bronze layer'
AS
    CALL SP_LOAD_RAW_PRODUCTS(NULL);

-- ============================================================================
-- TASK: Master Bronze Load (Triggered - for manual/on-demand use)
-- ============================================================================

CREATE OR REPLACE TASK TASK_LOAD_ALL_BRONZE
    WAREHOUSE = MEDALLION_TASK_WH
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Master task to load all Bronze layer data (trigger manually)'
AS
    CALL SP_LOAD_ALL_RAW_DATA();

-- ============================================================================
-- VERIFY TASKS
-- ============================================================================

SHOW TASKS IN SCHEMA BRONZE;

-- Note: Tasks are created in SUSPENDED state by default
-- To enable tasks, run:
-- ALTER TASK TASK_LOAD_RAW_ORDERS RESUME;
-- ALTER TASK TASK_LOAD_RAW_CUSTOMERS RESUME;
-- ALTER TASK TASK_LOAD_RAW_PRODUCTS RESUME;

SELECT 'Bronze layer tasks created successfully (in SUSPENDED state)' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
