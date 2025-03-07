-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Bronze Layer: Data Loading Procedures
-- ============================================================================
-- This script creates stored procedures for loading data from stages
-- into the Bronze layer raw tables
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA BRONZE;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- PROCEDURE: LOAD ORDERS FROM JSON STAGE
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_RAW_ORDERS(
    P_FILENAME VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_batch_id NUMBER;
    v_records_loaded NUMBER := 0;
    v_start_time TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    v_file_pattern VARCHAR;
BEGIN
    -- Set file pattern
    v_file_pattern := COALESCE(P_FILENAME, '.*\\.json');

    -- Get next batch ID
    v_batch_id := SEQ_BATCH_ID.NEXTVAL;

    -- Load data from stage
    COPY INTO RAW_ORDERS (FILENAME, FILE_ROW_NUMBER, RAW_DATA)
    FROM (
        SELECT
            METADATA$FILENAME,
            METADATA$FILE_ROW_NUMBER,
            $1
        FROM @STG_ORDERS
    )
    PATTERN = :v_file_pattern
    FILE_FORMAT = (FORMAT_NAME = 'UTILS.JSON_FORMAT')
    ON_ERROR = 'CONTINUE';

    -- Get count of loaded records
    v_records_loaded := SQLROWCOUNT;

    -- Log the batch
    INSERT INTO LOAD_BATCH_LOG (BATCH_ID, TABLE_NAME, FILENAME, RECORDS_LOADED,
                                LOAD_START_TIME, LOAD_END_TIME, LOAD_STATUS)
    VALUES (v_batch_id, 'RAW_ORDERS', v_file_pattern, v_records_loaded,
            v_start_time, CURRENT_TIMESTAMP(), 'SUCCESS');

    RETURN 'Loaded ' || v_records_loaded || ' records into RAW_ORDERS (Batch ID: ' || v_batch_id || ')';
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO LOAD_BATCH_LOG (BATCH_ID, TABLE_NAME, FILENAME, RECORDS_LOADED,
                                    LOAD_START_TIME, LOAD_END_TIME, LOAD_STATUS, ERROR_MESSAGE)
        VALUES (v_batch_id, 'RAW_ORDERS', v_file_pattern, 0,
                v_start_time, CURRENT_TIMESTAMP(), 'FAILED', SQLERRM);
        RAISE;
END;
$$;

-- ============================================================================
-- PROCEDURE: LOAD CUSTOMERS FROM CSV STAGE
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_RAW_CUSTOMERS(
    P_FILENAME VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_batch_id NUMBER;
    v_records_loaded NUMBER := 0;
    v_start_time TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    v_file_pattern VARCHAR;
BEGIN
    -- Set file pattern
    v_file_pattern := COALESCE(P_FILENAME, '.*\\.csv');

    -- Get next batch ID
    v_batch_id := SEQ_BATCH_ID.NEXTVAL;

    -- Load data from stage
    COPY INTO RAW_CUSTOMERS (
        FILENAME, FILE_ROW_NUMBER,
        CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE,
        ADDRESS, CITY, STATE, ZIP_CODE, COUNTRY,
        REGISTRATION_DATE, CUSTOMER_SEGMENT
    )
    FROM (
        SELECT
            METADATA$FILENAME,
            METADATA$FILE_ROW_NUMBER,
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
        FROM @STG_CUSTOMERS
    )
    PATTERN = :v_file_pattern
    FILE_FORMAT = (FORMAT_NAME = 'UTILS.CSV_FORMAT')
    ON_ERROR = 'CONTINUE';

    -- Get count of loaded records
    v_records_loaded := SQLROWCOUNT;

    -- Log the batch
    INSERT INTO LOAD_BATCH_LOG (BATCH_ID, TABLE_NAME, FILENAME, RECORDS_LOADED,
                                LOAD_START_TIME, LOAD_END_TIME, LOAD_STATUS)
    VALUES (v_batch_id, 'RAW_CUSTOMERS', v_file_pattern, v_records_loaded,
            v_start_time, CURRENT_TIMESTAMP(), 'SUCCESS');

    RETURN 'Loaded ' || v_records_loaded || ' records into RAW_CUSTOMERS (Batch ID: ' || v_batch_id || ')';
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO LOAD_BATCH_LOG (BATCH_ID, TABLE_NAME, FILENAME, RECORDS_LOADED,
                                    LOAD_START_TIME, LOAD_END_TIME, LOAD_STATUS, ERROR_MESSAGE)
        VALUES (v_batch_id, 'RAW_CUSTOMERS', v_file_pattern, 0,
                v_start_time, CURRENT_TIMESTAMP(), 'FAILED', SQLERRM);
        RAISE;
END;
$$;

-- ============================================================================
-- PROCEDURE: LOAD PRODUCTS FROM CSV STAGE
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_RAW_PRODUCTS(
    P_FILENAME VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_batch_id NUMBER;
    v_records_loaded NUMBER := 0;
    v_start_time TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
    v_file_pattern VARCHAR;
BEGIN
    -- Set file pattern
    v_file_pattern := COALESCE(P_FILENAME, '.*\\.csv');

    -- Get next batch ID
    v_batch_id := SEQ_BATCH_ID.NEXTVAL;

    -- Load data from stage
    COPY INTO RAW_PRODUCTS (
        FILENAME, FILE_ROW_NUMBER,
        PRODUCT_ID, PRODUCT_NAME, CATEGORY, SUBCATEGORY, BRAND,
        UNIT_PRICE, UNIT_COST, WEIGHT_KG, SUPPLIER_ID,
        IS_ACTIVE, CREATED_DATE, UPDATED_DATE
    )
    FROM (
        SELECT
            METADATA$FILENAME,
            METADATA$FILE_ROW_NUMBER,
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
        FROM @STG_PRODUCTS
    )
    PATTERN = :v_file_pattern
    FILE_FORMAT = (FORMAT_NAME = 'UTILS.CSV_FORMAT')
    ON_ERROR = 'CONTINUE';

    -- Get count of loaded records
    v_records_loaded := SQLROWCOUNT;

    -- Log the batch
    INSERT INTO LOAD_BATCH_LOG (BATCH_ID, TABLE_NAME, FILENAME, RECORDS_LOADED,
                                LOAD_START_TIME, LOAD_END_TIME, LOAD_STATUS)
    VALUES (v_batch_id, 'RAW_PRODUCTS', v_file_pattern, v_records_loaded,
            v_start_time, CURRENT_TIMESTAMP(), 'SUCCESS');

    RETURN 'Loaded ' || v_records_loaded || ' records into RAW_PRODUCTS (Batch ID: ' || v_batch_id || ')';
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO LOAD_BATCH_LOG (BATCH_ID, TABLE_NAME, FILENAME, RECORDS_LOADED,
                                    LOAD_START_TIME, LOAD_END_TIME, LOAD_STATUS, ERROR_MESSAGE)
        VALUES (v_batch_id, 'RAW_PRODUCTS', v_file_pattern, 0,
                v_start_time, CURRENT_TIMESTAMP(), 'FAILED', SQLERRM);
        RAISE;
END;
$$;

-- ============================================================================
-- PROCEDURE: MASTER LOAD PROCEDURE (Load all sources)
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_LOAD_ALL_RAW_DATA()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_result_orders VARCHAR;
    v_result_customers VARCHAR;
    v_result_products VARCHAR;
BEGIN
    -- Load orders
    CALL SP_LOAD_RAW_ORDERS(NULL);
    v_result_orders := 'Orders loaded';

    -- Load customers
    CALL SP_LOAD_RAW_CUSTOMERS(NULL);
    v_result_customers := 'Customers loaded';

    -- Load products
    CALL SP_LOAD_RAW_PRODUCTS(NULL);
    v_result_products := 'Products loaded';

    RETURN 'All raw data loaded successfully: ' ||
           v_result_orders || ', ' ||
           v_result_customers || ', ' ||
           v_result_products;
END;
$$;

-- ============================================================================
-- VERIFY PROCEDURES
-- ============================================================================

SHOW PROCEDURES IN SCHEMA BRONZE;

SELECT 'Bronze layer load procedures created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
