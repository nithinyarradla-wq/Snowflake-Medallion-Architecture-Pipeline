-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Pipeline Tasks: Silver Layer Tasks
-- ============================================================================
-- This script creates Snowflake Tasks for automating Silver layer transformations
-- These tasks are triggered by Bronze layer completion (stream-based)
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA SILVER;
USE WAREHOUSE MEDALLION_TASK_WH;

-- ============================================================================
-- TASK: Transform Customers (Triggered when stream has data)
-- ============================================================================

CREATE OR REPLACE TASK TASK_TRANSFORM_CUSTOMERS
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '5 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_CUSTOMERS')
    COMMENT = 'Transform customer data from Bronze to Silver when new data arrives'
AS
    CALL SP_TRANSFORM_CUSTOMERS();

-- ============================================================================
-- TASK: Transform Products (Triggered when stream has data)
-- ============================================================================

CREATE OR REPLACE TASK TASK_TRANSFORM_PRODUCTS
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '5 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_PRODUCTS')
    COMMENT = 'Transform product data from Bronze to Silver when new data arrives'
AS
    CALL SP_TRANSFORM_PRODUCTS();

-- ============================================================================
-- TASK: Transform Orders (Triggered when stream has data)
-- ============================================================================

CREATE OR REPLACE TASK TASK_TRANSFORM_ORDERS
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '5 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    WHEN SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_ORDERS')
    COMMENT = 'Transform order data from Bronze to Silver when new data arrives'
AS
    CALL SP_TRANSFORM_ORDERS();

-- ============================================================================
-- TASK: Transform Order Items (Child task, runs after TASK_TRANSFORM_ORDERS)
-- ============================================================================

CREATE OR REPLACE TASK TASK_TRANSFORM_ORDER_ITEMS
    WAREHOUSE = MEDALLION_TASK_WH
    AFTER TASK_TRANSFORM_ORDERS
    COMMENT = 'Flatten order items after order headers are transformed'
AS
    CALL SP_TRANSFORM_ORDER_ITEMS();

-- ============================================================================
-- TASK: Master Silver Transform (Scheduled - runs all transformations)
-- ============================================================================

CREATE OR REPLACE TASK TASK_TRANSFORM_ALL_SILVER
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '30 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Master task to run all Silver layer transformations'
AS
    CALL SP_TRANSFORM_ALL_TO_SILVER();

-- ============================================================================
-- VERIFY TASKS
-- ============================================================================

SHOW TASKS IN SCHEMA SILVER;

-- Note: Tasks are created in SUSPENDED state by default
-- To enable the task DAG, start from leaf tasks and work up:
-- ALTER TASK TASK_TRANSFORM_ORDER_ITEMS RESUME;
-- ALTER TASK TASK_TRANSFORM_ORDERS RESUME;
-- ALTER TASK TASK_TRANSFORM_PRODUCTS RESUME;
-- ALTER TASK TASK_TRANSFORM_CUSTOMERS RESUME;

SELECT 'Silver layer tasks created successfully (in SUSPENDED state)' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
