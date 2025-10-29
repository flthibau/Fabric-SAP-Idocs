# Databricks notebook source
# MAGIC %md
# MAGIC # Gold Layer - Warehouse Productivity Daily
# MAGIC 
# MAGIC **Purpose:** KPI entrepôt quotidien avec productivité et exceptions  
# MAGIC **Source:** idoc_warehouse_silver  
# MAGIC **Target:** warehouse_productivity_daily (Delta table)

# COMMAND ----------

from pyspark.sql.functions import (
    col, count, sum as _sum, avg, date_trunc, current_timestamp, lit,
    when, round as _round, countDistinct
)
from delta.tables import DeltaTable
import logging

# Configuration
SOURCE_TABLE = "idoc_warehouse_silver"
TARGET_TABLE = "warehouse_productivity_daily"
TARGET_LOCATION = f"Tables/{TARGET_TABLE}"
PRODUCTIVITY_TARGET = 100  # Pallets per hour target

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read Silver Layer

# COMMAND ----------

logger.info(f"Reading {SOURCE_TABLE}...")

df_warehouse = spark.table(SOURCE_TABLE)

logger.info(f"Warehouse movements: {df_warehouse.count():,}")
df_warehouse.printSchema()
display(df_warehouse.limit(5))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Calculate Daily Productivity Metrics

# COMMAND ----------

logger.info("Computing daily productivity metrics...")

# Agrégations par jour, entrepôt, type de mouvement
df_gold = df_warehouse.groupBy(
    date_trunc("day", col("movement_timestamp")).alias("movement_day"),
    col("warehouse_id"),
    col("movement_type"),
    col("sap_system")
).agg(
    # Volume metrics
    count("*").alias("total_movements"),
    _sum("quantity").alias("total_quantity"),
    countDistinct("material_number").alias("unique_materials"),
    countDistinct("operator_id").alias("unique_operators"),
    countDistinct("location_code").alias("unique_locations"),
    
    # Performance metrics
    avg("processing_time_minutes").alias("avg_processing_time_min"),
    avg("quantity").alias("avg_quantity_per_movement"),
    
    # Exception tracking
    count(when(col("exception_flag") == True, 1)).alias("exception_count"),
    count(when(col("exception_type") == "Damage", 1)).alias("damage_count"),
    count(when(col("exception_type") == "Shortage", 1)).alias("shortage_count"),
    count(when(col("exception_type") == "Quality", 1)).alias("quality_count")
)

# Calcul taux d'exception
df_gold = df_gold.withColumn(
    "exception_rate_pct",
    _round((col("exception_count") / col("total_movements") * 100), 2)
)

# Calcul productivité (mouvements par heure)
# Hypothèse: journée de travail = 8 heures
df_gold = df_gold.withColumn(
    "movements_per_hour",
    _round(col("total_movements") / 8, 2)
)

# Calcul productivité en quantité (palettes par heure)
df_gold = df_gold.withColumn(
    "quantity_per_hour",
    _round(col("total_quantity") / 8, 2)
)

# Target et variance
df_gold = df_gold.withColumn("productivity_target", lit(PRODUCTIVITY_TARGET))

df_gold = df_gold.withColumn(
    "productivity_variance_pct",
    _round(
        ((col("quantity_per_hour") - col("productivity_target")) / col("productivity_target") * 100),
        2
    )
)

# Performance status
df_gold = df_gold.withColumn(
    "performance_status",
    when(col("productivity_variance_pct") >= 10, "Exceeding")
    .when(col("productivity_variance_pct") >= 0, "Meeting")
    .when(col("productivity_variance_pct") >= -10, "Near Target")
    .otherwise("Below Target")
)

# Utilisation opérateurs (mouvements par opérateur)
df_gold = df_gold.withColumn(
    "movements_per_operator",
    _round(col("total_movements") / col("unique_operators"), 2)
)

# Métadonnées
df_gold = df_gold.withColumn("processed_timestamp", current_timestamp())
df_gold = df_gold.withColumn("source_table", lit(SOURCE_TABLE))

# Tri
df_gold = df_gold.orderBy("movement_day", "warehouse_id", "movement_type")

logger.info(f"Gold rows computed: {df_gold.count():,}")
display(df_gold.limit(10))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to Delta Table

# COMMAND ----------

logger.info(f"Writing to Delta table: {TARGET_TABLE}")

if DeltaTable.isDeltaTable(spark, TARGET_LOCATION):
    logger.info("Performing MERGE...")
    
    delta_table = DeltaTable.forPath(spark, TARGET_LOCATION)
    
    merge_condition = """
        target.movement_day = source.movement_day 
        AND target.warehouse_id = source.warehouse_id
        AND target.movement_type = source.movement_type
        AND target.sap_system = source.sap_system
    """
    
    delta_table.alias("target").merge(
        df_gold.alias("source"),
        merge_condition
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
        .partitionBy("movement_day") \
        .saveAsTable(TARGET_TABLE)
    
    logger.info(f"Table {TARGET_TABLE} created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Optimize

# COMMAND ----------

logger.info("Optimizing Delta table...")

spark.sql(f"""
    OPTIMIZE {TARGET_TABLE}
    ZORDER BY (warehouse_id, movement_type)
""")

spark.sql(f"""
    VACUUM {TARGET_TABLE} RETAIN 168 HOURS
""")

logger.info("Optimization completed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Checks

# COMMAND ----------

logger.info("Running data quality checks...")

# Check 1: Productivity values reasonable
productivity_check = df_gold.filter(
    (col("quantity_per_hour") < 0) | (col("quantity_per_hour") > 500)
).count()

if productivity_check > 0:
    logger.warning(f"⚠️ {productivity_check} rows with unrealistic productivity")
else:
    logger.info("✅ Productivity range validation passed")

# Check 2: Exception rate between 0-100%
exception_check = df_gold.filter(
    (col("exception_rate_pct") < 0) | (col("exception_rate_pct") > 100)
).count()

if exception_check > 0:
    logger.warning(f"⚠️ {exception_check} rows with invalid exception rate")
else:
    logger.info("✅ Exception rate validation passed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary Report

# COMMAND ----------

summary = spark.sql(f"""
    SELECT 
        COUNT(DISTINCT movement_day) as total_days,
        COUNT(DISTINCT warehouse_id) as total_warehouses,
        COUNT(DISTINCT movement_type) as movement_types,
        SUM(total_movements) as total_movements_all_time,
        ROUND(AVG(quantity_per_hour), 2) as avg_productivity,
        ROUND(AVG(exception_rate_pct), 2) as avg_exception_rate,
        SUM(CASE WHEN performance_status = 'Below Target' THEN 1 ELSE 0 END) as below_target_days,
        MAX(movement_day) as latest_day
    FROM {TARGET_TABLE}
""")

logger.info("=== WAREHOUSE PRODUCTIVITY SUMMARY ===")
display(summary)

# Performance by warehouse
warehouse_perf = spark.sql(f"""
    SELECT 
        warehouse_id,
        movement_type,
        COUNT(*) as total_days,
        ROUND(AVG(quantity_per_hour), 2) as avg_productivity,
        ROUND(AVG(exception_rate_pct), 2) as avg_exception_rate,
        performance_status,
        COUNT(*) as day_count
    FROM {TARGET_TABLE}
    WHERE movement_day >= CURRENT_DATE - INTERVAL 30 DAYS
    GROUP BY warehouse_id, movement_type, performance_status
    ORDER BY warehouse_id, movement_type, day_count DESC
""")

logger.info("Warehouse Performance (Last 30 Days):")
display(warehouse_perf)

logger.info("✅ Warehouse Productivity notebook completed")
