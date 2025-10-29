# Databricks notebook source
# MAGIC %md
# MAGIC # Gold Layer - SLA Performance Real-Time
# MAGIC 
# MAGIC **Purpose:** Tracking SLA temps réel avec classification  
# MAGIC **Source:** idoc_orders_silver + idoc_shipments_silver  
# MAGIC **Target:** sla_performance (Delta table)

# COMMAND ----------

from pyspark.sql.functions import (
    col, when, datediff, current_timestamp, lit, coalesce, round as _round
)
from delta.tables import DeltaTable
import logging

# Configuration
SOURCE_ORDERS = "idoc_orders_silver"
SOURCE_SHIPMENTS = "idoc_shipments_silver"
TARGET_TABLE = "sla_performance"
TARGET_LOCATION = f"Tables/{TARGET_TABLE}"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read Source Tables

# COMMAND ----------

logger.info("Reading source tables...")

df_orders = spark.table(SOURCE_ORDERS)
df_shipments = spark.table(SOURCE_SHIPMENTS)

logger.info(f"Orders: {df_orders.count():,} rows")
logger.info(f"Shipments: {df_shipments.count():,} rows")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Join Orders + Shipments

# COMMAND ----------

# Join pour enrichir avec données expédition
df_joined = df_orders.alias("o").join(
    df_shipments.alias("s"),
    col("o.order_number") == col("s.order_reference"),
    "left"
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Calculate SLA Metrics

# COMMAND ----------

logger.info("Computing SLA metrics...")

df_gold = df_joined.select(
    # Clés
    col("o.order_number"),
    col("o.customer_id"),
    col("o.sap_system"),
    
    # Dates clés
    col("o.order_date"),
    col("o.requested_delivery_date"),
    col("o.promised_delivery_date"),
    col("o.actual_ship_date"),
    col("s.actual_delivery_date"),
    
    # Statuts
    col("o.order_status"),
    col("o.sla_status"),
    
    # Calcul temps de traitement (order → ship)
    datediff(
        coalesce(col("o.actual_ship_date"), current_timestamp()),
        col("o.order_date")
    ).alias("processing_days"),
    
    # Calcul temps total (order → delivery)
    when(
        col("s.actual_delivery_date").isNotNull(),
        datediff(col("s.actual_delivery_date"), col("o.order_date"))
    ).alias("total_cycle_days"),
    
    # SLA Target (24h = 1 day)
    lit(1).alias("sla_target_days"),
    
    # Montant
    col("o.total_amount"),
    
    # Carrier (from shipment)
    col("s.carrier_name")
)

# Classification SLA enrichie
df_gold = df_gold.withColumn(
    "sla_compliance",
    when(col("processing_days") <= 1, "Good")
    .when(col("processing_days") <= 2, "At Risk")
    .otherwise("Breached")
)

# Écart vs SLA (en heures)
df_gold = df_gold.withColumn(
    "sla_variance_hours",
    (col("processing_days") - col("sla_target_days")) * 24
)

# Indicateur critique
df_gold = df_gold.withColumn(
    "is_critical",
    (col("sla_status") == "Breached") & (col("total_amount") > 10000)
)

# On-time delivery indicator
df_gold = df_gold.withColumn(
    "on_time_delivery",
    when(
        col("actual_delivery_date").isNull(), 
        lit(None)
    ).when(
        col("actual_delivery_date") <= col("promised_delivery_date"),
        lit(True)
    ).otherwise(lit(False))
)

# Métadonnées
df_gold = df_gold.withColumn("processed_timestamp", current_timestamp())
df_gold = df_gold.withColumn("source_tables", lit(f"{SOURCE_ORDERS}, {SOURCE_SHIPMENTS}"))

logger.info(f"Gold rows computed: {df_gold.count():,}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to Delta Table

# COMMAND ----------

logger.info(f"Writing to Delta table: {TARGET_TABLE}")

if DeltaTable.isDeltaTable(spark, TARGET_LOCATION):
    logger.info("Performing MERGE...")
    
    delta_table = DeltaTable.forPath(spark, TARGET_LOCATION)
    
    delta_table.alias("target").merge(
        df_gold.alias("source"),
        "target.order_number = source.order_number"
    ).whenMatchedUpdateAll(
    ).whenNotMatchedInsertAll(
    ).execute()
    
    logger.info("MERGE completed")
    
else:
    logger.info("Creating new Delta table...")
    
    df_gold.write \
        .format("delta") \
        .mode("overwrite") \
        .option("overwriteSchema", "true") \
        .partitionBy("order_date") \
        .saveAsTable(TARGET_TABLE)
    
    logger.info(f"Table {TARGET_TABLE} created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Optimize & Summary

# COMMAND ----------

spark.sql(f"""
    OPTIMIZE {TARGET_TABLE}
    ZORDER BY (sla_status, customer_id)
""")

# Summary report
summary = spark.sql(f"""
    SELECT 
        sla_compliance,
        COUNT(*) as order_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
        ROUND(AVG(processing_days), 2) as avg_processing_days,
        ROUND(AVG(sla_variance_hours), 2) as avg_variance_hours,
        SUM(CASE WHEN is_critical THEN 1 ELSE 0 END) as critical_count,
        ROUND(AVG(total_amount), 2) as avg_order_value
    FROM {TARGET_TABLE}
    GROUP BY sla_compliance
    ORDER BY order_count DESC
""")

logger.info("=== SLA PERFORMANCE SUMMARY ===")
display(summary)

logger.info("✅ SLA Performance notebook completed")
