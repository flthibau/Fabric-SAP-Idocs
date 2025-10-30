# MISE À JOUR RLS - CARRIER ID TRONQUÉ

## Problème découvert
Le carrier_id `CARRIER-FEDEX-GROUP` est tronqué à 19 caractères dans les données.
Valeur réelle: `CARRIER-FEDEX-GROU` (sans le "P" final)

## Actions requises dans Fabric Portal

### 1. Mettre à jour le rôle RLS "CarrierFedEx"

**Localisation**: Fabric Portal → Lakehouse → SQL Analytics Endpoint → Security → Manage Roles

**Rôle à modifier**: `CarrierFedEx`

**Changements**:

#### Table: gold_shipments_in_transit
- ❌ Ancien filtre: `carrier_id = 'CARRIER-FEDEX-GROUP'`
- ✅ Nouveau filtre: `carrier_id = 'CARRIER-FEDEX-GROU'`

#### Table: gold_sla_performance
- ❌ Ancien filtre: `carrier_id = 'CARRIER-FEDEX-GROUP'`
- ✅ Nouveau filtre: `carrier_id = 'CARRIER-FEDEX-GROU'`

### 2. Vérifier les autres valeurs RLS

D'après les données GraphQL, les autres valeurs semblent OK mais à vérifier:

- ✅ `warehouse_partner_id = 'PARTNER_WH003'` (à confirmer)
- ⚠️ `partner_access_scope` = ?
  - Dans les données on voit: `CARRIER_CUSTOMER` 
  - On attendait: `CUSTOMER`
  - **À vérifier**: Est-ce `CUSTOMER` ou `CARRIER_CUSTOMER` ?

## Fichiers déjà mis à jour

✅ Les fichiers suivants ont été mis à jour avec `CARRIER-FEDEX-GROU`:
- `fabric/warehouse/security/verify-rls-data.sql`
- `fabric/warehouse/security/ONELAKE_RLS_CONFIGURATION_GUIDE.md`
- `fabric/warehouse/security/onelake-rls-config.json`
- `api/scripts/test-graphql-rls-azcli.ps1`

## Prochaines étapes

1. **Vérifier partner_access_scope**:
   ```graphql
   {
     gold_orders_daily_summaries(first: 5) {
       items {
         partner_access_scope
         customer_id
       }
     }
   }
   ```

2. **Mettre à jour RLS dans Fabric Portal** avec les vraies valeurs

3. **Tester RLS** avec `.\test-graphql-rls-azcli.ps1`

4. **Si succès**, déployer APIM avec `.\deploy-apim.ps1`
