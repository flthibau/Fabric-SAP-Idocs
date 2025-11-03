# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze to Silver Transformation - SAP IDoc Orders
# MAGIC
# MAGIC **Purpose:** Transform raw IDoc data from Bronze layer to cleansed Silver layer  
# MAGIC **Source:** `idoc_raw` (Bronze layer)  
# MAGIC **Target:** `idoc_orders_silver` (Silver layer)  
# MAGIC **IDoc Type:** ORDERS (Purchase Orders)
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Transformation Steps
# MAGIC
# MAGIC 1. **Read Bronze Layer** - Filter ORDERS IDoc type
# MAGIC 2. **Parse Nested JSON** - Extract business fields from control and data segments
# MAGIC 3. **Data Validation** - Validate data types, ranges, and business rules
# MAGIC 4. **Deduplication** - Keep latest version per order number
# MAGIC 5. **Enrichment** - Calculate SLA status, order status, derived fields
# MAGIC 6. **Write to Silver** - Upsert to Delta table with merge logic
# MAGIC 7. **Data Quality Checks** - Validate output quality

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔧 1. Configuration and Setup

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, to_date, when, datediff, current_timestamp, current_date,
    get_json_object, lit, row_number, count, isNull
)
from pyspark.sql.window import Window
from delta.tables import DeltaTable
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
BRONZE_TABLE = "idoc_raw"
SILVER_TABLE = "idoc_orders_silver"
IDOC_TYPE = "ORDERS"

logger.info(f"Starting Bronze → Silver transformation for {IDOC_TYPE}")
logger.info(f"Source: {BRONZE_TABLE}")
logger.info(f"Target: {SILVER_TABLE}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📥 2. Read Bronze Layer Data

# COMMAND ----------

# Read Bronze layer - filter for ORDERS IDoc type only
logger.info(f"Reading Bronze layer: {BRONZE_TABLE}")

df_bronze = spark.table(BRONZE_TABLE) \
    .filter(col("idoc_type") == IDOC_TYPE)

# Count records
bronze_count = df_bronze.count()
logger.info(f"Bronze records (ORDERS): {bronze_count:,}")

# Display sample
print("\n=== Bronze Layer Sample ===")
df_bronze.select("message_id", "idoc_type", "sap_system", "timestamp").show(5, truncate=False)

# Display schema
print("\n=== Bronze Layer Schema ===")
df_bronze.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔍 3. Parse Nested JSON Fields
# MAGIC
# MAGIC Extract business fields from the nested JSON structure in the `control` and `data` columns.

# COMMAND ----------

# Parse control segment (IDoc header)
logger.info("Parsing control segment fields...")

df_parsed = df_bronze.select(
    col("message_id"),
    col("sap_system"),
    col("timestamp"),
    
    # Extract from control segment
    get_json_object(col("control"), "$.DOCNUM").alias("order_number"),
    get_json_object(col("control"), "$.DOCTYP").alias("order_type"),
    get_json_object(col("control"), "$.MESTYP").alias("message_type"),
    
    # Extract from data segment (first element of array)
    get_json_object(col("data"), "$[0].CUSTOMER_ID").alias("customer_number"),
    get_json_object(col("data"), "$[0].CUSTOMER_NAME").alias("customer_name"),
    get_json_object(col("data"), "$[0].ORDER_DATE").alias("order_date_raw"),
    get_json_object(col("data"), "$[0].DELIVERY_DATE").alias("delivery_date_raw"),
    get_json_object(col("data"), "$[0].SHIP_DATE").alias("actual_ship_date_raw"),
    get_json_object(col("data"), "$[0].DELIVERED_DATE").alias("actual_delivery_date_raw"),
    get_json_object(col("data"), "$[0].TOTAL_AMOUNT").alias("total_amount_raw"),
    get_json_object(col("data"), "$[0].CURRENCY").alias("currency"),
    get_json_object(col("data"), "$[0].STATUS").alias("order_status_raw"),
    
    # Keep original data for reference
    col("data").alias("line_items_raw")
)

# Display parsed sample
print("\n=== Parsed Fields Sample ===")
df_parsed.select("order_number", "customer_number", "order_date_raw", "total_amount_raw").show(5, truncate=False)

logger.info(f"Parsed {df_parsed.count():,} records")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🧹 4. Data Type Conversion and Validation

# COMMAND ----------

# Convert data types
logger.info("Converting data types and validating...")

df_validated = df_parsed.select(
    col("message_id"),
    col("order_number"),
    col("order_type"),
    col("message_type"),
    col("customer_number"),
    col("customer_name"),
    col("sap_system"),
    
    # Date conversions (SAP format: YYYYMMDD)
    to_date(col("order_date_raw"), "yyyyMMdd").alias("order_date"),
    to_date(col("delivery_date_raw"), "yyyyMMdd").alias("delivery_date"),
    to_date(col("actual_ship_date_raw"), "yyyyMMdd").alias("actual_ship_date"),
    to_date(col("actual_delivery_date_raw"), "yyyyMMdd").alias("actual_delivery_date"),
    
    # Numeric conversion
    col("total_amount_raw").cast("decimal(15,2)").alias("total_amount"),
    
    # String fields
    col("currency"),
    col("order_status_raw").alias("order_status"),
    
    # Keep line items for future processing
    col("line_items_raw"),
    
    # Keep timestamp for deduplication
    col("timestamp")
)

# Data validation - check for invalid conversions
print("\n=== Data Validation Results ===")

# Count null dates (failed conversions)
null_dates = df_validated.filter(col("order_date").isNull()).count()
print(f"Records with invalid order_date: {null_dates}")

# Count null amounts
null_amounts = df_validated.filter(col("total_amount").isNull()).count()
print(f"Records with invalid total_amount: {null_amounts}")

# Check for future dates (data quality issue)
future_dates = df_validated.filter(col("order_date") > current_date()).count()
print(f"Records with future order dates: {future_dates}")

# Display validated sample
print("\n=== Validated Data Sample ===")
df_validated.select(
    "order_number", "order_date", "delivery_date", "total_amount", "currency", "order_status"
).show(5, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔄 5. Deduplication
# MAGIC
# MAGIC Keep only the latest version of each order based on timestamp.

# COMMAND ----------

# Deduplicate - keep latest version per order number
logger.info("Deduplicating records...")

# Define window: partition by order_number, order by timestamp descending
window_spec = Window.partitionBy("order_number", "sap_system").orderBy(col("timestamp").desc())

# Add row number
df_with_row_num = df_validated.withColumn("row_num", row_number().over(window_spec))

# Keep only row_num = 1 (latest)
df_dedup = df_with_row_num.filter(col("row_num") == 1).drop("row_num")

# Log deduplication results
before_count = df_validated.count()
after_count = df_dedup.count()
duplicates_removed = before_count - after_count

logger.info(f"Deduplication complete:")
logger.info(f"  Before: {before_count:,} records")
logger.info(f"  After: {after_count:,} records")
logger.info(f"  Duplicates removed: {duplicates_removed:,}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## ⭐ 6. Enrichment - Calculate Derived Fields

# COMMAND ----------

# Calculate SLA status based on days remaining until delivery
logger.info("Calculating derived fields...")

df_enriched = df_dedup.withColumn(
    "sla_days_remaining",
    datediff(col("delivery_date"), current_date())
).withColumn(
    "sla_status",
    when(col("sla_days_remaining") >= 3, "Good")
    .when(col("sla_days_remaining").between(1, 2), "At Risk")
    .otherwise("Breached")
)

# Standardize order status
df_enriched = df_enriched.withColumn(
    "order_status",
    when(col("actual_delivery_date").isNotNull(), "Delivered")
    .when(col("actual_ship_date").isNotNull(), "Shipped")
    .when(col("order_status") == "CANCELLED", "Cancelled")
    .otherwise("Pending")
)

# Calculate days to ship and deliver
df_enriched = df_enriched.withColumn(
    "days_to_ship",
    datediff(col("actual_ship_date"), col("order_date"))
).withColumn(
    "days_to_delivery",
    datediff(col("actual_delivery_date"), col("order_date"))
)

# Add partner_access_scope for Row-Level Security
df_enriched = df_enriched.withColumn(
    "partner_access_scope",
    col("customer_number")  # Each customer can only see their own orders
)

# Add processing timestamp
df_enriched = df_enriched.withColumn("processed_timestamp", current_timestamp())

# Display enriched sample
print("\n=== Enriched Data Sample ===")
df_enriched.select(
    "order_number", "order_status", "sla_status", "sla_days_remaining", 
    "days_to_ship", "days_to_delivery"
).show(10, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 💾 7. Write to Silver Layer (Upsert)
# MAGIC
# MAGIC Use Delta Lake MERGE for idempotent writes.

# COMMAND ----------

# Prepare final Silver schema
logger.info("Preparing final Silver layer dataset...")

df_silver = df_enriched.select(
    col("order_number"),
    col("order_type"),
    col("order_date"),
    col("customer_number"),
    col("customer_name"),
    col("delivery_date"),
    col("actual_ship_date"),
    col("actual_delivery_date"),
    col("total_amount"),
    col("currency"),
    col("order_status"),
    col("sla_status"),
    col("sla_days_remaining"),
    col("days_to_ship"),
    col("days_to_delivery"),
    col("sap_system"),
    col("partner_access_scope"),
    col("processed_timestamp")
)

# Display final schema
print("\n=== Silver Layer Schema ===")
df_silver.printSchema()

logger.info(f"Final Silver records: {df_silver.count():,}")

# COMMAND ----------

# Write to Silver table using MERGE (upsert)
logger.info(f"Writing to Silver table: {SILVER_TABLE}...")

# Check if table exists
if DeltaTable.isDeltaTable(spark, f"Tables/{SILVER_TABLE}"):
    logger.info("Table exists - performing MERGE (upsert)")
    
    # Get Delta table
    delta_table = DeltaTable.forPath(spark, f"Tables/{SILVER_TABLE}")
    
    # Merge condition: match on order_number and sap_system
    merge_condition = "target.order_number = source.order_number AND target.sap_system = source.sap_system"
    
    # Execute merge
    delta_table.alias("target").merge(
        df_silver.alias("source"),
        merge_condition
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
    
    logger.info("MERGE completed successfully")
    
else:
    logger.info("Table does not exist - creating new table")
    
    # Create new Delta table
    df_silver.write \
        .format("delta") \
        .mode("overwrite") \
        .option("overwriteSchema", "true") \
        .partitionBy("order_date") \
        .saveAsTable(SILVER_TABLE)
    
    logger.info(f"Table {SILVER_TABLE} created successfully")

print("\n✅ Silver layer write complete")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔍 8. Data Quality Validation

# COMMAND ----------

# Read back from Silver table for validation
logger.info("Running data quality checks on Silver table...")

df_silver_check = spark.table(SILVER_TABLE)

print("\n=== DATA QUALITY REPORT ===")
print(f"Table: {SILVER_TABLE}")
print(f"Total Records: {df_silver_check.count():,}\n")

# Check 1: Completeness (mandatory fields)
print("1. COMPLETENESS CHECK (Mandatory Fields)")
mandatory_fields = ["order_number", "order_date", "customer_number", "total_amount"]

for field in mandatory_fields:
    null_count = df_silver_check.filter(col(field).isNull()).count()
    total = df_silver_check.count()
    completeness_pct = ((total - null_count) / total * 100) if total > 0 else 0
    status = "✅ PASS" if completeness_pct == 100 else "❌ FAIL"
    print(f"  {field}: {completeness_pct:.2f}% complete ({null_count} nulls) {status}")

# Check 2: Uniqueness (primary key)
print("\n2. UNIQUENESS CHECK (Primary Key)")
total_records = df_silver_check.count()
distinct_orders = df_silver_check.select("order_number", "sap_system").distinct().count()
duplicates = total_records - distinct_orders
uniqueness_status = "✅ PASS" if duplicates == 0 else "❌ FAIL"
print(f"  Total Records: {total_records:,}")
print(f"  Distinct Orders: {distinct_orders:,}")
print(f"  Duplicates: {duplicates} {uniqueness_status}")

# Check 3: Validity (allowed values)
print("\n3. VALIDITY CHECK (Allowed Values)")

# Valid currencies
valid_currencies = ["USD", "EUR", "GBP", "JPY", "CNY"]
invalid_currency = df_silver_check.filter(~col("currency").isin(valid_currencies)).count()
currency_status = "✅ PASS" if invalid_currency == 0 else "⚠️ WARNING"
print(f"  Invalid currency codes: {invalid_currency} {currency_status}")

# Valid order statuses
valid_statuses = ["Pending", "Shipped", "Delivered", "Cancelled"]
invalid_status = df_silver_check.filter(~col("order_status").isin(valid_statuses)).count()
status_check = "✅ PASS" if invalid_status == 0 else "⚠️ WARNING"
print(f"  Invalid order statuses: {invalid_status} {status_check}")

# Check 4: Business Rules
print("\n4. BUSINESS RULES CHECK")

# Delivery date should be >= order date
invalid_delivery_dates = df_silver_check.filter(
    col("delivery_date") < col("order_date")
).count()
delivery_date_status = "✅ PASS" if invalid_delivery_dates == 0 else "❌ FAIL"
print(f"  Invalid delivery dates (before order date): {invalid_delivery_dates} {delivery_date_status}")

# Negative amounts
negative_amounts = df_silver_check.filter(col("total_amount") < 0).count()
amount_status = "✅ PASS" if negative_amounts == 0 else "❌ FAIL"
print(f"  Negative order amounts: {negative_amounts} {amount_status}")

# Check 5: Timeliness
print("\n5. TIMELINESS CHECK")
from pyspark.sql.functions import hour

old_records = df_silver_check.filter(
    hour(current_timestamp() - col("processed_timestamp")) > 24
).count()
timeliness_status = "✅ PASS" if old_records == 0 else "⚠️ WARNING"
print(f"  Records older than 24 hours: {old_records} {timeliness_status}")

# Overall Quality Score
print("\n" + "="*50)
total_checks = 10  # Manual count of all checks
failed_checks = (
    (1 if duplicates > 0 else 0) +
    (1 if invalid_delivery_dates > 0 else 0) +
    (1 if negative_amounts > 0 else 0)
)
quality_score = ((total_checks - failed_checks) / total_checks * 100)
print(f"OVERALL QUALITY SCORE: {quality_score:.1f}%")

if quality_score >= 95:
    print("✅ Data quality meets standards")
elif quality_score >= 80:
    print("⚠️ Data quality acceptable but needs improvement")
else:
    print("❌ Data quality below acceptable threshold")

print("="*50)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📊 9. Summary Statistics

# COMMAND ----------

# Display summary statistics
print("\n=== SILVER LAYER SUMMARY ===")

summary = spark.sql(f"""
    SELECT 
        COUNT(*) as total_orders,
        COUNT(DISTINCT customer_number) as unique_customers,
        COUNT(DISTINCT sap_system) as sap_systems,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value,
        MIN(order_date) as earliest_order,
        MAX(order_date) as latest_order,
        COUNT(CASE WHEN order_status = 'Delivered' THEN 1 END) as delivered_orders,
        COUNT(CASE WHEN sla_status = 'Good' THEN 1 END) as sla_good,
        COUNT(CASE WHEN sla_status = 'At Risk' THEN 1 END) as sla_at_risk,
        COUNT(CASE WHEN sla_status = 'Breached' THEN 1 END) as sla_breached
    FROM {SILVER_TABLE}
""")

summary.show(vertical=True, truncate=False)

# Status breakdown
print("\n=== ORDER STATUS BREAKDOWN ===")
spark.sql(f"""
    SELECT 
        order_status,
        COUNT(*) as count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
    FROM {SILVER_TABLE}
    GROUP BY order_status
    ORDER BY count DESC
""").show()

# SLA status breakdown
print("\n=== SLA STATUS BREAKDOWN ===")
spark.sql(f"""
    SELECT 
        sla_status,
        COUNT(*) as count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
    FROM {SILVER_TABLE}
    GROUP BY sla_status
    ORDER BY 
        CASE sla_status 
            WHEN 'Good' THEN 1 
            WHEN 'At Risk' THEN 2 
            WHEN 'Breached' THEN 3 
        END
""").show()

logger.info("Bronze → Silver transformation completed successfully ✅")

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC
# MAGIC ## 🎓 Next Steps
# MAGIC
# MAGIC You have successfully transformed raw Bronze data into cleansed Silver data!
# MAGIC
# MAGIC **What you accomplished:**
# MAGIC - ✅ Parsed nested JSON structures
# MAGIC - ✅ Validated and converted data types
# MAGIC - ✅ Deduplicated records
# MAGIC - ✅ Calculated derived fields (SLA status, days to ship)
# MAGIC - ✅ Implemented upsert logic with Delta Lake MERGE
# MAGIC - ✅ Validated data quality
# MAGIC
# MAGIC **Next:** Proceed to **Silver to Gold transformation** to create business-ready aggregations.
# MAGIC
# MAGIC See: `silver-to-gold.py`
