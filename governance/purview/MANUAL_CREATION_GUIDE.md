## Guide - Créer Glossary Terms et OKRs au niveau Data Product (Purview Portal)

**Problème identifié :** L'API Purview 2025-09-15-preview ne supporte pas la création de Glossary Terms et OKRs au niveau Data Product. Le champ `dataProduct` est ignoré et les entités sont créées au niveau Domain.

**Solution :** Création manuelle via Purview Portal

---

## 📋 ÉTAPE 1 : Supprimer les Terms/OKRs créés au niveau Domain

Vous devez d'abord supprimer les 8 Glossary Terms et 3 Objectives créés au niveau Domain via le Portal :

1. Ouvrir Purview Portal : https://web.purview.azure.com/resource/stpurview
2. Aller à **Unified Catalog → Domains → Supply Chain**
3. **Glossary Terms** : Unpublish puis Delete les 8 termes
4. **Objectives** : Delete les 3 Objectives (les Key Results seront supprimés automatiquement)

---

## 📝 ÉTAPE 2 : Créer les Glossary Terms au niveau Data Product

1. Aller à **Unified Catalog → Data Products → 3PL Logistics Analytics**
2. Cliquer sur **Glossary** (ou **+ Add term**)
3. Créer chaque terme manuellement :

### Terme 1 : Order
- **Name:** Order
- **Acronyms:** PO, SO
- **Description:** A customer order for goods or services in the 3PL system. Represents a request from a customer to fulfill specific items with defined quantities, delivery requirements, and SLA expectations. Tracked from creation through fulfillment and invoicing.
- **Resources:** SAP IDoc ORDERS05 (https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/orders05)
- **Managed Attributes:**
  - dataCategory: Transactional
  - businessProcess: Order Management
  - retentionPeriod: 7 years

### Terme 2 : Shipment
- **Name:** Shipment
- **Acronyms:** SHPMNT, Delivery
- **Description:** Physical movement of goods from origin to destination as part of order fulfillment. Includes carrier assignment, tracking information, delivery status, and proof of delivery. Critical for SLA compliance and customer visibility.
- **Resources:** SAP IDoc SHPMNT05
- **Managed Attributes:**
  - dataCategory: Transactional
  - businessProcess: Transportation Management
  - retentionPeriod: 3 years

### Terme 3 : Warehouse Movement
- **Name:** Warehouse Movement
- **Acronyms:** WHSCON, WM
- **Description:** Internal warehouse operations including goods receipt, put-away, picking, packing, and goods issue. Tracks inventory location changes and productivity metrics. Essential for warehouse efficiency and inventory accuracy.
- **Resources:** SAP IDoc WHSCON
- **Managed Attributes:**
  - dataCategory: Operational
  - businessProcess: Warehouse Management
  - retentionPeriod: 2 years

### Terme 4 : Invoice
- **Name:** Invoice
- **Acronyms:** INV, INVOIC
- **Description:** Financial document requesting payment for services rendered. Generated based on order fulfillment, shipments, and warehouse activities. Includes pricing, taxes, payment terms, and customer billing information.
- **Resources:** SAP IDoc INVOIC02
- **Managed Attributes:**
  - dataCategory: Financial
  - businessProcess: Accounts Receivable
  - retentionPeriod: 7 years
  - compliance: SOX, GDPR

### Terme 5 : Customer
- **Name:** Customer
- **Acronyms:** Client, Partner
- **Description:** Business entity receiving 3PL services. Includes customer master data, contact information, billing preferences, SLA agreements, and service level commitments. Central to partner relationship management.
- **Managed Attributes:**
  - dataCategory: Master Data
  - businessProcess: Customer Relationship Management
  - retentionPeriod: Indefinite
  - compliance: GDPR

### Terme 6 : Carrier
- **Name:** Carrier
- **Acronyms:** LSP, Transporter
- **Description:** Transportation service provider responsible for moving shipments between locations. Includes carrier contract terms, service levels, rates, and performance metrics. Critical for transportation planning and cost optimization.
- **Managed Attributes:**
  - dataCategory: Master Data
  - businessProcess: Transportation Management
  - retentionPeriod: Indefinite

### Terme 7 : SLA Compliance
- **Name:** SLA Compliance
- **Acronyms:** SLA, Service Level
- **Description:** Measurement of service level agreement adherence for order fulfillment, delivery times, and quality metrics. Calculated as percentage of commitments met within agreed timeframes. Key performance indicator for customer satisfaction.
- **Managed Attributes:**
  - dataCategory: KPI
  - businessProcess: Performance Management
  - calculationFrequency: Real-time

### Terme 8 : Delivery Performance
- **Name:** Delivery Performance
- **Acronyms:** OTD, On-Time Delivery
- **Description:** Metric measuring on-time delivery rate, accuracy, and overall delivery quality. Includes lead time analysis, delay reasons, and customer feedback. Primary indicator of operational excellence and competitiveness.
- **Managed Attributes:**
  - dataCategory: KPI
  - businessProcess: Performance Management
  - calculationFrequency: Daily
  - targetValue: ≥ 95%

---

## 🎯 ÉTAPE 3 : Créer les OKRs au niveau Data Product

1. Aller à **Unified Catalog → Data Products → 3PL Logistics Analytics**
2. Cliquer sur **Objectives** (ou **+ Add objective**)
3. Créer chaque Objective avec ses Key Results :

### Objective 1 : Operational Excellence
- **Definition:** Achieve operational excellence in 3PL logistics operations through real-time monitoring, SLA compliance, and data-driven decision making. Ensure high-quality service delivery with minimal delays and maximum efficiency.
- **Target Date:** 2026-04-26 (Q2 2026)
- **Status:** Published

**Key Results:**
1. **SLA Compliance Rate**
   - Definition: Maintain Service Level Agreement compliance rate at or above 95% across all customers and service types. Measured by comparing actual delivery times against committed SLAs.
   - Goal: 95
   - Progress: 92
   - Status: OnTrack

2. **On-Time Delivery Rate**
   - Definition: Achieve on-time delivery rate of 92% or higher. Measured as percentage of shipments delivered within the promised time window.
   - Goal: 92
   - Progress: 89
   - Status: Behind

3. **Data Freshness**
   - Definition: Maintain real-time data freshness with end-to-end latency below 5 minutes from source system to analytics layer. Critical for operational decision-making.
   - Goal: 5.0
   - Progress: 4.2
   - Status: OnTrack

### Objective 2 : Customer Satisfaction
- **Definition:** Maximize customer satisfaction by providing accurate, timely, and transparent logistics data. Enable customers and partners to track their shipments, monitor performance, and resolve issues quickly.
- **Target Date:** 2026-04-26 (Q2 2026)
- **Status:** Published

**Key Results:**
1. **Customer Satisfaction Score**
   - Definition: Achieve customer satisfaction score of 4.5 out of 5 or higher based on quarterly surveys measuring data quality, timeliness, and usability of the analytics platform.
   - Goal: 4.5
   - Progress: 4.3
   - Status: OnTrack

2. **Data Quality Score**
   - Definition: Maintain data quality score at 95% or above, measured by completeness, accuracy, consistency, and timeliness of data across all tables (Silver and Gold layers).
   - Goal: 95
   - Progress: 94
   - Status: OnTrack

3. **Invoice Accuracy**
   - Definition: Achieve invoice accuracy rate of 99% or higher, reducing billing disputes and improving cash flow. Measured as percentage of invoices issued without errors.
   - Goal: 99
   - Progress: 98
   - Status: OnTrack

### Objective 3 : Platform Adoption
- **Definition:** Drive adoption of the 3PL Real-Time Analytics Data Product across internal teams and external partners. Increase usage, onboard new partners, and demonstrate business value through measurable outcomes.
- **Target Date:** 2026-04-26 (Q2 2026)
- **Status:** Published

**Key Results:**
1. **Active Users**
   - Definition: Grow active monthly users to 50 or more, including internal analysts, customer service teams, and external partner users accessing the data product.
   - Goal: 50
   - Progress: 35
   - Status: Behind

2. **Data Product Usage**
   - Definition: Achieve 1000+ queries per day against the Data Product, demonstrating active usage and business value. Track via Fabric/Purview usage metrics.
   - Goal: 1000
   - Progress: 650
   - Status: Behind

3. **Partner Onboarding**
   - Definition: Onboard 10 or more B2B partners (customers, carriers, warehouse operators) with governed access to the Data Product for self-service analytics.
   - Goal: 10
   - Progress: 6
   - Status: OnTrack

---

## ✅ Validation

Après création manuelle, vérifier dans Purview Portal :
- **Data Product → 3PL Logistics Analytics → Glossary** : 8 termes visibles
- **Data Product → 3PL Logistics Analytics → Objectives** : 3 Objectives avec 9 Key Results
- **Domain → Supply Chain** : Aucun terme/OKR (sauf si vous créez des éléments globaux plus tard)

---

## 📌 Note pour plus tard

Quand vous voudrez créer des **Glossary Terms et OKRs au niveau Domain** (vision globale Supply Chain), vous pourrez les créer via le Portal au niveau du Domain directement.
