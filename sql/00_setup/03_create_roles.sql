-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Roles and Access Control Setup
-- ============================================================================
-- This script creates functional roles for the medallion architecture
-- following Snowflake's RBAC best practices
-- ============================================================================

USE ROLE SECURITYADMIN;

-- ============================================================================
-- CREATE FUNCTIONAL ROLES
-- ============================================================================

-- ETL Developer Role: Can create and manage pipeline objects
CREATE ROLE IF NOT EXISTS MEDALLION_ETL_DEVELOPER
    COMMENT = 'Role for ETL developers managing the medallion pipeline';

-- Data Analyst Role: Read access to Silver and Gold layers
CREATE ROLE IF NOT EXISTS MEDALLION_DATA_ANALYST
    COMMENT = 'Role for analysts querying Silver and Gold layers';

-- Data Engineer Role: Full access to all medallion layers
CREATE ROLE IF NOT EXISTS MEDALLION_DATA_ENGINEER
    COMMENT = 'Role for data engineers with full pipeline access';

-- Admin Role: Administrative access for pipeline management
CREATE ROLE IF NOT EXISTS MEDALLION_ADMIN
    COMMENT = 'Administrative role for medallion pipeline';

-- ============================================================================
-- CREATE ROLE HIERARCHY
-- ============================================================================

-- Build role hierarchy
GRANT ROLE MEDALLION_DATA_ANALYST TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT ROLE MEDALLION_ETL_DEVELOPER TO ROLE MEDALLION_DATA_ENGINEER;
GRANT ROLE MEDALLION_DATA_ENGINEER TO ROLE MEDALLION_ADMIN;
GRANT ROLE MEDALLION_ADMIN TO ROLE SYSADMIN;

-- ============================================================================
-- GRANT DATABASE PERMISSIONS
-- ============================================================================

USE ROLE SYSADMIN;

-- Grant database usage to all medallion roles
GRANT USAGE ON DATABASE MEDALLION_DB TO ROLE MEDALLION_DATA_ANALYST;
GRANT USAGE ON DATABASE MEDALLION_DB TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT USAGE ON DATABASE MEDALLION_DB TO ROLE MEDALLION_DATA_ENGINEER;
GRANT USAGE ON DATABASE MEDALLION_DB TO ROLE MEDALLION_ADMIN;

-- ============================================================================
-- GRANT SCHEMA PERMISSIONS
-- ============================================================================

-- Data Analyst: Read access to Silver and Gold
GRANT USAGE ON SCHEMA MEDALLION_DB.SILVER TO ROLE MEDALLION_DATA_ANALYST;
GRANT USAGE ON SCHEMA MEDALLION_DB.GOLD TO ROLE MEDALLION_DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA MEDALLION_DB.SILVER TO ROLE MEDALLION_DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA MEDALLION_DB.GOLD TO ROLE MEDALLION_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MEDALLION_DB.SILVER TO ROLE MEDALLION_DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MEDALLION_DB.GOLD TO ROLE MEDALLION_DATA_ANALYST;

-- ETL Developer: Full access to Bronze, read to Silver/Gold, create objects
GRANT USAGE ON SCHEMA MEDALLION_DB.BRONZE TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT USAGE ON SCHEMA MEDALLION_DB.UTILS TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT ALL PRIVILEGES ON SCHEMA MEDALLION_DB.BRONZE TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA MEDALLION_DB.BRONZE TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA MEDALLION_DB.BRONZE TO ROLE MEDALLION_ETL_DEVELOPER;

-- Data Engineer: Full access to all schemas
GRANT ALL PRIVILEGES ON SCHEMA MEDALLION_DB.BRONZE TO ROLE MEDALLION_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON SCHEMA MEDALLION_DB.SILVER TO ROLE MEDALLION_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON SCHEMA MEDALLION_DB.GOLD TO ROLE MEDALLION_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON SCHEMA MEDALLION_DB.UTILS TO ROLE MEDALLION_DATA_ENGINEER;

-- Admin: Full database privileges
GRANT ALL PRIVILEGES ON DATABASE MEDALLION_DB TO ROLE MEDALLION_ADMIN;

-- ============================================================================
-- GRANT WAREHOUSE PERMISSIONS
-- ============================================================================

-- Analysts use the analytics warehouse
GRANT USAGE ON WAREHOUSE MEDALLION_ANALYTICS_WH TO ROLE MEDALLION_DATA_ANALYST;

-- ETL Developers and Engineers use the ETL warehouse
GRANT USAGE ON WAREHOUSE MEDALLION_ETL_WH TO ROLE MEDALLION_ETL_DEVELOPER;
GRANT USAGE ON WAREHOUSE MEDALLION_ETL_WH TO ROLE MEDALLION_DATA_ENGINEER;

-- Admin has access to all warehouses
GRANT USAGE ON WAREHOUSE MEDALLION_ETL_WH TO ROLE MEDALLION_ADMIN;
GRANT USAGE ON WAREHOUSE MEDALLION_ANALYTICS_WH TO ROLE MEDALLION_ADMIN;
GRANT USAGE ON WAREHOUSE MEDALLION_TASK_WH TO ROLE MEDALLION_ADMIN;

-- ============================================================================
-- VERIFY SETUP
-- ============================================================================

SHOW ROLES LIKE 'MEDALLION%';

SELECT 'Roles and permissions created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
