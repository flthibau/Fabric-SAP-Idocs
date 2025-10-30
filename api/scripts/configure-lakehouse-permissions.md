# Configuration des Permissions Lakehouse pour Service Principals

## Problème Identifié

**Erreur**: "The request to data source failed with authentication error"

**Cause**: Les Service Principals ont accès à l'API GraphQL, mais n'ont **PAS** accès au Lakehouse qui contient les données Gold.

**Solution**: Ajouter les Service Principals au **Lakehouse** avec le rôle **Viewer** (ou utiliser OneLake RLS).

---

## Actions Requises dans Fabric Portal

### Option 1: Permissions Lakehouse Directes (Plus Simple)

1. **Ouvrir Fabric Portal**
   ```
   https://msit.powerbi.com/groups/ad53e547-23dc-46b0-ab5f-2acbaf0eec64
   ```

2. **Naviguer vers le Lakehouse**
   - Cliquer sur **Lakehouse3PLAnalytics**
   - Ou aller directement à: Workspace → Lakehouse → Lakehouse3PLAnalytics

3. **Ajouter les Permissions**
   - Cliquer sur les **... (trois points)** à côté du nom du Lakehouse
   - Sélectionner **Manage permissions**
   - Cliquer **Add user**

4. **Ajouter chaque Service Principal avec rôle VIEWER** (3 fois):

   **FedEx Carrier API**
   - Nom/Email: `FedEx Carrier API` (ou App ID: `94a9edcc-7a22-4d89-b001-799e8414711a`)
   - Rôle: **Viewer** ✅
   - Cliquer **Grant**

   **Warehouse Partner API**
   - Nom/Email: `Warehouse Partner API` (ou App ID: `1de3dcee-f7eb-4701-8cd9-ed65f3792fe0`)
   - Rôle: **Viewer** ✅
   - Cliquer **Grant**

   **ACME Customer API**
   - Nom/Email: `ACME Customer API` (ou App ID: `a3e88682-8bef-4712-9cc5-031d109cefca`)
   - Rôle: **Viewer** ✅
   - Cliquer **Grant**

5. **Vérifier les Permissions**
   - Retourner à **Manage permissions**
   - Vous devriez voir les 3 Service Principals listés avec rôle **Viewer**

---

### Option 2: OneLake RLS (Déjà Configuré - Devrait Fonctionner)

Si vous avez **déjà configuré OneLake RLS** dans le SQL Analytics Endpoint avec les rôles CarrierFedEx, WarehousePartner, CustomerAcme:

1. **Vérifier que les Service Principals sont assignés aux rôles RLS**
   - Aller à: Lakehouse → **SQL Analytics Endpoint** → Security → **Manage Roles**
   - Vérifier que chaque rôle a le bon Service Principal Object ID:
     - **CarrierFedEx**: `fa86b10b-792c-495b-af85-bc8a765b44a1`
     - **WarehousePartner**: `bf7ca9fa-eb65-4261-91f2-08d2b360e919`
     - **CustomerAcme**: `efae8acd-de55-4c89-96b6-7f031a954ae6`

2. **OneLake RLS devrait automatiquement donner l'accès filtré**
   - Si les rôles sont bien assignés, les SP devraient avoir accès via RLS
   - Pas besoin de permissions Viewer supplémentaires

**MAIS**: Si l'erreur persiste même avec RLS → Ajouter quand même les permissions Viewer (Option 1)

---

## Pourquoi Cette Erreur?

### Architecture des Permissions Fabric

```
Service Principal
    ↓ (Permission 1)
Workspace → VIEWER ✅ (déjà fait)
    ↓ (Permission 2)
GraphQL API → Execute ✅ (déjà fait)
    ↓ (Permission 3 - MANQUANTE ❌)
Lakehouse → VIEWER ou RLS ⚠️ (à faire maintenant!)
    ↓
Gold Tables (données)
```

**Les 3 niveaux de permissions sont requis**:
1. ✅ Workspace VIEWER
2. ✅ GraphQL API Execute
3. ❌ Lakehouse VIEWER **OU** OneLake RLS

---

## Test Après Configuration

Une fois les permissions ajoutées, relancer le test:

```powershell
cd C:\Users\flthibau\Desktop\Fabric+SAP+Idocs\api\scripts
.\test-graphql-rls-azcli.ps1
```

**Résultat attendu**: 
- ✅ FedEx Carrier: 2/2 tests passés (seulement données CARRIER-FEDEX-GROU)
- ✅ Warehouse Partner: 1/1 tests passés (seulement données PARTNER-WH003)
- ✅ ACME Customer: 4/4 tests passés (seulement données CUSTOMER)

---

## Notes Importantes

- **OneLake RLS prend 1-2 minutes pour se propager** après modification
- Si vous utilisez **uniquement OneLake RLS** (sans Viewer), les SP doivent être **assignés aux rôles RLS**
- Si vous ajoutez **Viewer en plus de RLS**, le filtrage RLS sera appliqué automatiquement

---

## Alternative: Vérifier Permissions Actuelles

Pour voir quelles permissions les SP ont actuellement:

1. **Workspace Permissions**:
   - Workspace → Settings → Manage access
   - Chercher les 3 Service Principals

2. **Lakehouse Permissions**:
   - Lakehouse → ... → Manage permissions
   - Vérifier si les 3 SP sont listés

3. **GraphQL API Permissions**:
   - GraphQL API → ... → Manage permissions
   - Vérifier "Run Queries and Mutations"

---

## Service Principals à Configurer

| Service Principal | App ID | Object ID (pour RLS) | Rôle Lakehouse |
|---|---|---|---|
| **FedEx Carrier API** | `94a9edcc-7a22-4d89-b001-799e8414711a` | `fa86b10b-792c-495b-af85-bc8a765b44a1` | Viewer |
| **Warehouse Partner API** | `1de3dcee-f7eb-4701-8cd9-ed65f3792fe0` | `bf7ca9fa-eb65-4261-91f2-08d2b360e919` | Viewer |
| **ACME Customer API** | `a3e88682-8bef-4712-9cc5-031d109cefca` | `efae8acd-de55-4c89-96b6-7f031a954ae6` | Viewer |

---

## En Résumé

**Ce qu'il faut faire MAINTENANT**:

1. ✅ Ouvrir Fabric Portal
2. ✅ Aller à Lakehouse3PLAnalytics
3. ✅ **Manage permissions** → Add user
4. ✅ Ajouter les 3 Service Principals avec rôle **Viewer**
5. ✅ Relancer `.\test-graphql-rls-azcli.ps1`

**Temps estimé**: 5 minutes

**Résultat attendu**: Tests RLS passent avec filtrage correct des données! 🎯
