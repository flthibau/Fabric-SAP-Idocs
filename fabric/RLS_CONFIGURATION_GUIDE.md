# Configuration Row-Level Security (RLS) pour API GraphQL 3PL

## Vue d'ensemble

Ce guide explique comment configurer le Row-Level Security (RLS) sur les tables Silver de l'Eventhouse pour filtrer les données par partenaire dans l'API GraphQL.

## Architecture RLS

```
Partner App (JWT avec claim partner_id)
    ↓
Azure APIM (Managed Identity)
    ↓
Fabric GraphQL API
    ↓
RLS Filter (basé sur le rôle)
    ↓
Tables Silver filtrées
```

## Prérequis

- Tables Silver avec colonnes B2B :
  - `partner_access_scope` (orders, shipments, invoices, warehouse)
  - `carrier_id` (shipments)
  - `warehouse_partner_id` (warehouse)
- Accès Admin à l'Eventhouse
- API GraphQL créée et fonctionnelle

## Étape 1 : Ouvrir le SQL Analytics Endpoint

1. Ouvrir Fabric Portal : https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64
2. Trouver l'**Eventhouse** `eh_3pl_idocs`
3. Cliquer sur **SQL Analytics Endpoint**
4. Aller dans **Security** → **Manage Roles**

## Étape 2 : Créer les 3 rôles RLS

### Rôle 1 : CARRIER-FEDEX

**Nom du rôle :** `CARRIER-FEDEX`

**Tables et filtres :**

```sql
-- Table: idoc_shipments_silver
[carrier_id] = 'CARRIER-FEDEX'
```

**Membres :**
- Service Principal : `sp-partner-fedex` (à créer avec create-partner-apps.ps1)
- Managed Identity APIM : `apim-3pl-flt` (après déploiement APIM)

**Description :** FedEx peut voir uniquement les shipments où ils sont le carrier

---

### Rôle 2 : WAREHOUSE-EAST

**Nom du rôle :** `WAREHOUSE-EAST`

**Tables et filtres :**

```sql
-- Table: idoc_warehouse_silver
[warehouse_partner_id] = 'WAREHOUSE-EAST'
```

**Membres :**
- Service Principal : `sp-partner-warehouse-east` (à créer)
- Managed Identity APIM : `apim-3pl-flt`

**Description :** Warehouse East voit uniquement leurs mouvements d'entrepôt

---

### Rôle 3 : CUSTOMER-ACME

**Nom du rôle :** `CUSTOMER-ACME`

**Tables et filtres :**

```sql
-- Table: idoc_orders_silver
[partner_access_scope] = 'CUSTOMER-ACME'

-- Table: idoc_shipments_silver
[partner_access_scope] = 'CUSTOMER-ACME'

-- Table: idoc_invoices_silver
[partner_access_scope] = 'CUSTOMER-ACME'
```

**Membres :**
- Service Principal : `sp-partner-acme` (à créer)
- Managed Identity APIM : `apim-3pl-flt`

**Description :** ACME Corp voit leurs orders, shipments, et invoices

---

## Étape 3 : Procédure de création dans Fabric Portal

### Via l'interface graphique :

1. **Security** → **Manage Roles**
2. Cliquer sur **+ New Role**
3. Entrer le nom du rôle (ex: `CARRIER-FEDEX`)
4. Sélectionner la table (ex: `idoc_shipments_silver`)
5. Entrer le filtre DAX : `[carrier_id] = 'CARRIER-FEDEX'`
6. Cliquer sur **Save**
7. Aller dans **Members** → **+ Add Members**
8. Ajouter les Service Principals (après création)

### Via SQL (alternative) :

**Note :** L'Eventhouse utilise Kusto (KQL), pas SQL traditionnel. La création de RLS se fait via l'interface Fabric Portal.

## Étape 4 : Vérifier la configuration

### Test 1 : Sans RLS (Admin)

```graphql
query {
  idoc_shipments_silvers {
    items {
      shipment_number
      carrier_id
    }
  }
}
```

**Résultat attendu :** Tous les shipments (100 items)

### Test 2 : Avec RLS (Partner FedEx)

Après avoir assigné le Service Principal au rôle `CARRIER-FEDEX` :

```graphql
query {
  idoc_shipments_silvers {
    items {
      shipment_number
      carrier_id
    }
  }
}
```

**Résultat attendu :** Uniquement les shipments avec `carrier_id = 'CARRIER-FEDEX'`

## Étape 5 : Configuration dynamique (Avancé)

Pour un filtrage dynamique basé sur le claim JWT `partner_id` :

### Option 1 : Via APIM Policy

```xml
<set-header name="X-Partner-Id">
  <value>@{
    var jwt = context.Request.Headers.GetValueOrDefault("Authorization","")
                     .Replace("Bearer ", "");
    var token = jwt.AsJwt();
    return token?.Claims.GetValueOrDefault("partner_id", "");
  }</value>
</set-header>
```

### Option 2 : Via Fabric Security Context

Fabric peut lire les claims du JWT et appliquer le RLS automatiquement si configuré correctement.

## Résumé de la configuration

| Rôle | Table(s) | Filtre | Partenaires |
|------|----------|--------|-------------|
| CARRIER-FEDEX | idoc_shipments_silver | carrier_id = 'CARRIER-FEDEX' | FedEx |
| WAREHOUSE-EAST | idoc_warehouse_silver | warehouse_partner_id = 'WAREHOUSE-EAST' | Warehouse East |
| CUSTOMER-ACME | orders/shipments/invoices | partner_access_scope = 'CUSTOMER-ACME' | ACME Corp |

## Prochaines étapes

1. ✅ **Créer les 3 rôles RLS** (vous êtes ici)
2. ⏭️ **Créer Partner App Registrations** (`.\create-partner-apps.ps1`)
3. ⏭️ **Déployer APIM** (`.\deploy-apim.ps1`)
4. ⏭️ **Assigner Managed Identity APIM aux rôles**
5. ⏭️ **Tester avec différents partenaires**

## Troubleshooting

### Problème : RLS ne filtre pas les données

**Solutions :**
1. Vérifier que le Service Principal est bien membre du rôle
2. Vérifier que le filtre DAX est correct
3. Vérifier que la colonne utilisée existe dans la table
4. Tester avec un token JWT valide contenant le bon claim

### Problème : "Access Denied"

**Solutions :**
1. Vérifier les permissions du Service Principal sur l'Eventhouse
2. Ajouter le SP au rôle RLS
3. Vérifier que le Managed Identity APIM a les bonnes permissions

### Problème : Tous les partenaires voient toutes les données

**Solutions :**
1. Vérifier que RLS est activé sur les tables
2. Vérifier que les rôles sont bien assignés
3. Vérifier que les filtres DAX sont corrects

## Références

- [Fabric Row-Level Security](https://learn.microsoft.com/en-us/fabric/security/row-level-security)
- [Eventhouse Security](https://learn.microsoft.com/en-us/fabric/real-time-analytics/security)
- [DAX Filter Context](https://learn.microsoft.com/en-us/dax/filter-function-dax)
