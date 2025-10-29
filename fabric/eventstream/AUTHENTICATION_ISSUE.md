# Event Hub Authentication - Probleme et Solutions

## 🚨 Probleme Identifie

**Date:** 2025-10-23  
**Contexte:** Configuration Eventstream SAPIdocIngestAuto

### Symptome
Impossible de connecter Fabric Eventstream a Azure Event Hub.

### Cause Racine
**Azure Policy sur la souscription actuelle:**
- Bloque l'authentification par cle d'acces (Shared Access Key)
- Force l'utilisation d'Entra ID (Azure AD) uniquement

**Limitation Fabric:**
- Fabric Eventstream ne supporte PAS encore l'authentification Entra ID pour Event Hub
- Seule l'authentification par cle (connection string) est supportee actuellement

### Impact
```
Event Hub (auth Entra ID uniquement)
    ↓
    ✗ Eventstream (supporte uniquement auth par cle)
    ↓
KQL Database
```

## 🔧 Solutions

### Solution 1: Nouveau Tenant (RECOMMANDEE - En cours)

**Approche:** Deployer Event Hub dans un tenant sans Azure Policy restrictive.

**Avantages:**
✅ Utilise Fabric Eventstream comme prevu (architecture optimale)
✅ Ingestion temps reel native
✅ Pas de code custom necessaire
✅ Interface graphique Fabric pour monitoring

**Etapes:**
1. Creer/Utiliser tenant Azure sans policy "Entra ID only"
2. Deployer Event Hub avec auth par cle autorisee
3. Creer Data Connection dans Fabric avec connection string
4. Re-executer script `create-eventstream-hybrid.ps1`
5. Publier et valider le flux

**Configuration Event Hub requise:**
```bash
# Autoriser auth par cle dans le nouveau tenant
az eventhubs namespace update \
  --name <namespace> \
  --resource-group <rg> \
  --disable-local-auth false

# Creer authorization rule
az eventhubs eventhub authorization-rule create \
  --name fabric-listen \
  --eventhub-name idoc-events \
  --namespace-name <namespace> \
  --resource-group <rg> \
  --rights Listen

# Recuperer connection string
az eventhubs eventhub authorization-rule keys list \
  --name fabric-listen \
  --eventhub-name idoc-events \
  --namespace-name <namespace> \
  --resource-group <rg> \
  --query primaryConnectionString -o tsv
```

**Configuration Fabric Data Connection:**
```
Type: Azure Event Hubs
Connection String: Endpoint=sb://<namespace>.servicebus.windows.net/;...
Event Hub: idoc-events
Consumer Group: fabric-consumer
```

### Solution 2: Fabric Data Pipeline (ALTERNATIVE)

**Approche:** Utiliser Data Pipeline au lieu d'Eventstream.

**Note:** Les Data Pipelines Fabric supportent l'authentification Entra ID pour Event Hub.

**Avantages:**
✅ Supporte auth Entra ID
✅ Peut rester dans le tenant actuel
✅ Transformation des donnees possible

**Inconvenients:**
❌ Pas de streaming temps reel natif
❌ Pipeline batch (schedule ou trigger)
❌ Plus complexe a configurer
❌ Moins adapte pour streaming continu

**Architecture alternative:**
```
Event Hub (auth Entra ID)
    ↓
Data Pipeline (batch toutes les X minutes)
    ↓
Lakehouse / KQL Database
```

**Etapes (si necessaire):**
1. Creer Data Pipeline dans Fabric
2. Ajouter activite "Copy Data"
3. Source: Event Hub (auth Entra ID via Service Principal)
4. Sink: KQL Database
5. Schedule: toutes les 1-5 minutes
6. Publier et monitorer

### Solution 3: Azure Stream Analytics (HYBRIDE)

**Approche:** Utiliser Azure Stream Analytics comme pont.

**Architecture:**
```
Event Hub (auth Entra ID)
    ↓
Azure Stream Analytics (supporte Entra ID)
    ↓
Fabric KQL Database (via API)
```

**Avantages:**
✅ Streaming temps reel
✅ Supporte Entra ID
✅ Transformations SQL possibles

**Inconvenients:**
❌ Ressource Azure supplementaire
❌ Cout additionnel
❌ Gestion hors Fabric

### Solution 4: Event Hub avec Exceptions Policy

**Approche:** Demander exception Azure Policy pour Event Hub specifique.

**Si possible dans votre organisation:**
1. Soumettre demande d'exception pour namespace Event Hub
2. Justification: Integration Fabric limitee
3. Scope: Uniquement namespace `eh-idoc-flt8076`
4. Temporaire jusqu'a support Entra ID dans Fabric Eventstream

**Probabilite:** Faible dans environnements hautement regules.

## 📊 Comparaison Solutions

| Critere | Nouveau Tenant | Data Pipeline | Stream Analytics | Exception Policy |
|---------|---------------|---------------|------------------|------------------|
| **Complexite** | Faible | Moyenne | Elevee | Variable |
| **Temps reel** | ✅ Oui | ❌ Batch | ✅ Oui | ✅ Oui |
| **Cout** | Event Hub | Inclus Fabric | ASA + Event Hub | Event Hub |
| **Maintenance** | Faible | Moyenne | Elevee | Faible |
| **Conformite** | Depend tenant | ✅ Conforme | ✅ Conforme | ❓ Depend org |
| **Recommande** | **✅ OUI** | Si bloque | Si expertise | Si possible |

## 🎯 Recommendation

**OPTION RECOMMANDEE: Solution 1 - Nouveau Tenant**

### Justification:
1. **Architecture optimale:** Utilise Fabric Eventstream nativement
2. **Simplicite:** Pas de code custom, tout via UI Fabric
3. **Performance:** Streaming temps reel sans intermediaire
4. **Maintenabilite:** Moins de composants a gerer
5. **Evolutivite:** Pret pour futures features Fabric Eventstream

### Plan d'action (actuel):
1. ✅ Identifier probleme auth Entra ID
2. ⏳ **EN COURS:** Configurer Event Hub dans nouveau tenant
3. ⏳ Utiliser connection string dans Fabric Data Connection
4. ⏳ Re-executer `create-eventstream-hybrid.ps1`
5. ⏳ Valider flux end-to-end

## 📝 Notes pour le Nouveau Tenant

### Checklist Deployment Event Hub

```powershell
# Variables
$rg = "rg-idoc-fabric-dev"
$location = "westeurope"
$ns = "eh-idoc-flt$(Get-Random -Maximum 9999)"
$eh = "idoc-events"

# 1. Resource Group
az group create --name $rg --location $location

# 2. Event Hub Namespace (auth par cle AUTORISEE)
az eventhubs namespace create `
  --name $ns `
  --resource-group $rg `
  --location $location `
  --sku Standard `
  --capacity 2 `
  --disable-local-auth false  # ← CRITIQUE!

# 3. Event Hub
az eventhubs eventhub create `
  --name $eh `
  --namespace-name $ns `
  --resource-group $rg `
  --partition-count 4

# 4. Consumer Group pour Fabric
az eventhubs eventhub consumer-group create `
  --name fabric-consumer `
  --eventhub-name $eh `
  --namespace-name $ns `
  --resource-group $rg

# 5. Authorization Rule pour Fabric (Listen)
az eventhubs eventhub authorization-rule create `
  --name fabric-listen `
  --eventhub-name $eh `
  --namespace-name $ns `
  --resource-group $rg `
  --rights Listen

# 6. Authorization Rule pour Simulateur (Send)
az eventhubs eventhub authorization-rule create `
  --name simulator-send `
  --eventhub-name $eh `
  --namespace-name $ns `
  --resource-group $rg `
  --rights Send

# 7. Recuperer connection strings
Write-Host "`nConnection String Fabric (Listen):" -ForegroundColor Cyan
az eventhubs eventhub authorization-rule keys list `
  --name fabric-listen `
  --eventhub-name $eh `
  --namespace-name $ns `
  --resource-group $rg `
  --query primaryConnectionString -o tsv

Write-Host "`nConnection String Simulateur (Send):" -ForegroundColor Cyan
az eventhubs eventhub authorization-rule keys list `
  --name simulator-send `
  --eventhub-name $eh `
  --namespace-name $ns `
  --resource-group $rg `
  --query primaryConnectionString -o tsv
```

### Configuration Simulateur

Mettre a jour `simulator/config/config.yaml`:

```yaml
event_hub:
  connection_string: "Endpoint=sb://<nouveau-namespace>.servicebus.windows.net/;SharedAccessKeyName=simulator-send;SharedAccessKey=..."
  eventhub_name: "idoc-events"
```

### Configuration Fabric Data Connection

Dans Fabric Portal:
1. Workspace Settings → Connections
2. New connection → Azure Event Hubs
3. **Connection String:** (celle de fabric-listen)
4. **Event Hub Name:** idoc-events
5. **Consumer Group:** fabric-consumer
6. Sauvegarder et copier le GUID

### Re-execution Script Automation

```powershell
cd fabric\eventstream

# Avec nouveau Data Connection ID
.\create-eventstream-hybrid.ps1 `
  -EventHubNamespace "<nouveau-namespace>.servicebus.windows.net" `
  -DataConnectionId "<nouveau-guid>"
```

## 🔍 Verification Azure Policy

Pour verifier si auth par cle est bloquee:

```powershell
# Verifier policy sur la souscription
az policy assignment list --query "[?contains(displayName, 'Event Hub')]"

# Verifier config namespace actuel
az eventhubs namespace show `
  --name eh-idoc-flt8076 `
  --resource-group rg-idoc-fabric-dev `
  --query disableLocalAuth

# Si retourne "true" → auth par cle bloquee
```

## 📞 Support Microsoft

**Si le probleme persiste:**

**Forum Fabric:**
- https://community.fabric.microsoft.com/

**Question specifique:**
"Fabric Eventstream ne supporte pas l'authentification Entra ID pour Azure Event Hub. Notre Azure Policy bloque l'auth par cle. Quand le support Entra ID sera-t-il disponible?"

**Workaround temporaire documente:**
- Solution 1: Tenant separe sans policy
- Solution 2: Data Pipeline (batch)

## 🚀 Prochaines Etapes

### Immediat
1. ⏳ **Attendre configuration nouveau tenant**
2. ⏳ Deployer Event Hub avec auth par cle autorisee
3. ⏳ Creer Data Connection Fabric
4. ⏳ Tester connexion

### Une fois resolu
1. Publier Eventstream
2. Valider flux end-to-end
3. Tester avec simulateur
4. Documenter solution finale

### Long terme
- Surveiller roadmap Fabric pour support Entra ID
- Migrer vers auth Entra ID quand disponible
- Contribuer feedback Microsoft sur cette limitation

---

**Status:** En attente nouveau tenant  
**Blocage:** Azure Policy + Limitation Fabric  
**Solution choisie:** Nouveau tenant avec auth par cle
