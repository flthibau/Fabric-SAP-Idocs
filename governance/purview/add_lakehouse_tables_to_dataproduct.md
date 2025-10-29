# Guide: Ajouter les Tables Lakehouse au Data Product

## Contexte
Les 11 tables (4 Silver + 7 Gold) sont disponibles dans le **Fabric Lakehouse** mais ne sont pas encore dans Purview Data Map. Nous devons les ajouter manuellement au Data Product "3PL Real-Time Analytics".

## Data Product ID
```
818affc4-2deb-439d-939f-ea0a240e4c78
```

## Tables à Ajouter

### Tables Silver (4)
1. `idoc_orders_silver`
2. `idoc_shipments_silver`
3. `idoc_warehouse_silver`
4. `idoc_invoices_silver`

### Tables Gold (7)
1. `orders_daily_summary`
2. `sla_performance`
3. `shipments_in_transit`
4. `warehouse_productivity`
5. `revenue_realtime`
6. `invoice_aging`
7. `customer_performance`

## Option 1: Via Purview Portal (Recommandé)

### Étape 1: Scanner le Fabric Workspace

1. Ouvrir Purview Portal:
   ```
   https://web.purview.azure.com/resource/stpurview
   ```

2. Naviguer vers **Data Map** → **Sources**

3. Cliquer **Register** → Sélectionner **Microsoft Fabric**

4. Configurer la source:
   - **Name**: Fabric-3PL-Workspace
   - **Tenant ID**: 38de1b20-8309-40ba-9584-5d9fcb7203b4
   - **Workspace ID**: `ad53e547-23dc-46b0-ab5f-2acbaf0eec64` (votre workspace Fabric)
   - **Collection**: Root collection ou créer "3PL Logistics"

5. Créer un **Scan**:
   - **Name**: Scan-3PL-Lakehouse
   - **Credential**: Purview MSI ou Service Principal
   - **Scope**: Sélectionner le Lakehouse avec les tables

6. Lancer le scan → Attendre la complétion (5-15 minutes)

### Étape 2: Ajouter les Tables au Data Product

1. Aller dans **Unified Catalog** → **Data products**

2. Rechercher et ouvrir **"3PL Real-Time Analytics"**

3. Dans l'onglet **Data assets**, cliquer **Add data assets**

4. Rechercher les tables par nom:
   - `idoc_orders_silver`
   - `idoc_shipments_silver`
   - etc.

5. Sélectionner les 11 tables

6. Cliquer **Add** → Les tables sont maintenant liées au Data Product ✅

## Option 2: Via API (Si le scan est déjà fait)

Si les tables apparaissent déjà dans Purview Data Map, utiliser le script Python:

```bash
cd governance\purview
python link_fabric_tables.py
```

Le script recherchera automatiquement les tables et créera les relations.

## Vérification

Après l'ajout, vérifier dans Purview Portal:

1. **Data Product** → **Data assets** devrait afficher 11 tables
2. **Lineage** devrait montrer les connexions
3. **Schema** de chaque table visible
4. **Properties** → **Domain**: 3PL Logistics

## Informations Lakehouse

### Workspace Fabric
- **Workspace ID**: `ad53e547-23dc-46b0-ab5f-2acbaf0eec64`
- **Workspace Name**: MngEnvMCAP396311 (ou nom configuré)
- **Lakehouse**: Contient les tables mirrored depuis Eventhouse

### Eventhouse Source
- **Eventhouse**: Contient les tables KQL originales
- **Mirroring**: Actif vers Lakehouse
- **Database**: Contient les 4 Silver tables + 7 Gold views

## Notes Importantes

⚠️ **Avant de scanner**: Assurez-vous que:
1. Purview MSI a les droits **Contributor** sur le Fabric Workspace
2. Le Lakehouse mirroring est actif et à jour
3. Les tables sont bien visibles dans Lakehouse (vous l'avez confirmé ✅)

💡 **Alternative rapide**: Dans Purview, vous pouvez aussi utiliser **Live View** pour voir automatiquement les assets Fabric sans scan complet (si activé pour votre tenant).

## Prochaines Étapes Après Liaison

Une fois les tables liées au Data Product:

1. ✅ **Business Glossary**: Créer les termes métier
2. ✅ **Data Quality**: Configurer les règles de qualité
3. ✅ **OKRs**: Définir les objectifs et KPIs
4. ✅ **Access Policies**: Configurer les politiques d'accès B2B
5. ✅ **Documentation**: Ajouter descriptions et exemples d'usage
