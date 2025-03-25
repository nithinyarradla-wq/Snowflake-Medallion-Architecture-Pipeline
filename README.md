# Snowflake Medallion Architecture Pipeline

A production-ready data pipeline implementing the Bronze → Silver → Gold medallion architecture pattern using Snowflake's native features including stages, streams, and tasks.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MEDALLION ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐       │
│   │  SOURCE  │ ──── │  BRONZE  │ ──── │  SILVER  │ ──── │   GOLD   │       │
│   │   DATA   │      │   RAW    │      │ CLEANSED │      │ BUSINESS │       │
│   └──────────┘      └──────────┘      └──────────┘      └──────────┘       │
│                                                                              │
│   JSON/CSV          Stage+Tables       Streams+         Dimensions +        │
│   Files             Raw Ingestion      Transforms       Fact Tables         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
├── sql/
│   ├── 00_setup/           # Database, schema, warehouse setup
│   │   ├── 01_create_database.sql
│   │   ├── 02_create_warehouse.sql
│   │   └── 03_create_roles.sql
│   ├── 01_bronze/          # Bronze layer: stages, file formats, raw tables
│   │   ├── 01_file_formats.sql
│   │   ├── 02_stages.sql
│   │   ├── 03_raw_tables.sql
│   │   └── 04_load_procedures.sql
│   ├── 02_silver/          # Silver layer: streams, transformations
│   │   ├── 01_streams.sql
│   │   ├── 02_cleaned_tables.sql
│   │   └── 03_transformations.sql
│   ├── 03_gold/            # Gold layer: analytics-ready tables
│   │   ├── 01_dimension_tables.sql
│   │   ├── 02_fact_tables.sql
│   │   ├── 03_aggregations.sql
│   │   └── 04_analytics_views.sql
│   └── 04_tasks/           # Automated pipeline tasks
│       ├── 01_bronze_tasks.sql
│       ├── 02_silver_tasks.sql
│       ├── 03_gold_tasks.sql
│       └── 04_task_management.sql
├── data/
│   ├── json/               # Sample JSON data files
│   │   └── orders_sample.json
│   └── csv/                # Sample CSV data files
│       ├── customers_sample.csv
│       └── products_sample.csv
├── docs/
│   ├── ARCHITECTURE.md     # Detailed architecture documentation
│   └── SETUP_GUIDE.md      # Step-by-step setup instructions
└── scripts/                # Utility scripts
```

## Features

### Bronze Layer (Raw Data)
- **File Formats**: Configurable JSON and CSV parsers
- **Internal Stages**: Secure file upload areas
- **Raw Tables**: Store data as-is with metadata columns
- **Batch Tracking**: Audit trail for all data loads

### Silver Layer (Cleansed Data)
- **Streams**: Change Data Capture for incremental processing
- **Data Quality**: Scoring and validation rules
- **Transformations**: Type casting, normalization, enrichment
- **JSON Flattening**: Extract nested arrays into relational format

### Gold Layer (Business Ready)
- **Star Schema**: Dimension and fact tables
- **SCD Type 2**: Historical tracking for dimensions
- **Pre-Aggregations**: Daily snapshots and metrics
- **Analytics Views**: Ready-to-use business dashboards

### Automation
- **Scheduled Tasks**: Automatic data loading and transformation
- **Stream-Triggered Tasks**: Process only when new data arrives
- **Task DAG**: Proper dependency management
- **Monitoring Views**: Task execution history and status

## Snowflake Features Used

| Feature | Purpose |
|---------|---------|
| Stages | File landing zones |
| File Formats | JSON/CSV parsing |
| Streams | Change Data Capture |
| Tasks | Automation & scheduling |
| Stored Procedures | Reusable ETL logic |
| VARIANT | Semi-structured data |
| MERGE | Upsert operations |
| Clustering | Query optimization |

## Prerequisites

- Snowflake account with ACCOUNTADMIN or equivalent privileges
- Snowflake CLI (SnowSQL) for file uploads (optional)
- Access to Snowflake Web UI (Snowsight)

## Quick Start

### 1. Clone Repository
```bash
git clone <repository-url>
cd Snowflake-Medallion-Architecture-Pipeline
```

### 2. Run Setup Scripts
Execute scripts in Snowflake in this order:
```sql
-- Setup
@sql/00_setup/01_create_database.sql
@sql/00_setup/02_create_warehouse.sql
@sql/00_setup/03_create_roles.sql

-- Bronze Layer
@sql/01_bronze/01_file_formats.sql
@sql/01_bronze/02_stages.sql
@sql/01_bronze/03_raw_tables.sql
@sql/01_bronze/04_load_procedures.sql

-- Silver Layer
@sql/02_silver/01_streams.sql
@sql/02_silver/02_cleaned_tables.sql
@sql/02_silver/03_transformations.sql

-- Gold Layer
@sql/03_gold/01_dimension_tables.sql
@sql/03_gold/02_fact_tables.sql
@sql/03_gold/03_aggregations.sql
@sql/03_gold/04_analytics_views.sql

-- Tasks
@sql/04_tasks/01_bronze_tasks.sql
@sql/04_tasks/02_silver_tasks.sql
@sql/04_tasks/03_gold_tasks.sql
@sql/04_tasks/04_task_management.sql
```

### 3. Load Sample Data
```sql
-- Upload files to stages
PUT file://data/json/orders_sample.json @BRONZE.STG_ORDERS;
PUT file://data/csv/customers_sample.csv @BRONZE.STG_CUSTOMERS;
PUT file://data/csv/products_sample.csv @BRONZE.STG_PRODUCTS;
```

### 4. Run Pipeline
```sql
-- Execute full pipeline
CALL UTILS.SP_RUN_FULL_PIPELINE();
```

### 5. Query Results
```sql
-- Sales overview
SELECT * FROM GOLD.V_SALES_OVERVIEW;

-- Customer segments
SELECT * FROM GOLD.V_CUSTOMER_SEGMENTS;

-- Product performance
SELECT * FROM GOLD.V_PRODUCT_PERFORMANCE;
```

## Documentation

- [Setup Guide](docs/SETUP_GUIDE.md) - Detailed installation instructions
- [Architecture](docs/ARCHITECTURE.md) - System design and data flow

## Data Model

### Sample Data Entities
- **Orders**: E-commerce transactions with line items
- **Customers**: Customer master with segmentation
- **Products**: Product catalog with categories

### Analytics Views
- `V_SALES_OVERVIEW` - Daily sales metrics with trends
- `V_CUSTOMER_SEGMENTS` - Customer segmentation analysis
- `V_PRODUCT_PERFORMANCE` - Product ranking and metrics
- `V_MONTHLY_TRENDS` - Month-over-month comparisons
- `V_CATEGORY_PERFORMANCE` - Category-level aggregations
- `V_GEOGRAPHIC_SALES` - Regional sales distribution
- `V_TOP_CUSTOMERS` - RFM-based customer ranking
- `V_ORDER_STATUS_SUMMARY` - Order fulfillment metrics

## License

MIT License - See LICENSE file for details
