# Requêtes KQL pour analyser les IDocs dans Fabric

## Vue d'ensemble

Ce fichier contient des requêtes KQL (Kusto Query Language) pour analyser les messages IDoc dans Microsoft Fabric Real-Time Intelligence.

## Prérequis

- Eventstream configuré et opérationnel
- KQL Database créé : `kqldb-sap-idoc`
- Table : `idoc_raw`

---

## 1. Requêtes de base

### Aperçu des derniers messages

```kql
// Afficher les 10 derniers IDocs reçus
idoc_raw
| take 10
| order by timestamp desc
| project timestamp, idoc_type, message_type, sap_system, docnum=control.docnum
```

### Compter tous les messages

```kql
// Nombre total d'IDocs dans la base
idoc_raw
| count
```

### Plage temporelle des données

```kql
// Premier et dernier message reçu
idoc_raw
| summarize 
    Premier_Message = min(todatetime(timestamp)),
    Dernier_Message = max(todatetime(timestamp)),
    Total_Messages = count()
```

---

## 2. Analyse par type d'IDoc

### Distribution des types de messages

```kql
// Volume par type d'IDoc
idoc_raw
| summarize count() by message_type
| order by count_ desc
| render piechart 
```

### Top 5 types les plus fréquents

```kql
idoc_raw
| summarize Total = count() by message_type
| top 5 by Total desc
| render columnchart
```

### Répartition ORDERS vs INVOICE vs autres

```kql
idoc_raw
| summarize count() by 
    Type = case(
        message_type startswith "ORDERS", "Orders",
        message_type startswith "INVOIC", "Invoices",
        message_type startswith "WHSCON", "Warehouse Confirmations",
        message_type startswith "DESADV", "Delivery Advices",
        message_type startswith "SHPMNT", "Shipments",
        "Autres"
    )
| render piechart
```

---

## 3. Analyse temporelle

### Messages par heure (dernières 24h)

```kql
idoc_raw
| where timestamp > ago(24h)
| summarize count() by bin(timestamp, 1h)
| render timechart
```

### Débit de messages (messages/minute)

```kql
idoc_raw
| where timestamp > ago(1h)
| summarize Messages = count() by bin(timestamp, 1m)
| extend Debit_Par_Minute = Messages
| render timechart
```

### Heures de pointe

```kql
idoc_raw
| extend Heure = hourofday(todatetime(timestamp))
| summarize Total = count() by Heure
| order by Heure asc
| render columnchart
```

### Activité par jour de la semaine

```kql
idoc_raw
| extend Jour = dayofweek(todatetime(timestamp))
| summarize Total = count() by Jour
| extend Nom_Jour = case(
    Jour == 0d, "Dimanche",
    Jour == 1d, "Lundi",
    Jour == 2d, "Mardi",
    Jour == 3d, "Mercredi",
    Jour == 4d, "Jeudi",
    Jour == 5d, "Vendredi",
    Jour == 6d, "Samedi",
    "Inconnu"
)
| project Nom_Jour, Total
| order by Jour asc
```

---

## 4. Analyse des performances

### Latence d'ingestion

```kql
// Temps entre création du message et ingestion dans Fabric
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize 
    Latence_Moyenne = avg(latency_seconds),
    Latence_P50 = percentile(latency_seconds, 50),
    Latence_P95 = percentile(latency_seconds, 95),
    Latence_P99 = percentile(latency_seconds, 99),
    Latence_Max = max(latency_seconds)
```

### Latence par type de message

```kql
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))
| summarize Latence_Moyenne = avg(latency_seconds) by message_type
| order by Latence_Moyenne desc
| render barchart
```

### Taille des messages

```kql
// Statistiques sur la taille des messages (approximative)
idoc_raw
| extend message_size = estimate_data_size(data)
| summarize 
    Taille_Moyenne_KB = avg(message_size) / 1024,
    Taille_Min_KB = min(message_size) / 1024,
    Taille_Max_KB = max(message_size) / 1024,
    Taille_Total_MB = sum(message_size) / 1024 / 1024
    by message_type
| order by Taille_Moyenne_KB desc
```

---

## 5. Analyse métier (contenu des IDocs)

### Ordres de commande (ORDERS)

```kql
// Analyse des commandes
idoc_raw
| where message_type == "ORDERS05"
| extend 
    NumCommande = control.docnum,
    DateCommande = control.credat,
    Client = data.E1EDK01[0].BELNR,  // Numéro de document client
    Montant = data.E1EDK01[0].WKURS  // Taux de change (adapter selon schema)
| project timestamp, NumCommande, DateCommande, Client, sap_system
| take 100
```

### Confirmations d'entrepôt (WHSCON)

```kql
// Analyse des mouvements d'entrepôt
idoc_raw
| where message_type == "WHSCON01"
| extend 
    NumDoc = control.docnum,
    Entrepot = tostring(data.E1WHC00[0].LGNUM),
    Operation = tostring(data.E1WHC01[0].VLTYP),
    Materiel = tostring(data.E1WHC10[0].MATNR),
    Quantite = todouble(data.E1WHC10[0].LQNUM)
| summarize Operations = count() by Entrepot, Operation
| render columnchart
```

### Factures (INVOIC)

```kql
// Top 10 factures par montant
idoc_raw
| where message_type == "INVOIC02"
| extend 
    NumFacture = control.docnum,
    DateFacture = control.credat,
    Montant = todouble(data.E1EDK01[0].BELNR) // Adapter selon le champ réel
| top 10 by Montant desc
| project timestamp, NumFacture, DateFacture, Montant
```

### Livraisons (DESADV)

```kql
// Analyse des livraisons par statut
idoc_raw
| where message_type == "DESADV01"
| extend 
    NumLivraison = control.docnum,
    Statut = control.status,
    DateLivraison = control.credat
| summarize Total = count() by Statut
| render piechart
```

---

## 6. Détection d'anomalies et alertes

### Messages avec erreurs

```kql
// IDocs avec statut d'erreur (status != "03")
idoc_raw
| extend Statut = tostring(control.status)
| where Statut != "03"
| project 
    timestamp, 
    message_type, 
    NumDoc = control.docnum,
    Statut,
    sap_system
| order by timestamp desc
```

### Volume anormal de messages

```kql
// Détection de pic de messages (> 2x la moyenne)
let avgRate = toscalar(
    idoc_raw
    | where timestamp > ago(7d)
    | summarize count() by bin(timestamp, 1h)
    | summarize avg(count_)
);
idoc_raw
| where timestamp > ago(24h)
| summarize Messages = count() by bin(timestamp, 1h)
| where Messages > avgRate * 2
| project timestamp, Messages, Moyenne = avgRate, Ratio = Messages / avgRate
| order by timestamp desc
```

### Messages manquants (gaps temporels)

```kql
// Identifier les périodes sans messages
idoc_raw
| where timestamp > ago(24h)
| make-series Messages = count() default = 0 on timestamp step 5m
| mv-expand timestamp, Messages
| where Messages == 0
| project timestamp
```

### Délais de traitement suspects

```kql
// Messages avec latence > 5 minutes
idoc_raw
| where timestamp > ago(1h)
| extend ingestion_time = ingestion_time()
| extend latency_minutes = datetime_diff('minute', ingestion_time, todatetime(timestamp))
| where latency_minutes > 5
| project timestamp, message_type, latency_minutes, docnum=control.docnum
| order by latency_minutes desc
```

---

## 7. Rapports d'activité

### Résumé quotidien

```kql
// Rapport journalier complet
idoc_raw
| where timestamp > ago(24h)
| summarize 
    Total_Messages = count(),
    Types_Distincts = dcount(message_type),
    Systemes_SAP = dcount(sap_system),
    Premier_Message = min(todatetime(timestamp)),
    Dernier_Message = max(todatetime(timestamp))
| extend Duree_Heures = datetime_diff('hour', Dernier_Message, Premier_Message)
| extend Debit_Par_Heure = Total_Messages / Duree_Heures
```

### Tableau de bord exécutif

```kql
// Métriques clés pour tableau de bord
idoc_raw
| where timestamp > ago(1h)
| summarize 
    ['Messages (dernière heure)'] = count(),
    ['Messages/minute'] = count() / 60,
    ['Types d\'IDoc'] = dcount(message_type),
    ['Systèmes sources'] = dcount(sap_system)
```

### Comparaison période vs période

```kql
// Comparer cette heure vs heure précédente
let currentHour = idoc_raw | where timestamp > ago(1h) | count | project Current = Count;
let previousHour = idoc_raw | where timestamp between (ago(2h) .. ago(1h)) | count | project Previous = Count;
currentHour
| extend Previous = toscalar(previousHour)
| extend Evolution = round((todouble(Current - Previous) / Previous) * 100, 2)
| project 
    Heure_Actuelle = Current,
    Heure_Precedente = Previous,
    Evolution_Pourcent = Evolution
```

---

## 8. Requêtes d'optimisation

### Table size et croissance

```kql
// Taille de la table et projection de croissance
.show table idoc_raw extents
| summarize 
    Total_Extents = count(),
    Total_Rows = sum(RowCount),
    Total_Size_MB = sum(OriginalSize) / 1024 / 1024,
    Compressed_Size_MB = sum(ExtentSize) / 1024 / 1024
| extend Compression_Ratio = round(Total_Size_MB / Compressed_Size_MB, 2)
```

### Cardinality des colonnes

```kql
// Analyser la diversité des valeurs
idoc_raw
| summarize 
    Types_Uniques = dcount(message_type),
    Systemes_Uniques = dcount(sap_system),
    IDocs_Uniques = dcount(idoc_type)
```

---

## 9. Export et partage

### Export vers CSV (via Fabric)

```kql
// Préparer les données pour export
idoc_raw
| where timestamp > ago(7d)
| project 
    Date = format_datetime(todatetime(timestamp), 'yyyy-MM-dd HH:mm:ss'),
    Type = message_type,
    Systeme = sap_system,
    Document = control.docnum,
    Statut = control.status
| take 10000  // Limiter pour export
```

### Agrégation pour Power BI

```kql
// Vue agrégée pour dashboard Power BI
idoc_raw
| where timestamp > ago(30d)
| summarize 
    Total = count(),
    Taille_Moyenne = avg(estimate_data_size(data))
    by 
    Date = bin(todatetime(timestamp), 1d),
    Type = message_type,
    Systeme = sap_system
```

---

## 10. Maintenance et monitoring

### Vérifier la fraîcheur des données

```kql
// Dernière ingestion
idoc_raw
| summarize Dernier_Message = max(todatetime(timestamp))
| extend Minutes_Depuis = datetime_diff('minute', now(), Dernier_Message)
| project Dernier_Message, Minutes_Depuis
```

### Health check complet

```kql
// Vérification santé de l'ingestion
let derniere_heure = idoc_raw | where timestamp > ago(1h);
derniere_heure
| summarize 
    Messages_Recus = count(),
    Latence_Moyenne_Sec = avg(datetime_diff('second', ingestion_time(), todatetime(timestamp))),
    Types_Differents = dcount(message_type),
    Systemes_Actifs = dcount(sap_system),
    Dernier_Message = max(todatetime(timestamp))
| extend 
    Status = case(
        Messages_Recus > 0 and Latence_Moyenne_Sec < 60, "✅ HEALTHY",
        Messages_Recus > 0 and Latence_Moyenne_Sec < 300, "⚠️ DEGRADED",
        Messages_Recus == 0, "❌ NO DATA",
        "⚠️ WARNING"
    )
```

---

## Utilisation dans Fabric

1. **KQL Queryset** : Créez un queryset et collez ces requêtes
2. **Dashboards** : Utilisez les requêtes avec `render` pour créer des visualisations
3. **Power BI** : Connectez Power BI à la KQL Database pour des rapports interactifs
4. **Alertes** : Configurez Data Activator / Reflex avec les requêtes d'anomalies

## Ressources

- [Documentation KQL](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [Fabric Real-Time Intelligence](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/)
