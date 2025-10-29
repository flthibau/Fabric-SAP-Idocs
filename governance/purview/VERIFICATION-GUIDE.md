# Vérification Purview - Guide Rapide

## 🎯 Résultats de l'Automatisation

L'automatisation Purview via REST API a **RÉUSSI** ! Voici ce qui a été créé :

### ✅ Resources Créées

| Resource Type | Count | Status |
|--------------|-------|--------|
| **Glossary** | 1 | ✅ Existing (reused) |
| **Glossary Terms** | 6 | ✅ Created |
| **Collections** | 4 | ✅ Created |
| **Data Sources** | 0 | ⏸️ TODO |
| **Lineage** | 0 | ⏸️ TODO |

---

## 📋 Glossary Terms Créés

| Term Name | Definition | Technical Mapping |
|-----------|------------|-------------------|
| **Order** | Customer purchase request for logistics services | `idoc_orders_silver.order_number` |
| **Shipment** | Physical movement of goods from origin to destination | `idoc_shipments_silver.shipment_number` |
| **SLA Compliance %** | Percentage of orders delivered within 24 hours | `sla_performance.sla_compliance_pct` |
| **On-Time Delivery %** | Percentage of shipments delivered by planned delivery date | `shipments_in_transit.on_time_shipments` |
| **Warehouse Productivity** | Warehouse movements per hour per operator | `warehouse_productivity.total_movements` |
| **Days Sales Outstanding (DSO)** | Average days to collect payment after invoice | `revenue_realtime.avg_payment_efficiency` |

---

## 📁 Collections Créées

| Collection Name | Description | Parent |
|----------------|-------------|--------|
| **Bronze** | 3PL Data Product - Bronze | stpurview (root) |
| **Silver** | 3PL Data Product - Silver | stpurview (root) |
| **Gold** | 3PL Data Product - Gold | stpurview (root) |
| **API** | 3PL Data Product - API | stpurview (root) |

---

## 🌐 Vérification dans le Portal

### Étape 1: Accéder au Purview Portal

```
URL: https://web.purview.azure.com/resource/stpurview
```

**Credentials:** Utiliser votre compte Azure (admin@MngEnvMCAP396311.onmicrosoft.com)

---

### Étape 2: Vérifier le Business Glossary

1. **Navigation:** Data Catalog → **Glossary**
2. **Recherche:** "3PL Real-Time Analytics"
3. **Vérifications:**
   - ✅ Glossary existe
   - ✅ 6 terms visible (Order, Shipment, SLA Compliance %, etc.)
   - ✅ Chaque term a une définition et un technical mapping

**Capture attendue:**
```
Glossary: 3PL Real-Time Analytics
├── Order (Approved)
├── Shipment (Approved)
├── SLA Compliance % (Approved)
├── On-Time Delivery % (Approved)
├── Warehouse Productivity (Approved)
└── Days Sales Outstanding (DSO) (Approved)
```

---

### Étape 3: Vérifier les Collections

1. **Navigation:** Data Map → **Collections**
2. **Root Collection:** stpurview
3. **Vérifications:**
   - ✅ 4 child collections (Bronze, Silver, Gold, API)
   - ✅ Chaque collection a une description
   - ✅ Provisioning State = "Succeeded"

**Capture attendue:**
```
stpurview (Root)
├── Bronze (3PL Data Product - Bronze)
├── Silver (3PL Data Product - Silver)
├── Gold (3PL Data Product - Gold)
└── API (3PL Data Product - API)
```

---

### Étape 4: Vérifier le Summary JSON

Fichier local: `governance/purview/purview_setup_summary.json`

**Contenu clé:**
```json
{
  "glossary": null,  // Réutilisé (existe déjà)
  "terms": [6 objects with GUIDs],
  "collections": [4 objects with provisioning state],
  "data_sources": [],  // TODO
  "lineage": []  // TODO
}
```

---

## 🔧 Prochaines Étapes

### Option A: Scan Eventhouse Automatiquement

Utiliser le script pour enregistrer Eventhouse comme data source et lancer un scan :

```python
# Dans purview_automation.py, décommenter:
data_source = purview.register_kusto_data_source(
    data_source_name="Eventhouse-3PL-Analytics",
    cluster_uri="https://your-cluster.kusto.windows.net",
    database_name="kdb-3pl-analytics"
)
```

**Requis:** Cluster URI de votre Eventhouse

---

### Option B: Scan Manuel via Portal

1. **Navigation:** Data Map → **Sources**
2. **Click:** Register → Azure Data Explorer
3. **Configuration:**
   - Name: Eventhouse-3PL-Analytics
   - Subscription: ME-MngEnvMCAP396311-flthibau-1
   - Cluster URI: [Get from Fabric Portal]
   - Collection: Bronze
4. **Scan:** New Scan → Select database → Run

---

### Option C: Import Lineage Manuellement

1. **Navigation:** Data Catalog → **Lineage**
2. **Create Process:**
   - Source: idoc_raw (Bronze)
   - Process: update_policy_orders
   - Target: idoc_orders_silver (Silver)

---

## 📊 Statistiques du Run

```
Execution Time: ~30 seconds
API Calls: 15 successful calls
Authentication: Azure CLI credential (DefaultAzureCredential)
Token Scope: https://purview.azure.net/.default

Collections Created: 4 (Bronze, Silver, Gold, API)
Terms Created: 6 (Order, Shipment, SLA Compliance %, OTD %, Warehouse Productivity, DSO)
Errors: 0 (after fixes)
```

---

## 🐛 Troubleshooting

### Erreur: "Glossary already exists"

**Solution:** Le script vérifie maintenant l'existence avant création ✅

### Erreur: "Collection parent not found"

**Solution:** Utilise `stpurview` (account name) comme parent ✅

### Erreur: "Cannot construct LinkedHashMap"

**Solution:** Attributs custom stockés dans `longDescription` ✅

---

## ✅ Success Criteria

- [x] Glossary "3PL Real-Time Analytics" visible dans Purview Portal
- [x] 6 business terms créés avec définitions et technical mappings
- [x] 4 collections (Bronze/Silver/Gold/API) créées et provisionnées
- [x] Tous les status = "Approved" ou "Succeeded"
- [ ] Data sources registered (TODO: needs cluster URI)
- [ ] Lineage created (TODO: needs entity GUIDs after scan)

---

## 🎓 Lessons Learned

1. **REST API > CLI**: Fonctionne même quand l'extension CLI est bloquée
2. **DefaultAzureCredential**: Utilise automatiquement `az login` credentials
3. **Atlas API**: Purview utilise Apache Atlas API (v2) pour le catalog
4. **Custom Attributes**: Pas supportés dans term creation basique → utiliser `longDescription`
5. **Collections**: Parent collection = account name (pas "purview")

---

## 📚 Références

- **Purview Portal**: https://web.purview.azure.com/resource/stpurview
- **REST API Docs**: https://learn.microsoft.com/en-us/rest/api/purview/
- **Atlas API**: https://atlas.apache.org/api/v2/
- **Python Script**: `governance/purview/purview_automation.py`
- **Summary JSON**: `governance/purview/purview_setup_summary.json`
