-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Warehouse Setup Script
-- ============================================================================
-- This script creates warehouses optimized for different workload types
-- in the medallion architecture pipeline
-- ============================================================================

USE ROLE SYSADMIN;

-- ============================================================================
-- CREATE WAREHOUSES
-- ============================================================================

-- ETL Warehouse: For data ingestion and transformation workloads
CREATE WAREHOUSE IF NOT EXISTS MEDALLION_ETL_WH
    WAREHOUSE_SIZE = 'SMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60                    -- Suspend after 1 minute of inactivity
    AUTO_RESUME = TRUE                   -- Auto-resume when queries are submitted
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for ETL operations - Bronze to Silver to Gold processing';

-- Analytics Warehouse: For reporting and analytics queries
CREATE WAREHOUSE IF NOT EXISTS MEDALLION_ANALYTICS_WH
    WAREHOUSE_SIZE = 'SMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 120                   -- Suspend after 2 minutes of inactivity
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 4
    SCALING_POLICY = 'ECONOMY'           -- Cost-optimized scaling
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for analytics and reporting queries on Gold layer';

-- Task Warehouse: Dedicated warehouse for automated tasks
CREATE WAREHOUSE IF NOT EXISTS MEDALLION_TASK_WH
    WAREHOUSE_SIZE = 'XSMALL'
    WAREHOUSE_TYPE = 'STANDARD'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for Snowflake Tasks automation';

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant warehouse usage to relevant roles
GRANT USAGE ON WAREHOUSE MEDALLION_ETL_WH TO ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE MEDALLION_ANALYTICS_WH TO ROLE SYSADMIN;
GRANT USAGE ON WAREHOUSE MEDALLION_TASK_WH TO ROLE SYSADMIN;

-- ============================================================================
-- SET DEFAULT WAREHOUSE FOR SESSION
-- ============================================================================

USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- VERIFY SETUP
-- ============================================================================

SHOW WAREHOUSES LIKE 'MEDALLION%';

SELECT 'Warehouses created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
