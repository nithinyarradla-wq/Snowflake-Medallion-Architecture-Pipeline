-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Pipeline Tasks: Task Management Scripts
-- ============================================================================
-- This script provides utilities for managing pipeline tasks
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE WAREHOUSE MEDALLION_TASK_WH;

-- ============================================================================
-- VIEW: Task Status Dashboard
-- ============================================================================

CREATE OR REPLACE VIEW UTILS.V_TASK_STATUS AS
SELECT
    NAME AS TASK_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    WAREHOUSE,
    SCHEDULE,
    STATE,
    LAST_COMMITTED_ON,
    LAST_SUSPENDED_ON,
    COMMENT
FROM TABLE(INFORMATION_SCHEMA.TASK_DEPENDENTS(
    TASK_NAME => 'MEDALLION_DB.BRONZE.TASK_LOAD_RAW_ORDERS',
    RECURSIVE => TRUE
))
UNION ALL
SELECT
    NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    WAREHOUSE,
    SCHEDULE,
    STATE,
    LAST_COMMITTED_ON,
    LAST_SUSPENDED_ON,
    COMMENT
FROM TABLE(INFORMATION_SCHEMA.TASK_DEPENDENTS(
    TASK_NAME => 'MEDALLION_DB.GOLD.TASK_POPULATE_GOLD_LAYER',
    RECURSIVE => TRUE
));

-- ============================================================================
-- PROCEDURE: Resume All Pipeline Tasks
-- ============================================================================

CREATE OR REPLACE PROCEDURE UTILS.SP_RESUME_ALL_TASKS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Resume Gold layer tasks (leaf to root)
    ALTER TASK GOLD.TASK_POPULATE_DAILY_SALES RESUME;
    ALTER TASK GOLD.TASK_POPULATE_FACT_SALES RESUME;
    ALTER TASK GOLD.TASK_POPULATE_DIM_PRODUCT RESUME;
    ALTER TASK GOLD.TASK_POPULATE_DIM_CUSTOMER RESUME;
    ALTER TASK GOLD.TASK_POPULATE_GOLD_LAYER RESUME;

    -- Resume Silver layer tasks (leaf to root)
    ALTER TASK SILVER.TASK_TRANSFORM_ORDER_ITEMS RESUME;
    ALTER TASK SILVER.TASK_TRANSFORM_ORDERS RESUME;
    ALTER TASK SILVER.TASK_TRANSFORM_PRODUCTS RESUME;
    ALTER TASK SILVER.TASK_TRANSFORM_CUSTOMERS RESUME;
    ALTER TASK SILVER.TASK_TRANSFORM_ALL_SILVER RESUME;

    -- Resume Bronze layer tasks
    ALTER TASK BRONZE.TASK_LOAD_RAW_ORDERS RESUME;
    ALTER TASK BRONZE.TASK_LOAD_RAW_CUSTOMERS RESUME;
    ALTER TASK BRONZE.TASK_LOAD_RAW_PRODUCTS RESUME;

    RETURN 'All pipeline tasks resumed successfully';
END;
$$;

-- ============================================================================
-- PROCEDURE: Suspend All Pipeline Tasks
-- ============================================================================

CREATE OR REPLACE PROCEDURE UTILS.SP_SUSPEND_ALL_TASKS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Suspend Bronze layer tasks (root first)
    ALTER TASK BRONZE.TASK_LOAD_RAW_ORDERS SUSPEND;
    ALTER TASK BRONZE.TASK_LOAD_RAW_CUSTOMERS SUSPEND;
    ALTER TASK BRONZE.TASK_LOAD_RAW_PRODUCTS SUSPEND;

    -- Suspend Silver layer tasks (root to leaf)
    ALTER TASK SILVER.TASK_TRANSFORM_ALL_SILVER SUSPEND;
    ALTER TASK SILVER.TASK_TRANSFORM_CUSTOMERS SUSPEND;
    ALTER TASK SILVER.TASK_TRANSFORM_PRODUCTS SUSPEND;
    ALTER TASK SILVER.TASK_TRANSFORM_ORDERS SUSPEND;
    ALTER TASK SILVER.TASK_TRANSFORM_ORDER_ITEMS SUSPEND;

    -- Suspend Gold layer tasks (root to leaf)
    ALTER TASK GOLD.TASK_POPULATE_GOLD_LAYER SUSPEND;
    ALTER TASK GOLD.TASK_POPULATE_DIM_CUSTOMER SUSPEND;
    ALTER TASK GOLD.TASK_POPULATE_DIM_PRODUCT SUSPEND;
    ALTER TASK GOLD.TASK_POPULATE_FACT_SALES SUSPEND;
    ALTER TASK GOLD.TASK_POPULATE_DAILY_SALES SUSPEND;

    RETURN 'All pipeline tasks suspended successfully';
END;
$$;

-- ============================================================================
-- VIEW: Task Execution History
-- ============================================================================

CREATE OR REPLACE VIEW UTILS.V_TASK_HISTORY AS
SELECT
    NAME AS TASK_NAME,
    DATABASE_NAME,
    SCHEMA_NAME,
    STATE,
    SCHEDULED_TIME,
    QUERY_START_TIME,
    COMPLETED_TIME,
    DATEDIFF('second', QUERY_START_TIME, COMPLETED_TIME) AS DURATION_SECONDS,
    ERROR_CODE,
    ERROR_MESSAGE,
    RETURN_VALUE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 1000
))
ORDER BY SCHEDULED_TIME DESC;

-- ============================================================================
-- VIEW: Task Run Summary (Last 24 hours)
-- ============================================================================

CREATE OR REPLACE VIEW UTILS.V_TASK_SUMMARY_24H AS
SELECT
    NAME AS TASK_NAME,
    COUNT(*) AS TOTAL_RUNS,
    SUM(CASE WHEN STATE = 'SUCCEEDED' THEN 1 ELSE 0 END) AS SUCCESS_COUNT,
    SUM(CASE WHEN STATE = 'FAILED' THEN 1 ELSE 0 END) AS FAILURE_COUNT,
    AVG(DATEDIFF('second', QUERY_START_TIME, COMPLETED_TIME)) AS AVG_DURATION_SECONDS,
    MAX(DATEDIFF('second', QUERY_START_TIME, COMPLETED_TIME)) AS MAX_DURATION_SECONDS,
    MIN(SCHEDULED_TIME) AS FIRST_RUN,
    MAX(SCHEDULED_TIME) AS LAST_RUN
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 1000
))
GROUP BY NAME
ORDER BY TOTAL_RUNS DESC;

-- ============================================================================
-- PROCEDURE: Run Full Pipeline (Manual Trigger)
-- ============================================================================

CREATE OR REPLACE PROCEDURE UTILS.SP_RUN_FULL_PIPELINE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_result VARCHAR;
BEGIN
    -- Step 1: Load Bronze layer
    CALL BRONZE.SP_LOAD_ALL_RAW_DATA();

    -- Step 2: Transform to Silver layer
    CALL SILVER.SP_TRANSFORM_ALL_TO_SILVER();

    -- Step 3: Populate Gold layer
    CALL GOLD.SP_POPULATE_GOLD_LAYER();

    RETURN 'Full pipeline executed successfully: Bronze -> Silver -> Gold';
END;
$$;

-- ============================================================================
-- VERIFY MANAGEMENT OBJECTS
-- ============================================================================

SHOW VIEWS IN SCHEMA UTILS LIKE 'V_TASK%';
SHOW PROCEDURES IN SCHEMA UTILS LIKE 'SP_%TASK%';

SELECT 'Task management utilities created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
