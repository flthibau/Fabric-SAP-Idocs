#!/usr/bin/env python3
"""
Créer les Glossary Terms au niveau du DATA PRODUCT (pas au niveau Domain!)
8 termes spécifiques au Data Product "3PL Logistics Analytics"
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid
import time
from datetime import datetime

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def get_data_product_info():
    """Load Data Product ID and Domain ID"""
    try:
        with open("data_product_supply_chain.json", "r") as f:
            data = json.load(f)
            return data.get("id"), data.get("domain")
    except FileNotFoundError:
        print("❌ ERROR: data_product_supply_chain.json not found!")
        exit(1)

def create_term(credential, data_product_id, domain_id, term_data):
    """Create a Glossary Term linked to a Data Product"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Create term payload - LINKED TO BOTH DATA PRODUCT AND DOMAIN
    term_payload = {
        "id": str(uuid.uuid4()),
        "name": term_data["name"],
        "domain": domain_id,  # ← Requis par l'API
        "dataProduct": data_product_id,  # ← Lié au Data Product
        "status": "Published",
        "description": term_data["description"],
        "acronyms": term_data.get("acronyms", []),
        "contacts": {
            "owner": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "3PL Business Unit Owner"
                }
            ],
            "expert": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "Supply Chain Analyst"
                }
            ]
        },
        "resources": term_data.get("resources", []),
        "managedAttributes": term_data.get("managedAttributes", [])
    }
    
    # POST to create term
    url = f"{API_ENDPOINT}/datagovernance/catalog/terms?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=term_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ {term_data['name']} (ID: {result.get('id')})")
            return result
        else:
            print(f"   ❌ {term_data['name']} (Status: {response.status_code})")
            print(f"      Response: {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ Error creating {term_data['name']}: {str(e)}")
        return None

def main():
    print("\n" + "=" * 80)
    print("  CRÉATION DES GLOSSARY TERMS - DATA PRODUCT")
    print("  3PL Logistics Analytics (a4f24a45...)")
    print("=" * 80)
    
    # Authenticate
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Get Data Product ID and Domain ID
    data_product_id, domain_id = get_data_product_info()
    print(f"\n📦 Data Product ID: {data_product_id}")
    print(f"📦 Domain ID: {domain_id}")
    
    # Define terms (spécifiques au 3PL Logistics)
    terms = [
        {
            "name": "Order",
            "description": "A customer order for goods or services in the 3PL system. Represents a request from a customer to fulfill specific items with defined quantities, delivery requirements, and SLA expectations. Tracked from creation through fulfillment and invoicing.",
            "acronyms": ["PO", "SO"],
            "resources": [
                {
                    "name": "SAP IDoc ORDERS05",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/orders05"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Transactional"},
                {"name": "businessProcess", "value": "Order Management"},
                {"name": "retentionPeriod", "value": "7 years"}
            ]
        },
        {
            "name": "Shipment",
            "description": "Physical movement of goods from origin to destination as part of order fulfillment. Includes carrier assignment, tracking information, delivery status, and proof of delivery. Critical for SLA compliance and customer visibility.",
            "acronyms": ["SHPMNT", "Delivery"],
            "resources": [
                {
                    "name": "SAP IDoc SHPMNT05",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/shpmnt05"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Transactional"},
                {"name": "businessProcess", "value": "Transportation Management"},
                {"name": "retentionPeriod", "value": "3 years"}
            ]
        },
        {
            "name": "Warehouse Movement",
            "description": "Internal warehouse operations including goods receipt, put-away, picking, packing, and goods issue. Tracks inventory location changes and productivity metrics. Essential for warehouse efficiency and inventory accuracy.",
            "acronyms": ["WHSCON", "WM"],
            "resources": [
                {
                    "name": "SAP IDoc WHSCON",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/whscon"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Operational"},
                {"name": "businessProcess", "value": "Warehouse Management"},
                {"name": "retentionPeriod", "value": "2 years"}
            ]
        },
        {
            "name": "Invoice",
            "description": "Financial document requesting payment for services rendered. Generated based on order fulfillment, shipments, and warehouse activities. Includes pricing, taxes, payment terms, and customer billing information.",
            "acronyms": ["INV", "INVOIC"],
            "resources": [
                {
                    "name": "SAP IDoc INVOIC02",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/invoic02"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Financial"},
                {"name": "businessProcess", "value": "Accounts Receivable"},
                {"name": "retentionPeriod", "value": "7 years"},
                {"name": "compliance", "value": "SOX, GDPR"}
            ]
        },
        {
            "name": "Customer",
            "description": "Business entity receiving 3PL services. Includes customer master data, contact information, billing preferences, SLA agreements, and service level commitments. Central to partner relationship management.",
            "acronyms": ["Client", "Partner"],
            "resources": [
                {
                    "name": "Customer Master Data Guide",
                    "url": "https://internal-wiki.example.com/customer-master"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Master Data"},
                {"name": "businessProcess", "value": "Customer Relationship Management"},
                {"name": "retentionPeriod", "value": "Indefinite"},
                {"name": "compliance", "value": "GDPR"}
            ]
        },
        {
            "name": "Carrier",
            "description": "Transportation service provider responsible for moving shipments between locations. Includes carrier contract terms, service levels, rates, and performance metrics. Critical for transportation planning and cost optimization.",
            "acronyms": ["LSP", "Transporter"],
            "resources": [
                {
                    "name": "Carrier Management Guide",
                    "url": "https://internal-wiki.example.com/carrier-management"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Master Data"},
                {"name": "businessProcess", "value": "Transportation Management"},
                {"name": "retentionPeriod", "value": "Indefinite"}
            ]
        },
        {
            "name": "SLA Compliance",
            "description": "Measurement of service level agreement adherence for order fulfillment, delivery times, and quality metrics. Calculated as percentage of commitments met within agreed timeframes. Key performance indicator for customer satisfaction.",
            "acronyms": ["SLA", "Service Level"],
            "resources": [
                {
                    "name": "SLA Calculation Methodology",
                    "url": "https://internal-wiki.example.com/sla-methodology"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "KPI"},
                {"name": "businessProcess", "value": "Performance Management"},
                {"name": "calculationFrequency", "value": "Real-time"}
            ]
        },
        {
            "name": "Delivery Performance",
            "description": "Metric measuring on-time delivery rate, accuracy, and overall delivery quality. Includes lead time analysis, delay reasons, and customer feedback. Primary indicator of operational excellence and competitiveness.",
            "acronyms": ["OTD", "On-Time Delivery"],
            "resources": [
                {
                    "name": "Delivery Metrics Dashboard",
                    "url": "https://internal-wiki.example.com/delivery-metrics"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "KPI"},
                {"name": "businessProcess", "value": "Performance Management"},
                {"name": "calculationFrequency", "value": "Daily"},
                {"name": "targetValue", "value": "≥ 95%"}
            ]
        }
    ]
    
    # Create terms
    print(f"\n📚 Création de {len(terms)} Glossary Terms...")
    print("=" * 80)
    
    created_terms = []
    
    for i, term_data in enumerate(terms, 1):
        print(f"\n{i}. {term_data['name']}")
        term = create_term(credential, data_product_id, domain_id, term_data)
        if term:
            created_terms.append(term)
        time.sleep(1)  # Rate limiting
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ")
    print("=" * 80)
    
    print(f"\n✅ Termes créés: {len(created_terms)}/{len(terms)}")
    
    if created_terms:
        # Save results
        with open("glossary_terms_data_product.json", "w") as f:
            json.dump(created_terms, f, indent=2)
        print(f"\n💾 Résultats sauvegardés: glossary_terms_data_product.json")
        
        print("\n📋 Termes créés:")
        for term in created_terms:
            print(f"   • {term.get('name')} (ID: {term.get('id')})")
    
    print("\n🌐 Visualiser dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    print(f"   Unified Catalog → Data Products → 3PL Logistics Analytics → Glossary")
    
    print("\n" + "=" * 80)
    print("\n✨ Glossary Terms créés avec succès au niveau Data Product!\n")

if __name__ == "__main__":
    main()
