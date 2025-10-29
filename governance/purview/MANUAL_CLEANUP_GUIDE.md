# Guide de Nettoyage Manuel - Purview Portal

## ⚠️ Limitations API Découvertes

L'API Purview Unified Catalog (2025-09-15-preview) a des limitations importantes :

1. ❌ **Glossary Terms Published** : Impossible à supprimer via API (erreur 400)
2. ❌ **PATCH non supporté** : Impossible de dépublier (erreur 405)  
3. ❌ **OKRs en erreur 500** : Problème serveur lors de la suppression
4. ❌ **Data Product** : Référencé par d'autres entités (impossible à supprimer tant que références existent)

## ✅ Solution Recommandée : Nettoyage Manuel via Portal

### Étape 1 : Ouvrir Purview Portal

```
https://web.purview.azure.com/resource/stpurview
```

### Étape 2 : Naviguer vers Unified Catalog

1. Menu latéral → **Data Catalog**
2. Cliquer sur **Unified Catalog**

### Étape 3 : Supprimer les Glossary Terms (8 termes)

1. Aller dans **Glossary** ou **Terms**
2. Pour chaque terme (Order, Shipment, Warehouse Movement, Invoice, Customer, Carrier, SLA Compliance, Delivery Performance) :
   - Cliquer sur le terme
   - **Cliquer sur "..." (menu)** → **Change Status** → **Draft**
   - Puis **Delete** (maintenant que c'est Draft)

**Alternative** : Si "Change Status" n'existe pas dans l'UI :
- Sélectionner tous les termes
- Actions en masse → Delete (si disponible)
- OU les laisser tels quels et les réutiliser pour le nouveau Data Product

### Étape 4 : Supprimer les OKRs (3 Objectives)

1. Aller dans **Objectives**
2. Pour chaque Objective :
   - "Operational Excellence"
   - "Customer Satisfaction"  
   - "Platform Adoption"
3. Cliquer sur chaque → **Delete**
   - Les Key Results seront automatiquement supprimés

### Étape 5 : Supprimer le Data Product

1. Aller dans **Data Products**
2. Trouver **"3PL Real-Time Analytics"**
3. Cliquer sur le Data Product
4. **Unlink** toutes les Data Assets (9 tables) :
   - idoc_orders_silver
   - idoc_shipments_silver
   - idoc_warehouse_silver
   - idoc_invoices_silver
   - orders_daily_summary
   - sla_performance
   - shipments_in_transit
   - warehouse_productivity
   - revenue_realtime
5. Une fois déliées, **Delete** le Data Product

### Étape 6 : Supprimer l'ancien Domain

1. Aller dans **Domains**
2. Trouver **"3PL Logistics"** (ID: 1800fc8e-0360-4b9a-883a-ea23dcfa38dc)
3. S'assurer qu'aucun Data Product n'y est rattaché
4. **Delete** le Domain

### Étape 7 : Vérifier le Domain "Supply Chain"

1. Dans **Domains**, vérifier que **"Supply Chain"** existe
2. ID: `041de34f-62cf-4c8a-9a17-d1cc823e9538`
3. Type: LineOfBusiness
4. Status: Published
5. ✅ Prêt pour recevoir le nouveau Data Product

---

## 🔄 Option Alternative : Garder et Réutiliser

Si le nettoyage manual est trop compliqué, on peut :

### Option A : Renommer (si l'UI le permet)
1. Renommer Domain "3PL Logistics" → "Supply Chain"
2. Garder tout tel quel
3. Supprimer le nouveau Domain "Supply Chain" créé

### Option B : Réutiliser les Termes et OKRs
1. Créer le nouveau Data Product dans Domain "Supply Chain"
2. **Réassigner** les Glossary Terms au nouveau Domain (via UI ou API UPDATE)
3. **Réassigner** les OKRs au nouveau Domain (via UI ou API UPDATE)
4. Supprimer l'ancien Data Product et Domain

---

## 📝 Prochaines Étapes Après Nettoyage

Une fois le nettoyage terminé :

### 1. Recréer Data Product
```bash
python create_data_product_supply_chain.py
```
- Name: "3PL Logistics Analytics"
- Domain: Supply Chain (041de34f-62cf-4c8a-9a17-d1cc823e9538)
- Type: Analytical
- Status: Draft (Endorsed: true)

### 2. Re-lier les 9 Tables
Via Fabric Portal (manuel) ou API :
- 4 Silver tables
- 5 Gold tables

### 3. Recréer Glossary Terms
```bash
python create_business_glossary.py
```
- Domain ID: 041de34f... (Supply Chain)
- 8 termes avec métadonnées complètes

### 4. Recréer OKRs
```bash
python create_okrs.py
```
- Domain ID: 041de34f... (Supply Chain)
- 3 Objectives + 9 Key Results

---

## 🎯 Résultat Final Attendu

```
Domain: Supply Chain (041de34f-62cf-4c8a-9a17-d1cc823e9538)
└── Data Product: 3PL Logistics Analytics (NEW ID)
      ├── Data Assets (9 tables)
      ├── Business Glossary (8 termes)
      └── OKRs (3 Objectives + 9 KRs)
```

---

## 📞 Support

Si problèmes avec l'UI Purview Portal :
1. Vérifier les permissions (Data Curator role requis)
2. Contacter support Azure Purview
3. Attendre maturation de l'API (actuellement Public Preview)

**Recommandation** : Faire le nettoyage manuellement dans Portal, c'est plus fiable que l'API pour l'instant.
