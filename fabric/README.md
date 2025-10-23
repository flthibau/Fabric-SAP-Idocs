# Microsoft Fabric Components

## Overview

This directory contains all Microsoft Fabric-related configurations and code for the SAP 3PL Data Product, including:
- Eventstream configuration
- Data Engineering pipelines (Spark)
- SQL Warehouse schema

## Structure

```
fabric/
├── eventstream/
│   └── eventstream-config.json       # Eventstream configuration
├── data-engineering/
│   ├── notebooks/
│   │   ├── bronze_to_silver.ipynb    # Bronze → Silver transformation
│   │   ├── silver_to_gold.ipynb      # Silver → Gold transformation
│   │   └── data_quality_checks.ipynb # Quality validation
│   └── pipelines/
│       ├── ingestion_pipeline.json   # Main ingestion pipeline
│       └── transformation_pipeline.json
└── warehouse/
    └── schema/
        ├── bronze_tables.sql         # Bronze layer DDL
        ├── silver_tables.sql         # Silver layer DDL
        ├── gold_dimensions.sql       # Gold dimension tables
        └── gold_facts.sql            # Gold fact tables
```

## Prerequisites

- Microsoft Fabric capacity (F64 or higher recommended)
- Fabric workspace created
- Lakehouse created: `sap-idoc-lakehouse`
- SQL Warehouse created: `sap-3pl-warehouse`
- Service Principal or User account with permissions

## Setup Instructions

### 1. Eventstream Setup

1. Navigate to your Fabric workspace
2. Create a new Eventstream: `sap-idoc-ingest`
3. Configure source (Event Hub)
4. Apply transformation from `eventstream/eventstream-config.json`
5. Set destination to Lakehouse

### 2. Lakehouse Configuration

```bash
# Create Lakehouse using Fabric API or UI
# Name: sap-idoc-lakehouse
```

Run DDL scripts in order:
1. `warehouse/schema/bronze_tables.sql`
2. `warehouse/schema/silver_tables.sql`
3. `warehouse/schema/gold_dimensions.sql`
4. `warehouse/schema/gold_facts.sql`

### 3. Data Engineering Pipelines

Import notebooks:
1. Upload notebooks to Fabric workspace
2. Attach to Lakehouse
3. Configure Spark settings

Schedule pipelines:
- Bronze to Silver: Every 5 minutes
- Silver to Gold: Every 15 minutes
- Data Quality: Hourly

## Medallion Architecture

### Bronze Layer (Raw)
- Purpose: Store raw IDoc messages
- Format: Delta Lake
- Retention: 90 days
- Partitioning: By date and IDoc type

### Silver Layer (Cleansed)
- Purpose: Cleaned and normalized data
- Format: Delta Lake
- Retention: 2 years
- Features: Deduplication, validation, standardization

### Gold Layer (Analytics)
- Purpose: Business-ready dimensional model
- Format: SQL Warehouse tables
- Retention: 7 years
- Design: Star schema with dimensions and facts

## Key Tables

| Table | Layer | Description |
|-------|-------|-------------|
| `bronze_idocs` | Bronze | Raw IDoc messages |
| `silver_shipments` | Silver | Cleansed shipment data |
| `silver_deliveries` | Silver | Cleansed delivery data |
| `dim_customer` | Gold | Customer dimension |
| `dim_location` | Gold | Location dimension |
| `fact_shipment` | Gold | Shipment fact table |

## Data Transformation Flow

```
Event Hub
    ↓
Eventstream (validation, enrichment)
    ↓
bronze_idocs (raw storage)
    ↓
Spark Notebook: bronze_to_silver
    ↓
silver_* tables (cleansed data)
    ↓
Spark Notebook: silver_to_gold
    ↓
dim_* & fact_* tables (analytics)
```

## Monitoring

- Use Fabric Monitoring for Eventstream metrics
- Check pipeline execution history
- Monitor Delta Lake table metrics
- Set up alerts for pipeline failures

## Performance Optimization

### Delta Lake Optimization

```sql
-- Optimize tables regularly
OPTIMIZE bronze_idocs ZORDER BY (idoc_type, processing_date);
OPTIMIZE silver_shipments ZORDER BY (customer_id, ship_date);

-- Vacuum old versions
VACUUM bronze_idocs RETAIN 168 HOURS;
VACUUM silver_shipments RETAIN 168 HOURS;
```

### Spark Configuration

```python
# Recommended Spark settings for notebooks
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")
spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
```

## Troubleshooting

### Eventstream Issues
- Check Event Hub connectivity
- Verify schema validation rules
- Review error logs in monitoring

### Pipeline Failures
- Check Spark logs
- Verify table permissions
- Ensure sufficient capacity

### Performance Issues
- Review partition strategy
- Optimize Delta tables
- Increase Spark compute resources

## Development Workflow

1. Develop transformations in notebooks
2. Test with sample data
3. Validate data quality
4. Deploy to production workspace
5. Schedule pipelines

## Contributing

When modifying Fabric components:
1. Test in development workspace
2. Document changes in notebook markdown
3. Update this README
4. Create backup of current configuration
5. Deploy changes incrementally

## Support

- Fabric Documentation: https://learn.microsoft.com/fabric/
- Internal Support: data-engineering@company.com
