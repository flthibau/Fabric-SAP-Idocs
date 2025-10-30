# Databricks notebook source
# MAGIC %md
# MAGIC # Gold Layer - Orders Daily Summary
# MAGIC 
# MAGIC **Purpose:** Agrégations quotidiennes des commandes par SAP système  
# MAGIC **Source:** idoc_orders_silver (via Lakehouse shortcut)  
# MAGIC **Target:** orders_daily_summary (Delta table native Lakehouse)  
# MAGIC **Refresh:** Scheduled pipeline (daily at 2 AM) + on-demand trigger

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Configuration

# COMMAND ----------

from pyspark.sql import SparkSession, Window
from pyspark.sql.functions import (
    col, count, sum as _sum, avg, min as _min, max as _max,
    date_trunc, current_timestamp, lit, when, datediff
)
from delta.tables import DeltaTable
import logging

# Configuration
LAKEHOUSE_NAME = "Lakehouse3PLAnalytics"
SOURCE_TABLE = "idoc_orders_silver"  # Via OneLake shortcut
TARGET_TABLE = "orders_daily_summary"  # Delta table native
TARGET_LOCATION = f"Tables/{TARGET_TABLE}"

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Read Silver Layer (via Shortcut)

# COMMAND ----------

logger.info(f"Reading source table: {SOURCE_TABLE}")

# Lire la table Silver via le shortcut OneLake
df_orders_silver = spark.table(SOURCE_TABLE)

# Validation
row_count = df_orders_silver.count()
logger.info(f"Source rows: {row_count:,}")

# Afficher schema
df_orders_silver.printSchema()

# Sample pour debug
display(df_orders_silver.limit(5))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Business Logic - Daily Aggregations

# COMMAND ----------

logger.info("Computing daily aggregations...")

# Agrégations quotidiennes par SAP système, SLA status ET partner_access_scope (pour RLS)
df_gold = df_orders_silver.groupBy(
    date_trunc("day", col("order_date")).alias("order_day"),
    col("sap_system"),
    col("sla_status"),
    col("partner_access_scope")  # AJOUT: Colonne RLS pour filtrage par partenaire
).agg(
    # Métriques de volume
    count("*").alias("total_orders"),
    count(when(col("order_status") == "Delivered", 1)).alias("delivered_orders"),
    count(when(col("order_status") == "Cancelled", 1)).alias("cancelled_orders"),
    
    # Métriques financières
    _sum("total_amount").alias("total_revenue"),
    avg("total_amount").alias("avg_order_value"),
    _min("total_amount").alias("min_order_value"),
    _max("total_amount").alias("max_order_value"),
    
    # Métriques de performance
    avg(
        datediff(col("actual_ship_date"), col("order_date"))
    ).alias("avg_days_to_ship"),
    
    avg(
        datediff(col("actual_delivery_date"), col("order_date"))
    ).alias("avg_days_to_delivery"),
    
    # SLA metrics
    count(when(col("sla_status") == "Good", 1)).alias("sla_good_count"),
    count(when(col("sla_status") == "At Risk", 1)).alias("sla_at_risk_count"),
    count(when(col("sla_status") == "Breached", 1)).alias("sla_breached_count")
)

# Calculer % SLA Compliance
df_gold = df_gold.withColumn(
    "sla_compliance_pct",
    (col("sla_good_count") / col("total_orders") * 100).cast("decimal(5,2)")
)

# Calculer delivery rate
df_gold = df_gold.withColumn(
    "delivery_rate_pct",
    (col("delivered_orders") / col("total_orders") * 100).cast("decimal(5,2)")
)

# Calculer cancellation rate
df_gold = df_gold.withColumn(
    "cancellation_rate_pct",
    (col("cancelled_orders") / col("total_orders") * 100).cast("decimal(5,2)")
)

# Ajouter métadonnées
df_gold = df_gold.withColumn("processed_timestamp", current_timestamp())
df_gold = df_gold.withColumn("source_table", lit(SOURCE_TABLE))

# Tri par date et système
df_gold = df_gold.orderBy("order_day", "sap_system", "sla_status", "partner_access_scope")

# Validation
logger.info(f"Gold rows computed: {df_gold.count():,}")
display(df_gold.limit(10))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Write to Delta Table (Upsert)

# COMMAND ----------

logger.info(f"Writing to Delta table: {TARGET_TABLE}")

# Mode: Merge (upsert) pour idempotence
# Clé: order_day + sap_system + sla_status

if DeltaTable.isDeltaTable(spark, TARGET_LOCATION):
    logger.info("Delta table exists - performing MERGE")
    
    # Table existante
    delta_table = DeltaTable.forPath(spark, TARGET_LOCATION)
    
    # Merge condition
    merge_condition = """
        target.order_day = source.order_day 
        AND target.sap_system = source.sap_system
        AND target.sla_status = source.sla_status
        AND target.partner_access_scope = source.partner_access_scope
    """
    
    # Upsert
    delta_table.alias("target").merge(
        df_gold.alias("source"),
        merge_condition
    ).whenMatchedUpdateAll(
    ).whenNotMatchedInsertAll(
    ).execute()
    
    logger.info("MERGE completed successfully")
    
else:
    logger.info("Delta table does not exist - creating new table")
    
    # Créer nouvelle table Delta
    df_gold.write \
        .format("delta") \
        .mode("overwrite") \
        .option("overwriteSchema", "true") \
        .partitionBy("order_day") \
        .saveAsTable(TARGET_TABLE)
    
    logger.info(f"Delta table {TARGET_TABLE} created successfully")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Optimize & Vacuum

# COMMAND ----------

logger.info("Optimizing Delta table...")

# Optimize (compaction)
spark.sql(f"""
    OPTIMIZE {TARGET_TABLE}
    ZORDER BY (sap_system, sla_status)
""")

logger.info("Optimization completed")

# Vacuum (cleanup old files > 7 days)
spark.sql(f"""
    VACUUM {TARGET_TABLE} RETAIN 168 HOURS
""")

logger.info("Vacuum completed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Data Quality Validation

# COMMAND ----------

logger.info("Running data quality checks...")

# Check 1: No nulls in key columns
null_check = df_gold.select([
    count(when(col(c).isNull(), 1)).alias(c)
    for c in ["order_day", "sap_system", "sla_status", "total_orders"]
])

logger.info("Null check results:")
display(null_check)

# Check 2: SLA compliance % between 0-100
sla_range_check = df_gold.filter(
    (col("sla_compliance_pct") < 0) | (col("sla_compliance_pct") > 100)
).count()

if sla_range_check > 0:
    logger.warning(f"⚠️ {sla_range_check} rows with invalid SLA compliance %")
else:
    logger.info("✅ SLA compliance % validation passed")

# Check 3: Total orders = sum of status counts
consistency_check = df_gold.withColumn(
    "sum_check",
    col("delivered_orders") + col("cancelled_orders")
).filter(
    col("sum_check") > col("total_orders")
).count()

if consistency_check > 0:
    logger.warning(f"⚠️ {consistency_check} rows with inconsistent counts")
else:
    logger.info("✅ Order count consistency validation passed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Summary Report

# COMMAND ----------

# Final summary
summary = spark.sql(f"""
    SELECT 
        COUNT(DISTINCT order_day) as total_days,
        COUNT(DISTINCT sap_system) as total_systems,
        COUNT(*) as total_rows,
        SUM(total_orders) as total_orders_all_time,
        SUM(total_revenue) as total_revenue_all_time,
        AVG(sla_compliance_pct) as avg_sla_compliance_pct,
        MIN(order_day) as earliest_day,
        MAX(order_day) as latest_day,
        MAX(processed_timestamp) as last_processed
    FROM {TARGET_TABLE}
""")

logger.info("=== GOLD LAYER SUMMARY - ORDERS DAILY SUMMARY ===")
display(summary)

# Display latest data
latest_data = spark.sql(f"""
    SELECT *
    FROM {TARGET_TABLE}
    WHERE order_day = (SELECT MAX(order_day) FROM {TARGET_TABLE})
    ORDER BY sap_system, sla_status
""")

logger.info("Latest day data:")
display(latest_data)

logger.info("✅ Notebook execution completed successfully")
