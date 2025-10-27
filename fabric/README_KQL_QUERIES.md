# KQL Queries for IDoc Analysis in Fabric# Requêtes KQL pour analyser les IDocs dans Fabric



## Overview## Vue d'ensemble



This file contains KQL (Kusto Query Language) queries to analyze SAP IDoc messages in Microsoft Fabric Real-Time Intelligence.Ce fichier contient des requêtes KQL (Kusto Query Language) pour analyser les messages IDoc dans Microsoft Fabric Real-Time Intelligence.



## Prerequisites## Prérequis



- Eventstream configured and operational- Eventstream configuré et opérationnel

- KQL Database created: `kqldbsapidoc`- KQL Database créé : `kqldb-sap-idoc`

- Table: `idoc_raw`- Table : `idoc_raw`



------



## 1. Basic Queries## 1. Requêtes de base



### Latest Messages Overview### Aperçu des derniers messages



```kql```kql

// Display the 10 most recent IDocs received// Afficher les 10 derniers IDocs reçus

idoc_rawidoc_raw

| take 10| take 10

| order by timestamp desc| order by timestamp desc

| project timestamp, idoc_type, message_type, sap_system, docnum=control.docnum| project timestamp, idoc_type, message_type, sap_system, docnum=control.docnum

``````



### Count All Messages### Compter tous les messages



```kql```kql

// Total number of IDocs in the database// Nombre total d'IDocs dans la base

idoc_rawidoc_raw

| count| count

``````



### Data Time Range### Plage temporelle des données



```kql```kql

// First and last message received// Premier et dernier message reçu

idoc_rawidoc_raw

| summarize | summarize 

    First_Message = min(todatetime(timestamp)),    Premier_Message = min(todatetime(timestamp)),

    Last_Message = max(todatetime(timestamp)),    Dernier_Message = max(todatetime(timestamp)),

    Total_Messages = count()    Total_Messages = count()

``````



------



## 2. Analysis by IDoc Type## 2. Analyse par type d'IDoc



### Message Type Distribution### Distribution des types de messages



```kql```kql

// Volume by IDoc type// Volume par type d'IDoc

idoc_rawidoc_raw

| summarize count() by message_type| summarize count() by message_type

| order by count_ desc| order by count_ desc

| render piechart | render piechart 

``````



### Top 5 Most Frequent Types### Top 5 types les plus fréquents



```kql```kql

idoc_rawidoc_raw

| summarize Total = count() by message_type| summarize Total = count() by message_type

| top 5 by Total desc| top 5 by Total desc

| render columnchart| render columnchart

``````



### ORDERS vs INVOICE vs Others Distribution### Répartition ORDERS vs INVOICE vs autres



```kql```kql

idoc_rawidoc_raw

| summarize count() by | summarize count() by 

    Type = case(    Type = case(

        message_type startswith "ORDERS", "Orders",        message_type startswith "ORDERS", "Orders",

        message_type startswith "INVOIC", "Invoices",        message_type startswith "INVOIC", "Invoices",

        message_type startswith "WHSCON", "Warehouse Confirmations",        message_type startswith "WHSCON", "Warehouse Confirmations",

        message_type startswith "DESADV", "Delivery Advices",        message_type startswith "DESADV", "Delivery Advices",

        message_type startswith "SHPMNT", "Shipments",        message_type startswith "SHPMNT", "Shipments",

        "Others"        "Autres"

    )    )

| render piechart| render piechart

``````



------



## 3. Temporal Analysis## 3. Analyse temporelle



### Messages per Hour (Last 24h)### Messages par heure (dernières 24h)



```kql```kql

idoc_rawidoc_raw

| where timestamp > ago(24h)| where timestamp > ago(24h)

| summarize count() by bin(timestamp, 1h)| summarize count() by bin(timestamp, 1h)

| render timechart| render timechart

``````



### Message Rate (messages/minute)### Débit de messages (messages/minute)



```kql```kql

idoc_rawidoc_raw

| where timestamp > ago(1h)| where timestamp > ago(1h)

| summarize Messages = count() by bin(timestamp, 1m)| summarize Messages = count() by bin(timestamp, 1m)

| extend Messages_Per_Minute = Messages| extend Debit_Par_Minute = Messages

| render timechart| render timechart

``````



### Peak Hours### Heures de pointe



```kql```kql

idoc_rawidoc_raw

| extend Hour = hourofday(todatetime(timestamp))| extend Heure = hourofday(todatetime(timestamp))

| summarize Total = count() by Hour| summarize Total = count() by Heure

| order by Hour asc| order by Heure asc

| render columnchart| render columnchart

``````



### Activity by Day of Week### Activité par jour de la semaine



```kql```kql

idoc_rawidoc_raw

| extend DayNum = dayofweek(todatetime(timestamp))| extend Jour = dayofweek(todatetime(timestamp))

| summarize Total = count() by DayNum| summarize Total = count() by Jour

| extend Day_Name = case(| extend Nom_Jour = case(

    DayNum == 0d, "Sunday",    Jour == 0d, "Dimanche",

    DayNum == 1d, "Monday",    Jour == 1d, "Lundi",

    DayNum == 2d, "Tuesday",    Jour == 2d, "Mardi",

    DayNum == 3d, "Wednesday",    Jour == 3d, "Mercredi",

    DayNum == 4d, "Thursday",    Jour == 4d, "Jeudi",

    DayNum == 5d, "Friday",    Jour == 5d, "Vendredi",

    DayNum == 6d, "Saturday",    Jour == 6d, "Samedi",

    "Unknown"    "Inconnu"

))

| project Day_Name, Total| project Nom_Jour, Total

| order by DayNum asc| order by Jour asc

``````



------



## 4. Performance Analysis## 4. Analyse des performances



### Ingestion Latency### Latence d'ingestion



```kql```kql

// Time between message creation and ingestion in Fabric// Temps entre création du message et ingestion dans Fabric

idoc_rawidoc_raw

| where timestamp > ago(1h)| where timestamp > ago(1h)

| extend ingestion_time = ingestion_time()| extend ingestion_time = ingestion_time()

| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))

| summarize | summarize 

    Average_Latency = avg(latency_seconds),    Latence_Moyenne = avg(latency_seconds),

    P50_Latency = percentile(latency_seconds, 50),    Latence_P50 = percentile(latency_seconds, 50),

    P95_Latency = percentile(latency_seconds, 95),    Latence_P95 = percentile(latency_seconds, 95),

    P99_Latency = percentile(latency_seconds, 99),    Latence_P99 = percentile(latency_seconds, 99),

    Max_Latency = max(latency_seconds)    Latence_Max = max(latency_seconds)

``````



### Latency by Message Type### Latence par type de message



```kql```kql

idoc_rawidoc_raw

| where timestamp > ago(1h)| where timestamp > ago(1h)

| extend ingestion_time = ingestion_time()| extend ingestion_time = ingestion_time()

| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))| extend latency_seconds = datetime_diff('second', ingestion_time, todatetime(timestamp))

| summarize Average_Latency = avg(latency_seconds) by message_type| summarize Latence_Moyenne = avg(latency_seconds) by message_type

| order by Average_Latency desc| order by Latence_Moyenne desc

| render barchart| render barchart

``````



### Message Size Statistics### Taille des messages



```kql```kql

// Message size statistics (approximate)// Statistiques sur la taille des messages (approximative)

idoc_rawidoc_raw

| extend message_size = estimate_data_size(data)| extend message_size = estimate_data_size(data)

| summarize | summarize 

    Avg_Size_KB = avg(message_size) / 1024,    Taille_Moyenne_KB = avg(message_size) / 1024,

    Min_Size_KB = min(message_size) / 1024,    Taille_Min_KB = min(message_size) / 1024,

    Max_Size_KB = max(message_size) / 1024,    Taille_Max_KB = max(message_size) / 1024,

    Total_Size_MB = sum(message_size) / 1024 / 1024    Taille_Total_MB = sum(message_size) / 1024 / 1024

    by message_type    by message_type

| order by Avg_Size_KB desc| order by Taille_Moyenne_KB desc

``````



------



## 5. Business Analysis (IDoc Content)## 5. Analyse métier (contenu des IDocs)



### Purchase Orders (ORDERS)### Ordres de commande (ORDERS)



```kql```kql

// Order analysis// Analyse des commandes

idoc_rawidoc_raw

| where message_type == "ORDERS"| where message_type == "ORDERS05"

| extend | extend 

    Order_Number = control.docnum,    NumCommande = control.docnum,

    Order_Date = control.credat,    DateCommande = control.credat,

    Customer = tostring(data.customer_id),    Client = data.E1EDK01[0].BELNR,  // Numéro de document client

    Material = tostring(data.material_id)    Montant = data.E1EDK01[0].WKURS  // Taux de change (adapter selon schema)

| project timestamp, Order_Number, Order_Date, Customer, Material, sap_system| project timestamp, NumCommande, DateCommande, Client, sap_system

| take 100| take 100

``````



### Warehouse Confirmations (WHSCON)### Confirmations d'entrepôt (WHSCON)



```kql```kql

// Warehouse movement analysis// Analyse des mouvements d'entrepôt

idoc_rawidoc_raw

| where message_type == "WHSCON"| where message_type == "WHSCON01"

| extend | extend 

    Doc_Number = control.docnum,    NumDoc = control.docnum,

    Warehouse = tostring(data.warehouse_id),    Entrepot = tostring(data.E1WHC00[0].LGNUM),

    Movement_Type = tostring(data.movement_type),    Operation = tostring(data.E1WHC01[0].VLTYP),

    Material = tostring(data.material_id),    Materiel = tostring(data.E1WHC10[0].MATNR),

    Quantity = todouble(data.quantity)    Quantite = todouble(data.E1WHC10[0].LQNUM)

| summarize Operations = count() by Warehouse, Movement_Type| summarize Operations = count() by Entrepot, Operation

| render columnchart| render columnchart

``````



### Invoices (INVOIC)### Factures (INVOIC)



```kql```kql

// Top 10 invoices by amount// Top 10 factures par montant

idoc_rawidoc_raw

| where message_type == "INVOIC"| where message_type == "INVOIC02"

| extend | extend 

    Invoice_Number = control.docnum,    NumFacture = control.docnum,

    Invoice_Date = control.credat,    DateFacture = control.credat,

    Amount = todouble(data.total_amount)    Montant = todouble(data.E1EDK01[0].BELNR) // Adapter selon le champ réel

| top 10 by Amount desc| top 10 by Montant desc

| project timestamp, Invoice_Number, Invoice_Date, Amount| project timestamp, NumFacture, DateFacture, Montant

``````



### Deliveries (DESADV)### Livraisons (DESADV)



```kql```kql

// Delivery analysis by status// Analyse des livraisons par statut

idoc_rawidoc_raw

| where message_type == "DESADV"| where message_type == "DESADV01"

| extend | extend 

    Delivery_Number = control.docnum,    NumLivraison = control.docnum,

    Status = control.status,    Statut = control.status,

    Delivery_Date = control.credat    DateLivraison = control.credat

| summarize Total = count() by Status| summarize Total = count() by Statut

| render piechart| render piechart

``````



------



## 6. Anomaly Detection and Alerts## 6. Détection d'anomalies et alertes



### Messages with Errors### Messages avec erreurs



```kql```kql

// IDocs with error status (status != "03")// IDocs avec statut d'erreur (status != "03")

idoc_rawidoc_raw

| extend Status = tostring(control.status)| extend Statut = tostring(control.status)

| where Status != "03"| where Statut != "03"

| project | project 

    timestamp,     timestamp, 

    message_type,     message_type, 

    Doc_Number = control.docnum,    NumDoc = control.docnum,

    Status,    Statut,

    sap_system    sap_system

| order by timestamp desc| order by timestamp desc

``````



### Abnormal Message Volume### Volume anormal de messages



```kql```kql

// Detect message spikes (> 2x average)// Détection de pic de messages (> 2x la moyenne)

let avgRate = toscalar(let avgRate = toscalar(

    idoc_raw    idoc_raw

    | where timestamp > ago(7d)    | where timestamp > ago(7d)

    | summarize count() by bin(timestamp, 1h)    | summarize count() by bin(timestamp, 1h)

    | summarize avg(count_)    | summarize avg(count_)

););

idoc_rawidoc_raw

| where timestamp > ago(24h)| where timestamp > ago(24h)

| summarize Messages = count() by bin(timestamp, 1h)| summarize Messages = count() by bin(timestamp, 1h)

| where Messages > avgRate * 2| where Messages > avgRate * 2

| project timestamp, Messages, Average = avgRate, Ratio = Messages / avgRate| project timestamp, Messages, Moyenne = avgRate, Ratio = Messages / avgRate

| order by timestamp desc| order by timestamp desc

``````



### Missing Messages (Time Gaps)### Messages manquants (gaps temporels)



```kql```kql

// Identify periods without messages// Identifier les périodes sans messages

idoc_rawidoc_raw

| where timestamp > ago(24h)| where timestamp > ago(24h)

| make-series Messages = count() default = 0 on timestamp step 5m| make-series Messages = count() default = 0 on timestamp step 5m

| mv-expand timestamp, Messages| mv-expand timestamp, Messages

| where Messages == 0| where Messages == 0

| project timestamp| project timestamp

``````



### Suspicious Processing Delays### Délais de traitement suspects



```kql```kql

// Messages with latency > 5 minutes// Messages avec latence > 5 minutes

idoc_rawidoc_raw

| where timestamp > ago(1h)| where timestamp > ago(1h)

| extend ingestion_time = ingestion_time()| extend ingestion_time = ingestion_time()

| extend latency_minutes = datetime_diff('minute', ingestion_time, todatetime(timestamp))| extend latency_minutes = datetime_diff('minute', ingestion_time, todatetime(timestamp))

| where latency_minutes > 5| where latency_minutes > 5

| project timestamp, message_type, latency_minutes, docnum=control.docnum| project timestamp, message_type, latency_minutes, docnum=control.docnum

| order by latency_minutes desc| order by latency_minutes desc

``````



------



## 7. Activity Reports## 7. Rapports d'activité



### Daily Summary### Résumé quotidien



```kql```kql

// Complete daily report// Rapport journalier complet

idoc_rawidoc_raw

| where timestamp > ago(24h)| where timestamp > ago(24h)

| summarize | summarize 

    Total_Messages = count(),    Total_Messages = count(),

    Distinct_Types = dcount(message_type),    Types_Distincts = dcount(message_type),

    SAP_Systems = dcount(sap_system),    Systemes_SAP = dcount(sap_system),

    First_Message = min(todatetime(timestamp)),    Premier_Message = min(todatetime(timestamp)),

    Last_Message = max(todatetime(timestamp))    Dernier_Message = max(todatetime(timestamp))

| extend Duration_Hours = datetime_diff('hour', Last_Message, First_Message)| extend Duree_Heures = datetime_diff('hour', Dernier_Message, Premier_Message)

| extend Rate_Per_Hour = Total_Messages / Duration_Hours| extend Debit_Par_Heure = Total_Messages / Duree_Heures

``````



### Executive Dashboard### Tableau de bord exécutif



```kql```kql

// Key metrics for dashboard// Métriques clés pour tableau de bord

idoc_rawidoc_raw

| where timestamp > ago(1h)| where timestamp > ago(1h)

| summarize | summarize 

    ['Messages (last hour)'] = count(),    ['Messages (dernière heure)'] = count(),

    ['Messages/minute'] = count() / 60,    ['Messages/minute'] = count() / 60,

    ['IDoc Types'] = dcount(message_type),    ['Types d\'IDoc'] = dcount(message_type),

    ['Source Systems'] = dcount(sap_system)    ['Systèmes sources'] = dcount(sap_system)

``````



### Period-over-Period Comparison### Comparaison période vs période



```kql```kql

// Compare current hour vs previous hour// Comparer cette heure vs heure précédente

let currentHour = idoc_raw | where timestamp > ago(1h) | count | project Current = Count;let currentHour = idoc_raw | where timestamp > ago(1h) | count | project Current = Count;

let previousHour = idoc_raw | where timestamp between (ago(2h) .. ago(1h)) | count | project Previous = Count;let previousHour = idoc_raw | where timestamp between (ago(2h) .. ago(1h)) | count | project Previous = Count;

currentHourcurrentHour

| extend Previous = toscalar(previousHour)| extend Previous = toscalar(previousHour)

| extend Change = round((todouble(Current - Previous) / Previous) * 100, 2)| extend Evolution = round((todouble(Current - Previous) / Previous) * 100, 2)

| project | project 

    Current_Hour = Current,    Heure_Actuelle = Current,

    Previous_Hour = Previous,    Heure_Precedente = Previous,

    Change_Percent = Change    Evolution_Pourcent = Evolution

``````



------



## 8. Optimization Queries## 8. Requêtes d'optimisation



### Table Size and Growth### Table size et croissance



```kql```kql

// Table size and growth projection// Taille de la table et projection de croissance

.show table idoc_raw extents.show table idoc_raw extents

| summarize | summarize 

    Total_Extents = count(),    Total_Extents = count(),

    Total_Rows = sum(RowCount),    Total_Rows = sum(RowCount),

    Total_Size_MB = sum(OriginalSize) / 1024 / 1024,    Total_Size_MB = sum(OriginalSize) / 1024 / 1024,

    Compressed_Size_MB = sum(ExtentSize) / 1024 / 1024    Compressed_Size_MB = sum(ExtentSize) / 1024 / 1024

| extend Compression_Ratio = round(Total_Size_MB / Compressed_Size_MB, 2)| extend Compression_Ratio = round(Total_Size_MB / Compressed_Size_MB, 2)

``````



### Column Cardinality### Cardinality des colonnes



```kql```kql

// Analyze value diversity// Analyser la diversité des valeurs

idoc_rawidoc_raw

| summarize | summarize 

    Unique_Types = dcount(message_type),    Types_Uniques = dcount(message_type),

    Unique_Systems = dcount(sap_system),    Systemes_Uniques = dcount(sap_system),

    Unique_IDocs = dcount(idoc_type)    IDocs_Uniques = dcount(idoc_type)

``````



------



## 9. Export and Sharing## 9. Export et partage



### Export to CSV (via Fabric)### Export vers CSV (via Fabric)



```kql```kql

// Prepare data for export// Préparer les données pour export

idoc_rawidoc_raw

| where timestamp > ago(7d)| where timestamp > ago(7d)

| project | project 

    Date = format_datetime(todatetime(timestamp), 'yyyy-MM-dd HH:mm:ss'),    Date = format_datetime(todatetime(timestamp), 'yyyy-MM-dd HH:mm:ss'),

    Type = message_type,    Type = message_type,

    System = sap_system,    Systeme = sap_system,

    Document = control.docnum,    Document = control.docnum,

    Status = control.status    Statut = control.status

| take 10000  // Limit for export| take 10000  // Limiter pour export

``````



### Aggregation for Power BI### Agrégation pour Power BI



```kql```kql

// Aggregated view for Power BI dashboard// Vue agrégée pour dashboard Power BI

idoc_rawidoc_raw

| where timestamp > ago(30d)| where timestamp > ago(30d)

| summarize | summarize 

    Total = count(),    Total = count(),

    Avg_Size = avg(estimate_data_size(data))    Taille_Moyenne = avg(estimate_data_size(data))

    by     by 

    Date = bin(todatetime(timestamp), 1d),    Date = bin(todatetime(timestamp), 1d),

    Type = message_type,    Type = message_type,

    System = sap_system    Systeme = sap_system

``````



------



## 10. Maintenance and Monitoring## 10. Maintenance et monitoring



### Check Data Freshness### Vérifier la fraîcheur des données



```kql```kql

// Last ingestion// Dernière ingestion

idoc_rawidoc_raw

| summarize Last_Message = max(todatetime(timestamp))| summarize Dernier_Message = max(todatetime(timestamp))

| extend Minutes_Since = datetime_diff('minute', now(), Last_Message)| extend Minutes_Depuis = datetime_diff('minute', now(), Dernier_Message)

| project Last_Message, Minutes_Since| project Dernier_Message, Minutes_Depuis

``````



### Complete Health Check### Health check complet



```kql```kql

// Ingestion health check// Vérification santé de l'ingestion

let last_hour = idoc_raw | where timestamp > ago(1h);let derniere_heure = idoc_raw | where timestamp > ago(1h);

last_hourderniere_heure

| summarize | summarize 

    Messages_Received = count(),    Messages_Recus = count(),

    Avg_Latency_Sec = avg(datetime_diff('second', ingestion_time(), todatetime(timestamp))),    Latence_Moyenne_Sec = avg(datetime_diff('second', ingestion_time(), todatetime(timestamp))),

    Different_Types = dcount(message_type),    Types_Differents = dcount(message_type),

    Active_Systems = dcount(sap_system),    Systemes_Actifs = dcount(sap_system),

    Last_Message = max(todatetime(timestamp))    Dernier_Message = max(todatetime(timestamp))

| extend | extend 

    Status = case(    Status = case(

        Messages_Received > 0 and Avg_Latency_Sec < 60, "✅ HEALTHY",        Messages_Recus > 0 and Latence_Moyenne_Sec < 60, "✅ HEALTHY",

        Messages_Received > 0 and Avg_Latency_Sec < 300, "⚠️ DEGRADED",        Messages_Recus > 0 and Latence_Moyenne_Sec < 300, "⚠️ DEGRADED",

        Messages_Received == 0, "❌ NO DATA",        Messages_Recus == 0, "❌ NO DATA",

        "⚠️ WARNING"        "⚠️ WARNING"

    )    )

``````



------



## Usage in Fabric## Utilisation dans Fabric



1. **KQL Queryset**: Create a queryset and paste these queries1. **KQL Queryset** : Créez un queryset et collez ces requêtes

2. **Dashboards**: Use queries with `render` to create visualizations2. **Dashboards** : Utilisez les requêtes avec `render` pour créer des visualisations

3. **Power BI**: Connect Power BI to KQL Database for interactive reports3. **Power BI** : Connectez Power BI à la KQL Database pour des rapports interactifs

4. **Alerts**: Configure Data Activator / Reflex with anomaly queries4. **Alertes** : Configurez Data Activator / Reflex avec les requêtes d'anomalies



## Resources## Ressources



- [KQL Documentation](https://learn.microsoft.com/azure/data-explorer/kusto/query/)- [Documentation KQL](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)

- [Fabric Real-Time Intelligence](https://learn.microsoft.com/fabric/real-time-intelligence/)- [Fabric Real-Time Intelligence](https://learn.microsoft.com/en-us/fabric/real-time-intelligence/)

- [KQL Query Best Practices](https://learn.microsoft.com/azure/data-explorer/kusto/query/best-practices)

---

**50+ queries ready to use for IDoc analysis in Microsoft Fabric!**
