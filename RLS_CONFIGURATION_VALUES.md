# ✅ VALEURS RLS CORRECTES - À CONFIGURER DANS FABRIC PORTAL

## Résumé des corrections

Les valeurs suivantes ont été identifiées comme correctes dans les données Gold :

| Rôle RLS | Colonne | Valeur Correcte | Service Principal |
|----------|---------|-----------------|-------------------|
| **CarrierFedEx** | `carrier_id` | `CARRIER-FEDEX-GROU` | fa86b10b-792c-495b-af85-bc8a765b44a1 |
| **WarehousePartner** | `warehouse_partner_id` | `PARTNER-WH003` | bf7ca9fa-eb65-4261-91f2-08d2b360e919 |
| **CustomerAcme** | `partner_access_scope` | `CUSTOMER` | efae8acd-de55-4c89-96b6-7f031a954ae6 |

---

## Actions requises dans Fabric Portal

### Étape 1 : Ouvrir la configuration RLS

1. Aller dans Fabric Portal
2. Naviguer vers : **Workspace** → **Lakehouse3PLAnalytics** → **SQL Analytics Endpoint**
3. Cliquer sur **Security** → **Manage Roles**

### Étape 2 : Configurer les 3 rôles RLS

#### 🔵 Rôle 1 : CarrierFedEx

**Service Principal** : `fa86b10b-792c-495b-af85-bc8a765b44a1` (FedEx Carrier Partner API)

**Table 1** : `gold_shipments_in_transit`
```sql
carrier_id = 'CARRIER-FEDEX-GROU'
```

**Table 2** : `gold_sla_performance`
```sql
carrier_id = 'CARRIER-FEDEX-GROU'
```

---

#### 🟢 Rôle 2 : WarehousePartner

**Service Principal** : `bf7ca9fa-eb65-4261-91f2-08d2b360e919` (Warehouse East Partner API)

**Table 1** : `gold_warehouse_productivity_daily`
```sql
warehouse_partner_id = 'PARTNER-WH003'
```

---

#### 🟡 Rôle 3 : CustomerAcme

**Service Principal** : `efae8acd-de55-4c89-96b6-7f031a954ae6` (ACME Corp Customer API)

**Table 1** : `gold_orders_daily_summary`
```sql
partner_access_scope = 'CUSTOMER'
```

**Table 2** : `gold_shipments_in_transit`
```sql
partner_access_scope = 'CUSTOMER'
```

**Table 3** : `gold_revenue_recognition_realtime`
```sql
partner_access_scope = 'CUSTOMER'
```

**Table 4** : `gold_sla_performance`
```sql
partner_access_scope = 'CUSTOMER'
```

---

## Notes importantes

### ⚠️ Valeur tronquée : CARRIER-FEDEX-GROU
- Le carrier_id est limité à 19 caractères
- `CARRIER-FEDEX-GROUP` → `CARRIER-FEDEX-GROU` (P final supprimé)
- **NE PAS UTILISER** `CARRIER-FEDEX-GROUP` dans la configuration RLS

### ⚠️ Format avec tirets, pas underscores
- Warehouse Partner ID utilise des **tirets** : `PARTNER-WH003`
- **NE PAS UTILISER** `PARTNER_WH003` (avec underscore)

---

## Vérification après configuration

Une fois la configuration RLS mise à jour dans le Portal, testez avec :

```powershell
cd api\scripts
.\test-graphql-rls-azcli.ps1
```

### Résultats attendus :

✅ **FedEx Carrier** : Voit uniquement les données avec `carrier_id = 'CARRIER-FEDEX-GROU'`  
✅ **Warehouse Partner** : Voit uniquement les données avec `warehouse_partner_id = 'PARTNER-WH003'`  
✅ **ACME Customer** : Voit uniquement les données avec `partner_access_scope = 'CUSTOMER'`

---

## Fichiers de configuration mis à jour

Les fichiers suivants ont été mis à jour avec les valeurs correctes :

- ✅ `fabric/warehouse/security/verify-rls-data.sql`
- ✅ `fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md`
- ✅ `fabric/warehouse/security/onelake-rls-config.json`
- ✅ `api/scripts/test-graphql-rls-azcli.ps1`

---

## Prochaines étapes

1. ✅ **Mettre à jour la configuration RLS** dans Fabric Portal (avec les valeurs ci-dessus)
2. ⏸️ **Tester RLS** : `.\test-graphql-rls-azcli.ps1`
3. ⏸️ **Déployer APIM** : `.\deploy-apim.ps1`
4. ⏸️ **Test end-to-end** via APIM

