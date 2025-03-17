-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Gold Layer: Aggregation Procedures
-- ============================================================================
-- This script creates procedures to populate Gold layer fact tables
-- from Silver layer data
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA GOLD;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- PROCEDURE: Populate Customer Dimension
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_POPULATE_DIM_CUSTOMER()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_records_processed NUMBER := 0;
BEGIN
    -- SCD Type 1: Overwrite with latest data
    MERGE INTO GOLD.DIM_CUSTOMER AS tgt
    USING (
        SELECT
            CUSTOMER_SK,
            CUSTOMER_ID,
            CUSTOMER_ID AS CUSTOMER_BK,
            FULL_NAME,
            EMAIL,
            EMAIL_DOMAIN,
            PHONE_FORMATTED AS PHONE,
            CITY,
            STATE,
            STATE_CODE,
            COUNTRY,
            COUNTRY_CODE,
            CASE
                WHEN STATE IN ('CA', 'OR', 'WA', 'NV', 'AZ') THEN 'West'
                WHEN STATE IN ('TX', 'OK', 'NM', 'AR', 'LA') THEN 'South'
                WHEN STATE IN ('NY', 'NJ', 'PA', 'MA', 'CT') THEN 'Northeast'
                ELSE 'Midwest'
            END AS REGION,
            CUSTOMER_SEGMENT,
            CUSTOMER_TIER,
            REGISTRATION_DATE,
            DAYS_SINCE_REGISTRATION AS CUSTOMER_TENURE_DAYS,
            CASE
                WHEN DAYS_SINCE_REGISTRATION <= 30 THEN 'New (0-30 days)'
                WHEN DAYS_SINCE_REGISTRATION <= 90 THEN 'Recent (31-90 days)'
                WHEN DAYS_SINCE_REGISTRATION <= 365 THEN 'Established (91-365 days)'
                ELSE 'Loyal (365+ days)'
            END AS TENURE_BAND,
            IS_CURRENT AS IS_ACTIVE,
            IS_EMAIL_VALID
        FROM SILVER.CUSTOMERS
        WHERE IS_CURRENT = TRUE
    ) AS src
    ON tgt.CUSTOMER_ID = src.CUSTOMER_ID AND tgt.IS_CURRENT = TRUE

    WHEN MATCHED THEN UPDATE SET
        FULL_NAME = src.FULL_NAME,
        EMAIL = src.EMAIL,
        EMAIL_DOMAIN = src.EMAIL_DOMAIN,
        PHONE = src.PHONE,
        CITY = src.CITY,
        STATE = src.STATE,
        STATE_CODE = src.STATE_CODE,
        COUNTRY = src.COUNTRY,
        COUNTRY_CODE = src.COUNTRY_CODE,
        REGION = src.REGION,
        CUSTOMER_SEGMENT = src.CUSTOMER_SEGMENT,
        CUSTOMER_TIER = src.CUSTOMER_TIER,
        CUSTOMER_TENURE_DAYS = src.CUSTOMER_TENURE_DAYS,
        TENURE_BAND = src.TENURE_BAND,
        IS_ACTIVE = src.IS_ACTIVE,
        IS_EMAIL_VALID = src.IS_EMAIL_VALID,
        UPDATED_TS = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        CUSTOMER_SK, CUSTOMER_ID, CUSTOMER_BK, FULL_NAME, EMAIL, EMAIL_DOMAIN, PHONE,
        CITY, STATE, STATE_CODE, COUNTRY, COUNTRY_CODE, REGION,
        CUSTOMER_SEGMENT, CUSTOMER_TIER, REGISTRATION_DATE, CUSTOMER_TENURE_DAYS, TENURE_BAND,
        IS_ACTIVE, IS_EMAIL_VALID
    ) VALUES (
        src.CUSTOMER_SK, src.CUSTOMER_ID, src.CUSTOMER_BK, src.FULL_NAME, src.EMAIL, src.EMAIL_DOMAIN, src.PHONE,
        src.CITY, src.STATE, src.STATE_CODE, src.COUNTRY, src.COUNTRY_CODE, src.REGION,
        src.CUSTOMER_SEGMENT, src.CUSTOMER_TIER, src.REGISTRATION_DATE, src.CUSTOMER_TENURE_DAYS, src.TENURE_BAND,
        src.IS_ACTIVE, src.IS_EMAIL_VALID
    );

    v_records_processed := SQLROWCOUNT;
    RETURN 'Processed ' || v_records_processed || ' customer dimension records';
END;
$$;

-- ============================================================================
-- PROCEDURE: Populate Product Dimension
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_POPULATE_DIM_PRODUCT()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_records_processed NUMBER := 0;
BEGIN
    MERGE INTO GOLD.DIM_PRODUCT AS tgt
    USING (
        SELECT
            PRODUCT_SK,
            PRODUCT_ID,
            PRODUCT_ID AS PRODUCT_BK,
            PRODUCT_NAME,
            CATEGORY,
            SUBCATEGORY,
            CATEGORY_PATH,
            BRAND,
            UNIT_PRICE,
            UNIT_COST,
            PROFIT_MARGIN,
            MARGIN_PERCENT,
            CASE
                WHEN UNIT_PRICE < 25 THEN 'Budget'
                WHEN UNIT_PRICE < 100 THEN 'Mid-Range'
                WHEN UNIT_PRICE < 500 THEN 'Premium'
                ELSE 'Luxury'
            END AS PRICE_BAND,
            WEIGHT_KG,
            SUPPLIER_ID,
            IS_ACTIVE
        FROM SILVER.PRODUCTS
        WHERE IS_CURRENT = TRUE
    ) AS src
    ON tgt.PRODUCT_ID = src.PRODUCT_ID AND tgt.IS_CURRENT = TRUE

    WHEN MATCHED THEN UPDATE SET
        PRODUCT_NAME = src.PRODUCT_NAME,
        CATEGORY = src.CATEGORY,
        SUBCATEGORY = src.SUBCATEGORY,
        CATEGORY_PATH = src.CATEGORY_PATH,
        BRAND = src.BRAND,
        UNIT_PRICE = src.UNIT_PRICE,
        UNIT_COST = src.UNIT_COST,
        PROFIT_MARGIN = src.PROFIT_MARGIN,
        MARGIN_PERCENT = src.MARGIN_PERCENT,
        PRICE_BAND = src.PRICE_BAND,
        WEIGHT_KG = src.WEIGHT_KG,
        SUPPLIER_ID = src.SUPPLIER_ID,
        IS_ACTIVE = src.IS_ACTIVE,
        UPDATED_TS = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        PRODUCT_SK, PRODUCT_ID, PRODUCT_BK, PRODUCT_NAME, CATEGORY, SUBCATEGORY, CATEGORY_PATH, BRAND,
        UNIT_PRICE, UNIT_COST, PROFIT_MARGIN, MARGIN_PERCENT, PRICE_BAND, WEIGHT_KG, SUPPLIER_ID, IS_ACTIVE
    ) VALUES (
        src.PRODUCT_SK, src.PRODUCT_ID, src.PRODUCT_BK, src.PRODUCT_NAME, src.CATEGORY, src.SUBCATEGORY, src.CATEGORY_PATH, src.BRAND,
        src.UNIT_PRICE, src.UNIT_COST, src.PROFIT_MARGIN, src.MARGIN_PERCENT, src.PRICE_BAND, src.WEIGHT_KG, src.SUPPLIER_ID, src.IS_ACTIVE
    );

    v_records_processed := SQLROWCOUNT;
    RETURN 'Processed ' || v_records_processed || ' product dimension records';
END;
$$;

-- ============================================================================
-- PROCEDURE: Populate Sales Fact
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_POPULATE_FACT_SALES()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_records_processed NUMBER := 0;
BEGIN
    MERGE INTO GOLD.FACT_SALES AS tgt
    USING (
        SELECT
            o.ORDER_ID,
            TO_NUMBER(TO_CHAR(o.ORDER_DATE, 'YYYYMMDD')) AS DATE_SK,
            c.CUSTOMER_SK,
            NULL AS PRODUCT_SK,  -- Order level, no single product
            g.GEOGRAPHY_SK,
            o.ORDER_DATE,
            o.CUSTOMER_ID,
            o.ORDER_STATUS,
            o.ORDER_PRIORITY,
            o.SHIP_MODE,
            o.TOTAL_ITEMS,
            o.TOTAL_QUANTITY,
            o.UNIQUE_PRODUCTS,
            o.SUBTOTAL,
            o.DISCOUNT_AMOUNT,
            o.DISCOUNT_PERCENT,
            o.TAX_AMOUNT,
            o.SHIPPING_COST,
            o.TOTAL_AMOUNT,
            o.SUBTOTAL * 0.30 AS PROFIT_AMOUNT,  -- Estimated 30% profit margin
            DATEDIFF('day', o.ORDER_DATE, o.SHIP_DATE) AS DAYS_TO_SHIP,
            o.ORDER_SK AS SOURCE_ORDER_SK
        FROM SILVER.ORDERS o
        LEFT JOIN GOLD.DIM_CUSTOMER c ON o.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE
        LEFT JOIN GOLD.DIM_GEOGRAPHY g ON o.SHIPPING_CITY = g.CITY AND o.SHIPPING_STATE = g.STATE
    ) AS src
    ON tgt.ORDER_ID = src.ORDER_ID

    WHEN MATCHED THEN UPDATE SET
        ORDER_STATUS = src.ORDER_STATUS,
        TOTAL_AMOUNT = src.TOTAL_AMOUNT,
        DAYS_TO_SHIP = src.DAYS_TO_SHIP,
        ETL_LOAD_TS = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        ORDER_ID, DATE_SK, CUSTOMER_SK, PRODUCT_SK, GEOGRAPHY_SK,
        ORDER_DATE, CUSTOMER_ID, ORDER_STATUS, ORDER_PRIORITY, SHIP_MODE,
        TOTAL_ITEMS, TOTAL_QUANTITY, UNIQUE_PRODUCTS,
        SUBTOTAL, DISCOUNT_AMOUNT, DISCOUNT_PERCENT, TAX_AMOUNT, SHIPPING_COST, TOTAL_AMOUNT, PROFIT_AMOUNT,
        DAYS_TO_SHIP, SOURCE_ORDER_SK
    ) VALUES (
        src.ORDER_ID, src.DATE_SK, src.CUSTOMER_SK, src.PRODUCT_SK, src.GEOGRAPHY_SK,
        src.ORDER_DATE, src.CUSTOMER_ID, src.ORDER_STATUS, src.ORDER_PRIORITY, src.SHIP_MODE,
        src.TOTAL_ITEMS, src.TOTAL_QUANTITY, src.UNIQUE_PRODUCTS,
        src.SUBTOTAL, src.DISCOUNT_AMOUNT, src.DISCOUNT_PERCENT, src.TAX_AMOUNT, src.SHIPPING_COST, src.TOTAL_AMOUNT, src.PROFIT_AMOUNT,
        src.DAYS_TO_SHIP, src.SOURCE_ORDER_SK
    );

    v_records_processed := SQLROWCOUNT;
    RETURN 'Processed ' || v_records_processed || ' sales fact records';
END;
$$;

-- ============================================================================
-- PROCEDURE: Populate Daily Sales Snapshot
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_POPULATE_DAILY_SALES(P_DATE DATE DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_target_date DATE;
    v_records_processed NUMBER := 0;
BEGIN
    v_target_date := COALESCE(P_DATE, CURRENT_DATE() - 1);

    MERGE INTO GOLD.FACT_DAILY_SALES AS tgt
    USING (
        SELECT
            TO_NUMBER(TO_CHAR(ORDER_DATE, 'YYYYMMDD')) AS DATE_SK,
            ORDER_DATE AS SNAPSHOT_DATE,
            COUNT(DISTINCT ORDER_ID) AS TOTAL_ORDERS,
            COUNT(DISTINCT CUSTOMER_ID) AS TOTAL_CUSTOMERS,
            0 AS NEW_CUSTOMERS,  -- Would need customer registration date logic
            SUM(TOTAL_ITEMS) AS TOTAL_ITEMS_SOLD,
            SUM(TOTAL_QUANTITY) AS TOTAL_QUANTITY,
            SUM(SUBTOTAL) AS GROSS_REVENUE,
            SUM(DISCOUNT_AMOUNT) AS TOTAL_DISCOUNTS,
            SUM(TOTAL_AMOUNT) AS NET_REVENUE,
            SUM(TAX_AMOUNT) AS TOTAL_TAX,
            SUM(SHIPPING_COST) AS TOTAL_SHIPPING,
            AVG(TOTAL_AMOUNT) AS AVG_ORDER_VALUE,
            AVG(TOTAL_ITEMS) AS AVG_ITEMS_PER_ORDER,
            AVG(DISCOUNT_PERCENT) AS AVG_DISCOUNT_PERCENT,
            SUM(UNIQUE_PRODUCTS) AS UNIQUE_PRODUCTS_SOLD
        FROM SILVER.ORDERS
        WHERE ORDER_DATE = :v_target_date
        GROUP BY ORDER_DATE
    ) AS src
    ON tgt.DATE_SK = src.DATE_SK

    WHEN MATCHED THEN UPDATE SET
        TOTAL_ORDERS = src.TOTAL_ORDERS,
        TOTAL_CUSTOMERS = src.TOTAL_CUSTOMERS,
        TOTAL_ITEMS_SOLD = src.TOTAL_ITEMS_SOLD,
        TOTAL_QUANTITY = src.TOTAL_QUANTITY,
        GROSS_REVENUE = src.GROSS_REVENUE,
        TOTAL_DISCOUNTS = src.TOTAL_DISCOUNTS,
        NET_REVENUE = src.NET_REVENUE,
        TOTAL_TAX = src.TOTAL_TAX,
        TOTAL_SHIPPING = src.TOTAL_SHIPPING,
        AVG_ORDER_VALUE = src.AVG_ORDER_VALUE,
        AVG_ITEMS_PER_ORDER = src.AVG_ITEMS_PER_ORDER,
        AVG_DISCOUNT_PERCENT = src.AVG_DISCOUNT_PERCENT,
        UNIQUE_PRODUCTS_SOLD = src.UNIQUE_PRODUCTS_SOLD,
        ETL_LOAD_TS = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        DATE_SK, SNAPSHOT_DATE, TOTAL_ORDERS, TOTAL_CUSTOMERS, NEW_CUSTOMERS,
        TOTAL_ITEMS_SOLD, TOTAL_QUANTITY, GROSS_REVENUE, TOTAL_DISCOUNTS, NET_REVENUE,
        TOTAL_TAX, TOTAL_SHIPPING, AVG_ORDER_VALUE, AVG_ITEMS_PER_ORDER, AVG_DISCOUNT_PERCENT,
        UNIQUE_PRODUCTS_SOLD
    ) VALUES (
        src.DATE_SK, src.SNAPSHOT_DATE, src.TOTAL_ORDERS, src.TOTAL_CUSTOMERS, src.NEW_CUSTOMERS,
        src.TOTAL_ITEMS_SOLD, src.TOTAL_QUANTITY, src.GROSS_REVENUE, src.TOTAL_DISCOUNTS, src.NET_REVENUE,
        src.TOTAL_TAX, src.TOTAL_SHIPPING, src.AVG_ORDER_VALUE, src.AVG_ITEMS_PER_ORDER, src.AVG_DISCOUNT_PERCENT,
        src.UNIQUE_PRODUCTS_SOLD
    );

    v_records_processed := SQLROWCOUNT;
    RETURN 'Processed daily snapshot for ' || v_target_date || ' (' || v_records_processed || ' records)';
END;
$$;

-- ============================================================================
-- MASTER PROCEDURE: Populate All Gold Layer
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_POPULATE_GOLD_LAYER()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    CALL SP_POPULATE_DIM_CUSTOMER();
    CALL SP_POPULATE_DIM_PRODUCT();
    CALL SP_POPULATE_FACT_SALES();
    CALL SP_POPULATE_DAILY_SALES(NULL);

    RETURN 'Gold layer population completed successfully';
END;
$$;

-- ============================================================================
-- VERIFY PROCEDURES
-- ============================================================================

SHOW PROCEDURES IN SCHEMA GOLD;

SELECT 'Gold layer aggregation procedures created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
