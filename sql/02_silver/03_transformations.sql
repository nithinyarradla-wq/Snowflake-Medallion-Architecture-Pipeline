-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Silver Layer: Transformation Procedures
-- ============================================================================
-- This script creates stored procedures to transform data from Bronze
-- to Silver layer with data cleansing and business logic
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA SILVER;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- PROCEDURE: Transform Customers (Bronze to Silver)
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFORM_CUSTOMERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_records_processed NUMBER := 0;
    v_start_time TIMESTAMP_NTZ := CURRENT_TIMESTAMP();
BEGIN
    -- Merge transformed data from stream into Silver table
    MERGE INTO SILVER.CUSTOMERS AS tgt
    USING (
        SELECT
            -- Source fields
            CUSTOMER_ID,
            TRIM(FIRST_NAME) AS FIRST_NAME,
            TRIM(LAST_NAME) AS LAST_NAME,
            TRIM(FIRST_NAME) || ' ' || TRIM(LAST_NAME) AS FULL_NAME,

            -- Email transformations
            LOWER(TRIM(EMAIL)) AS EMAIL,
            SPLIT_PART(LOWER(TRIM(EMAIL)), '@', 2) AS EMAIL_DOMAIN,

            -- Phone formatting
            TRIM(PHONE) AS PHONE,
            REGEXP_REPLACE(PHONE, '[^0-9]', '') AS PHONE_FORMATTED,

            -- Address standardization
            TRIM(ADDRESS) AS ADDRESS,
            UPPER(TRIM(CITY)) AS CITY,
            UPPER(TRIM(STATE)) AS STATE,
            UPPER(LEFT(TRIM(STATE), 2)) AS STATE_CODE,
            TRIM(ZIP_CODE) AS ZIP_CODE,
            UPPER(TRIM(COUNTRY)) AS COUNTRY,
            CASE UPPER(TRIM(COUNTRY))
                WHEN 'UNITED STATES' THEN 'US'
                WHEN 'USA' THEN 'US'
                WHEN 'CANADA' THEN 'CA'
                WHEN 'UNITED KINGDOM' THEN 'UK'
                WHEN 'AUSTRALIA' THEN 'AU'
                ELSE LEFT(UPPER(TRIM(COUNTRY)), 2)
            END AS COUNTRY_CODE,

            -- Date transformations
            TRY_TO_DATE(REGISTRATION_DATE) AS REGISTRATION_DATE,
            UPPER(TRIM(CUSTOMER_SEGMENT)) AS CUSTOMER_SEGMENT,

            -- Derived fields
            CASE
                WHEN UPPER(TRIM(CUSTOMER_SEGMENT)) IN ('PREMIUM', 'VIP') THEN 'TIER_1'
                WHEN UPPER(TRIM(CUSTOMER_SEGMENT)) = 'REGULAR' THEN 'TIER_2'
                ELSE 'TIER_3'
            END AS CUSTOMER_TIER,
            DATEDIFF('day', TRY_TO_DATE(REGISTRATION_DATE), CURRENT_DATE()) AS DAYS_SINCE_REGISTRATION,

            -- Data quality flags
            CASE WHEN EMAIL LIKE '%@%.%' THEN TRUE ELSE FALSE END AS IS_EMAIL_VALID,
            CASE WHEN LENGTH(REGEXP_REPLACE(PHONE, '[^0-9]', '')) >= 10 THEN TRUE ELSE FALSE END AS IS_PHONE_VALID,

            -- DQ Score (simple scoring)
            ROUND((
                (CASE WHEN CUSTOMER_ID IS NOT NULL THEN 0.2 ELSE 0 END) +
                (CASE WHEN FIRST_NAME IS NOT NULL THEN 0.15 ELSE 0 END) +
                (CASE WHEN LAST_NAME IS NOT NULL THEN 0.15 ELSE 0 END) +
                (CASE WHEN EMAIL LIKE '%@%.%' THEN 0.2 ELSE 0 END) +
                (CASE WHEN PHONE IS NOT NULL THEN 0.15 ELSE 0 END) +
                (CASE WHEN CITY IS NOT NULL THEN 0.15 ELSE 0 END)
            ), 2) AS DQ_SCORE,

            -- Audit fields
            RECORD_ID AS SOURCE_RECORD_ID,
            FILENAME AS SOURCE_FILENAME,
            LOAD_TIMESTAMP AS BRONZE_LOAD_TS
        FROM BRONZE.STREAM_RAW_CUSTOMERS
        WHERE METADATA$ACTION = 'INSERT'
    ) AS src
    ON tgt.CUSTOMER_ID = src.CUSTOMER_ID

    -- Update existing records
    WHEN MATCHED THEN UPDATE SET
        FIRST_NAME = src.FIRST_NAME,
        LAST_NAME = src.LAST_NAME,
        FULL_NAME = src.FULL_NAME,
        EMAIL = src.EMAIL,
        EMAIL_DOMAIN = src.EMAIL_DOMAIN,
        PHONE = src.PHONE,
        PHONE_FORMATTED = src.PHONE_FORMATTED,
        ADDRESS = src.ADDRESS,
        CITY = src.CITY,
        STATE = src.STATE,
        STATE_CODE = src.STATE_CODE,
        ZIP_CODE = src.ZIP_CODE,
        COUNTRY = src.COUNTRY,
        COUNTRY_CODE = src.COUNTRY_CODE,
        REGISTRATION_DATE = src.REGISTRATION_DATE,
        CUSTOMER_SEGMENT = src.CUSTOMER_SEGMENT,
        CUSTOMER_TIER = src.CUSTOMER_TIER,
        DAYS_SINCE_REGISTRATION = src.DAYS_SINCE_REGISTRATION,
        IS_EMAIL_VALID = src.IS_EMAIL_VALID,
        IS_PHONE_VALID = src.IS_PHONE_VALID,
        DQ_SCORE = src.DQ_SCORE,
        SILVER_UPDATE_TS = CURRENT_TIMESTAMP()

    -- Insert new records
    WHEN NOT MATCHED THEN INSERT (
        CUSTOMER_ID, FIRST_NAME, LAST_NAME, FULL_NAME,
        EMAIL, EMAIL_DOMAIN, PHONE, PHONE_FORMATTED,
        ADDRESS, CITY, STATE, STATE_CODE, ZIP_CODE, COUNTRY, COUNTRY_CODE,
        REGISTRATION_DATE, CUSTOMER_SEGMENT, CUSTOMER_TIER, DAYS_SINCE_REGISTRATION,
        IS_EMAIL_VALID, IS_PHONE_VALID, DQ_SCORE,
        SOURCE_RECORD_ID, SOURCE_FILENAME, BRONZE_LOAD_TS
    ) VALUES (
        src.CUSTOMER_ID, src.FIRST_NAME, src.LAST_NAME, src.FULL_NAME,
        src.EMAIL, src.EMAIL_DOMAIN, src.PHONE, src.PHONE_FORMATTED,
        src.ADDRESS, src.CITY, src.STATE, src.STATE_CODE, src.ZIP_CODE, src.COUNTRY, src.COUNTRY_CODE,
        src.REGISTRATION_DATE, src.CUSTOMER_SEGMENT, src.CUSTOMER_TIER, src.DAYS_SINCE_REGISTRATION,
        src.IS_EMAIL_VALID, src.IS_PHONE_VALID, src.DQ_SCORE,
        src.SOURCE_RECORD_ID, src.SOURCE_FILENAME, src.BRONZE_LOAD_TS
    );

    v_records_processed := SQLROWCOUNT;

    RETURN 'Transformed ' || v_records_processed || ' customer records to Silver layer';
END;
$$;

-- ============================================================================
-- PROCEDURE: Transform Products (Bronze to Silver)
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFORM_PRODUCTS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_records_processed NUMBER := 0;
BEGIN
    MERGE INTO SILVER.PRODUCTS AS tgt
    USING (
        SELECT
            PRODUCT_ID,
            TRIM(PRODUCT_NAME) AS PRODUCT_NAME,
            REGEXP_REPLACE(UPPER(TRIM(PRODUCT_NAME)), '[^A-Z0-9 ]', '') AS PRODUCT_NAME_CLEAN,
            UPPER(TRIM(CATEGORY)) AS CATEGORY,
            UPPER(TRIM(SUBCATEGORY)) AS SUBCATEGORY,
            UPPER(TRIM(CATEGORY)) || ' > ' || UPPER(TRIM(SUBCATEGORY)) AS CATEGORY_PATH,
            UPPER(TRIM(BRAND)) AS BRAND,

            -- Pricing with validation
            TRY_TO_NUMBER(UNIT_PRICE, 18, 4) AS UNIT_PRICE,
            TRY_TO_NUMBER(UNIT_COST, 18, 4) AS UNIT_COST,
            TRY_TO_NUMBER(UNIT_PRICE, 18, 4) - TRY_TO_NUMBER(UNIT_COST, 18, 4) AS PROFIT_MARGIN,
            CASE
                WHEN TRY_TO_NUMBER(UNIT_PRICE, 18, 4) > 0
                THEN ROUND((TRY_TO_NUMBER(UNIT_PRICE, 18, 4) - TRY_TO_NUMBER(UNIT_COST, 18, 4)) /
                     TRY_TO_NUMBER(UNIT_PRICE, 18, 4) * 100, 2)
                ELSE 0
            END AS MARGIN_PERCENT,

            -- Weight conversions
            TRY_TO_NUMBER(WEIGHT_KG, 12, 4) AS WEIGHT_KG,
            ROUND(TRY_TO_NUMBER(WEIGHT_KG, 12, 4) * 2.20462, 4) AS WEIGHT_LBS,

            SUPPLIER_ID,
            UPPER(TRIM(IS_ACTIVE)) IN ('TRUE', 'YES', '1', 'Y') AS IS_ACTIVE,
            TRY_TO_DATE(CREATED_DATE) AS CREATED_DATE,
            TRY_TO_DATE(UPDATED_DATE) AS UPDATED_DATE,
            DATEDIFF('day', TRY_TO_DATE(CREATED_DATE), CURRENT_DATE()) AS DAYS_SINCE_CREATED,

            -- DQ Score
            ROUND((
                (CASE WHEN PRODUCT_ID IS NOT NULL THEN 0.2 ELSE 0 END) +
                (CASE WHEN PRODUCT_NAME IS NOT NULL THEN 0.2 ELSE 0 END) +
                (CASE WHEN CATEGORY IS NOT NULL THEN 0.15 ELSE 0 END) +
                (CASE WHEN TRY_TO_NUMBER(UNIT_PRICE, 18, 4) > 0 THEN 0.2 ELSE 0 END) +
                (CASE WHEN TRY_TO_NUMBER(UNIT_COST, 18, 4) > 0 THEN 0.15 ELSE 0 END) +
                (CASE WHEN BRAND IS NOT NULL THEN 0.1 ELSE 0 END)
            ), 2) AS DQ_SCORE,

            RECORD_ID AS SOURCE_RECORD_ID,
            FILENAME AS SOURCE_FILENAME,
            LOAD_TIMESTAMP AS BRONZE_LOAD_TS
        FROM BRONZE.STREAM_RAW_PRODUCTS
        WHERE METADATA$ACTION = 'INSERT'
    ) AS src
    ON tgt.PRODUCT_ID = src.PRODUCT_ID

    WHEN MATCHED THEN UPDATE SET
        PRODUCT_NAME = src.PRODUCT_NAME,
        PRODUCT_NAME_CLEAN = src.PRODUCT_NAME_CLEAN,
        CATEGORY = src.CATEGORY,
        SUBCATEGORY = src.SUBCATEGORY,
        CATEGORY_PATH = src.CATEGORY_PATH,
        BRAND = src.BRAND,
        UNIT_PRICE = src.UNIT_PRICE,
        UNIT_COST = src.UNIT_COST,
        PROFIT_MARGIN = src.PROFIT_MARGIN,
        MARGIN_PERCENT = src.MARGIN_PERCENT,
        WEIGHT_KG = src.WEIGHT_KG,
        WEIGHT_LBS = src.WEIGHT_LBS,
        SUPPLIER_ID = src.SUPPLIER_ID,
        IS_ACTIVE = src.IS_ACTIVE,
        UPDATED_DATE = src.UPDATED_DATE,
        DAYS_SINCE_CREATED = src.DAYS_SINCE_CREATED,
        DQ_SCORE = src.DQ_SCORE,
        SILVER_UPDATE_TS = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        PRODUCT_ID, PRODUCT_NAME, PRODUCT_NAME_CLEAN,
        CATEGORY, SUBCATEGORY, CATEGORY_PATH, BRAND,
        UNIT_PRICE, UNIT_COST, PROFIT_MARGIN, MARGIN_PERCENT,
        WEIGHT_KG, WEIGHT_LBS, SUPPLIER_ID, IS_ACTIVE,
        CREATED_DATE, UPDATED_DATE, DAYS_SINCE_CREATED, DQ_SCORE,
        SOURCE_RECORD_ID, SOURCE_FILENAME, BRONZE_LOAD_TS
    ) VALUES (
        src.PRODUCT_ID, src.PRODUCT_NAME, src.PRODUCT_NAME_CLEAN,
        src.CATEGORY, src.SUBCATEGORY, src.CATEGORY_PATH, src.BRAND,
        src.UNIT_PRICE, src.UNIT_COST, src.PROFIT_MARGIN, src.MARGIN_PERCENT,
        src.WEIGHT_KG, src.WEIGHT_LBS, src.SUPPLIER_ID, src.IS_ACTIVE,
        src.CREATED_DATE, src.UPDATED_DATE, src.DAYS_SINCE_CREATED, src.DQ_SCORE,
        src.SOURCE_RECORD_ID, src.SOURCE_FILENAME, src.BRONZE_LOAD_TS
    );

    v_records_processed := SQLROWCOUNT;

    RETURN 'Transformed ' || v_records_processed || ' product records to Silver layer';
END;
$$;

-- ============================================================================
-- PROCEDURE: Transform Orders (Bronze to Silver - with JSON flattening)
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFORM_ORDERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_orders_processed NUMBER := 0;
    v_items_processed NUMBER := 0;
BEGIN
    -- First, insert/update order headers
    MERGE INTO SILVER.ORDERS AS tgt
    USING (
        SELECT
            RAW_DATA:order_id::VARCHAR AS ORDER_ID,
            RAW_DATA:customer_id::VARCHAR AS CUSTOMER_ID,
            TRY_TO_DATE(RAW_DATA:order_date::VARCHAR) AS ORDER_DATE,
            TRY_TO_TIMESTAMP_NTZ(RAW_DATA:order_timestamp::VARCHAR) AS ORDER_TIMESTAMP,
            UPPER(RAW_DATA:order_status::VARCHAR) AS ORDER_STATUS,
            UPPER(RAW_DATA:priority::VARCHAR) AS ORDER_PRIORITY,

            TRY_TO_DATE(RAW_DATA:ship_date::VARCHAR) AS SHIP_DATE,
            RAW_DATA:ship_mode::VARCHAR AS SHIP_MODE,
            RAW_DATA:shipping:address::VARCHAR AS SHIPPING_ADDRESS,
            RAW_DATA:shipping:city::VARCHAR AS SHIPPING_CITY,
            RAW_DATA:shipping:state::VARCHAR AS SHIPPING_STATE,
            RAW_DATA:shipping:zip::VARCHAR AS SHIPPING_ZIP,
            RAW_DATA:shipping:country::VARCHAR AS SHIPPING_COUNTRY,

            RAW_DATA:totals:subtotal::NUMBER(18,4) AS SUBTOTAL,
            RAW_DATA:totals:discount::NUMBER(18,4) AS DISCOUNT_AMOUNT,
            CASE
                WHEN RAW_DATA:totals:subtotal::NUMBER > 0
                THEN ROUND(RAW_DATA:totals:discount::NUMBER / RAW_DATA:totals:subtotal::NUMBER * 100, 2)
                ELSE 0
            END AS DISCOUNT_PERCENT,
            RAW_DATA:totals:tax::NUMBER(18,4) AS TAX_AMOUNT,
            RAW_DATA:totals:shipping::NUMBER(18,4) AS SHIPPING_COST,
            RAW_DATA:totals:total::NUMBER(18,4) AS TOTAL_AMOUNT,

            ARRAY_SIZE(RAW_DATA:items) AS TOTAL_ITEMS,
            (SELECT SUM(VALUE:quantity::NUMBER) FROM TABLE(FLATTEN(RAW_DATA:items))) AS TOTAL_QUANTITY,
            (SELECT COUNT(DISTINCT VALUE:product_id::VARCHAR) FROM TABLE(FLATTEN(RAW_DATA:items))) AS UNIQUE_PRODUCTS,

            YEAR(TRY_TO_DATE(RAW_DATA:order_date::VARCHAR)) AS ORDER_YEAR,
            MONTH(TRY_TO_DATE(RAW_DATA:order_date::VARCHAR)) AS ORDER_MONTH,
            QUARTER(TRY_TO_DATE(RAW_DATA:order_date::VARCHAR)) AS ORDER_QUARTER,
            WEEKOFYEAR(TRY_TO_DATE(RAW_DATA:order_date::VARCHAR)) AS ORDER_WEEK,
            DAYOFWEEK(TRY_TO_DATE(RAW_DATA:order_date::VARCHAR)) AS ORDER_DAY_OF_WEEK,
            DAYOFWEEK(TRY_TO_DATE(RAW_DATA:order_date::VARCHAR)) IN (0, 6) AS IS_WEEKEND,

            0.95 AS DQ_SCORE,
            RECORD_ID AS SOURCE_RECORD_ID,
            FILENAME AS SOURCE_FILENAME,
            LOAD_TIMESTAMP AS BRONZE_LOAD_TS
        FROM BRONZE.STREAM_RAW_ORDERS
        WHERE METADATA$ACTION = 'INSERT'
    ) AS src
    ON tgt.ORDER_ID = src.ORDER_ID

    WHEN MATCHED THEN UPDATE SET
        ORDER_STATUS = src.ORDER_STATUS,
        SHIP_DATE = src.SHIP_DATE,
        TOTAL_AMOUNT = src.TOTAL_AMOUNT,
        SILVER_UPDATE_TS = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        ORDER_ID, CUSTOMER_ID, ORDER_DATE, ORDER_TIMESTAMP, ORDER_STATUS, ORDER_PRIORITY,
        SHIP_DATE, SHIP_MODE, SHIPPING_ADDRESS, SHIPPING_CITY, SHIPPING_STATE, SHIPPING_ZIP, SHIPPING_COUNTRY,
        SUBTOTAL, DISCOUNT_AMOUNT, DISCOUNT_PERCENT, TAX_AMOUNT, SHIPPING_COST, TOTAL_AMOUNT,
        TOTAL_ITEMS, TOTAL_QUANTITY, UNIQUE_PRODUCTS,
        ORDER_YEAR, ORDER_MONTH, ORDER_QUARTER, ORDER_WEEK, ORDER_DAY_OF_WEEK, IS_WEEKEND,
        DQ_SCORE, SOURCE_RECORD_ID, SOURCE_FILENAME, BRONZE_LOAD_TS
    ) VALUES (
        src.ORDER_ID, src.CUSTOMER_ID, src.ORDER_DATE, src.ORDER_TIMESTAMP, src.ORDER_STATUS, src.ORDER_PRIORITY,
        src.SHIP_DATE, src.SHIP_MODE, src.SHIPPING_ADDRESS, src.SHIPPING_CITY, src.SHIPPING_STATE, src.SHIPPING_ZIP, src.SHIPPING_COUNTRY,
        src.SUBTOTAL, src.DISCOUNT_AMOUNT, src.DISCOUNT_PERCENT, src.TAX_AMOUNT, src.SHIPPING_COST, src.TOTAL_AMOUNT,
        src.TOTAL_ITEMS, src.TOTAL_QUANTITY, src.UNIQUE_PRODUCTS,
        src.ORDER_YEAR, src.ORDER_MONTH, src.ORDER_QUARTER, src.ORDER_WEEK, src.ORDER_DAY_OF_WEEK, src.IS_WEEKEND,
        src.DQ_SCORE, src.SOURCE_RECORD_ID, src.SOURCE_FILENAME, src.BRONZE_LOAD_TS
    );

    v_orders_processed := SQLROWCOUNT;

    RETURN 'Transformed ' || v_orders_processed || ' orders to Silver layer';
END;
$$;

-- ============================================================================
-- PROCEDURE: Transform Order Items (Flatten from Orders JSON)
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFORM_ORDER_ITEMS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_records_processed NUMBER := 0;
BEGIN
    INSERT INTO SILVER.ORDER_ITEMS (
        ORDER_ID, PRODUCT_ID, LINE_NUMBER,
        QUANTITY, UNIT_PRICE, DISCOUNT_PERCENT,
        LINE_TOTAL, LINE_DISCOUNT, LINE_NET_AMOUNT,
        SOURCE_RECORD_ID
    )
    SELECT
        RAW_DATA:order_id::VARCHAR AS ORDER_ID,
        items.VALUE:product_id::VARCHAR AS PRODUCT_ID,
        items.INDEX + 1 AS LINE_NUMBER,
        items.VALUE:quantity::NUMBER AS QUANTITY,
        items.VALUE:unit_price::NUMBER(18,4) AS UNIT_PRICE,
        COALESCE(items.VALUE:discount_percent::NUMBER(8,4), 0) AS DISCOUNT_PERCENT,
        items.VALUE:quantity::NUMBER * items.VALUE:unit_price::NUMBER(18,4) AS LINE_TOTAL,
        ROUND(items.VALUE:quantity::NUMBER * items.VALUE:unit_price::NUMBER(18,4) *
              COALESCE(items.VALUE:discount_percent::NUMBER(8,4), 0) / 100, 4) AS LINE_DISCOUNT,
        ROUND(items.VALUE:quantity::NUMBER * items.VALUE:unit_price::NUMBER(18,4) *
              (1 - COALESCE(items.VALUE:discount_percent::NUMBER(8,4), 0) / 100), 4) AS LINE_NET_AMOUNT,
        RECORD_ID AS SOURCE_RECORD_ID
    FROM BRONZE.RAW_ORDERS,
         LATERAL FLATTEN(INPUT => RAW_DATA:items) AS items
    WHERE NOT EXISTS (
        SELECT 1 FROM SILVER.ORDER_ITEMS oi
        WHERE oi.ORDER_ID = RAW_DATA:order_id::VARCHAR
          AND oi.LINE_NUMBER = items.INDEX + 1
    );

    v_records_processed := SQLROWCOUNT;

    RETURN 'Transformed ' || v_records_processed || ' order items to Silver layer';
END;
$$;

-- ============================================================================
-- MASTER PROCEDURE: Transform All Bronze to Silver
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_TRANSFORM_ALL_TO_SILVER()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    CALL SP_TRANSFORM_CUSTOMERS();
    CALL SP_TRANSFORM_PRODUCTS();
    CALL SP_TRANSFORM_ORDERS();
    CALL SP_TRANSFORM_ORDER_ITEMS();

    RETURN 'All Bronze to Silver transformations completed successfully';
END;
$$;

-- ============================================================================
-- VERIFY PROCEDURES
-- ============================================================================

SHOW PROCEDURES IN SCHEMA SILVER;

SELECT 'Silver layer transformation procedures created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
