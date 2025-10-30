# OneLake Row-Level Security (RLS) - Guide de Configuration

## Vue d'ensemble

OneLake RLS permet de configurer la sécurité au niveau des lignes **directement sur les tables Delta/Parquet** dans OneLake. Le RLS est automatiquement propagé à tous les services qui accèdent aux données.

## Architecture

```
OneLake (Storage Layer)
    ↓
Delta Tables avec .rls configuration
    ↓ Propagation automatique
    ├─→ GraphQL API ✓
    ├─→ SQL Analytics Endpoint ✓
    ├─→ Power BI Direct Lake ✓
    ├─→ Notebooks ✓
    └─→ Pipelines ✓
```

## Configuration pour les Tables SILVER

### Tables concernées (Eventhouse)
- `idoc_orders_silver`
- `idoc_shipments_silver`
- `idoc_warehouse_silver`
- `idoc_invoices_silver`

### Rôles RLS à créer

#### 1. **Rôle CarrierFedEx**
- **Description**: Transporteur FedEx - Accès uniquement à ses expéditions
- **Table**: `idoc_shipments_silver`
- **Filtre**: `carrier_id = 'CARRIER-FEDEX'`

#### 2. **Rôle WarehouseEast**
- **Description**: Entrepôt East - Accès uniquement à ses mouvements
- **Table**: `idoc_warehouse_silver`
- **Filtre**: `warehouse_partner_id = 'WAREHOUSE-EAST'`

#### 3. **Rôle CustomerAcme**
- **Description**: Client ACME - Accès à ses commandes, expéditions et factures
- **Tables**: 
  - `idoc_orders_silver` → Filtre: `partner_access_scope = 'CUSTOMER-ACME'`
  - `idoc_shipments_silver` → Filtre: `partner_access_scope = 'CUSTOMER-ACME'`
  - `idoc_invoices_silver` → Filtre: `partner_access_scope = 'CUSTOMER-ACME'`

## Fichier de configuration RLS

Le fichier `onelake-rls-config.json` définit les 3 rôles et leurs règles.

**Note**: Les `<APP-ID>` seront remplacés par les Service Principal IDs créés via Azure AD.

## Étapes de déploiement

### Option 1: Via Fabric Portal (Recommandé)

1. **Ouvrir l'Eventhouse**
   - Fabric Portal → Workspace MngEnvMCAP396311
   - Ouvrir l'Eventhouse `eh_idoc_realtime`

2. **Configurer OneLake Security**
   - Aller dans **Settings** → **OneLake Security** ou **Security**
   - Chercher l'option **Row-Level Security**

3. **Créer les rôles**
   - Cliquer sur **+ New Role**
   - Configurer les 3 rôles avec leurs filtres respectifs

4. **Assigner les Service Principals**
   - Pour chaque rôle, ajouter le Service Principal de l'app Azure AD correspondante
   - Les Service Principals seront créés via le script `create-partner-apps.ps1`

### Option 2: Via API REST Fabric

Utiliser l'API Fabric pour uploader le fichier `.rls` dans le workspace OneLake.

**Endpoint**:
```
POST https://api.fabric.microsoft.com/v1/workspaces/{workspaceId}/items/{itemId}/onelake/security
```

### Option 3: Via fichier .rls dans OneLake

Déposer le fichier `.rls.json` directement dans le dossier de la table Delta via l'explorateur OneLake.

## Propagation au GraphQL API

Une fois le RLS configuré dans OneLake :

1. ✅ Le GraphQL API appliquera **automatiquement** le RLS
2. ✅ Quand un Service Principal (ex: CARRIER-FEDEX) interroge l'API GraphQL
3. ✅ Seules les lignes correspondant au filtre RLS sont retournées
4. ✅ Pas besoin de logique applicative supplémentaire !

## Test du RLS

### 1. Créer les Service Principals (App Registrations)
```powershell
cd api/scripts
.\create-partner-apps.ps1
```

Cela crée 3 apps :
- CARRIER-FEDEX-API
- WAREHOUSE-EAST-API
- CUSTOMER-ACME-API

### 2. Configurer le RLS avec les App IDs
Remplacer les `<APP-ID>` dans `onelake-rls-config.json` avec les vrais IDs.

### 3. Appliquer le RLS dans Fabric Portal
Suivre les étapes de l'Option 1 ci-dessus.

### 4. Tester avec différentes identités
```powershell
# Test avec CARRIER-FEDEX (devrait voir uniquement ses shipments)
az login --service-principal -u <CARRIER-FEDEX-APP-ID> -p <SECRET> --tenant <TENANT-ID>
.\test-graphql-simple.ps1

# Test avec CUSTOMER-ACME (devrait voir ses orders, shipments, invoices)
az login --service-principal -u <CUSTOMER-ACME-APP-ID> -p <SECRET> --tenant <TENANT-ID>
.\test-graphql-simple.ps1
```

## Avantages de OneLake RLS

✅ **Performance** - Filtrage au niveau du moteur de stockage (pas de surcharge)
✅ **Simplicité** - Configuration centralisée, propagation automatique
✅ **Sécurité** - Impossible de contourner le RLS (appliqué au niveau stockage)
✅ **Cohérence** - Même règles de sécurité pour tous les services
✅ **Maintenance** - Modification du RLS = impact immédiat sur tous les endpoints

## Ressources

- [Documentation OneLake RLS](https://learn.microsoft.com/en-us/fabric/onelake/security/row-level-security)
- [Configuration RLS dans Fabric](https://learn.microsoft.com/en-us/fabric/data-warehouse/row-level-security)

## Prochaines étapes

1. ✅ Créer les 3 Service Principals (App Registrations)
2. ✅ Configurer OneLake RLS avec les 3 rôles
3. ✅ Tester le RLS via GraphQL API
4. ✅ Déployer APIM avec Managed Identity
5. ✅ Configurer OAuth dans APIM pour les partenaires
