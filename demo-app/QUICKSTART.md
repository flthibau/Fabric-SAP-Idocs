# 🚀 Quick Start Guide - 3PL Partner API Demo

## En 5 Minutes

### Étape 1: Obtenir un Token (2 min)

```powershell
# Dans le dossier demo-app
.\get-token.ps1 -ServicePrincipal fedex
```

Entrez le secret du Service Principal FedEx quand demandé.
Le token sera copié dans votre presse-papiers.

### Étape 2: Lancer l'Application (1 min)

```powershell
.\start-demo.ps1
```

L'application s'ouvrira automatiquement dans votre navigateur à `http://localhost:8000`

### Étape 3: Se Connecter (1 min)

1. Cliquez sur **"FedEx Carrier"**
2. Quand demandé, **collez le token** (Ctrl+V)
3. Le dashboard s'affiche !

### Étape 4: Explorer les Données (1 min)

- **Statistiques** : Voir les compteurs en haut
- **Onglets** : Cliquer sur Shipments, Orders, etc.
- **Refresh** : Bouton 🔄 pour recharger les données

---

## Tester les 3 Service Principals

### FedEx (Transporteur) 🚚

```powershell
.\get-token.ps1 -ServicePrincipal fedex
```

**Données visibles** :
- ✅ Shipments FedEx uniquement
- ✅ SLA Performance FedEx
- ❌ Pas de données Warehouse/Customer

### Warehouse Partner (Entrepôt) 🏭

```powershell
.\get-token.ps1 -ServicePrincipal warehouse
```

**Données visibles** :
- ✅ Warehouse Productivity (WH003)
- ✅ Shipments traités par WH003
- ❌ Pas de données autres entrepôts

### ACME Customer (Client) 🏢

```powershell
.\get-token.ps1 -ServicePrincipal acme
```

**Données visibles** :
- ✅ Orders ACME
- ✅ Revenue ACME
- ❌ Pas de données autres clients

---

## Démonstration du RLS

### Scénario 1: Comparer FedEx vs UPS

1. Se connecter avec **FedEx**
2. Noter le nombre de shipments (ex: 5)
3. Se déconnecter
4. Se connecter avec **Warehouse** (autre vue)
5. Vérifier que les données sont différentes

**Résultat** : RLS fonctionne ! Chaque SP voit ses propres données.

### Scénario 2: Aucune Donnée = RLS OK

Si une API retourne **0 items**, c'est normal :
- Le RLS filtre les données
- Ce SP n'a pas accès à cette vue
- Exemple: FedEx ne voit pas les données Orders

---

## Troubleshooting Express

### ❌ "API Error 401"

**Problème** : Token expiré ou invalide

**Solution** :
```powershell
.\get-token.ps1 -ServicePrincipal fedex
```

### ❌ "CORS Error"

**Problème** : Application ouverte avec file://

**Solution** :
```powershell
.\start-demo.ps1  # Utilise un serveur HTTP
```

### ❌ "Python not found"

**Solutions** :
1. **Installer Python** : https://python.org
2. **VS Code Live Server** : Extension gratuite
3. **Node.js** : `npm install -g http-server`

### ❌ "No data returned"

**C'est normal !** Le RLS filtre les données.

**Vérifier** :
- Êtes-vous connecté avec le bon SP ?
- Ce SP a-t-il accès à ces données ?
- Les rôles RLS sont-ils configurés dans Fabric ?

---

## Raccourcis Utiles

| Action | Raccourci |
|--------|-----------|
| Onglet Shipments | `Alt + 1` |
| Onglet Orders | `Alt + 2` |
| Onglet Warehouse | `Alt + 3` |
| Onglet SLA | `Alt + 4` |
| Onglet Revenue | `Alt + 5` |
| Refresh onglet | `Ctrl + R` |

---

## Next Steps

### Pour une Démo Complète

1. **Préparer 3 tokens** :
   ```powershell
   .\get-token.ps1 -ServicePrincipal fedex > token-fedex.txt
   .\get-token.ps1 -ServicePrincipal warehouse > token-warehouse.txt
   .\get-token.ps1 -ServicePrincipal acme > token-acme.txt
   ```

2. **Montrer le RLS** :
   - Connectez-vous avec chaque SP
   - Comparez les données affichées
   - Montrez que 0 items = RLS fonctionne

3. **Expliquer l'architecture** :
   - Browser → APIM → Fabric GraphQL
   - Token passthrough (pas de Managed Identity)
   - RLS appliqué selon Object ID du SP

### Pour Améliorer l'App

Voir `README.md` section "Améliorations Futures" :
- Backend proxy pour gérer les tokens
- Graphiques et visualisations
- Export CSV/Excel
- Mode sombre

---

## Support

**Documentation** :
- `demo-app/README.md` - Documentation complète
- `api/APIM_CONFIGURATION.md` - Configuration APIM
- `governance/RLS_CONFIGURATION_VALUES.md` - Configuration RLS

**Scripts** :
- `start-demo.ps1` - Lancer l'app
- `get-token.ps1` - Obtenir token SP

---

**Ready to demo! 🎉**
