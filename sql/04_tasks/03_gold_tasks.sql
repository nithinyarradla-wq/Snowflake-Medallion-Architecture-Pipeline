-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Pipeline Tasks: Gold Layer Tasks
-- ============================================================================
-- This script creates Snowflake Tasks for automating Gold layer aggregations
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA GOLD;
USE WAREHOUSE MEDALLION_TASK_WH;

-- ============================================================================
-- TASK: Populate Customer Dimension
-- ============================================================================

CREATE OR REPLACE TASK TASK_POPULATE_DIM_CUSTOMER
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '60 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Populate customer dimension from Silver layer'
AS
    CALL SP_POPULATE_DIM_CUSTOMER();

-- ============================================================================
-- TASK: Populate Product Dimension
-- ============================================================================

CREATE OR REPLACE TASK TASK_POPULATE_DIM_PRODUCT
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = '60 MINUTE'
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Populate product dimension from Silver layer'
AS
    CALL SP_POPULATE_DIM_PRODUCT();

-- ============================================================================
-- TASK: Populate Sales Fact (runs after dimensions)
-- ============================================================================

CREATE OR REPLACE TASK TASK_POPULATE_FACT_SALES
    WAREHOUSE = MEDALLION_TASK_WH
    AFTER TASK_POPULATE_DIM_CUSTOMER, TASK_POPULATE_DIM_PRODUCT
    COMMENT = 'Populate sales fact table after dimensions are updated'
AS
    CALL SP_POPULATE_FACT_SALES();

-- ============================================================================
-- TASK: Populate Daily Sales Snapshot
-- ============================================================================

CREATE OR REPLACE TASK TASK_POPULATE_DAILY_SALES
    WAREHOUSE = MEDALLION_TASK_WH
    AFTER TASK_POPULATE_FACT_SALES
    COMMENT = 'Calculate daily sales snapshot after fact table is updated'
AS
    CALL SP_POPULATE_DAILY_SALES(CURRENT_DATE() - 1);

-- ============================================================================
-- TASK: Master Gold Layer Population
-- ============================================================================

CREATE OR REPLACE TASK TASK_POPULATE_GOLD_LAYER
    WAREHOUSE = MEDALLION_TASK_WH
    SCHEDULE = 'USING CRON 0 2 * * * America/New_York'  -- Daily at 2 AM EST
    ALLOW_OVERLAPPING_EXECUTION = FALSE
    COMMENT = 'Master task to populate entire Gold layer (daily)'
AS
    CALL SP_POPULATE_GOLD_LAYER();

-- ============================================================================
-- VERIFY TASKS
-- ============================================================================

SHOW TASKS IN SCHEMA GOLD;

-- Note: Tasks are created in SUSPENDED state by default
-- To enable the task DAG, start from leaf tasks and work up:
-- ALTER TASK TASK_POPULATE_DAILY_SALES RESUME;
-- ALTER TASK TASK_POPULATE_FACT_SALES RESUME;
-- ALTER TASK TASK_POPULATE_DIM_PRODUCT RESUME;
-- ALTER TASK TASK_POPULATE_DIM_CUSTOMER RESUME;

SELECT 'Gold layer tasks created successfully (in SUSPENDED state)' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
