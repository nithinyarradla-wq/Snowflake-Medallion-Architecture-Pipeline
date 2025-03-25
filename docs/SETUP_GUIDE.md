# Setup Guide

This guide walks you through setting up the Snowflake Medallion Architecture Pipeline from scratch.

## Prerequisites

- Snowflake account with ACCOUNTADMIN role access
- SnowSQL CLI installed (optional, for file uploads)
- Access to Snowflake Web UI (Snowsight)

## Step 1: Initial Setup

Execute the setup scripts in order:

```sql
-- Connect to Snowflake and run:

-- 1. Create database and schemas
@sql/00_setup/01_create_database.sql

-- 2. Create warehouses
@sql/00_setup/02_create_warehouse.sql

-- 3. Create roles and permissions
@sql/00_setup/03_create_roles.sql
```

## Step 2: Create Bronze Layer Objects

```sql
-- 1. Create file formats
@sql/01_bronze/01_file_formats.sql

-- 2. Create stages
@sql/01_bronze/02_stages.sql

-- 3. Create raw tables
@sql/01_bronze/03_raw_tables.sql

-- 4. Create load procedures
@sql/01_bronze/04_load_procedures.sql
```

## Step 3: Create Silver Layer Objects

```sql
-- 1. Create streams
@sql/02_silver/01_streams.sql

-- 2. Create cleaned tables
@sql/02_silver/02_cleaned_tables.sql

-- 3. Create transformation procedures
@sql/02_silver/03_transformations.sql
```

## Step 4: Create Gold Layer Objects

```sql
-- 1. Create dimension tables
@sql/03_gold/01_dimension_tables.sql

-- 2. Create fact tables
@sql/03_gold/02_fact_tables.sql

-- 3. Create aggregation procedures
@sql/03_gold/03_aggregations.sql

-- 4. Create analytics views
@sql/03_gold/04_analytics_views.sql
```

## Step 5: Set Up Automated Tasks

```sql
-- 1. Create Bronze layer tasks
@sql/04_tasks/01_bronze_tasks.sql

-- 2. Create Silver layer tasks
@sql/04_tasks/02_silver_tasks.sql

-- 3. Create Gold layer tasks
@sql/04_tasks/03_gold_tasks.sql

-- 4. Create task management utilities
@sql/04_tasks/04_task_management.sql
```

## Step 6: Load Sample Data

### Using SnowSQL CLI:

```bash
# Upload sample data to stages
snowsql -a <account> -u <user> -d MEDALLION_DB -s BRONZE -w MEDALLION_ETL_WH

# Inside SnowSQL:
PUT file://data/json/orders_sample.json @STG_ORDERS;
PUT file://data/csv/customers_sample.csv @STG_CUSTOMERS;
PUT file://data/csv/products_sample.csv @STG_PRODUCTS;
```

### Using Snowsight Web UI:

1. Navigate to Data > Databases > MEDALLION_DB > BRONZE
2. Click on each stage (STG_ORDERS, STG_CUSTOMERS, STG_PRODUCTS)
3. Use the "Load Data" button to upload files

## Step 7: Run the Pipeline

### Manual Execution:

```sql
-- Run full pipeline
CALL UTILS.SP_RUN_FULL_PIPELINE();

-- Or run each layer separately:
CALL BRONZE.SP_LOAD_ALL_RAW_DATA();
CALL SILVER.SP_TRANSFORM_ALL_TO_SILVER();
CALL GOLD.SP_POPULATE_GOLD_LAYER();
```

### Enable Automated Tasks:

```sql
-- Resume all tasks
CALL UTILS.SP_RESUME_ALL_TASKS();

-- Or resume individually (start with leaf tasks):
ALTER TASK GOLD.TASK_POPULATE_DAILY_SALES RESUME;
ALTER TASK GOLD.TASK_POPULATE_FACT_SALES RESUME;
-- ... continue for all tasks
```

## Step 8: Verify Installation

```sql
-- Check all objects
SHOW TABLES IN DATABASE MEDALLION_DB;
SHOW VIEWS IN DATABASE MEDALLION_DB;
SHOW PROCEDURES IN DATABASE MEDALLION_DB;
SHOW TASKS IN DATABASE MEDALLION_DB;
SHOW STREAMS IN DATABASE MEDALLION_DB;

-- Check data flow
SELECT COUNT(*) FROM BRONZE.RAW_CUSTOMERS;
SELECT COUNT(*) FROM SILVER.CUSTOMERS;
SELECT COUNT(*) FROM GOLD.DIM_CUSTOMER;

-- Query analytics views
SELECT * FROM GOLD.V_SALES_OVERVIEW LIMIT 10;
SELECT * FROM GOLD.V_CUSTOMER_SEGMENTS;
```

## Troubleshooting

### Tasks Not Running

1. Check if tasks are resumed: `SHOW TASKS;`
2. Verify warehouse is active: `SHOW WAREHOUSES;`
3. Check task history: `SELECT * FROM UTILS.V_TASK_HISTORY;`

### Data Not Transforming

1. Verify streams have data: `SELECT * FROM UTILS.V_STREAM_STATUS;`
2. Check for errors in procedures
3. Review load batch log: `SELECT * FROM BRONZE.LOAD_BATCH_LOG;`

### Permission Issues

1. Ensure correct role is active: `SELECT CURRENT_ROLE();`
2. Verify grants: `SHOW GRANTS ON DATABASE MEDALLION_DB;`
