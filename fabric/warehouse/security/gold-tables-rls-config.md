# Configuration RLS pour Tables GOLD

## Problème Identifié ⚠️

Les tables Gold actuelles sont des **agrégations** qui n'incluent PAS les colonnes de filtrage RLS :
- ❌ `partner_access_scope` 
- ❌ `carrier_id`
- ❌ `warehouse_partner_id`

**Ces colonnes sont perdues lors du `summarize`** car elles ne sont pas dans la clause `by`.

---

## Solution ✅

### Option 1: Modifier les vues Gold pour inclure les colonnes RLS (RECOMMANDÉ)

Ajouter les colonnes de filtrage dans le `by` clause de chaque vue matérialisée.

#### **gold_orders_daily_summary** - À MODIFIER

**Ajouter dans le `by` clause** :
```kql
by order_date_only, sap_system, partner_access_scope
```

Cela permet de :
- ✅ Conserver `partner_access_scope` dans la table Gold
- ✅ Appliquer le filtre RLS : `partner_access_scope = 'CUSTOMER-ACME'`
- ✅ Agréger par partenaire (chaque partenaire voit ses propres métriques)

#### **gold_shipments_in_transit** - À MODIFIER

**Ajouter dans le `by` clause** :
```kql
by transit_date, sap_system, carrier_id, partner_access_scope
```

Cela permet :
- ✅ RLS pour transporteurs : `carrier_id = 'CARRIER-FEDEX'`
- ✅ RLS pour clients : `partner_access_scope = 'CUSTOMER-ACME'`

#### **gold_warehouse_productivity_daily** - À MODIFIER

**Ajouter dans le `by` clause** :
```kql
by date, sap_system, warehouse_partner_id
```

Cela permet :
- ✅ RLS pour entrepôts : `warehouse_partner_id = 'WAREHOUSE-EAST'`

#### **gold_revenue_recognition_realtime** - À MODIFIER

**Ajouter dans le `by` clause** :
```kql
by invoice_date, sap_system, partner_access_scope
```

Cela permet :
- ✅ RLS pour clients : `partner_access_scope = 'CUSTOMER-ACME'`

#### **gold_sla_performance** - À MODIFIER

**Ajouter dans le `by` clause** :
```kql
by date, sap_system, partner_access_scope
```

---

## Configuration RLS OneLake Security (Après modification des vues)

Une fois les vues Gold modifiées avec les colonnes RLS, configurer dans **Fabric Portal** :

### **Rôle 1: CarrierFedEx**

**Table**: `gold_shipments_in_transit`
```sql
SELECT * FROM gold_shipments_in_transit WHERE carrier_id = 'CARRIER-FEDEX'
```

**Service Principal**: `fa86b10b-792c-495b-af85-bc8a765b44a1`

---

### **Rôle 2: WarehouseEast**

**Table**: `gold_warehouse_productivity_daily`
```sql
SELECT * FROM gold_warehouse_productivity_daily WHERE warehouse_partner_id = 'WAREHOUSE-EAST'
```

**Service Principal**: `bf7ca9fa-eb65-4261-91f2-08d2b360e919`

---

### **Rôle 3: CustomerAcme**

**Tables multiples** :

1. **Orders**
```sql
SELECT * FROM gold_orders_daily_summary WHERE partner_access_scope = 'CUSTOMER-ACME'
```

2. **Shipments**
```sql
SELECT * FROM gold_shipments_in_transit WHERE partner_access_scope = 'CUSTOMER-ACME'
```

3. **Revenue/Invoices**
```sql
SELECT * FROM gold_revenue_recognition_realtime WHERE partner_access_scope = 'CUSTOMER-ACME'
```

4. **SLA Performance**
```sql
SELECT * FROM gold_sla_performance WHERE partner_access_scope = 'CUSTOMER-ACME'
```

**Service Principal**: `efae8acd-de55-4c89-96b6-7f031a954ae6`

---

## Option 2: Créer des vues filtrées par partenaire (Alternative)

Si tu ne veux pas modifier les vues Gold existantes, créer des vues dédiées :

```kql
// Vue pour ACME
.create function gold_orders_acme() {
    gold_orders_daily_summary
    | join kind=inner (
        idoc_orders_silver 
        | where partner_access_scope == 'CUSTOMER-ACME'
        | distinct order_date_only = startofday(order_date), sap_system
    ) on order_date, sap_system
}

// Vue pour FedEx
.create function gold_shipments_fedex() {
    gold_shipments_in_transit
    | join kind=inner (
        idoc_shipments_silver 
        | where carrier_id == 'CARRIER-FEDEX'
        | distinct transit_date, sap_system
    ) on transit_date, sap_system
}
```

Mais cette approche est **moins performante** car elle nécessite des JOINs.

---

## Recommandation finale 🎯

**Modifier les 5 vues Gold** pour inclure les colonnes RLS dans le `by` clause :

1. ✅ Performance optimale (pas de JOIN supplémentaire)
2. ✅ RLS natif OneLake Security
3. ✅ Chaque partenaire voit uniquement ses métriques agrégées
4. ✅ Propagation automatique au GraphQL API

**Étapes** :
1. Modifier les scripts `.create materialized-view` pour ajouter colonnes RLS
2. Recréer les vues Gold dans Eventhouse
3. Configurer OneLake RLS dans Fabric Portal
4. Tester avec les Service Principals

Veux-tu que je modifie les 5 scripts KQL pour ajouter les colonnes RLS ?
