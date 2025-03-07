-- ============================================================================
-- Snowflake Medallion Architecture Pipeline
-- Bronze Layer: File Formats
-- ============================================================================
-- This script creates file formats for ingesting JSON and CSV data
-- into the Bronze layer
-- ============================================================================

USE ROLE SYSADMIN;
USE DATABASE MEDALLION_DB;
USE SCHEMA UTILS;
USE WAREHOUSE MEDALLION_ETL_WH;

-- ============================================================================
-- JSON FILE FORMATS
-- ============================================================================

-- Standard JSON format for nested data
CREATE OR REPLACE FILE FORMAT JSON_FORMAT
    TYPE = 'JSON'
    COMPRESSION = 'AUTO'
    STRIP_OUTER_ARRAY = TRUE           -- Handle arrays of JSON objects
    ENABLE_OCTAL = FALSE
    ALLOW_DUPLICATE = FALSE
    STRIP_NULL_VALUES = FALSE
    IGNORE_UTF8_ERRORS = FALSE
    COMMENT = 'Standard JSON file format for raw data ingestion';

-- JSON format for single objects (no outer array)
CREATE OR REPLACE FILE FORMAT JSON_SINGLE_FORMAT
    TYPE = 'JSON'
    COMPRESSION = 'AUTO'
    STRIP_OUTER_ARRAY = FALSE
    ENABLE_OCTAL = FALSE
    ALLOW_DUPLICATE = FALSE
    STRIP_NULL_VALUES = FALSE
    IGNORE_UTF8_ERRORS = FALSE
    COMMENT = 'JSON format for single object files';

-- ============================================================================
-- CSV FILE FORMATS
-- ============================================================================

-- Standard CSV format with headers
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    COMPRESSION = 'AUTO'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1                    -- Skip header row
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    ESCAPE = 'NONE'
    ESCAPE_UNENCLOSED_FIELD = '\\'
    DATE_FORMAT = 'AUTO'
    TIMESTAMP_FORMAT = 'AUTO'
    NULL_IF = ('NULL', 'null', '')
    COMMENT = 'Standard CSV file format with headers';

-- CSV format without headers
CREATE OR REPLACE FILE FORMAT CSV_NO_HEADER_FORMAT
    TYPE = 'CSV'
    COMPRESSION = 'AUTO'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 0                    -- No header to skip
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    NULL_IF = ('NULL', 'null', '')
    COMMENT = 'CSV file format without headers';

-- Pipe-delimited format
CREATE OR REPLACE FILE FORMAT PIPE_DELIMITED_FORMAT
    TYPE = 'CSV'
    COMPRESSION = 'AUTO'
    FIELD_DELIMITER = '|'
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('NULL', 'null', '')
    COMMENT = 'Pipe-delimited file format';

-- ============================================================================
-- VERIFY FILE FORMATS
-- ============================================================================

SHOW FILE FORMATS IN SCHEMA UTILS;

SELECT 'File formats created successfully' AS STATUS,
       CURRENT_TIMESTAMP() AS COMPLETED_AT;
