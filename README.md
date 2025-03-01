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
│   JSON/CSV          Stage+Tables       Streams+         Aggregations        │
│   Files             Raw Ingestion      Transforms       Analytics           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
├── sql/
│   ├── 00_setup/           # Database, schema, warehouse setup
│   ├── 01_bronze/          # Bronze layer: stages, file formats, raw tables
│   ├── 02_silver/          # Silver layer: streams, transformations
│   ├── 03_gold/            # Gold layer: analytics-ready tables
│   └── 04_tasks/           # Automated pipeline tasks
├── data/
│   ├── json/               # Sample JSON data files
│   └── csv/                # Sample CSV data files
├── docs/                   # Documentation
└── scripts/                # Utility scripts
```

## Features

- **Bronze Layer**: Raw data ingestion from JSON/CSV files using Snowflake stages
- **Silver Layer**: Data cleansing and transformation using streams for CDC
- **Gold Layer**: Business-ready aggregations and analytics tables
- **Automated Pipeline**: Snowflake tasks for scheduled data processing
- **Change Data Capture**: Streams for incremental processing

## Prerequisites

- Snowflake account with ACCOUNTADMIN or equivalent privileges
- Snowflake CLI (SnowSQL) or access to Snowflake Web UI

## Quick Start

1. Clone this repository
2. Run setup scripts in order:
   ```sql
   -- Execute in Snowflake
   -- 1. Setup database and schemas
   -- 2. Create bronze layer objects
   -- 3. Create silver layer objects
   -- 4. Create gold layer objects
   -- 5. Setup automated tasks
   ```

## License

MIT License
