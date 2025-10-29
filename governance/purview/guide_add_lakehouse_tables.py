#!/usr/bin/env python3
"""
Ajouter manuellement les Tables Lakehouse au Data Product via Purview Portal

Ce script génère les informations nécessaires pour ajouter manuellement
les assets Fabric Lakehouse au Data Product dans Purview Portal.

IMPORTANT: Les tables doivent d'abord être scannées dans Purview Data Map
via un scan Fabric Lakehouse.
"""

import json

# Configuration
PURVIEW_ACCOUNT = "stpurview"
DATA_PRODUCT_ID = "818affc4-2deb-439d-939f-ea0a240e4c78"
WORKSPACE_ID = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64"
TENANT_ID = "38de1b20-8309-40ba-9584-5d9fcb7203b4"

# Tables à ajouter
SILVER_TABLES = [
    "idoc_orders_silver",
    "idoc_shipments_silver",
    "idoc_warehouse_silver",
    "idoc_invoices_silver"
]

GOLD_TABLES = [
    "orders_daily_summary",
    "sla_performance",
    "shipments_in_transit",
    "warehouse_productivity",
    "revenue_realtime",
    "invoice_aging",
    "customer_performance"
]

ALL_TABLES = SILVER_TABLES + GOLD_TABLES

def print_header():
    print("\n" + "=" * 80)
    print("  GUIDE: AJOUTER LES TABLES LAKEHOUSE AU DATA PRODUCT")
    print("=" * 80)

def print_info():
    print("\n📦 DATA PRODUCT")
    print(f"   Name: 3PL Real-Time Analytics")
    print(f"   ID: {DATA_PRODUCT_ID}")
    print(f"   URL: https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}/")
    print(f"        datagovernance/catalog/dataProducts/{DATA_PRODUCT_ID}")
    
    print("\n🏢 FABRIC WORKSPACE")
    print(f"   Workspace ID: {WORKSPACE_ID}")
    print(f"   Tenant ID: {TENANT_ID}")
    
    print("\n📊 TABLES À AJOUTER")
    print(f"\n   Silver Tables ({len(SILVER_TABLES)}):")
    for table in SILVER_TABLES:
        print(f"     ✓ {table}")
    
    print(f"\n   Gold Tables ({len(GOLD_TABLES)}):")
    for table in GOLD_TABLES:
        print(f"     ✓ {table}")
    
    print(f"\n   TOTAL: {len(ALL_TABLES)} tables")

def print_steps():
    print("\n" + "=" * 80)
    print("  ÉTAPES À SUIVRE")
    print("=" * 80)
    
    print("\n📍 ÉTAPE 1: SCANNER LE FABRIC WORKSPACE DANS PURVIEW")
    print("   " + "-" * 76)
    print("\n   1.1. Ouvrir Purview Portal:")
    print(f"        https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    
    print("\n   1.2. Naviguer vers: Data Map → Sources")
    
    print("\n   1.3. Cliquer 'Register' → Sélectionner 'Microsoft Fabric'")
    
    print("\n   1.4. Configurer la source Fabric:")
    print("        • Name: Fabric-3PL-Workspace")
    print(f"        • Tenant ID: {TENANT_ID}")
    print(f"        • Workspace ID: {WORKSPACE_ID}")
    print("        • Collection: 3PL Logistics (ou Root Collection)")
    
    print("\n   1.5. Créer un nouveau Scan:")
    print("        • Name: Scan-3PL-Lakehouse")
    print("        • Credential: Purview MSI (recommandé)")
    print("        • Scope: Sélectionner le Lakehouse avec vos tables")
    print("        • Include: Tables")
    
    print("\n   1.6. Lancer le scan → Attendre la complétion (5-15 min)")
    
    print("\n📍 ÉTAPE 2: AJOUTER LES TABLES AU DATA PRODUCT")
    print("   " + "-" * 76)
    
    print("\n   2.1. Dans Purview Portal, aller à: Unified Catalog → Data products")
    
    print("\n   2.2. Rechercher et ouvrir: '3PL Real-Time Analytics'")
    print(f"        Ou utiliser ce lien direct:")
    print(f"        https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}/")
    print(f"        datagovernance/catalog/dataProducts/{DATA_PRODUCT_ID}")
    
    print("\n   2.3. Cliquer sur l'onglet 'Data assets'")
    
    print("\n   2.4. Cliquer 'Add data assets'")
    
    print("\n   2.5. Rechercher les tables une par une:")
    for i, table in enumerate(ALL_TABLES, 1):
        print(f"        {i:2d}. {table}")
    
    print("\n   2.6. Sélectionner toutes les tables trouvées")
    
    print("\n   2.7. Cliquer 'Add' → Les tables sont liées au Data Product ✅")
    
    print("\n📍 ÉTAPE 3: VÉRIFICATION")
    print("   " + "-" * 76)
    
    print("\n   3.1. Dans le Data Product, vérifier:")
    print("        • Onglet 'Data assets': doit afficher 11 tables")
    print("        • Onglet 'Lineage': doit montrer les connexions")
    print("        • Chaque table: Schema visible, Properties correctes")
    
    print("\n   3.2. Vérifier que Domain = '3PL Logistics'")

def print_alternative():
    print("\n" + "=" * 80)
    print("  ALTERNATIVE: LIVE VIEW (Plus Rapide)")
    print("=" * 80)
    
    print("\n   Si Live View est activé pour votre tenant Fabric:")
    
    print("\n   1. Aller dans: Unified Catalog → Discovery → Data assets")
    
    print("\n   2. Sélectionner: Microsoft Fabric → Fabric Workspaces")
    
    print("\n   3. Les tables Lakehouse devraient être visibles automatiquement")
    
    print("\n   4. Ajouter directement au Data Product (Étape 2 ci-dessus)")
    
    print("\n   ℹ️  Live View affiche les assets Fabric sans scan Data Map")
    print("       mais nécessite les permissions Viewer sur le workspace")

def print_prerequisites():
    print("\n" + "=" * 80)
    print("  ⚠️  PRÉREQUIS IMPORTANTS")
    print("=" * 80)
    
    print("\n   ✓ Purview MSI doit avoir 'Contributor' sur le Fabric Workspace")
    print("   ✓ Lakehouse mirroring doit être actif et à jour")
    print("   ✓ Les 11 tables doivent être visibles dans Lakehouse")
    print("   ✓ Vous devez avoir 'Data Curator' dans Purview")

def print_next_steps():
    print("\n" + "=" * 80)
    print("  🚀 PROCHAINES ÉTAPES APRÈS LIAISON")
    print("=" * 80)
    
    print("\n   Une fois les tables liées au Data Product:")
    
    print("\n   1. Business Glossary:")
    print("      Créer les termes métier (Order, Shipment, Invoice, etc.)")
    
    print("\n   2. Data Quality:")
    print("      Configurer les règles de qualité sur les tables")
    
    print("\n   3. OKRs (Objectives & Key Results):")
    print("      Définir les KPIs et objectifs du Data Product")
    
    print("\n   4. Access Policies:")
    print("      Configurer les politiques d'accès B2B pour les partenaires")
    
    print("\n   5. Documentation:")
    print("      Enrichir les descriptions, ajouter exemples d'usage")

def save_config():
    """Sauvegarder la configuration pour référence"""
    config = {
        "purview_account": PURVIEW_ACCOUNT,
        "data_product_id": DATA_PRODUCT_ID,
        "workspace_id": WORKSPACE_ID,
        "tenant_id": TENANT_ID,
        "tables": {
            "silver": SILVER_TABLES,
            "gold": GOLD_TABLES,
            "total": len(ALL_TABLES)
        },
        "urls": {
            "purview_portal": f"https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}",
            "data_product": f"https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}/datagovernance/catalog/dataProducts/{DATA_PRODUCT_ID}",
            "data_map": f"https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}/datamap"
        }
    }
    
    with open("lakehouse_tables_config.json", "w") as f:
        json.dump(config, f, indent=2)
    
    print(f"\n💾 Configuration sauvegardée: lakehouse_tables_config.json")

def main():
    print_header()
    print_info()
    print_prerequisites()
    print_steps()
    print_alternative()
    print_next_steps()
    save_config()
    
    print("\n" + "=" * 80)
    print("  📋 CHECKLIST")
    print("=" * 80)
    print("\n   [ ] Scanner le Fabric Workspace dans Purview Data Map")
    print("   [ ] Vérifier que les 11 tables apparaissent dans le scan")
    print("   [ ] Ouvrir le Data Product '3PL Real-Time Analytics'")
    print("   [ ] Ajouter les 11 tables via 'Add data assets'")
    print("   [ ] Vérifier que toutes les tables sont liées")
    print("   [ ] Consulter Lineage et Schema de chaque table")
    
    print("\n" + "=" * 80)
    print("\n✨ Suivez les étapes ci-dessus dans Purview Portal")
    print("   Une fois terminé, les tables seront gouvernées via le Data Product!\n")

if __name__ == "__main__":
    main()
