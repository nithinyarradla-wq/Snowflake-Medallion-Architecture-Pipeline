-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Bronze Layer: Raw Tables
-- ============================================================================
-- This script creates raw tables that store data exactly as ingested
-- from source systems with minimal transformations
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA BRONZE;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- RAW ORDERS TABLE (JSON Source)
-- ============================================================================

-- Raw orders table storing JSON as VARIANT
CREATE OR REPLACE TABLE RAW_ORDERS (
    -- Metadata columns
    RECORD_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    FILENAME            VARCHAR(500),
    FILE_ROW_NUMBER     NUMBER,
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Raw JSON data stored as VARIANT
    RAW_DATA            VARIANT NOT NULL,

    -- Extracted key fields for partitioning and querying
    ORDER_ID            VARCHAR(100) AS (RAW_DATA:order_id::VARCHAR),
    ORDER_DATE          DATE AS (TRY_TO_DATE(RAW_DATA:order_date::VARCHAR))
)
CLUSTER BY (ORDER_DATE)
COMMENT = 'Raw orders data ingested from JSON source files';

-- ============================================================================
-- RAW CUSTOMERS TABLE (CSV Source)
-- ============================================================================

CREATE OR REPLACE TABLE RAW_CUSTOMERS (
    -- Metadata columns
    RECORD_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    FILENAME            VARCHAR(500),
    FILE_ROW_NUMBER     NUMBER,
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Raw columns as VARCHAR to preserve source data
    CUSTOMER_ID         VARCHAR(100),
    FIRST_NAME          VARCHAR(500),
    LAST_NAME           VARCHAR(500),
    EMAIL               VARCHAR(500),
    PHONE               VARCHAR(100),
    ADDRESS             VARCHAR(1000),
    CITY                VARCHAR(200),
    STATE               VARCHAR(100),
    ZIP_CODE            VARCHAR(50),
    COUNTRY             VARCHAR(100),
    REGISTRATION_DATE   VARCHAR(100),
    CUSTOMER_SEGMENT    VARCHAR(100)
)
COMMENT = 'Raw customer data ingested from CSV source files';

-- ============================================================================
-- RAW PRODUCTS TABLE (CSV Source)
-- ============================================================================

CREATE OR REPLACE TABLE RAW_PRODUCTS (
    -- Metadata columns
    RECORD_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    FILENAME            VARCHAR(500),
    FILE_ROW_NUMBER     NUMBER,
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Raw columns as VARCHAR to preserve source data
    PRODUCT_ID          VARCHAR(100),
    PRODUCT_NAME        VARCHAR(500),
    CATEGORY            VARCHAR(200),
    SUBCATEGORY         VARCHAR(200),
    BRAND               VARCHAR(200),
    UNIT_PRICE          VARCHAR(100),
    UNIT_COST           VARCHAR(100),
    WEIGHT_KG           VARCHAR(100),
    SUPPLIER_ID         VARCHAR(100),
    IS_ACTIVE           VARCHAR(50),
    CREATED_DATE        VARCHAR(100),
    UPDATED_DATE        VARCHAR(100)
)
COMMENT = 'Raw product catalog data ingested from CSV source files';

-- ============================================================================
-- RAW EVENTS TABLE (JSON Source - for clickstream/events data)
-- ============================================================================

CREATE OR REPLACE TABLE RAW_EVENTS (
    -- Metadata columns
    RECORD_ID           NUMBER AUTOINCREMENT PRIMARY KEY,
    FILENAME            VARCHAR(500),
    FILE_ROW_NUMBER     NUMBER,
    LOAD_TIMESTAMP      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Raw JSON data
    RAW_DATA            VARIANT NOT NULL,

    -- Extracted key fields
    EVENT_ID            VARCHAR(100) AS (RAW_DATA:event_id::VARCHAR),
    EVENT_TYPE          VARCHAR(100) AS (RAW_DATA:event_type::VARCHAR),
    EVENT_TIMESTAMP     TIMESTAMP_NTZ AS (TRY_TO_TIMESTAMP_NTZ(RAW_DATA:event_timestamp::VARCHAR))
)
CLUSTER BY (TO_DATE(EVENT_TIMESTAMP))
COMMENT = 'Raw event/clickstream data ingested from JSON source files';

-- ============================================================================
-- CREATE SEQUENCES FOR BATCH TRACKING
-- ============================================================================

CREATE OR REPLACE SEQUENCE SEQ_BATCH_ID
    START = 1
    INCREMENT = 1
    COMMENT = 'Sequence for tracking data load batches';

-- ============================================================================
-- BATCH LOAD TRACKING TABLE
-- ============================================================================

CREATE OR REPLACE TABLE LOAD_BATCH_LOG (
    BATCH_ID            NUMBER DEFAULT SEQ_BATCH_ID.NEXTVAL PRIMARY KEY,
    TABLE_NAME          VARCHAR(200) NOT NULL,
    FILENAME            VARCHAR(500),
    RECORDS_LOADED      NUMBER,
    RECORDS_REJECTED    NUMBER DEFAULT 0,
    LOAD_START_TIME     TIMESTAMP_NTZ,
    LOAD_END_TIME       TIMESTAMP_NTZ,
    LOAD_STATUS         VARCHAR(50),
    ERROR_MESSAGE       VARCHAR(5000),
    LOADED_BY           VARCHAR(200) DEFAULT CURRENT_USER()
)
COMMENT = 'Tracking table for data load batches';

-- ============================================================================
-- VERIFY TABLES
-- ============================================================================

SHOW TABLES IN SCHEMA BRONZE;

SELECT 'Bronze layer raw tables created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
