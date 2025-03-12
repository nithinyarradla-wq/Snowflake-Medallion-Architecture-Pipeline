-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Silver Layer: Streams for Change Data Capture
-- ============================================================================
-- This script creates streams on Bronze layer tables to capture changes
-- for incremental processing into the Silver layer
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA SILVER;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- STREAMS ON BRONZE TABLES
-- ============================================================================

-- Stream on RAW_ORDERS for capturing new/changed orders
CREATE OR REPLACE STREAM BRONZE.STREAM_RAW_ORDERS
    ON TABLE BRONZE.RAW_ORDERS
    APPEND_ONLY = FALSE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for capturing changes to raw orders';

-- Stream on RAW_CUSTOMERS for capturing new/changed customers
CREATE OR REPLACE STREAM BRONZE.STREAM_RAW_CUSTOMERS
    ON TABLE BRONZE.RAW_CUSTOMERS
    APPEND_ONLY = FALSE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for capturing changes to raw customers';

-- Stream on RAW_PRODUCTS for capturing new/changed products
CREATE OR REPLACE STREAM BRONZE.STREAM_RAW_PRODUCTS
    ON TABLE BRONZE.RAW_PRODUCTS
    APPEND_ONLY = FALSE
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for capturing changes to raw products';

-- Stream on RAW_EVENTS for capturing new events
CREATE OR REPLACE STREAM BRONZE.STREAM_RAW_EVENTS
    ON TABLE BRONZE.RAW_EVENTS
    APPEND_ONLY = TRUE    -- Events are append-only by nature
    SHOW_INITIAL_ROWS = FALSE
    COMMENT = 'CDC stream for capturing new events (append-only)';

-- ============================================================================
-- HELPER VIEW: Check Stream Status
-- ============================================================================

CREATE OR REPLACE VIEW UTILS.V_STREAM_STATUS AS
SELECT
    'STREAM_RAW_ORDERS' AS STREAM_NAME,
    SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_ORDERS') AS HAS_DATA
UNION ALL
SELECT
    'STREAM_RAW_CUSTOMERS',
    SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_CUSTOMERS')
UNION ALL
SELECT
    'STREAM_RAW_PRODUCTS',
    SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_PRODUCTS')
UNION ALL
SELECT
    'STREAM_RAW_EVENTS',
    SYSTEM$STREAM_HAS_DATA('BRONZE.STREAM_RAW_EVENTS');

-- ============================================================================
-- VERIFY STREAMS
-- ============================================================================

SHOW STREAMS IN SCHEMA BRONZE;

SELECT 'Streams created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
