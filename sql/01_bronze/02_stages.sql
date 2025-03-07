-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Bronze Layer: Stages
-- ============================================================================
-- This script creates internal and external stages for data ingestion
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA BRONZE;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- INTERNAL STAGES
-- ============================================================================

-- Internal stage for JSON data files
CREATE OR REPLACE STAGE STG_JSON_DATA
    FILE_FORMAT = UTILS.JSON_FORMAT
    COMMENT = 'Internal stage for JSON data file uploads';

-- Internal stage for CSV data files
CREATE OR REPLACE STAGE STG_CSV_DATA
    FILE_FORMAT = UTILS.CSV_FORMAT
    COMMENT = 'Internal stage for CSV data file uploads';

-- Internal stage for orders data (JSON)
CREATE OR REPLACE STAGE STG_ORDERS
    FILE_FORMAT = UTILS.JSON_FORMAT
    COMMENT = 'Stage for order transaction data in JSON format';

-- Internal stage for customers data (CSV)
CREATE OR REPLACE STAGE STG_CUSTOMERS
    FILE_FORMAT = UTILS.CSV_FORMAT
    COMMENT = 'Stage for customer master data in CSV format';

-- Internal stage for products data (CSV)
CREATE OR REPLACE STAGE STG_PRODUCTS
    FILE_FORMAT = UTILS.CSV_FORMAT
    COMMENT = 'Stage for product catalog data in CSV format';

-- ============================================================================
-- EXTERNAL STAGES (Template - Uncomment and configure as needed)
-- ============================================================================

/*
-- AWS S3 External Stage Example
CREATE OR REPLACE STAGE STG_S3_DATA
    URL = 's3://your-bucket-name/medallion/raw/'
    STORAGE_INTEGRATION = your_s3_integration
    FILE_FORMAT = UTILS.JSON_FORMAT
    COMMENT = 'External S3 stage for raw data ingestion';

-- Azure Blob External Stage Example
CREATE OR REPLACE STAGE STG_AZURE_DATA
    URL = 'azure://your-account.blob.core.windows.net/container/medallion/raw/'
    STORAGE_INTEGRATION = your_azure_integration
    FILE_FORMAT = UTILS.CSV_FORMAT
    COMMENT = 'External Azure Blob stage for raw data ingestion';

-- GCS External Stage Example
CREATE OR REPLACE STAGE STG_GCS_DATA
    URL = 'gcs://your-bucket-name/medallion/raw/'
    STORAGE_INTEGRATION = your_gcs_integration
    FILE_FORMAT = UTILS.JSON_FORMAT
    COMMENT = 'External GCS stage for raw data ingestion';
*/

-- ============================================================================
-- STAGE UPLOAD EXAMPLES (Run from SnowSQL CLI)
-- ============================================================================

/*
-- Upload files to internal stages using SnowSQL:

-- Upload JSON files
PUT file://path/to/orders.json @STG_ORDERS AUTO_COMPRESS=TRUE;

-- Upload CSV files
PUT file://path/to/customers.csv @STG_CUSTOMERS AUTO_COMPRESS=TRUE;
PUT file://path/to/products.csv @STG_PRODUCTS AUTO_COMPRESS=TRUE;

-- List files in stage
LIST @STG_ORDERS;
LIST @STG_CUSTOMERS;
LIST @STG_PRODUCTS;
*/

-- ============================================================================
-- VERIFY STAGES
-- ============================================================================

SHOW STAGES IN SCHEMA BRONZE;

SELECT 'Stages created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
