-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Silver Layer: Cleaned and Transformed Tables
-- ============================================================================
-- This script creates Silver layer tables with proper data types,
-- data quality validations, and business transformations applied
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA SILVER;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- CLEANED CUSTOMERS TABLE
-- ============================================================================

CREATE OR REPLACE TABLE CUSTOMERS (
    -- Primary Key
    CUSTOMER_SK         NUMBER AUTOINCREMENT PRIMARY KEY,
    CUSTOMER_ID         VARCHAR(100) NOT NULL,

    -- Cleaned and standardized fields
    FIRST_NAME          VARCHAR(200),
    LAST_NAME           VARCHAR(200),
    FULL_NAME           VARCHAR(500),
    EMAIL               VARCHAR(500),
    EMAIL_DOMAIN        VARCHAR(200),
    PHONE               VARCHAR(50),
    PHONE_FORMATTED     VARCHAR(50),

    -- Address components
    ADDRESS             VARCHAR(1000),
    CITY                VARCHAR(200),
    STATE               VARCHAR(100),
    STATE_CODE          VARCHAR(10),
    ZIP_CODE            VARCHAR(20),
    COUNTRY             VARCHAR(100),
    COUNTRY_CODE        VARCHAR(10),

    -- Business attributes
    REGISTRATION_DATE   DATE,
    CUSTOMER_SEGMENT    VARCHAR(50),
    CUSTOMER_TIER       VARCHAR(50),
    DAYS_SINCE_REGISTRATION NUMBER,

    -- Data quality flags
    IS_EMAIL_VALID      BOOLEAN,
    IS_PHONE_VALID      BOOLEAN,
    DQ_SCORE            NUMBER(3,2),

    -- Audit columns
    SOURCE_RECORD_ID    NUMBER,
    SOURCE_FILENAME     VARCHAR(500),
    BRONZE_LOAD_TS      TIMESTAMP_NTZ,
    SILVER_LOAD_TS      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SILVER_UPDATE_TS    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    IS_CURRENT          BOOLEAN DEFAULT TRUE,

    -- Constraints
    CONSTRAINT UK_CUSTOMER_ID UNIQUE (CUSTOMER_ID)
)
CLUSTER BY (CUSTOMER_SEGMENT, STATE)
COMMENT = 'Cleaned and validated customer master data';

-- ============================================================================
-- CLEANED PRODUCTS TABLE
-- ============================================================================

CREATE OR REPLACE TABLE PRODUCTS (
    -- Primary Key
    PRODUCT_SK          NUMBER AUTOINCREMENT PRIMARY KEY,
    PRODUCT_ID          VARCHAR(100) NOT NULL,

    -- Product details
    PRODUCT_NAME        VARCHAR(500) NOT NULL,
    PRODUCT_NAME_CLEAN  VARCHAR(500),
    CATEGORY            VARCHAR(200),
    SUBCATEGORY         VARCHAR(200),
    CATEGORY_PATH       VARCHAR(500),
    BRAND               VARCHAR(200),

    -- Pricing
    UNIT_PRICE          NUMBER(18,4),
    UNIT_COST           NUMBER(18,4),
    PROFIT_MARGIN       NUMBER(18,4),
    MARGIN_PERCENT      NUMBER(8,4),

    -- Physical attributes
    WEIGHT_KG           NUMBER(12,4),
    WEIGHT_LBS          NUMBER(12,4),

    -- Status and dates
    SUPPLIER_ID         VARCHAR(100),
    IS_ACTIVE           BOOLEAN,
    CREATED_DATE        DATE,
    UPDATED_DATE        DATE,
    DAYS_SINCE_CREATED  NUMBER,

    -- Data quality
    DQ_SCORE            NUMBER(3,2),

    -- Audit columns
    SOURCE_RECORD_ID    NUMBER,
    SOURCE_FILENAME     VARCHAR(500),
    BRONZE_LOAD_TS      TIMESTAMP_NTZ,
    SILVER_LOAD_TS      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SILVER_UPDATE_TS    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    IS_CURRENT          BOOLEAN DEFAULT TRUE,

    -- Constraints
    CONSTRAINT UK_PRODUCT_ID UNIQUE (PRODUCT_ID)
)
CLUSTER BY (CATEGORY, IS_ACTIVE)
COMMENT = 'Cleaned and enriched product catalog data';

-- ============================================================================
-- CLEANED ORDERS TABLE
-- ============================================================================

CREATE OR REPLACE TABLE ORDERS (
    -- Primary Key
    ORDER_SK            NUMBER AUTOINCREMENT PRIMARY KEY,
    ORDER_ID            VARCHAR(100) NOT NULL,

    -- Order header
    CUSTOMER_ID         VARCHAR(100),
    ORDER_DATE          DATE,
    ORDER_TIMESTAMP     TIMESTAMP_NTZ,
    ORDER_STATUS        VARCHAR(50),
    ORDER_PRIORITY      VARCHAR(50),

    -- Shipping details
    SHIP_DATE           DATE,
    SHIP_MODE           VARCHAR(100),
    SHIPPING_ADDRESS    VARCHAR(1000),
    SHIPPING_CITY       VARCHAR(200),
    SHIPPING_STATE      VARCHAR(100),
    SHIPPING_ZIP        VARCHAR(20),
    SHIPPING_COUNTRY    VARCHAR(100),

    -- Order totals
    SUBTOTAL            NUMBER(18,4),
    DISCOUNT_AMOUNT     NUMBER(18,4),
    DISCOUNT_PERCENT    NUMBER(8,4),
    TAX_AMOUNT          NUMBER(18,4),
    SHIPPING_COST       NUMBER(18,4),
    TOTAL_AMOUNT        NUMBER(18,4),

    -- Order metrics
    TOTAL_ITEMS         NUMBER,
    TOTAL_QUANTITY      NUMBER,
    UNIQUE_PRODUCTS     NUMBER,

    -- Time dimensions
    ORDER_YEAR          NUMBER,
    ORDER_MONTH         NUMBER,
    ORDER_QUARTER       NUMBER,
    ORDER_WEEK          NUMBER,
    ORDER_DAY_OF_WEEK   NUMBER,
    IS_WEEKEND          BOOLEAN,

    -- Data quality
    DQ_SCORE            NUMBER(3,2),

    -- Audit columns
    SOURCE_RECORD_ID    NUMBER,
    SOURCE_FILENAME     VARCHAR(500),
    BRONZE_LOAD_TS      TIMESTAMP_NTZ,
    SILVER_LOAD_TS      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SILVER_UPDATE_TS    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT UK_ORDER_ID UNIQUE (ORDER_ID)
)
CLUSTER BY (ORDER_DATE)
COMMENT = 'Cleaned and transformed order header data';

-- ============================================================================
-- ORDER LINE ITEMS TABLE (Flattened from JSON)
-- ============================================================================

CREATE OR REPLACE TABLE ORDER_ITEMS (
    -- Primary Key
    ORDER_ITEM_SK       NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Foreign Keys
    ORDER_ID            VARCHAR(100) NOT NULL,
    PRODUCT_ID          VARCHAR(100),
    LINE_NUMBER         NUMBER,

    -- Item details
    QUANTITY            NUMBER,
    UNIT_PRICE          NUMBER(18,4),
    DISCOUNT_PERCENT    NUMBER(8,4),
    LINE_TOTAL          NUMBER(18,4),
    LINE_DISCOUNT       NUMBER(18,4),
    LINE_NET_AMOUNT     NUMBER(18,4),

    -- Audit columns
    SOURCE_RECORD_ID    NUMBER,
    SILVER_LOAD_TS      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SILVER_UPDATE_TS    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (ORDER_ID)
COMMENT = 'Order line items flattened from JSON order data';

-- ============================================================================
-- CLEANED EVENTS TABLE
-- ============================================================================

CREATE OR REPLACE TABLE EVENTS (
    -- Primary Key
    EVENT_SK            NUMBER AUTOINCREMENT PRIMARY KEY,
    EVENT_ID            VARCHAR(100) NOT NULL,

    -- Event details
    EVENT_TYPE          VARCHAR(100),
    EVENT_CATEGORY      VARCHAR(100),
    EVENT_ACTION        VARCHAR(200),
    EVENT_TIMESTAMP     TIMESTAMP_NTZ,
    EVENT_DATE          DATE,

    -- User/Session context
    USER_ID             VARCHAR(100),
    SESSION_ID          VARCHAR(200),
    DEVICE_TYPE         VARCHAR(50),
    BROWSER             VARCHAR(100),
    OS                  VARCHAR(100),

    -- Page/Product context
    PAGE_URL            VARCHAR(2000),
    PAGE_TITLE          VARCHAR(500),
    REFERRER_URL        VARCHAR(2000),
    PRODUCT_ID          VARCHAR(100),

    -- Event properties
    EVENT_VALUE         NUMBER(18,4),
    PROPERTIES          VARIANT,

    -- Time dimensions
    EVENT_HOUR          NUMBER,
    EVENT_DAY_OF_WEEK   NUMBER,
    IS_BUSINESS_HOURS   BOOLEAN,

    -- Audit columns
    SOURCE_RECORD_ID    NUMBER,
    BRONZE_LOAD_TS      TIMESTAMP_NTZ,
    SILVER_LOAD_TS      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
CLUSTER BY (EVENT_DATE, EVENT_TYPE)
COMMENT = 'Cleaned and structured event data';

-- ============================================================================
-- VERIFY TABLES
-- ============================================================================

SHOW TABLES IN SCHEMA SILVER;

SELECT 'Silver layer tables created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
