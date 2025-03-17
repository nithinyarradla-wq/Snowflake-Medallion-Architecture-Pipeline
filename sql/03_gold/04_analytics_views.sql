-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Gold Layer: Analytics Views
-- ============================================================================
-- This script creates analytical views for business reporting
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA GOLD;
USE WAREHOUSE MEDALLION_ANALYTICS_WH;

-- ============================================================================
-- VIEW: Sales Overview Dashboard
-- ============================================================================

CREATE OR REPLACE VIEW V_SALES_OVERVIEW AS
SELECT
    d.FULL_DATE,
    d.YEAR,
    d.QUARTER,
    d.MONTH,
    d.MONTH_NAME,
    d.WEEK_OF_YEAR,
    d.DAY_NAME,
    d.IS_WEEKEND,
    fs.TOTAL_ORDERS,
    fs.TOTAL_CUSTOMERS,
    fs.TOTAL_QUANTITY,
    fs.GROSS_REVENUE,
    fs.TOTAL_DISCOUNTS,
    fs.NET_REVENUE,
    fs.AVG_ORDER_VALUE,
    -- Moving averages
    AVG(fs.NET_REVENUE) OVER (ORDER BY d.FULL_DATE ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS REVENUE_7DAY_AVG,
    AVG(fs.TOTAL_ORDERS) OVER (ORDER BY d.FULL_DATE ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ORDERS_7DAY_AVG,
    -- YoY comparisons
    LAG(fs.NET_REVENUE, 365) OVER (ORDER BY d.FULL_DATE) AS REVENUE_SAME_DAY_LAST_YEAR,
    -- Growth rate
    CASE
        WHEN LAG(fs.NET_REVENUE, 1) OVER (ORDER BY d.FULL_DATE) > 0
        THEN ROUND((fs.NET_REVENUE - LAG(fs.NET_REVENUE, 1) OVER (ORDER BY d.FULL_DATE)) /
             LAG(fs.NET_REVENUE, 1) OVER (ORDER BY d.FULL_DATE) * 100, 2)
        ELSE 0
    END AS REVENUE_DOD_GROWTH_PCT
FROM GOLD.FACT_DAILY_SALES fs
JOIN GOLD.DIM_DATE d ON fs.DATE_SK = d.DATE_SK
ORDER BY d.FULL_DATE DESC;

-- ============================================================================
-- VIEW: Customer Segmentation Analysis
-- ============================================================================

CREATE OR REPLACE VIEW V_CUSTOMER_SEGMENTS AS
SELECT
    c.CUSTOMER_SEGMENT,
    c.CUSTOMER_TIER,
    c.TENURE_BAND,
    c.REGION,
    COUNT(DISTINCT c.CUSTOMER_ID) AS CUSTOMER_COUNT,
    COUNT(DISTINCT f.ORDER_ID) AS TOTAL_ORDERS,
    SUM(f.TOTAL_AMOUNT) AS TOTAL_REVENUE,
    AVG(f.TOTAL_AMOUNT) AS AVG_ORDER_VALUE,
    SUM(f.TOTAL_QUANTITY) AS TOTAL_ITEMS_PURCHASED,
    ROUND(SUM(f.TOTAL_AMOUNT) / NULLIF(COUNT(DISTINCT c.CUSTOMER_ID), 0), 2) AS REVENUE_PER_CUSTOMER,
    ROUND(COUNT(DISTINCT f.ORDER_ID) / NULLIF(COUNT(DISTINCT c.CUSTOMER_ID), 0), 2) AS ORDERS_PER_CUSTOMER
FROM GOLD.DIM_CUSTOMER c
LEFT JOIN GOLD.FACT_SALES f ON c.CUSTOMER_SK = f.CUSTOMER_SK
WHERE c.IS_CURRENT = TRUE
GROUP BY
    c.CUSTOMER_SEGMENT,
    c.CUSTOMER_TIER,
    c.TENURE_BAND,
    c.REGION;

-- ============================================================================
-- VIEW: Product Performance Dashboard
-- ============================================================================

CREATE OR REPLACE VIEW V_PRODUCT_PERFORMANCE AS
SELECT
    p.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.CATEGORY,
    p.SUBCATEGORY,
    p.BRAND,
    p.PRICE_BAND,
    p.UNIT_PRICE,
    p.UNIT_COST,
    p.MARGIN_PERCENT,
    COUNT(DISTINCT fi.ORDER_ID) AS TIMES_ORDERED,
    SUM(fi.QUANTITY) AS TOTAL_QUANTITY_SOLD,
    SUM(fi.LINE_NET_AMOUNT) AS TOTAL_REVENUE,
    SUM(fi.LINE_PROFIT) AS TOTAL_PROFIT,
    ROUND(AVG(fi.DISCOUNT_PERCENT), 2) AS AVG_DISCOUNT_GIVEN,
    -- Ranking within category
    RANK() OVER (PARTITION BY p.CATEGORY ORDER BY SUM(fi.LINE_NET_AMOUNT) DESC) AS CATEGORY_REVENUE_RANK,
    -- Overall ranking
    RANK() OVER (ORDER BY SUM(fi.LINE_NET_AMOUNT) DESC) AS OVERALL_REVENUE_RANK
FROM GOLD.DIM_PRODUCT p
LEFT JOIN GOLD.FACT_SALES_ITEMS fi ON p.PRODUCT_SK = fi.PRODUCT_SK
WHERE p.IS_CURRENT = TRUE
GROUP BY
    p.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.CATEGORY,
    p.SUBCATEGORY,
    p.BRAND,
    p.PRICE_BAND,
    p.UNIT_PRICE,
    p.UNIT_COST,
    p.MARGIN_PERCENT;

-- ============================================================================
-- VIEW: Monthly Revenue Trends
-- ============================================================================

CREATE OR REPLACE VIEW V_MONTHLY_TRENDS AS
SELECT
    d.YEAR,
    d.MONTH,
    d.MONTH_NAME,
    d.YEAR_MONTH,
    COUNT(DISTINCT f.ORDER_ID) AS TOTAL_ORDERS,
    COUNT(DISTINCT f.CUSTOMER_ID) AS UNIQUE_CUSTOMERS,
    SUM(f.TOTAL_AMOUNT) AS TOTAL_REVENUE,
    SUM(f.DISCOUNT_AMOUNT) AS TOTAL_DISCOUNTS,
    SUM(f.PROFIT_AMOUNT) AS TOTAL_PROFIT,
    AVG(f.TOTAL_AMOUNT) AS AVG_ORDER_VALUE,
    SUM(f.TOTAL_QUANTITY) AS TOTAL_ITEMS,
    -- Month over month comparison
    LAG(SUM(f.TOTAL_AMOUNT), 1) OVER (ORDER BY d.YEAR, d.MONTH) AS PREV_MONTH_REVENUE,
    CASE
        WHEN LAG(SUM(f.TOTAL_AMOUNT), 1) OVER (ORDER BY d.YEAR, d.MONTH) > 0
        THEN ROUND((SUM(f.TOTAL_AMOUNT) - LAG(SUM(f.TOTAL_AMOUNT), 1) OVER (ORDER BY d.YEAR, d.MONTH)) /
             LAG(SUM(f.TOTAL_AMOUNT), 1) OVER (ORDER BY d.YEAR, d.MONTH) * 100, 2)
        ELSE 0
    END AS MOM_GROWTH_PCT,
    -- Year over year comparison
    LAG(SUM(f.TOTAL_AMOUNT), 12) OVER (ORDER BY d.YEAR, d.MONTH) AS SAME_MONTH_LAST_YEAR,
    CASE
        WHEN LAG(SUM(f.TOTAL_AMOUNT), 12) OVER (ORDER BY d.YEAR, d.MONTH) > 0
        THEN ROUND((SUM(f.TOTAL_AMOUNT) - LAG(SUM(f.TOTAL_AMOUNT), 12) OVER (ORDER BY d.YEAR, d.MONTH)) /
             LAG(SUM(f.TOTAL_AMOUNT), 12) OVER (ORDER BY d.YEAR, d.MONTH) * 100, 2)
        ELSE 0
    END AS YOY_GROWTH_PCT
FROM GOLD.FACT_SALES f
JOIN GOLD.DIM_DATE d ON f.DATE_SK = d.DATE_SK
GROUP BY
    d.YEAR,
    d.MONTH,
    d.MONTH_NAME,
    d.YEAR_MONTH
ORDER BY d.YEAR DESC, d.MONTH DESC;

-- ============================================================================
-- VIEW: Category Performance Summary
-- ============================================================================

CREATE OR REPLACE VIEW V_CATEGORY_PERFORMANCE AS
SELECT
    p.CATEGORY,
    p.SUBCATEGORY,
    COUNT(DISTINCT p.PRODUCT_ID) AS PRODUCT_COUNT,
    COUNT(DISTINCT fi.ORDER_ID) AS TOTAL_ORDERS,
    SUM(fi.QUANTITY) AS TOTAL_UNITS_SOLD,
    SUM(fi.LINE_NET_AMOUNT) AS TOTAL_REVENUE,
    SUM(fi.LINE_PROFIT) AS TOTAL_PROFIT,
    ROUND(SUM(fi.LINE_PROFIT) / NULLIF(SUM(fi.LINE_NET_AMOUNT), 0) * 100, 2) AS PROFIT_MARGIN_PCT,
    AVG(fi.UNIT_PRICE) AS AVG_UNIT_PRICE,
    ROUND(AVG(fi.DISCOUNT_PERCENT), 2) AS AVG_DISCOUNT_PCT,
    -- Category contribution
    ROUND(SUM(fi.LINE_NET_AMOUNT) / NULLIF(SUM(SUM(fi.LINE_NET_AMOUNT)) OVER (), 0) * 100, 2) AS REVENUE_CONTRIBUTION_PCT
FROM GOLD.DIM_PRODUCT p
LEFT JOIN GOLD.FACT_SALES_ITEMS fi ON p.PRODUCT_SK = fi.PRODUCT_SK
WHERE p.IS_CURRENT = TRUE
GROUP BY
    p.CATEGORY,
    p.SUBCATEGORY
ORDER BY TOTAL_REVENUE DESC;

-- ============================================================================
-- VIEW: Geographic Sales Distribution
-- ============================================================================

CREATE OR REPLACE VIEW V_GEOGRAPHIC_SALES AS
SELECT
    c.REGION,
    c.STATE,
    c.CITY,
    COUNT(DISTINCT c.CUSTOMER_ID) AS CUSTOMER_COUNT,
    COUNT(DISTINCT f.ORDER_ID) AS TOTAL_ORDERS,
    SUM(f.TOTAL_AMOUNT) AS TOTAL_REVENUE,
    AVG(f.TOTAL_AMOUNT) AS AVG_ORDER_VALUE,
    SUM(f.SHIPPING_COST) AS TOTAL_SHIPPING,
    ROUND(SUM(f.TOTAL_AMOUNT) / NULLIF(COUNT(DISTINCT c.CUSTOMER_ID), 0), 2) AS REVENUE_PER_CUSTOMER,
    -- Regional contribution
    ROUND(SUM(f.TOTAL_AMOUNT) / NULLIF(SUM(SUM(f.TOTAL_AMOUNT)) OVER (), 0) * 100, 2) AS REVENUE_PCT_OF_TOTAL
FROM GOLD.DIM_CUSTOMER c
LEFT JOIN GOLD.FACT_SALES f ON c.CUSTOMER_SK = f.CUSTOMER_SK
WHERE c.IS_CURRENT = TRUE
GROUP BY
    c.REGION,
    c.STATE,
    c.CITY
ORDER BY TOTAL_REVENUE DESC;

-- ============================================================================
-- VIEW: Top Customers (RFM-based)
-- ============================================================================

CREATE OR REPLACE VIEW V_TOP_CUSTOMERS AS
SELECT
    c.CUSTOMER_ID,
    c.FULL_NAME,
    c.EMAIL,
    c.CUSTOMER_SEGMENT,
    c.CUSTOMER_TIER,
    c.REGION,
    c.REGISTRATION_DATE,
    c.CUSTOMER_TENURE_DAYS,
    COUNT(DISTINCT f.ORDER_ID) AS LIFETIME_ORDERS,
    SUM(f.TOTAL_AMOUNT) AS LIFETIME_VALUE,
    AVG(f.TOTAL_AMOUNT) AS AVG_ORDER_VALUE,
    MAX(f.ORDER_DATE) AS LAST_ORDER_DATE,
    DATEDIFF('day', MAX(f.ORDER_DATE), CURRENT_DATE()) AS DAYS_SINCE_LAST_ORDER,
    -- RFM Scoring
    NTILE(5) OVER (ORDER BY DATEDIFF('day', MAX(f.ORDER_DATE), CURRENT_DATE()) DESC) AS RECENCY_SCORE,
    NTILE(5) OVER (ORDER BY COUNT(DISTINCT f.ORDER_ID)) AS FREQUENCY_SCORE,
    NTILE(5) OVER (ORDER BY SUM(f.TOTAL_AMOUNT)) AS MONETARY_SCORE
FROM GOLD.DIM_CUSTOMER c
LEFT JOIN GOLD.FACT_SALES f ON c.CUSTOMER_SK = f.CUSTOMER_SK
WHERE c.IS_CURRENT = TRUE
GROUP BY
    c.CUSTOMER_ID,
    c.FULL_NAME,
    c.EMAIL,
    c.CUSTOMER_SEGMENT,
    c.CUSTOMER_TIER,
    c.REGION,
    c.REGISTRATION_DATE,
    c.CUSTOMER_TENURE_DAYS
ORDER BY LIFETIME_VALUE DESC;

-- ============================================================================
-- VIEW: Order Status Summary
-- ============================================================================

CREATE OR REPLACE VIEW V_ORDER_STATUS_SUMMARY AS
SELECT
    ORDER_STATUS,
    ORDER_PRIORITY,
    SHIP_MODE,
    COUNT(*) AS ORDER_COUNT,
    SUM(TOTAL_AMOUNT) AS TOTAL_REVENUE,
    AVG(TOTAL_AMOUNT) AS AVG_ORDER_VALUE,
    AVG(DAYS_TO_SHIP) AS AVG_DAYS_TO_SHIP,
    SUM(CASE WHEN DAYS_TO_SHIP <= 3 THEN 1 ELSE 0 END) AS ORDERS_SHIPPED_WITHIN_3_DAYS,
    ROUND(SUM(CASE WHEN DAYS_TO_SHIP <= 3 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 2) AS PCT_SHIPPED_WITHIN_3_DAYS
FROM GOLD.FACT_SALES
GROUP BY
    ORDER_STATUS,
    ORDER_PRIORITY,
    SHIP_MODE
ORDER BY ORDER_COUNT DESC;

-- ============================================================================
-- VERIFY VIEWS
-- ============================================================================

SHOW VIEWS IN SCHEMA GOLD;

SELECT 'Analytics views created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
