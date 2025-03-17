-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Gold Layer: Dimension Tables
-- ============================================================================
-- This script creates dimension tables for the star schema analytics layer
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA GOLD;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- DATE DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE DIM_DATE (
    DATE_SK             NUMBER PRIMARY KEY,
    FULL_DATE           DATE NOT NULL,

    -- Date components
    YEAR                NUMBER(4),
    QUARTER             NUMBER(1),
    MONTH               NUMBER(2),
    MONTH_NAME          VARCHAR(20),
    MONTH_ABBR          VARCHAR(3),
    WEEK_OF_YEAR        NUMBER(2),
    DAY_OF_YEAR         NUMBER(3),
    DAY_OF_MONTH        NUMBER(2),
    DAY_OF_WEEK         NUMBER(1),
    DAY_NAME            VARCHAR(20),
    DAY_ABBR            VARCHAR(3),

    -- Fiscal calendar (assuming fiscal year starts in January)
    FISCAL_YEAR         NUMBER(4),
    FISCAL_QUARTER      NUMBER(1),
    FISCAL_MONTH        NUMBER(2),

    -- Flags
    IS_WEEKEND          BOOLEAN,
    IS_HOLIDAY          BOOLEAN DEFAULT FALSE,
    IS_BUSINESS_DAY     BOOLEAN,

    -- Period names
    YEAR_MONTH          VARCHAR(7),
    YEAR_QUARTER        VARCHAR(7),
    YEAR_WEEK           VARCHAR(8),

    -- For comparison
    SAME_DAY_LAST_YEAR  DATE,
    SAME_DAY_LAST_MONTH DATE
)
COMMENT = 'Date dimension for time-based analytics';

-- Populate date dimension (5 years: 2020-2025)
INSERT INTO DIM_DATE
SELECT
    TO_NUMBER(TO_CHAR(d.DATE_VALUE, 'YYYYMMDD')) AS DATE_SK,
    d.DATE_VALUE AS FULL_DATE,

    YEAR(d.DATE_VALUE) AS YEAR,
    QUARTER(d.DATE_VALUE) AS QUARTER,
    MONTH(d.DATE_VALUE) AS MONTH,
    MONTHNAME(d.DATE_VALUE) AS MONTH_NAME,
    LEFT(MONTHNAME(d.DATE_VALUE), 3) AS MONTH_ABBR,
    WEEKOFYEAR(d.DATE_VALUE) AS WEEK_OF_YEAR,
    DAYOFYEAR(d.DATE_VALUE) AS DAY_OF_YEAR,
    DAY(d.DATE_VALUE) AS DAY_OF_MONTH,
    DAYOFWEEK(d.DATE_VALUE) AS DAY_OF_WEEK,
    DAYNAME(d.DATE_VALUE) AS DAY_NAME,
    LEFT(DAYNAME(d.DATE_VALUE), 3) AS DAY_ABBR,

    YEAR(d.DATE_VALUE) AS FISCAL_YEAR,
    QUARTER(d.DATE_VALUE) AS FISCAL_QUARTER,
    MONTH(d.DATE_VALUE) AS FISCAL_MONTH,

    DAYOFWEEK(d.DATE_VALUE) IN (0, 6) AS IS_WEEKEND,
    FALSE AS IS_HOLIDAY,
    DAYOFWEEK(d.DATE_VALUE) NOT IN (0, 6) AS IS_BUSINESS_DAY,

    TO_CHAR(d.DATE_VALUE, 'YYYY-MM') AS YEAR_MONTH,
    YEAR(d.DATE_VALUE) || '-Q' || QUARTER(d.DATE_VALUE) AS YEAR_QUARTER,
    YEAR(d.DATE_VALUE) || '-W' || LPAD(WEEKOFYEAR(d.DATE_VALUE), 2, '0') AS YEAR_WEEK,

    DATEADD('year', -1, d.DATE_VALUE) AS SAME_DAY_LAST_YEAR,
    DATEADD('month', -1, d.DATE_VALUE) AS SAME_DAY_LAST_MONTH
FROM (
    SELECT DATEADD('day', SEQ4(), '2020-01-01'::DATE) AS DATE_VALUE
    FROM TABLE(GENERATOR(ROWCOUNT => 2192))  -- ~6 years of dates
) d
WHERE d.DATE_VALUE <= '2025-12-31';

-- ============================================================================
-- CUSTOMER DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE DIM_CUSTOMER (
    CUSTOMER_SK         NUMBER PRIMARY KEY,
    CUSTOMER_ID         VARCHAR(100) NOT NULL,
    CUSTOMER_BK         VARCHAR(100),  -- Business Key

    -- Customer attributes
    FULL_NAME           VARCHAR(500),
    EMAIL               VARCHAR(500),
    EMAIL_DOMAIN        VARCHAR(200),
    PHONE               VARCHAR(50),

    -- Geography
    CITY                VARCHAR(200),
    STATE               VARCHAR(100),
    STATE_CODE          VARCHAR(10),
    COUNTRY             VARCHAR(100),
    COUNTRY_CODE        VARCHAR(10),
    REGION              VARCHAR(100),

    -- Segmentation
    CUSTOMER_SEGMENT    VARCHAR(50),
    CUSTOMER_TIER       VARCHAR(50),
    REGISTRATION_DATE   DATE,
    CUSTOMER_TENURE_DAYS NUMBER,
    TENURE_BAND         VARCHAR(50),

    -- Flags
    IS_ACTIVE           BOOLEAN DEFAULT TRUE,
    IS_EMAIL_VALID      BOOLEAN,

    -- SCD Type 2 columns
    EFFECTIVE_DATE      DATE DEFAULT CURRENT_DATE(),
    EXPIRATION_DATE     DATE DEFAULT '9999-12-31',
    IS_CURRENT          BOOLEAN DEFAULT TRUE,

    -- Audit
    CREATED_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT UK_DIM_CUSTOMER_BK UNIQUE (CUSTOMER_ID, EFFECTIVE_DATE)
)
COMMENT = 'Customer dimension with SCD Type 2 support';

-- ============================================================================
-- PRODUCT DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE DIM_PRODUCT (
    PRODUCT_SK          NUMBER PRIMARY KEY,
    PRODUCT_ID          VARCHAR(100) NOT NULL,
    PRODUCT_BK          VARCHAR(100),  -- Business Key

    -- Product attributes
    PRODUCT_NAME        VARCHAR(500),
    CATEGORY            VARCHAR(200),
    SUBCATEGORY         VARCHAR(200),
    CATEGORY_PATH       VARCHAR(500),
    BRAND               VARCHAR(200),

    -- Pricing
    UNIT_PRICE          NUMBER(18,4),
    UNIT_COST           NUMBER(18,4),
    PROFIT_MARGIN       NUMBER(18,4),
    MARGIN_PERCENT      NUMBER(8,4),
    PRICE_BAND          VARCHAR(50),

    -- Physical
    WEIGHT_KG           NUMBER(12,4),

    -- Status
    SUPPLIER_ID         VARCHAR(100),
    IS_ACTIVE           BOOLEAN,

    -- SCD Type 2 columns
    EFFECTIVE_DATE      DATE DEFAULT CURRENT_DATE(),
    EXPIRATION_DATE     DATE DEFAULT '9999-12-31',
    IS_CURRENT          BOOLEAN DEFAULT TRUE,

    -- Audit
    CREATED_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_TS          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    CONSTRAINT UK_DIM_PRODUCT_BK UNIQUE (PRODUCT_ID, EFFECTIVE_DATE)
)
COMMENT = 'Product dimension with SCD Type 2 support';

-- ============================================================================
-- GEOGRAPHY DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE DIM_GEOGRAPHY (
    GEOGRAPHY_SK        NUMBER AUTOINCREMENT PRIMARY KEY,
    CITY                VARCHAR(200),
    STATE               VARCHAR(100),
    STATE_CODE          VARCHAR(10),
    COUNTRY             VARCHAR(100),
    COUNTRY_CODE        VARCHAR(10),
    REGION              VARCHAR(100),
    SUBREGION           VARCHAR(100),

    -- Coordinates (placeholder for enrichment)
    LATITUDE            NUMBER(10,6),
    LONGITUDE           NUMBER(10,6),

    CONSTRAINT UK_GEOGRAPHY UNIQUE (CITY, STATE, COUNTRY)
)
COMMENT = 'Geography dimension for location-based analytics';

-- ============================================================================
-- VERIFY DIMENSION TABLES
-- ============================================================================

SHOW TABLES IN SCHEMA GOLD LIKE 'DIM_%';

SELECT 'Dimension tables created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
