"""
Configure OneLake Availability for Eventhouse KQL Database
and create shortcuts in Lakehouse for Purview integration
"""

print("""
================================================================================
CONFIGURATION ONELAKE AVAILABILITY + LAKEHOUSE SHORTCUTS
================================================================================

📋 ARCHITECTURE:
   Eventhouse KQL Tables → OneLake Delta → Lakehouse Shortcuts → Purview Scan

🎯 ÉTAPES:

PARTIE 1: ACTIVER ONELAKE AVAILABILITY SUR EVENTHOUSE (Fabric Portal)
======================================================================

1. Ouvrez l'Eventhouse kqldbsapidoc:
   https://app.fabric.microsoft.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/5c2c08ee-cb8f-4248-a1c8-ea35a4e6e057

2. Dans le menu de gauche, cliquez sur "Settings"

3. Section "OneLake availability":
   ✅ Activer "Enable OneLake availability for all tables"
   
   Ou activer table par table:
   
   Bronze Layer:
   ✅ idoc_raw
   
   Silver Layer:
   ✅ idoc_orders_silver
   ✅ idoc_shipments_silver
   ✅ idoc_warehouse_silver
   ✅ idoc_invoices_silver
   
   Gold Layer (Materialized Views):
   ✅ orders_daily_summary
   ✅ sla_performance
   ✅ shipments_in_transit
   ✅ warehouse_productivity_daily
   ✅ revenue_recognition_realtime

4. Cliquez "Save"

5. Attendez quelques minutes - Fabric crée les versions Delta dans OneLake

⏳ IMPORTANT: La création des tables Delta prend 2-5 minutes


PARTIE 2: CRÉER LES SHORTCUTS DANS LAKEHOUSE (Fabric Portal)
=============================================================

6. Ouvrez le Lakehouse:
   https://app.fabric.microsoft.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/lakehouses/21a1bc2d-92e4-41fb-8ca8-1c16569fc483

7. Dans la section "Tables":
   - Cliquez sur "..." (More options)
   - Sélectionnez "New shortcut"

8. Type de source:
   - Sélectionnez "OneLake"

9. Naviguer vers l'Eventhouse:
   - Workspace: JAc
   - Item: kqldbsapidoc (Eventhouse)
   - Folder: Tables/

10. Sélectionner les tables:
    
    OPTION A - Créer un shortcut par table (Recommandé pour Purview):
    ----------------------------------------------------------------
    
    Bronze:
    📊 Shortcut Name: idoc_raw
       Path: /Tables/idoc_raw
    
    Silver:
    📊 Shortcut Name: idoc_orders_silver
       Path: /Tables/idoc_orders_silver
    
    📊 Shortcut Name: idoc_shipments_silver
       Path: /Tables/idoc_shipments_silver
    
    📊 Shortcut Name: idoc_warehouse_silver
       Path: /Tables/idoc_warehouse_silver
    
    📊 Shortcut Name: idoc_invoices_silver
       Path: /Tables/idoc_invoices_silver
    
    Gold:
    📊 Shortcut Name: orders_daily_summary
       Path: /Tables/orders_daily_summary
    
    📊 Shortcut Name: sla_performance
       Path: /Tables/sla_performance
    
    📊 Shortcut Name: shipments_in_transit
       Path: /Tables/shipments_in_transit
    
    📊 Shortcut Name: warehouse_productivity_daily
       Path: /Tables/warehouse_productivity_daily
    
    📊 Shortcut Name: revenue_recognition_realtime
       Path: /Tables/revenue_recognition_realtime
    
    
    OPTION B - Créer un shortcut global (Plus simple):
    --------------------------------------------------
    
    📊 Shortcut Name: eventhouse_tables
       Path: /Tables/
       
       → Toutes les tables seront accessibles sous eventhouse_tables/

11. Cliquer "Create" pour chaque shortcut

12. Vérifier que les shortcuts apparaissent dans la section "Tables" du Lakehouse


PARTIE 3: VÉRIFIER LES TABLES DELTA
====================================

13. Dans le Lakehouse, ouvrez le SQL Endpoint:
    - Cliquez sur "SQL endpoint" en haut à droite

14. Testez les tables:

    -- Lister toutes les tables
    SELECT * FROM INFORMATION_SCHEMA.TABLES;
    
    -- Tester une table Bronze
    SELECT TOP 10 * FROM idoc_raw;
    
    -- Tester une table Silver
    SELECT TOP 10 * FROM idoc_orders_silver;
    
    -- Tester une table Gold
    SELECT TOP 10 * FROM orders_daily_summary;

15. Vérifier le format Delta:

    DESCRIBE DETAIL idoc_orders_silver;
    
    -- Devrait afficher: format = delta


PARTIE 4: DÉCLENCHER LE SCAN PURVIEW
=====================================

16. Une fois les shortcuts créés, déclenchez le scan Purview:

    Retournez dans ce terminal et exécutez:
    
    cd governance/purview
    python purview_automation.py

17. Le scan Fabric-JAc découvrira automatiquement:
    - Lakehouse: Lakehouse3PLAnalytics
    - 10 tables Delta (via shortcuts)
    - Métadonnées complètes


ALTERNATIVE - SCRIPT AUTOMATISÉ
================================

Si vous préférez créer les shortcuts via API (plus complexe):

1. L'API Fabric Shortcuts est en preview
2. Nécessite des droits élevés
3. Plus simple de le faire manuellement dans le Portal

Mais je peux créer un script si besoin.


RÉSUMÉ DE L'ARCHITECTURE FINALE
================================

┌─────────────────────────────────────────────────────────────────┐
│                         SAP S/4HANA                             │
│                              │                                  │
│                              ▼                                  │
│                         Event Hub                               │
│                              │                                  │
│                              ▼                                  │
│                    ┌─────────────────┐                          │
│                    │   Eventhouse    │                          │
│                    │   (KQL Tables)  │                          │
│                    └─────────────────┘                          │
│                            │                                     │
│                 OneLake Availability                             │
│                    (Auto-sync)                                   │
│                            │                                     │
│                            ▼                                     │
│                    ┌─────────────────┐                          │
│                    │  OneLake Delta  │                          │
│                    │     Tables      │                          │
│                    └─────────────────┘                          │
│                            │                                     │
│                      Shortcuts                                   │
│                            │                                     │
│                            ▼                                     │
│                    ┌─────────────────┐                          │
│                    │   Lakehouse     │                          │
│                    │ (10 shortcuts)  │                          │
│                    └─────────────────┘                          │
│                            │                                     │
│                      Purview Scan                                │
│                            │                                     │
│                            ▼                                     │
│                    ┌─────────────────┐                          │
│                    │  Purview Portal │                          │
│                    │  Data Product   │                          │
│                    └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘

BÉNÉFICES:
==========

✅ Synchronisation temps réel automatique (OneLake)
✅ Aucun pipeline à maintenir
✅ Format Delta natif pour Purview
✅ Pas de duplication de données (shortcuts)
✅ Gouvernance complète via Purview
✅ Power BI peut se connecter directement au Lakehouse
✅ Spark peut interroger les shortcuts
✅ Lineage automatique (Eventhouse → Lakehouse)


PROCHAINES ÉTAPES APRÈS CONFIGURATION:
=======================================

1. ✅ OneLake Availability activé sur Eventhouse
2. ✅ Shortcuts créés dans Lakehouse
3. 🔄 Déclencher scan Purview
4. 📊 Vérifier assets découverts (10 tables)
5. 🏛️ Créer Business Domain dans Purview
6. 📦 Créer Data Product avec assets Lakehouse
7. ✅ Configurer Data Quality rules
8. 📈 Connecter Power BI au Lakehouse
9. 🚀 Développer GraphQL API


COMMANDES UTILES:
=================

# Vérifier les tables dans Eventhouse
Eventhouse Query Editor:
.show tables

# Vérifier OneLake availability
.show table idoc_orders_silver policy onelake

# Vérifier les shortcuts dans Lakehouse SQL Endpoint
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'EXTERNAL';

================================================================================
""")

print("\n💡 Commencez par la PARTIE 1 dans le Fabric Portal")
print("   Ouvrez l'Eventhouse et activez OneLake Availability")
print("\n🔗 URL Eventhouse:")
print("   https://app.fabric.microsoft.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/databases/5c2c08ee-cb8f-4248-a1c8-ea35a4e6e057")
print("\n🔗 URL Lakehouse:")
print("   https://app.fabric.microsoft.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64/lakehouses/21a1bc2d-92e4-41fb-8ca8-1c16569fc483")
print("\n✅ Une fois terminé, revenez ici pour déclencher le scan Purview")
print("="*80)
