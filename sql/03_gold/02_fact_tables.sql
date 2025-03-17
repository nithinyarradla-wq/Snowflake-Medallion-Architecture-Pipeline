-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Gold Layer: Fact Tables
-- ============================================================================
-- This script creates fact tables for the star schema analytics layer
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA GOLD;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- FACT: SALES (Order-level grain)
-- ============================================================================

CREATE OR REPLACE TABLE FACT_SALES (
    -- Surrogate Key
    SALES_SK            NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Degenerate Dimension (Transaction ID)
    ORDER_ID            VARCHAR(100) NOT NULL,

    -- Foreign Keys to Dimensions
    DATE_SK             NUMBER,
    CUSTOMER_SK         NUMBER,
    PRODUCT_SK          NUMBER,
    GEOGRAPHY_SK        NUMBER,

    -- Business Keys (for debugging/reconciliation)
    ORDER_DATE          DATE,
    CUSTOMER_ID         VARCHAR(100),

    -- Order attributes
    ORDER_STATUS        VARCHAR(50),
    ORDER_PRIORITY      VARCHAR(50),
    SHIP_MODE           VARCHAR(100),

    -- Measures
    TOTAL_ITEMS         NUMBER,
    TOTAL_QUANTITY      NUMBER,
    UNIQUE_PRODUCTS     NUMBER,
    SUBTOTAL            NUMBER(18,4),
    DISCOUNT_AMOUNT     NUMBER(18,4),
    DISCOUNT_PERCENT    NUMBER(8,4),
    TAX_AMOUNT          NUMBER(18,4),
    SHIPPING_COST       NUMBER(18,4),
    TOTAL_AMOUNT        NUMBER(18,4),
    PROFIT_AMOUNT       NUMBER(18,4),

    -- Time metrics
    DAYS_TO_SHIP        NUMBER,

    -- Audit
    SOURCE_ORDER_SK     NUMBER,
    ETL_LOAD_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT UK_FACT_SALES_ORDER UNIQUE (ORDER_ID)
)
CLUSTER BY (DATE_SK)
COMMENT = 'Sales fact table at order grain';

-- ============================================================================
-- FACT: SALES LINE ITEMS (Line item grain)
-- ============================================================================

CREATE OR REPLACE TABLE FACT_SALES_ITEMS (
    -- Surrogate Key
    SALES_ITEM_SK       NUMBER AUTOINCREMENT PRIMARY KEY,

    -- Foreign Keys
    SALES_SK            NUMBER,
    DATE_SK             NUMBER,
    CUSTOMER_SK         NUMBER,
    PRODUCT_SK          NUMBER,

    -- Degenerate Dimensions
    ORDER_ID            VARCHAR(100) NOT NULL,
    LINE_NUMBER         NUMBER,

    -- Business Keys
    ORDER_DATE          DATE,
    CUSTOMER_ID         VARCHAR(100),
    PRODUCT_ID          VARCHAR(100),

    -- Measures
    QUANTITY            NUMBER,
    UNIT_PRICE          NUMBER(18,4),
    UNIT_COST           NUMBER(18,4),
    DISCOUNT_PERCENT    NUMBER(8,4),
    LINE_TOTAL          NUMBER(18,4),
    LINE_DISCOUNT       NUMBER(18,4),
    LINE_NET_AMOUNT     NUMBER(18,4),
    LINE_COST           NUMBER(18,4),
    LINE_PROFIT         NUMBER(18,4),
    LINE_MARGIN_PERCENT NUMBER(8,4),

    -- Audit
    ETL_LOAD_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    -- Constraints
    CONSTRAINT UK_FACT_SALES_ITEMS UNIQUE (ORDER_ID, LINE_NUMBER)
)
CLUSTER BY (DATE_SK, PRODUCT_SK)
COMMENT = 'Sales fact table at line item grain';

-- ============================================================================
-- FACT: DAILY SALES SNAPSHOT (Aggregated daily metrics)
-- ============================================================================

CREATE OR REPLACE TABLE FACT_DAILY_SALES (
    -- Composite Key
    DATE_SK             NUMBER NOT NULL,
    SNAPSHOT_DATE       DATE NOT NULL,

    -- Measures
    TOTAL_ORDERS        NUMBER,
    TOTAL_CUSTOMERS     NUMBER,
    NEW_CUSTOMERS       NUMBER,
    TOTAL_ITEMS_SOLD    NUMBER,
    TOTAL_QUANTITY      NUMBER,

    -- Revenue metrics
    GROSS_REVENUE       NUMBER(18,4),
    TOTAL_DISCOUNTS     NUMBER(18,4),
    NET_REVENUE         NUMBER(18,4),
    TOTAL_TAX           NUMBER(18,4),
    TOTAL_SHIPPING      NUMBER(18,4),

    -- Averages
    AVG_ORDER_VALUE     NUMBER(18,4),
    AVG_ITEMS_PER_ORDER NUMBER(8,2),
    AVG_DISCOUNT_PERCENT NUMBER(8,4),

    -- Product metrics
    UNIQUE_PRODUCTS_SOLD NUMBER,

    -- Cumulative metrics (YTD)
    YTD_ORDERS          NUMBER,
    YTD_REVENUE         NUMBER(18,4),
    YTD_CUSTOMERS       NUMBER,

    -- Comparison metrics
    REVENUE_VS_PREV_DAY  NUMBER(18,4),
    REVENUE_VS_PREV_WEEK NUMBER(18,4),
    ORDERS_VS_PREV_DAY   NUMBER,

    -- Audit
    ETL_LOAD_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    PRIMARY KEY (DATE_SK)
)
COMMENT = 'Daily sales snapshot for trend analysis';

-- ============================================================================
-- FACT: CUSTOMER ACTIVITY (Customer behavior tracking)
-- ============================================================================

CREATE OR REPLACE TABLE FACT_CUSTOMER_ACTIVITY (
    -- Composite Key
    DATE_SK             NUMBER NOT NULL,
    CUSTOMER_SK         NUMBER NOT NULL,
    ACTIVITY_DATE       DATE NOT NULL,

    -- Order metrics
    ORDERS_PLACED       NUMBER DEFAULT 0,
    ITEMS_PURCHASED     NUMBER DEFAULT 0,
    TOTAL_SPEND         NUMBER(18,4) DEFAULT 0,

    -- Cumulative metrics
    LIFETIME_ORDERS     NUMBER,
    LIFETIME_SPEND      NUMBER(18,4),
    LIFETIME_ITEMS      NUMBER,

    -- Recency metrics
    DAYS_SINCE_FIRST_ORDER NUMBER,
    DAYS_SINCE_LAST_ORDER  NUMBER,

    -- Frequency metrics
    AVG_ORDER_VALUE     NUMBER(18,4),
    AVG_DAYS_BETWEEN_ORDERS NUMBER(8,2),

    -- Segmentation
    RFM_RECENCY_SCORE   NUMBER(1),
    RFM_FREQUENCY_SCORE NUMBER(1),
    RFM_MONETARY_SCORE  NUMBER(1),
    RFM_SEGMENT         VARCHAR(50),

    -- Audit
    ETL_LOAD_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    PRIMARY KEY (DATE_SK, CUSTOMER_SK)
)
CLUSTER BY (DATE_SK)
COMMENT = 'Customer activity and behavior metrics';

-- ============================================================================
-- FACT: PRODUCT PERFORMANCE (Product metrics)
-- ============================================================================

CREATE OR REPLACE TABLE FACT_PRODUCT_PERFORMANCE (
    -- Composite Key
    DATE_SK             NUMBER NOT NULL,
    PRODUCT_SK          NUMBER NOT NULL,
    PERFORMANCE_DATE    DATE NOT NULL,

    -- Sales metrics
    TIMES_ORDERED       NUMBER DEFAULT 0,
    QUANTITY_SOLD       NUMBER DEFAULT 0,
    GROSS_REVENUE       NUMBER(18,4) DEFAULT 0,
    TOTAL_DISCOUNTS     NUMBER(18,4) DEFAULT 0,
    NET_REVENUE         NUMBER(18,4) DEFAULT 0,

    -- Profit metrics
    TOTAL_COST          NUMBER(18,4),
    TOTAL_PROFIT        NUMBER(18,4),
    PROFIT_MARGIN       NUMBER(8,4),

    -- Cumulative metrics
    MTD_QUANTITY        NUMBER,
    MTD_REVENUE         NUMBER(18,4),
    YTD_QUANTITY        NUMBER,
    YTD_REVENUE         NUMBER(18,4),

    -- Ranking
    DAILY_REVENUE_RANK  NUMBER,
    CATEGORY_REVENUE_RANK NUMBER,

    -- Audit
    ETL_LOAD_TS         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),

    PRIMARY KEY (DATE_SK, PRODUCT_SK)
)
CLUSTER BY (DATE_SK)
COMMENT = 'Product performance metrics for analysis';

-- ============================================================================
-- VERIFY FACT TABLES
-- ============================================================================

SHOW TABLES IN SCHEMA GOLD LIKE 'FACT_%';

SELECT 'Fact tables created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
