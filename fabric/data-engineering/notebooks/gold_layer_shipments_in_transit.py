# Databricks notebook source
# MAGIC %md
# MAGIC # Gold Layer - Shipments In Transit
# MAGIC 
# MAGIC **Purpose:** Expéditions en cours avec ETA  
# MAGIC **Source:** idoc_shipments_silver  
# MAGIC **Target:** shipments_in_transit (Delta table)  
# MAGIC **Filter:** Status = "In Transit" uniquement

# COMMAND ----------

from pyspark.sql.functions import (
    col, current_timestamp, lit, datediff, when, 
    date_add, current_date, round as _round
)
from delta.tables import DeltaTable
import logging

# Configuration
SOURCE_TABLE = "idoc_shipments_silver"
TARGET_TABLE = "shipments_in_transit"
TARGET_LOCATION = f"Tables/{TARGET_TABLE}"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Read Silver Layer

# COMMAND ----------

logger.info(f"Reading {SOURCE_TABLE}...")

df_shipments = spark.table(SOURCE_TABLE)

logger.info(f"Total shipments: {df_shipments.count():,}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Filter In-Transit Shipments

# COMMAND ----------

logger.info("Filtering In Transit shipments...")

# Critères: actual_ship_date existe MAIS actual_delivery_date est NULL
df_in_transit = df_shipments.filter(
    (col("shipment_status") == "In Transit") |
    (
        col("actual_ship_date").isNotNull() & 
        col("actual_delivery_date").isNull()
    )
)

logger.info(f"In Transit shipments: {df_in_transit.count():,}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Calculate ETA & Delay Metrics

# COMMAND ----------

logger.info("Computing ETA and delay metrics...")

df_gold = df_in_transit.select(
    # Identifiants
    col("shipment_number"),
    col("order_reference"),
    col("customer_id"),
    col("sap_system"),
    
    # Localisation
    col("origin_location"),
    col("destination_location"),
    col("carrier_name"),
    
    # Dates clés
    col("planned_ship_date"),
    col("actual_ship_date"),
    col("planned_delivery_date"),
    
    # Status
    col("shipment_status"),
    
    # Montant
    col("shipment_value")
)

# Calcul jours en transit (depuis expédition réelle)
df_gold = df_gold.withColumn(
    "days_in_transit",
    datediff(current_date(), col("actual_ship_date"))
)

# Calcul jours restants jusqu'à livraison prévue
df_gold = df_gold.withColumn(
    "days_until_planned_delivery",
    datediff(col("planned_delivery_date"), current_date())
)

# ETA (Estimated Time of Arrival) = planned_delivery_date si positif, sinon OVERDUE
df_gold = df_gold.withColumn(
    "eta_date",
    col("planned_delivery_date")
)

# Statut délai
df_gold = df_gold.withColumn(
    "delay_status",
    when(col("days_until_planned_delivery") > 2, "On Track")
    .when(col("days_until_planned_delivery").between(0, 2), "At Risk")
    .when(col("days_until_planned_delivery") < 0, "Delayed")
    .otherwise("Unknown")
)

# Jours de retard (si négatif)
df_gold = df_gold.withColumn(
    "days_delayed",
    when(col("days_until_planned_delivery") < 0, -col("days_until_planned_delivery"))
    .otherwise(0)
)

# Priorité (basé sur valeur + délai)
df_gold = df_gold.withColumn(
    "priority",
    when(
        (col("delay_status") == "Delayed") & (col("shipment_value") > 10000),
        "High"
    ).when(
        (col("delay_status") == "At Risk") & (col("shipment_value") > 5000),
        "Medium"
    ).otherwise("Normal")
)

# Métadonnées
df_gold = df_gold.withColumn("snapshot_timestamp", current_timestamp())
df_gold = df_gold.withColumn("source_table", lit(SOURCE_TABLE))

# Tri par priorité et délai
df_gold = df_gold.orderBy(
    col("priority").desc(),
    col("days_delayed").desc(),
    col("shipment_value").desc()
)

logger.info(f"Gold rows computed: {df_gold.count():,}")
display(df_gold.limit(20))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to Delta Table (Full Refresh)

# COMMAND ----------

logger.info(f"Writing to Delta table: {TARGET_TABLE}")

# Mode: Overwrite (car snapshot temps réel)
# Pas de merge nécessaire - on veut l'état actuel uniquement

df_gold.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .option("replaceWhere", "1=1") \
    .saveAsTable(TARGET_TABLE)

logger.info(f"Table {TARGET_TABLE} refreshed successfully")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary Report

# COMMAND ----------

summary = spark.sql(f"""
    SELECT 
        delay_status,
        priority,
        COUNT(*) as shipment_count,
        ROUND(AVG(days_in_transit), 1) as avg_days_in_transit,
        ROUND(AVG(days_delayed), 1) as avg_days_delayed,
        ROUND(SUM(shipment_value), 2) as total_value,
        COUNT(DISTINCT carrier_name) as carrier_count
    FROM {TARGET_TABLE}
    GROUP BY delay_status, priority
    ORDER BY 
        CASE priority 
            WHEN 'High' THEN 1 
            WHEN 'Medium' THEN 2 
            ELSE 3 
        END,
        shipment_count DESC
""")

logger.info("=== SHIPMENTS IN TRANSIT SUMMARY ===")
display(summary)

# Top delayed shipments
top_delayed = spark.sql(f"""
    SELECT 
        shipment_number,
        order_reference,
        carrier_name,
        days_in_transit,
        days_delayed,
        delay_status,
        priority,
        shipment_value,
        planned_delivery_date,
        eta_date
    FROM {TARGET_TABLE}
    WHERE delay_status = 'Delayed'
    ORDER BY days_delayed DESC, shipment_value DESC
    LIMIT 10
""")

logger.info("Top 10 Delayed Shipments:")
display(top_delayed)

logger.info("✅ Shipments In Transit notebook completed")
