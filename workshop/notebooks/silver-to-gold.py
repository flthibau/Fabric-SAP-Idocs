# Databricks notebook source
# MAGIC %md
# MAGIC # Silver to Gold Transformation - Orders Daily Summary
# MAGIC
# MAGIC **Purpose:** Aggregate Silver layer data into Gold layer business metrics  
# MAGIC **Source:** `idoc_orders_silver` (Silver layer)  
# MAGIC **Target:** `orders_daily_summary` (Gold layer)  
# MAGIC **Refresh:** Scheduled (daily) or on-demand
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Aggregation Steps
# MAGIC
# MAGIC 1. **Read Silver Layer** - Load cleansed orders data
# MAGIC 2. **Group by Dimensions** - Aggregate by day, SAP system, SLA status, partner
# MAGIC 3. **Calculate Metrics** - Count, sum, average, min, max
# MAGIC 4. **Calculate KPIs** - SLA compliance %, delivery rate %, cancellation rate %
# MAGIC 5. **Write to Gold** - Upsert with merge logic
# MAGIC 6. **Optimize** - Run OPTIMIZE and VACUUM
# MAGIC 7. **Validate** - Quality checks and summary report

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔧 1. Configuration and Setup

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as _sum, avg, min as _min, max as _max,
    date_trunc, current_timestamp, when, datediff, lit, round as _round
)
from delta.tables import DeltaTable
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
SILVER_TABLE = "idoc_orders_silver"
GOLD_TABLE = "orders_daily_summary"

logger.info(f"Starting Silver → Gold transformation")
logger.info(f"Source: {SILVER_TABLE}")
logger.info(f"Target: {GOLD_TABLE}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📥 2. Read Silver Layer Data

# COMMAND ----------

# Read Silver layer
logger.info(f"Reading Silver layer: {SILVER_TABLE}")

df_silver = spark.table(SILVER_TABLE)

# Count records
silver_count = df_silver.count()
logger.info(f"Silver layer records: {silver_count:,}")

# Display sample
print("\n=== Silver Layer Sample ===")
df_silver.select(
    "order_number", "order_date", "customer_number", "total_amount", 
    "order_status", "sla_status"
).show(5, truncate=False)

# Display schema
print("\n=== Silver Layer Schema ===")
df_silver.printSchema()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📊 3. Calculate Daily Aggregations
# MAGIC
# MAGIC Aggregate by order day, SAP system, SLA status, and partner (for Row-Level Security).

# COMMAND ----------

# Group by dimensions and calculate metrics
logger.info("Calculating daily aggregations...")

df_gold = df_silver.groupBy(
    # Dimensions
    date_trunc("day", col("order_date")).alias("order_day"),
    col("sap_system"),
    col("sla_status"),
    col("partner_access_scope")  # For Row-Level Security filtering
).agg(
    # Volume metrics
    count("*").alias("total_orders"),
    count(when(col("order_status") == "Delivered", 1)).alias("delivered_orders"),
    count(when(col("order_status") == "Shipped", 1)).alias("shipped_orders"),
    count(when(col("order_status") == "Pending", 1)).alias("pending_orders"),
    count(when(col("order_status") == "Cancelled", 1)).alias("cancelled_orders"),
    
    # Financial metrics
    _sum("total_amount").alias("total_revenue"),
    avg("total_amount").alias("avg_order_value"),
    _min("total_amount").alias("min_order_value"),
    _max("total_amount").alias("max_order_value"),
    
    # Performance metrics (only for shipped/delivered orders)
    avg(when(col("days_to_ship").isNotNull(), col("days_to_ship"))).alias("avg_days_to_ship"),
    avg(when(col("days_to_delivery").isNotNull(), col("days_to_delivery"))).alias("avg_days_to_delivery"),
    
    # SLA metrics by status
    count(when(col("sla_status") == "Good", 1)).alias("sla_good_count"),
    count(when(col("sla_status") == "At Risk", 1)).alias("sla_at_risk_count"),
    count(when(col("sla_status") == "Breached", 1)).alias("sla_breached_count")
)

# Display intermediate results
print("\n=== Aggregated Metrics Sample ===")
df_gold.select(
    "order_day", "sap_system", "sla_status", "total_orders", "total_revenue"
).show(5, truncate=False)

logger.info(f"Aggregated into {df_gold.count():,} summary records")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📈 4. Calculate KPI Percentages

# COMMAND ----------

# Calculate percentage-based KPIs
logger.info("Calculating KPI percentages...")

df_gold = df_gold.withColumn(
    "sla_compliance_pct",
    _round((col("sla_good_count") / col("total_orders") * 100), 2)
).withColumn(
    "delivery_rate_pct",
    _round((col("delivered_orders") / col("total_orders") * 100), 2)
).withColumn(
    "cancellation_rate_pct",
    _round((col("cancelled_orders") / col("total_orders") * 100), 2)
).withColumn(
    "pending_rate_pct",
    _round((col("pending_orders") / col("total_orders") * 100), 2)
)

# Round financial metrics to 2 decimal places
df_gold = df_gold.withColumn(
    "total_revenue",
    _round(col("total_revenue"), 2)
).withColumn(
    "avg_order_value",
    _round(col("avg_order_value"), 2)
).withColumn(
    "avg_days_to_ship",
    _round(col("avg_days_to_ship"), 2)
).withColumn(
    "avg_days_to_delivery",
    _round(col("avg_days_to_delivery"), 2)
)

# Add processing timestamp
df_gold = df_gold.withColumn("processed_timestamp", current_timestamp())

# Display with KPIs
print("\n=== Gold Layer with KPIs ===")
df_gold.select(
    "order_day", "sla_status", "total_orders", "total_revenue",
    "sla_compliance_pct", "delivery_rate_pct", "cancellation_rate_pct"
).show(10, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 💾 5. Write to Gold Layer (Upsert)
# MAGIC
# MAGIC Use Delta Lake MERGE for idempotent writes.

# COMMAND ----------

# Prepare final Gold schema
logger.info("Preparing final Gold layer dataset...")

df_gold_final = df_gold.select(
    col("order_day"),
    col("sap_system"),
    col("sla_status"),
    col("partner_access_scope"),
    col("total_orders"),
    col("delivered_orders"),
    col("shipped_orders"),
    col("pending_orders"),
    col("cancelled_orders"),
    col("total_revenue"),
    col("avg_order_value"),
    col("min_order_value"),
    col("max_order_value"),
    col("avg_days_to_ship"),
    col("avg_days_to_delivery"),
    col("sla_good_count"),
    col("sla_at_risk_count"),
    col("sla_breached_count"),
    col("sla_compliance_pct"),
    col("delivery_rate_pct"),
    col("cancellation_rate_pct"),
    col("pending_rate_pct"),
    col("processed_timestamp")
)

# Sort by date and system
df_gold_final = df_gold_final.orderBy("order_day", "sap_system", "sla_status")

# Display final schema
print("\n=== Gold Layer Final Schema ===")
df_gold_final.printSchema()

logger.info(f"Final Gold records: {df_gold_final.count():,}")

# COMMAND ----------

# Write to Gold table using MERGE (upsert)
logger.info(f"Writing to Gold table: {GOLD_TABLE}...")

# Check if table exists
if DeltaTable.isDeltaTable(spark, f"Tables/{GOLD_TABLE}"):
    logger.info("Table exists - performing MERGE (upsert)")
    
    # Get Delta table
    delta_table = DeltaTable.forPath(spark, f"Tables/{GOLD_TABLE}")
    
    # Merge condition: match on all dimension fields
    merge_condition = """
        target.order_day = source.order_day 
        AND target.sap_system = source.sap_system
        AND target.sla_status = source.sla_status
        AND target.partner_access_scope = source.partner_access_scope
    """
    
    # Execute merge
    delta_table.alias("target").merge(
        df_gold_final.alias("source"),
        merge_condition
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
    
    logger.info("MERGE completed successfully")
    
else:
    logger.info("Table does not exist - creating new table")
    
    # Create new Delta table
    df_gold_final.write \
        .format("delta") \
        .mode("overwrite") \
        .option("overwriteSchema", "true") \
        .partitionBy("order_day") \
        .saveAsTable(GOLD_TABLE)
    
    logger.info(f"Table {GOLD_TABLE} created successfully")

print("\n✅ Gold layer write complete")

# COMMAND ----------

# MAGIC %md
# MAGIC ## ⚡ 6. Optimize Delta Table
# MAGIC
# MAGIC Run OPTIMIZE and Z-ORDER for better query performance.

# COMMAND ----------

# Optimize table (compact small files)
logger.info("Optimizing Delta table...")

spark.sql(f"""
    OPTIMIZE {GOLD_TABLE}
    ZORDER BY (sap_system, sla_status, partner_access_scope)
""")

logger.info("Optimization completed")

# Vacuum old files (cleanup versions older than 7 days)
logger.info("Running VACUUM...")

spark.sql(f"""
    VACUUM {GOLD_TABLE} RETAIN 168 HOURS
""")

logger.info("Vacuum completed")

# Display table history
print("\n=== Delta Table History ===")
spark.sql(f"DESCRIBE HISTORY {GOLD_TABLE}").select(
    "version", "timestamp", "operation", "operationMetrics"
).show(5, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔍 7. Data Quality Validation

# COMMAND ----------

# Read back from Gold table for validation
logger.info("Running data quality checks on Gold table...")

df_gold_check = spark.table(GOLD_TABLE)

print("\n=== DATA QUALITY REPORT ===")
print(f"Table: {GOLD_TABLE}")
print(f"Total Records: {df_gold_check.count():,}\n")

# Check 1: Completeness (mandatory fields)
print("1. COMPLETENESS CHECK")
mandatory_fields = ["order_day", "total_orders", "total_revenue", "sla_compliance_pct"]

for field in mandatory_fields:
    null_count = df_gold_check.filter(col(field).isNull()).count()
    total = df_gold_check.count()
    completeness_pct = ((total - null_count) / total * 100) if total > 0 else 0
    status = "✅ PASS" if completeness_pct == 100 else "❌ FAIL"
    print(f"  {field}: {completeness_pct:.2f}% complete {status}")

# Check 2: Range validation (percentages)
print("\n2. RANGE VALIDATION (Percentages 0-100)")

invalid_sla = df_gold_check.filter(
    (col("sla_compliance_pct") < 0) | (col("sla_compliance_pct") > 100)
).count()
sla_status = "✅ PASS" if invalid_sla == 0 else "❌ FAIL"
print(f"  Invalid SLA compliance %: {invalid_sla} {sla_status}")

invalid_delivery = df_gold_check.filter(
    (col("delivery_rate_pct") < 0) | (col("delivery_rate_pct") > 100)
).count()
delivery_status = "✅ PASS" if invalid_delivery == 0 else "❌ FAIL"
print(f"  Invalid delivery rate %: {invalid_delivery} {delivery_status}")

# Check 3: Consistency (sum of status counts = total)
print("\n3. CONSISTENCY CHECK")

inconsistent = df_gold_check.filter(
    (col("delivered_orders") + col("shipped_orders") + 
     col("pending_orders") + col("cancelled_orders")) != col("total_orders")
).count()
consistency_status = "✅ PASS" if inconsistent == 0 else "⚠️ WARNING"
print(f"  Inconsistent order counts: {inconsistent} {consistency_status}")

# Check 4: Business rules
print("\n4. BUSINESS RULES CHECK")

# Average should be between min and max
invalid_avg = df_gold_check.filter(
    (col("avg_order_value") < col("min_order_value")) |
    (col("avg_order_value") > col("max_order_value"))
).count()
avg_status = "✅ PASS" if invalid_avg == 0 else "❌ FAIL"
print(f"  Invalid avg (not between min/max): {invalid_avg} {avg_status}")

# Negative revenue
negative_revenue = df_gold_check.filter(col("total_revenue") < 0).count()
revenue_status = "✅ PASS" if negative_revenue == 0 else "❌ FAIL"
print(f"  Negative revenue: {negative_revenue} {revenue_status}")

# Check 5: Timeliness
print("\n5. TIMELINESS CHECK")
from pyspark.sql.functions import hour

old_records = df_gold_check.filter(
    hour(current_timestamp() - col("processed_timestamp")) > 24
).count()
timeliness_status = "✅ PASS" if old_records == 0 else "⚠️ WARNING"
print(f"  Records older than 24 hours: {old_records} {timeliness_status}")

# Overall Quality Score
print("\n" + "="*50)
total_checks = 8
failed_checks = (
    (1 if invalid_sla > 0 else 0) +
    (1 if invalid_delivery > 0 else 0) +
    (1 if invalid_avg > 0 else 0) +
    (1 if negative_revenue > 0 else 0)
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
# MAGIC ## 📊 8. Summary Report and Analytics

# COMMAND ----------

# Overall summary
print("\n=== GOLD LAYER SUMMARY ===")

summary = spark.sql(f"""
    SELECT 
        COUNT(DISTINCT order_day) as total_days,
        COUNT(DISTINCT sap_system) as total_systems,
        COUNT(*) as total_rows,
        SUM(total_orders) as total_orders_all_time,
        SUM(total_revenue) as total_revenue_all_time,
        AVG(sla_compliance_pct) as avg_sla_compliance_pct,
        AVG(delivery_rate_pct) as avg_delivery_rate_pct,
        MIN(order_day) as earliest_day,
        MAX(order_day) as latest_day,
        MAX(processed_timestamp) as last_processed
    FROM {GOLD_TABLE}
""")

summary.show(vertical=True, truncate=False)

# Latest day summary
print("\n=== LATEST DAY METRICS ===")
latest_day = spark.sql(f"""
    SELECT 
        order_day,
        sap_system,
        SUM(total_orders) as orders,
        SUM(total_revenue) as revenue,
        AVG(sla_compliance_pct) as sla_pct,
        AVG(delivery_rate_pct) as delivery_pct
    FROM {GOLD_TABLE}
    WHERE order_day = (SELECT MAX(order_day) FROM {GOLD_TABLE})
    GROUP BY order_day, sap_system
    ORDER BY sap_system
""")

latest_day.show(truncate=False)

# SLA Status Distribution
print("\n=== SLA STATUS DISTRIBUTION ===")
sla_dist = spark.sql(f"""
    SELECT 
        sla_status,
        SUM(total_orders) as total_orders,
        SUM(total_revenue) as total_revenue,
        ROUND(AVG(sla_compliance_pct), 2) as avg_compliance_pct
    FROM {GOLD_TABLE}
    GROUP BY sla_status
    ORDER BY 
        CASE sla_status 
            WHEN 'Good' THEN 1 
            WHEN 'At Risk' THEN 2 
            WHEN 'Breached' THEN 3 
        END
""")

sla_dist.show(truncate=False)

# Trend analysis (last 7 days)
print("\n=== 7-DAY TREND ===")
trend = spark.sql(f"""
    SELECT 
        order_day,
        SUM(total_orders) as orders,
        SUM(total_revenue) as revenue,
        ROUND(AVG(sla_compliance_pct), 2) as sla_compliance
    FROM {GOLD_TABLE}
    WHERE order_day >= date_sub(current_date(), 7)
    GROUP BY order_day
    ORDER BY order_day DESC
""")

trend.show(truncate=False)

logger.info("Silver → Gold transformation completed successfully ✅")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 📋 9. Set Table Properties for Governance

# COMMAND ----------

# Add table metadata for governance and documentation
logger.info("Setting table properties...")

spark.sql(f"""
    ALTER TABLE {GOLD_TABLE}
    SET TBLPROPERTIES (
        'description' = 'Gold layer - Daily order summary with KPIs and business metrics',
        'quality_level' = 'Gold',
        'data_classification' = 'Internal',
        'refresh_frequency' = 'Daily at 2:00 AM UTC',
        'retention_days' = '2555',
        'owner' = '3PL Analytics Team',
        'source_table' = 'idoc_orders_silver',
        'last_optimized' = current_timestamp()
    )
""")

logger.info("Table properties updated")

# Verify properties
print("\n=== Table Properties ===")
spark.sql(f"SHOW TBLPROPERTIES {GOLD_TABLE}").show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC
# MAGIC ## 🎓 Congratulations!
# MAGIC
# MAGIC You have successfully created a Gold layer with business-ready analytics!
# MAGIC
# MAGIC **What you accomplished:**
# MAGIC - ✅ Aggregated Silver data into daily summaries
# MAGIC - ✅ Calculated volume, financial, and performance metrics
# MAGIC - ✅ Computed KPI percentages (SLA compliance, delivery rate)
# MAGIC - ✅ Implemented upsert logic with Delta Lake MERGE
# MAGIC - ✅ Optimized table with OPTIMIZE and Z-ORDER
# MAGIC - ✅ Validated data quality
# MAGIC - ✅ Generated summary reports and trend analysis
# MAGIC
# MAGIC **Key Metrics Available:**
# MAGIC - 📊 Daily order volumes by SAP system and SLA status
# MAGIC - 💰 Revenue metrics (total, average, min, max)
# MAGIC - ⏱️ Performance metrics (days to ship, days to delivery)
# MAGIC - 📈 KPIs (SLA compliance %, delivery rate %, cancellation rate %)
# MAGIC - 🔍 Row-Level Security enabled via partner_access_scope
# MAGIC
# MAGIC **Next Steps:**
# MAGIC 1. Set up scheduled refresh (daily at 2 AM)
# MAGIC 2. Create additional Gold tables (shipments, revenue, warehouse)
# MAGIC 3. Build Power BI dashboards
# MAGIC 4. Expose via GraphQL API (Module 6)
# MAGIC
# MAGIC **Continue Learning:**
# MAGIC - [Module 5: OneLake Security and RLS](../labs/module5-security-rls.md)
# MAGIC - [Module 6: GraphQL API Development](../labs/module6-api-development.md)
