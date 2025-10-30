# 3PL Partner API Demo Application

Application web de démonstration pour les APIs 3PL Partner avec Row-Level Security (RLS).

## 📋 Vue d'ensemble

Cette application démontre l'accès aux APIs Fabric GraphQL exposées via Azure APIM avec authentification Service Principal et filtrage RLS.

### Fonctionnalités

- 🔐 **Authentification multi-tenant** : Connexion avec 3 Service Principals différents
- 📊 **Dashboard interactif** : Visualisation des données en temps réel
- 🔒 **Démonstration RLS** : Chaque SP voit uniquement ses données autorisées
- 🚀 **Interface moderne** : Design responsive avec animations
- 📱 **Mobile-friendly** : Fonctionne sur tous les appareils

### APIs Démontrées

| API | Endpoint | Description |
|-----|----------|-------------|
| Shipments | `/shipments` | Envois en transit |
| Orders | `/orders` | Résumé quotidien des commandes |
| Warehouse | `/warehouse-productivity` | Productivité des entrepôts |
| SLA Performance | `/sla-performance` | Performance des transporteurs |
| Revenue | `/revenue` | Reconnaissance de revenus |

## 🚀 Installation

### Prérequis

- Un serveur web local (Python, Node.js, ou extension VS Code)
- Azure CLI installé
- Accès aux 3 Service Principals configurés

### Option 1: Python Simple HTTP Server

```bash
cd demo-app
python -m http.server 8000
```

Puis ouvrez: `http://localhost:8000`

### Option 2: Node.js http-server

```bash
npm install -g http-server
cd demo-app
http-server -p 8000
```

### Option 3: VS Code Live Server

1. Installez l'extension "Live Server"
2. Clic droit sur `index.html`
3. Sélectionnez "Open with Live Server"

## 🔧 Configuration

### 1. Configurer les Secrets des Service Principals

Éditez `js/config.js` et ajoutez les secrets :

```javascript
servicePrincipals: {
    fedex: {
        secret: 'VOTRE_SECRET_FEDEX'
    },
    warehouse: {
        secret: 'VOTRE_SECRET_WAREHOUSE'
    },
    acme: {
        secret: 'VOTRE_SECRET_ACME'
    }
}
```

⚠️ **IMPORTANT** : Pour la production, ne stockez JAMAIS les secrets dans le code frontend. Utilisez un backend proxy.

### 2. Vérifier l'URL APIM

Dans `js/config.js`, vérifiez que l'URL APIM est correcte :

```javascript
apimGateway: 'https://apim-3pl-flt.azure-api.net'
```

## 📖 Utilisation

### Connexion

1. **Sélectionnez un Service Principal** :
   - 🚚 FedEx Carrier : Voit uniquement ses shipments
   - 🏭 Warehouse Partner : Voit les données de l'entrepôt WH003
   - 🏢 ACME Customer : Voit ses commandes et factures

2. **Obtenez un token** :
   - Option manuelle (pour démo) :
     ```powershell
     # Connectez-vous avec le SP
     az login --service-principal `
       -u <APP_ID> `
       -p <SECRET> `
       --tenant 38de1b20-8309-40ba-9584-5d9fcb7203b4
     
     # Obtenez le token
     $token = (az account get-access-token `
       --resource "https://analysis.windows.net/powerbi/api" `
       --scope "https://analysis.windows.net/powerbi/api/.default" `
       | ConvertFrom-Json).accessToken
     
     echo $token
     ```
   - Copiez et collez le token dans l'interface

3. **Explorez les données** :
   - Le dashboard affiche automatiquement les données filtrées par RLS
   - Utilisez les onglets pour naviguer entre les différentes APIs
   - Cliquez sur "Refresh" pour recharger les données

### Raccourcis Clavier

- `Alt + 1-5` : Navigation rapide entre les onglets
- `Ctrl + R` : Refresh de l'onglet actif

## 🎨 Structure du Projet

```
demo-app/
├── index.html              # Page principale
├── css/
│   └── styles.css         # Styles de l'application
├── js/
│   ├── config.js          # Configuration APIM et SPs
│   ├── auth.js            # Module d'authentification
│   ├── api.js             # Appels API et rendering
│   └── app.js             # Logique principale
└── README.md              # Cette documentation
```

## 🔐 Sécurité

### Pour la Démo

L'application actuelle demande à l'utilisateur de coller manuellement un token Bearer. Ceci est acceptable pour une démo interne.

### Pour la Production

Implémentez un backend proxy qui :

1. **Gère l'authentification** :
   ```
   Frontend → Backend Proxy → Azure AD → APIM
   ```

2. **Protège les secrets** :
   - Les secrets SP stockés côté serveur uniquement
   - Backend obtient les tokens via Client Credentials Flow
   - Frontend n'a jamais accès aux secrets

3. **Exemple d'architecture** :
   ```
   [Browser] 
      ↓ (User login)
   [Auth Backend - Node.js/Python]
      ↓ (SP auth + token)
   [APIM Gateway]
      ↓ (GraphQL query)
   [Fabric GraphQL + RLS]
   ```

## 📊 Démonstration du RLS

### Test avec FedEx SP

```
Connexion : FedEx Carrier
Résultat  : Voit uniquement les shipments FedEx
Tables    : gold_shipments_in_transits filtrés
```

### Test avec Warehouse SP

```
Connexion : Warehouse Partner (WH003)
Résultat  : Voit uniquement les données de WH003
Tables    : gold_warehouse_productivity_dailies filtrés
```

### Test avec ACME SP

```
Connexion : ACME Customer
Résultat  : Voit ses commandes et revenus
Tables    : gold_orders_daily_summaries, gold_revenue_* filtrés
```

## 🐛 Dépannage

### CORS Errors

Si vous voyez des erreurs CORS dans la console :

1. **Vérifiez le serveur web** :
   - N'utilisez PAS `file://` directement
   - Utilisez un serveur HTTP local

2. **Configurez APIM** :
   - Ajoutez une policy CORS dans APIM :
   ```xml
   <cors allow-credentials="false">
       <allowed-origins>
           <origin>http://localhost:8000</origin>
       </allowed-origins>
       <allowed-methods>
           <method>GET</method>
           <method>POST</method>
       </allowed-methods>
       <allowed-headers>
           <header>*</header>
       </allowed-headers>
   </cors>
   ```

### Token Invalide

Si vous obtenez `401 Unauthorized` :

1. Vérifiez que le token n'a pas expiré (1h de validité)
2. Régénérez un nouveau token
3. Vérifiez le scope : `https://analysis.windows.net/powerbi/api/.default`

### Pas de Données Retournées

Si l'API retourne 0 items :

1. **C'est peut-être normal** : Le RLS filtre les données
2. **Vérifiez le RLS** :
   - Les rôles sont-ils configurés dans Fabric ?
   - Les Object IDs sont-ils corrects ?
3. **Testez avec un autre SP** pour comparer

## 🔄 Améliorations Futures

### Version 1.0 (Actuelle)
- ✅ Authentification manuelle avec token
- ✅ Dashboard avec 5 APIs
- ✅ Tableaux de données
- ✅ Stats en temps réel

### Version 2.0 (Planifiée)
- [ ] Backend proxy Node.js/Python
- [ ] Authentification automatique
- [ ] Graphiques et visualisations
- [ ] Export CSV/Excel
- [ ] Filtres et recherche avancée
- [ ] Mode sombre

### Version 3.0 (Future)
- [ ] Real-time avec WebSockets
- [ ] Notifications push
- [ ] Multi-langue (EN/FR)
- [ ] Tests unitaires
- [ ] CI/CD pipeline

## 📝 Notes

### GraphQL dans le Body

Actuellement, l'application envoie des requêtes GraphQL dans le body des requêtes POST. Pour une API REST "pure", voir la section suivante de la roadmap.

### Migration vers REST Standard

Pour transformer les endpoints en véritables APIs REST :

1. **Backend transformation layer** :
   - Convertir les query parameters en GraphQL
   - `GET /shipments?carrier_id=FEDEX` → GraphQL query

2. **APIM Policies** :
   - Utiliser `set-body` avec C# pour générer GraphQL
   - Plus complexe mais plus "REST-like"

3. **Alternative** : Utiliser Fabric REST APIs directement (quand disponibles)

## 📞 Support

Pour toute question :
- Consultez `api/APIM_CONFIGURATION.md` pour la configuration APIM
- Consultez `api/GRAPHQL_QUERIES_REFERENCE.md` pour les queries GraphQL
- Vérifiez `governance/RLS_CONFIGURATION_VALUES.md` pour le RLS

## 📜 Licence

Projet de démonstration interne - Microsoft
