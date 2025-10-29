# Architecture de Gouvernance Purview - 3PL Logistics Analytics

**Date**: 28 octobre 2025  
**Statut**: Implémenté avec ajustements  
**API**: Purview Unified Catalog API (2025-09-15-preview)

---

## 📊 Architecture Actuelle (AS-IS)

### Hiérarchie Implémentée

```
Business Domain: "3PL Logistics"
├── ID: 1800fc8e-0360-4b9a-883a-ea23dcfa38dc
├── Type: LineOfBusiness
├── Status: Published
│
├── Data Product: "3PL Real-Time Analytics"
│   ├── ID: 818affc4-2deb-439d-939f-ea0a240e4c78
│   ├── Type: Analytical
│   ├── Domain: 1800fc8e-0360-4b9a-883a-ea23dcfa38dc
│   ├── Status: Draft (Endorsed: true)
│   │
│   └── Data Assets (9 tables liées)
│       ├── idoc_orders_silver
│       ├── idoc_shipments_silver
│       ├── idoc_warehouse_silver
│       ├── idoc_invoices_silver
│       ├── orders_daily_summary (Gold)
│       ├── sla_performance (Gold)
│       ├── shipments_in_transit (Gold)
│       ├── warehouse_productivity (Gold)
│       └── revenue_realtime (Gold)
│
├── Business Glossary (8 termes)
│   ├── Domain: 1800fc8e-0360-4b9a-883a-ea23dcfa38dc
│   ├── Order (720cc4a9-e76a-4ae5-9cca-33e9b348f1d4)
│   ├── Shipment (c4919c7a-4e11-4dcf-a92c-f5c0ec6a06e2)
│   ├── Warehouse Movement (22e918f3-e2cc-4962-a0dd-cac5548323e9)
│   ├── Invoice (21a592f7-bfd3-4734-8285-0eb9be211a70)
│   ├── Customer (0442f6bd-01ad-4738-8ed8-73cd55d0dcc1)
│   ├── Carrier (fbcc1793-cda4-45a1-ad46-3b1821508c9c)
│   ├── SLA Compliance (f592dfa5-4f26-4025-a12f-f73cc84d3f46)
│   └── Delivery Performance (be0d6d20-49d3-46af-b5ae-9dabf3244a2d)
│
└── OKRs (3 Objectives + 9 Key Results)
    ├── Domain: 1800fc8e-0360-4b9a-883a-ea23dcfa38dc
    │
    ├── Objective 1: Operational Excellence
    │   ├── ID: 43869a6e-3419-4765-bfc3-41d3ce1e2718
    │   ├── KR: SLA Compliance Rate ≥ 95% (92/95)
    │   ├── KR: On-Time Delivery ≥ 92% (89/92) [Behind]
    │   └── KR: Data Freshness < 5 min (4.2/5.0)
    │
    ├── Objective 2: Customer Satisfaction
    │   ├── ID: 9e37be22-9d3d-4329-9558-e14ea60c38e4
    │   ├── KR: Customer Satisfaction ≥ 4.5/5 (4.3/4.5)
    │   ├── KR: Data Quality ≥ 95% (94/95)
    │   └── KR: Invoice Accuracy ≥ 99% (98/99)
    │
    └── Objective 3: Platform Adoption
        ├── ID: 6ae25954-3182-48ba-9f4c-fa8ec4e8222c
        ├── KR: Active Users ≥ 50 (35/50) [Behind]
        ├── KR: Daily Queries ≥ 1000 (650/1000) [Behind]
        └── KR: B2B Partners ≥ 10 (6/10)
```

### Note sur l'Architecture AS-IS

**Limitation identifiée** : Dans l'architecture actuelle, le Business Glossary et les OKRs sont liés au **Domain** (`1800fc8e-0360...`), et non au **Data Product** (`818affc4-2deb...`).

**Impact** :
- ✅ **Fonctionnel** : L'architecture fonctionne correctement
- ⚠️ **Sémantique** : Le Domain "3PL Logistics" est trop spécifique - devrait être "Supply Chain"
- ⚠️ **Évolutivité** : Difficile d'ajouter d'autres Data Products (Manufacturing, Procurement) dans ce Domain

---

## 🎯 Architecture Cible (TO-BE)

### Hiérarchie Idéale

```
Business Domain: "Supply Chain"  ← Domaine métier global
├── ID: 041de34f-62cf-4c8a-9a17-d1cc823e9538 (NEW - créé)
├── Type: LineOfBusiness
├── Status: Published
│
├── Data Product 1: "3PL Logistics Analytics"
│   ├── ID: 818affc4-2deb-439d-939f-ea0a240e4c78
│   ├── Type: Analytical
│   ├── Domain: 041de34f... (Supply Chain) ← À migrer
│   ├── Status: Draft (Endorsed: true)
│   │
│   ├── Data Assets (9 tables)
│   │   └── [Silver + Gold tables]
│   │
│   ├── Business Glossary (8 termes) ← Liés au Data Product
│   │   ├── Domain: 041de34f... (ou Data Product)
│   │   └── [Order, Shipment, Invoice, etc.]
│   │
│   └── OKRs (3 Objectives + 9 KRs) ← Liés au Data Product
│       ├── Domain: 041de34f... (ou Data Product)
│       └── [Operational Excellence, Customer Satisfaction, Platform Adoption]
│
├── Data Product 2: "Manufacturing Analytics" (FUTUR)
│   ├── Type: Operational
│   ├── Domain: 041de34f... (Supply Chain)
│   └── [Assets, Glossary, OKRs propres]
│
└── Data Product 3: "Procurement Analytics" (FUTUR)
    ├── Type: Transactional
    ├── Domain: 041de34f... (Supply Chain)
    └── [Assets, Glossary, OKRs propres]
```

### Avantages de l'Architecture TO-BE

1. **Sémantique correcte** :
   - Domain = Domaine métier large (Supply Chain)
   - Data Product = Produit de données spécifique (3PL, Manufacturing, etc.)

2. **Évolutivité** :
   - Peut contenir plusieurs Data Products sous un même Domain
   - OKRs et Glossary isolés par Data Product
   - Gouvernance cohérente à travers tous les Data Products

3. **Alignement avec best practices Purview** :
   - Domain = Boundary de gouvernance
   - Data Product = Asset de données gouverné
   - OKRs = Mesures de succès du Data Product (pas du Domain)

---

## 🔧 État de la Migration

### ✅ Complété

1. **Business Domain "Supply Chain" créé**
   - ID: `041de34f-62cf-4c8a-9a17-d1cc823e9538`
   - Type: LineOfBusiness
   - Status: Published
   - Fichier: `supply_chain_domain_created.json`

### ⏸️ Bloqué - Limitations API

2. **Mise à jour Data Product → FAILED**
   - **Problème** : API PATCH non supportée (HTTP 405)
   - **Tentative** : Modifier `domain` field du Data Product
   - **Statut** : Le Data Product pointe toujours vers l'ancien Domain

3. **Migration OKRs → NON TENTÉE**
   - **Problème** : OKRs ont un field `domain`, pas `dataProduct`
   - **Question** : L'API permet-elle de lier OKRs à un Data Product ?
   - **Statut** : Les OKRs pointent toujours vers l'ancien Domain

4. **Migration Glossary Terms → NON TENTÉE**
   - **Problème** : Terms ont un field `domain`, pas `dataProduct`
   - **Question** : L'API permet-elle de lier Terms à un Data Product ?
   - **Statut** : Les Terms pointent toujours vers l'ancien Domain

---

## 🤔 Analyse et Recommandations

### Option 1 : Accepter l'Architecture AS-IS ✅ (RECOMMANDÉE)

**Rationale** :
- L'architecture fonctionne correctement
- OKRs et Glossary au niveau Domain est un pattern valide
- Moins de risque de casser l'implémentation existante

**Actions** :
1. ✅ Garder Domain "3PL Logistics" comme domaine principal
2. ✅ Documenter que c'est un "Domain mono-produit"
3. ✅ Si besoin d'évolution, créer un nouveau Domain pour Manufacturing/Procurement

**Avantages** :
- ✅ Pas de risque de régression
- ✅ Tout fonctionne déjà
- ✅ Conforme à l'API actuelle (Public Preview)

**Inconvénients** :
- ⚠️ Nom de Domain pas optimal ("3PL Logistics" au lieu de "Supply Chain")
- ⚠️ Moins évolutif (nécessite nouveau Domain pour chaque vertical)

---

### Option 2 : Tout Recréer (Architecture TO-BE) ⚠️

**Rationale** :
- Architecture sémantiquement correcte
- Évolutivité maximale
- Aligné avec best practices

**Actions** :
1. Supprimer tous les OKRs (via DELETE API)
2. Supprimer tous les Glossary Terms (via DELETE API)
3. Supprimer le Data Product (via DELETE API)
4. Supprimer l'ancien Domain "3PL Logistics"
5. Recréer Data Product avec `domain = Supply Chain`
6. Recréer OKRs (lier au nouveau Data Product si API le supporte)
7. Recréer Glossary Terms (lier au nouveau Data Product si API le supporte)

**Avantages** :
- ✅ Architecture parfaite
- ✅ Évolutivité maximale
- ✅ Aligné avec documentation Microsoft

**Inconvénients** :
- ❌ Risque de perdre des données
- ❌ Temps de développement élevé
- ❌ API peut ne pas supporter Data Product-level OKRs/Glossary
- ❌ Possible que l'API impose Domain-level uniquement

---

### Option 3 : Migration Partielle (Hybride) 🤷

**Rationale** :
- Garder ce qui fonctionne
- Migrer ce qui est faisable

**Actions** :
1. ✅ Créer nouveau Domain "Supply Chain" (FAIT)
2. ❌ Mettre à jour Data Product → Domain (API ne supporte pas)
3. ⏳ Tester si on peut créer de nouveaux OKRs au niveau Data Product
4. ⏳ Tester si on peut créer de nouveaux Terms au niveau Data Product
5. ✅ Documenter les limitations

**Avantages** :
- ✅ Progressif et sécurisé
- ✅ On découvre les capacités réelles de l'API

**Inconvénients** :
- ⚠️ Architecture mixte (pas clean)
- ⚠️ Peut nécessiter cleanup ultérieur

---

## 📚 Références API

### Endpoints Testés

| Endpoint | Method | Status | Notes |
|----------|--------|--------|-------|
| `/businessdomains` | POST | ✅ 201 | Création Domain fonctionne |
| `/dataProducts` | POST | ✅ 201 | Création Data Product fonctionne |
| `/dataProducts/{id}` | PATCH | ❌ 405 | Mise à jour non supportée |
| `/objectives` | POST | ✅ 201 | Création OKRs fonctionne (domain-level) |
| `/terms` | POST | ✅ 201 | Création Terms fonctionne (domain-level) |

### Questions Sans Réponse

1. **OKRs au niveau Data Product** :
   - L'API supporte-t-elle un field `dataProduct` au lieu de `domain` ?
   - Peut-on lier un Objective à un Data Product directement ?

2. **Glossary Terms au niveau Data Product** :
   - Les Terms peuvent-ils être liés à un Data Product au lieu d'un Domain ?
   - Y a-t-il un relationship type `TERM_TO_DATA_PRODUCT` ?

3. **Update Data Product** :
   - Pourquoi PATCH ne fonctionne pas ?
   - Faut-il utiliser PUT avec payload complet ?
   - L'API est-elle en read-only après création ?

---

## 🎯 Décision Finale

### Recommandation : **Option 1 - Accepter AS-IS**

**Pourquoi** :
1. L'architecture actuelle **fonctionne**
2. L'API est en **Public Preview** (limitations attendues)
3. Risque de **régression** trop élevé
4. La sémantique n'est pas parfaite mais **acceptable**

**Actions Immédiates** :
1. ✅ Documenter l'architecture AS-IS (ce document)
2. ✅ Garder le nouveau Domain "Supply Chain" pour usage futur
3. ✅ Continuer avec les prochaines étapes de gouvernance :
   - Lier Glossary Terms aux colonnes des tables
   - Configurer Data Quality rules
   - Implémenter B2B Access Policies

**Actions Futures** :
- Quand l'API sera plus mature (GA), réévaluer migration vers TO-BE
- Si besoin d'ajouter Manufacturing/Procurement, créer nouveaux Domains séparés
- Monitorer les release notes de Purview pour nouvelles capacités

---

## 📊 Fichiers Générés

```
governance/purview/
├── business_domain_created.json          # Ancien Domain "3PL Logistics"
├── supply_chain_domain_created.json      # Nouveau Domain "Supply Chain" (créé, non utilisé)
├── data_product_created.json             # Data Product pointant vers ancien Domain
├── data_product_updated.json             # (non créé - PATCH failed)
├── okrs_created.json                     # OKRs liés à ancien Domain
├── glossary_terms_created.json           # Terms liés à ancien Domain
├── create_supply_chain_domain.py         # Script de création nouveau Domain
└── update_data_product_domain.py         # Script de mise à jour (failed)
```

---

**Conclusion** : L'architecture actuelle est **fonctionnelle et acceptable**. Les limitations rencontrées sont dues à l'API en Public Preview. La recommandation est de **continuer avec l'architecture AS-IS** et de documenter l'approche TO-BE pour une migration future quand l'API sera plus mature.
