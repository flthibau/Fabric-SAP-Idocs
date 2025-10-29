# Databricks notebook source
# MAGIC %md
# MAGIC # Gold Layer - Revenue Recognition Real-Time
# MAGIC 
# MAGIC **Purpose:** Performance financière temps réel avec aging buckets  
# MAGIC **Source:** idoc_invoices_silver  
# MAGIC **Target:** revenue_recognition_realtime (Delta table)

# COMMAND ----------

from pyspark.sql.functions import (
    col, count, sum as _sum, avg, date_trunc, current_timestamp, lit,
    when, datediff, current_date, round as _round, countDistinct
)
from delta.tables import DeltaTable
import logging

# Configuration
SOURCE_TABLE = "idoc_invoices_silver"
TARGET_TABLE = "revenue_recognition_realtime"
TARGET_LOCATION = f"Tables/{TARGET_TABLE}"
PAYMENT_TERMS_DAYS = 30  # Net 30 days

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read Silver Layer

# COMMAND ----------

logger.info(f"Reading {SOURCE_TABLE}...")

df_invoices = spark.table(SOURCE_TABLE)

logger.info(f"Total invoices: {df_invoices.count():,}")
df_invoices.printSchema()
display(df_invoices.limit(5))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Calculate Revenue Metrics by Day & Customer

# COMMAND ----------

logger.info("Computing revenue metrics...")

# Agrégations par jour de facturation et client
df_gold = df_invoices.groupBy(
    date_trunc("day", col("invoice_date")).alias("invoice_day"),
    col("customer_id"),
    col("sap_system")
).agg(
    # Volume metrics
    count("*").alias("total_invoices"),
    countDistinct("invoice_number").alias("unique_invoices"),
    
    # Revenue metrics
    _sum("total_amount").alias("total_revenue"),
    _sum("amount_paid").alias("total_paid"),
    _sum("amount_due").alias("total_due"),
    
    # Payment status counts
    count(when(col("payment_status") == "Pending", 1)).alias("pending_invoices"),
    count(when(col("payment_status") == "Partial", 1)).alias("partial_invoices"),
    count(when(col("payment_status") == "Paid", 1)).alias("paid_invoices"),
    count(when(col("payment_status") == "Overdue", 1)).alias("overdue_invoices"),
    
    # Aging buckets (montants)
    _sum(when(col("aging_bucket") == "Current", col("amount_due"))).alias("aging_current"),
    _sum(when(col("aging_bucket") == "1-30", col("amount_due"))).alias("aging_1_30"),
    _sum(when(col("aging_bucket") == "31-60", col("amount_due"))).alias("aging_31_60"),
    _sum(when(col("aging_bucket") == "61-90", col("amount_due"))).alias("aging_61_90"),
    _sum(when(col("aging_bucket") == "90+", col("amount_due"))).alias("aging_90_plus"),
    
    # DSO (Days Sales Outstanding) calculation
    avg(
        when(col("payment_date").isNotNull(), 
             datediff(col("payment_date"), col("invoice_date"))
        )
    ).alias("avg_days_to_payment"),
    
    # Average invoice value
    avg("total_amount").alias("avg_invoice_value")
)

# Remplacer NULL par 0 dans aging buckets
for bucket in ["aging_current", "aging_1_30", "aging_31_60", "aging_61_90", "aging_90_plus"]:
    df_gold = df_gold.withColumn(bucket, when(col(bucket).isNull(), 0).otherwise(col(bucket)))

# Calcul collection efficiency (% collecté)
df_gold = df_gold.withColumn(
    "collection_efficiency_pct",
    _round(
        when(col("total_revenue") > 0, (col("total_paid") / col("total_revenue") * 100))
        .otherwise(0),
        2
    )
)

# Calcul payment rate (% factures payées)
df_gold = df_gold.withColumn(
    "payment_rate_pct",
    _round((col("paid_invoices") / col("total_invoices") * 100), 2)
)

# Calcul overdue rate (% factures en retard)
df_gold = df_gold.withColumn(
    "overdue_rate_pct",
    _round((col("overdue_invoices") / col("total_invoices") * 100), 2)
)

# DSO Target (Net 30)
df_gold = df_gold.withColumn("dso_target_days", lit(PAYMENT_TERMS_DAYS))

df_gold = df_gold.withColumn(
    "dso_variance_days",
    _round(col("avg_days_to_payment") - col("dso_target_days"), 1)
)

# Risk classification
df_gold = df_gold.withColumn(
    "collection_risk",
    when(col("overdue_rate_pct") > 20, "High")
    .when(col("overdue_rate_pct") > 10, "Medium")
    .otherwise("Low")
)

# Calcul total outstanding (somme aging buckets)
df_gold = df_gold.withColumn(
    "total_outstanding",
    col("aging_current") + col("aging_1_30") + col("aging_31_60") + 
    col("aging_61_90") + col("aging_90_plus")
)

# Aging distribution (% par bucket)
df_gold = df_gold.withColumn(
    "aging_current_pct",
    _round(
        when(col("total_outstanding") > 0, (col("aging_current") / col("total_outstanding") * 100))
        .otherwise(0),
        2
    )
)

df_gold = df_gold.withColumn(
    "aging_90_plus_pct",
    _round(
        when(col("total_outstanding") > 0, (col("aging_90_plus") / col("total_outstanding") * 100))
        .otherwise(0),
        2
    )
)

# Métadonnées
df_gold = df_gold.withColumn("processed_timestamp", current_timestamp())
df_gold = df_gold.withColumn("source_table", lit(SOURCE_TABLE))

# Tri
df_gold = df_gold.orderBy("invoice_day", col("total_revenue").desc())

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
        target.invoice_day = source.invoice_day 
        AND target.customer_id = source.customer_id
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
        .partitionBy("invoice_day") \
        .saveAsTable(TARGET_TABLE)
    
    logger.info(f"Table {TARGET_TABLE} created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Optimize

# COMMAND ----------

logger.info("Optimizing Delta table...")

spark.sql(f"""
    OPTIMIZE {TARGET_TABLE}
    ZORDER BY (customer_id, sap_system)
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

# Check 1: Collection efficiency between 0-100%
collection_check = df_gold.filter(
    (col("collection_efficiency_pct") < 0) | (col("collection_efficiency_pct") > 100)
).count()

if collection_check > 0:
    logger.warning(f"⚠️ {collection_check} rows with invalid collection efficiency")
else:
    logger.info("✅ Collection efficiency validation passed")

# Check 2: Total outstanding = sum of aging buckets
consistency_check = df_gold.withColumn(
    "aging_sum",
    col("aging_current") + col("aging_1_30") + col("aging_31_60") + 
    col("aging_61_90") + col("aging_90_plus")
).filter(
    abs(col("aging_sum") - col("total_outstanding")) > 0.01  # Tolerance 1 cent
).count()

if consistency_check > 0:
    logger.warning(f"⚠️ {consistency_check} rows with inconsistent aging totals")
else:
    logger.info("✅ Aging bucket consistency validation passed")

# Check 3: Total paid + total due = total revenue
revenue_check = df_gold.withColumn(
    "revenue_sum",
    col("total_paid") + col("total_due")
).filter(
    abs(col("revenue_sum") - col("total_revenue")) > 0.01  # Tolerance 1 cent
).count()

if revenue_check > 0:
    logger.warning(f"⚠️ {revenue_check} rows with inconsistent revenue amounts")
else:
    logger.info("✅ Revenue consistency validation passed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary Report

# COMMAND ----------

summary = spark.sql(f"""
    SELECT 
        COUNT(DISTINCT invoice_day) as total_days,
        COUNT(DISTINCT customer_id) as total_customers,
        SUM(total_invoices) as total_invoices_all_time,
        ROUND(SUM(total_revenue), 2) as total_revenue_all_time,
        ROUND(SUM(total_paid), 2) as total_collected,
        ROUND(SUM(total_due), 2) as total_outstanding,
        ROUND(AVG(collection_efficiency_pct), 2) as avg_collection_efficiency,
        ROUND(AVG(avg_days_to_payment), 1) as avg_dso,
        COUNT(CASE WHEN collection_risk = 'High' THEN 1 END) as high_risk_customers,
        MAX(invoice_day) as latest_day
    FROM {TARGET_TABLE}
""")

logger.info("=== REVENUE RECOGNITION SUMMARY ===")
display(summary)

# Aging analysis
aging_summary = spark.sql(f"""
    SELECT 
        ROUND(SUM(aging_current), 2) as current_outstanding,
        ROUND(SUM(aging_1_30), 2) as aging_1_30_outstanding,
        ROUND(SUM(aging_31_60), 2) as aging_31_60_outstanding,
        ROUND(SUM(aging_61_90), 2) as aging_61_90_outstanding,
        ROUND(SUM(aging_90_plus), 2) as aging_90_plus_outstanding,
        ROUND(SUM(total_outstanding), 2) as total_outstanding,
        ROUND(SUM(aging_90_plus) * 100.0 / SUM(total_outstanding), 2) as pct_90_plus
    FROM {TARGET_TABLE}
    WHERE invoice_day >= CURRENT_DATE - INTERVAL 30 DAYS
""")

logger.info("Aging Analysis (Last 30 Days):")
display(aging_summary)

# Top customers by revenue
top_customers = spark.sql(f"""
    SELECT 
        customer_id,
        SUM(total_revenue) as total_revenue,
        SUM(total_paid) as total_collected,
        SUM(total_due) as total_outstanding,
        ROUND(AVG(collection_efficiency_pct), 2) as avg_collection_efficiency,
        ROUND(AVG(avg_days_to_payment), 1) as avg_dso,
        MAX(collection_risk) as risk_level,
        COUNT(DISTINCT invoice_day) as invoice_days
    FROM {TARGET_TABLE}
    WHERE invoice_day >= CURRENT_DATE - INTERVAL 90 DAYS
    GROUP BY customer_id
    ORDER BY total_revenue DESC
    LIMIT 20
""")

logger.info("Top 20 Customers by Revenue (Last 90 Days):")
display(top_customers)

# High risk customers (90+ days outstanding)
high_risk = spark.sql(f"""
    SELECT 
        customer_id,
        ROUND(SUM(aging_90_plus), 2) as aging_90_plus,
        ROUND(SUM(total_outstanding), 2) as total_outstanding,
        ROUND(SUM(aging_90_plus) * 100.0 / SUM(total_outstanding), 2) as pct_90_plus,
        collection_risk,
        COUNT(DISTINCT invoice_day) as invoice_days
    FROM {TARGET_TABLE}
    WHERE aging_90_plus > 0
      AND invoice_day >= CURRENT_DATE - INTERVAL 30 DAYS
    GROUP BY customer_id, collection_risk
    ORDER BY aging_90_plus DESC
    LIMIT 10
""")

logger.info("Top 10 High Risk Customers (90+ Days Outstanding):")
display(high_risk)

logger.info("✅ Revenue Recognition notebook completed")
