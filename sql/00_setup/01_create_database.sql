-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Database Setup Script
-- ============================================================================
-- This script creates the main database and schemas for the medallion
-- architecture (Bronze, Silver, Gold layers)
-- ============================================================================

-- Use ACCOUNTADMIN role for initial setup
USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- CREATE DATABASE
-- ============================================================================

CREATE DATABASE IF NOT EXISTS MEDALLION_DB
    COMMENT = 'Medallion Architecture Database - Bronze, Silver, Gold layers';

-- Grant usage to SYSADMIN for ongoing management
GRANT USAGE ON DATABASE MEDALLION_DB TO ROLE SYSADMIN;
GRANT CREATE SCHEMA ON DATABASE MEDALLION_DB TO ROLE SYSADMIN;

-- Switch to SYSADMIN for remaining operations
USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;

-- ============================================================================
-- CREATE SCHEMAS
-- ============================================================================

-- Bronze Schema: Raw data ingestion layer
CREATE SCHEMA IF NOT EXISTS BRONZE
    COMMENT = 'Bronze layer - Raw data as ingested from source systems';

-- Silver Schema: Cleansed and transformed data layer
CREATE SCHEMA IF NOT EXISTS SILVER
    COMMENT = 'Silver layer - Cleansed, validated, and transformed data';

-- Gold Schema: Business-ready analytics layer
CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Gold layer - Aggregated, business-ready analytics data';

-- Utility Schema: For staging areas and utilities
CREATE SCHEMA IF NOT EXISTS UTILS
    COMMENT = 'Utility schema for file formats, stages, and helper objects';

-- ============================================================================
-- VERIFY SETUP
-- ============================================================================

SHOW SCHEMAS IN DATABASE MEDALLION_DB;

-- Log completion
SELECT 'Database and schemas created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
