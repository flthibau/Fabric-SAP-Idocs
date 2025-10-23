# Event Hub Reader CLI - Guide d'utilisation

## Installation

Le CLI utilise les mêmes dépendances que le simulateur :
```bash
cd simulator
pip install -r requirements.txt aiohttp
```

## Configuration

Le CLI lit automatiquement les variables d'environnement depuis `.env` :
- `EVENT_HUB_NAMESPACE` : Le namespace Event Hub (sans .servicebus.windows.net)
- `EVENT_HUB_NAME` : Le nom de l'Event Hub

## Commandes

### Lire les 10 derniers messages
```bash
python read_eventhub.py --max 10
```

### Lire les 5 derniers messages avec détails complets (JSON)
```bash
python read_eventhub.py --max 5 --details
```

### Lire 1 message avec détails
```bash
python read_eventhub.py --max 1 --details
```

### Mode continu (appuyez Ctrl+C pour arrêter)
```bash
python read_eventhub.py
```

### Lire depuis les derniers messages (mode temps réel)
```bash
python read_eventhub.py --from-latest
```

## Options

- `--max N` : Nombre maximum de messages à lire
- `--details` : Afficher le JSON complet de chaque message
- `--from-latest` : Commencer depuis les derniers messages (temps réel)
- `--namespace NAME` : Spécifier le namespace (remplace .env)
- `--eventhub NAME` : Spécifier l'Event Hub (remplace .env)
- `--consumer-group NAME` : Groupe de consommateurs (défaut: $Default)

## Exemples d'affichage

### Mode normal (résumé)
```
📨 Message #1 | Partition: 0
================================================================================
IDoc Type:     WHSCON01
Message Type:  WHSCON
SAP System:    S4HPRD
Timestamp:     2025-10-23T14:14:47.129482

Warehouse Confirmation:
  Confirmation: WHC202510231414477779

📊 Size: 1,981 bytes (1.93 KB)
```

### Mode détaillé (--details)
Affiche le JSON complet du message IDoc.

## Permissions requises

Vous devez avoir le rôle **Azure Event Hubs Data Receiver** sur l'Event Hub :
```bash
az role assignment create \
  --assignee <your-object-id> \
  --role "Azure Event Hubs Data Receiver" \
  --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.EventHub/namespaces/<ns>/eventhubs/<eh>"
```

## Troubleshooting

### "No messages found"
- Vérifiez que le simulateur a bien envoyé des messages
- Essayez avec `--from-latest` pour capturer de nouveaux messages

### "Permission denied"
- Vérifiez que vous avez le rôle Data Receiver
- Exécutez `az login` pour rafraîchir votre authentification

### Le script ne s'arrête pas
- Appuyez sur Ctrl+C
- Utilisez toujours `--max N` pour une lecture limitée
