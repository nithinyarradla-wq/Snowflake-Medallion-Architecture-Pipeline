# Architecture Overview

## Medallion Architecture Pattern

The Medallion Architecture (also known as Multi-Hop Architecture) is a data design pattern that organizes data into three layers: Bronze, Silver, and Gold. Each layer serves a specific purpose and progressively refines the data quality.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DATA FLOW ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐       │
│   │  SOURCE  │      │  BRONZE  │      │  SILVER  │      │   GOLD   │       │
│   │   DATA   │ ──── │   RAW    │ ──── │ CLEANSED │ ──── │ BUSINESS │       │
│   │  (Files) │      │ (Tables) │      │ (Tables) │      │ (Star)   │       │
│   └──────────┘      └──────────┘      └──────────┘      └──────────┘       │
│        │                  │                │                  │             │
│        │                  │                │                  │             │
│   JSON/CSV           Stages +          Streams +         Dimensions +       │
│   Files              Raw Tables        Transforms        Fact Tables        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Layer Details

### Bronze Layer (Raw)

**Purpose**: Store raw data exactly as received from source systems.

**Components**:
- **Stages**: Landing zones for file uploads (JSON, CSV)
- **File Formats**: Parsing configurations for different file types
- **Raw Tables**: Store data with minimal transformation
- **Load Procedures**: Bulk load data from stages to tables

**Key Characteristics**:
- Data stored in original format (VARIANT for JSON)
- Metadata columns added (filename, row number, load timestamp)
- No business transformations applied
- Append-only pattern for auditability

**Tables**:
| Table | Source Format | Description |
|-------|---------------|-------------|
| RAW_ORDERS | JSON | Order transactions with nested items |
| RAW_CUSTOMERS | CSV | Customer master data |
| RAW_PRODUCTS | CSV | Product catalog |
| RAW_EVENTS | JSON | Clickstream/event data |
| LOAD_BATCH_LOG | - | Audit table for load tracking |

### Silver Layer (Cleansed)

**Purpose**: Clean, validate, and transform data for consumption.

**Components**:
- **Streams**: Change Data Capture on Bronze tables
- **Cleaned Tables**: Properly typed and validated data
- **Transformation Procedures**: Business logic and data quality rules

**Key Characteristics**:
- Proper data types applied
- Data quality checks and scoring
- Business transformations (derived fields)
- Deduplication and validation
- CDC-enabled incremental processing

**Tables**:
| Table | Description |
|-------|-------------|
| CUSTOMERS | Cleaned customer data with DQ scoring |
| PRODUCTS | Validated product catalog |
| ORDERS | Order headers with calculated fields |
| ORDER_ITEMS | Flattened line items from JSON |
| EVENTS | Structured event data |

### Gold Layer (Business)

**Purpose**: Business-ready data for analytics and reporting.

**Components**:
- **Dimension Tables**: Descriptive attributes (Date, Customer, Product)
- **Fact Tables**: Metrics and measures at various grains
- **Analytics Views**: Pre-built queries for common analyses

**Key Characteristics**:
- Star schema design
- Pre-aggregated metrics
- SCD Type 2 support for dimensions
- Optimized for query performance
- Self-service analytics ready

**Dimensions**:
| Dimension | Type | Description |
|-----------|------|-------------|
| DIM_DATE | Static | Pre-populated date calendar |
| DIM_CUSTOMER | SCD-2 | Customer attributes |
| DIM_PRODUCT | SCD-2 | Product attributes |
| DIM_GEOGRAPHY | Static | Location hierarchy |

**Facts**:
| Fact | Grain | Description |
|------|-------|-------------|
| FACT_SALES | Order | Order-level metrics |
| FACT_SALES_ITEMS | Line Item | Product-level metrics |
| FACT_DAILY_SALES | Day | Daily aggregations |
| FACT_CUSTOMER_ACTIVITY | Customer-Day | Customer behavior |
| FACT_PRODUCT_PERFORMANCE | Product-Day | Product metrics |

## Data Flow

```
1. Source Files → Stages (PUT command or UI upload)
2. Stages → Bronze Tables (COPY INTO / Stored Procedures)
3. Bronze Tables → Streams (Automatic CDC capture)
4. Streams → Silver Tables (Transformation Procedures)
5. Silver Tables → Gold Dimensions (MERGE operations)
6. Silver Tables → Gold Facts (Aggregation Procedures)
```

## Automation Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TASK ORCHESTRATION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   BRONZE TASKS                SILVER TASKS                GOLD TASKS         │
│   ┌────────────┐              ┌────────────┐              ┌────────────┐    │
│   │ Load       │              │ Transform  │              │ Populate   │    │
│   │ Orders     │──┐           │ Customers  │              │ Dim Cust.  │──┐ │
│   └────────────┘  │           └────────────┘              └────────────┘  │ │
│   ┌────────────┐  │           ┌────────────┐              ┌────────────┐  │ │
│   │ Load       │  ├──Stream──▶│ Transform  │──────────────│ Populate   │──┤ │
│   │ Customers  │  │           │ Products   │              │ Dim Prod.  │  │ │
│   └────────────┘  │           └────────────┘              └────────────┘  │ │
│   ┌────────────┐  │           ┌────────────┐              ┌────────────┐  │ │
│   │ Load       │──┘           │ Transform  │──┐           │ Populate   │──┘ │
│   │ Products   │              │ Orders     │  │           │ Fact Sales │    │
│   └────────────┘              └────────────┘  │           └────────────┘    │
│                               ┌────────────┐  │           ┌────────────┐    │
│                               │ Transform  │◀─┘           │ Daily      │    │
│                               │ Order Items│              │ Snapshot   │    │
│                               └────────────┘              └────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Snowflake Features Used

| Feature | Usage |
|---------|-------|
| **Stages** | File landing zones for data ingestion |
| **File Formats** | JSON and CSV parsing configurations |
| **Streams** | Change Data Capture for incremental processing |
| **Tasks** | Scheduled and event-driven automation |
| **Stored Procedures** | Reusable data transformation logic |
| **VARIANT** | Semi-structured JSON data storage |
| **MERGE** | Upsert operations for dimensions |
| **Clustering** | Performance optimization for large tables |
| **Views** | Pre-built analytics queries |

## Best Practices Implemented

1. **Idempotent Operations**: All procedures can be safely re-run
2. **Incremental Processing**: Stream-based CDC reduces processing time
3. **Data Quality**: DQ scores calculated at Silver layer
4. **Audit Trail**: Metadata columns track data lineage
5. **Separation of Concerns**: Clear boundaries between layers
6. **Role-Based Access**: RBAC for security
7. **Resource Optimization**: Dedicated warehouses per workload type
