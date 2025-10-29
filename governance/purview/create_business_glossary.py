#!/usr/bin/env python3
"""
Créer le Business Glossary pour le domaine 3PL Logistics
Utilise l'API Unified Catalog (2025-09-15-preview)

Termes créés :
- Order (Commande)
- Shipment (Expédition)
- Warehouse Movement (Mouvement d'entrepôt)
- Invoice (Facture)
- Customer (Client)
- Carrier (Transporteur)
- SLA Compliance (Conformité SLA)
- Delivery Performance (Performance de livraison)
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid
import time

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def get_domain_id():
    """Load Business Domain ID from saved file"""
    try:
        with open("business_domain_created.json", "r") as f:
            data = json.load(f)
            return data.get("id")
    except FileNotFoundError:
        print("❌ ERROR: business_domain_created.json not found!")
        exit(1)

def create_term(credential, domain_id, term_data):
    """Create a term in the Business Glossary"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Create term payload
    term_payload = {
        "id": str(uuid.uuid4()),
        "name": term_data["name"],
        "domain": domain_id,
        "status": "PUBLISHED",
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
        "isLeaf": True
    }
    
    # Add managed attributes if provided
    if "managedAttributes" in term_data:
        term_payload["managedAttributes"] = term_data["managedAttributes"]
    
    # POST to create term
    url = f"{API_ENDPOINT}/datagovernance/catalog/terms?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=term_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ Created: {term_data['name']}")
            print(f"      ID: {result.get('id')}")
            return result
        else:
            print(f"   ❌ Failed: {term_data['name']} (Status: {response.status_code})")
            print(f"      Response: {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ Error creating {term_data['name']}: {str(e)}")
        return None

def main():
    print("\n" + "=" * 80)
    print("  CRÉATION DU BUSINESS GLOSSARY - 3PL LOGISTICS")
    print("=" * 80)
    
    # Authenticate
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Get Domain ID
    domain_id = get_domain_id()
    print(f"\n📦 Business Domain ID: {domain_id}")
    
    # Define glossary terms
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
            "description": "A physical delivery of goods from origin to destination. Represents the logistics execution phase including carrier assignment, tracking, transit monitoring, and delivery confirmation. Critical for SLA compliance and customer satisfaction.",
            "acronyms": ["SHPMNT", "DESADV"],
            "resources": [
                {
                    "name": "SAP IDoc SHPMNT05",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/shpmnt05"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Transactional"},
                {"name": "businessProcess", "value": "Transportation Management"},
                {"name": "retentionPeriod", "value": "7 years"}
            ]
        },
        {
            "name": "Warehouse Movement",
            "description": "Physical movement of goods within or between warehouse locations. Includes goods receipt, putaway, picking, packing, and staging operations. Essential for inventory accuracy and fulfillment efficiency.",
            "acronyms": ["WHSCON", "WM"],
            "resources": [
                {
                    "name": "SAP IDoc WHSCON02",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/whscon02"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Transactional"},
                {"name": "businessProcess", "value": "Warehouse Management"},
                {"name": "retentionPeriod", "value": "3 years"}
            ]
        },
        {
            "name": "Invoice",
            "description": "Financial document requesting payment for goods or services delivered. Represents the billing cycle including pricing, taxes, payment terms, and settlement tracking. Critical for revenue recognition and cash flow management.",
            "acronyms": ["INVOIC"],
            "resources": [
                {
                    "name": "SAP IDoc INVOIC02",
                    "url": "https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/invoic02"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Financial"},
                {"name": "businessProcess", "value": "Billing & Invoicing"},
                {"name": "retentionPeriod", "value": "10 years"},
                {"name": "compliance", "value": "SOX, GDPR"}
            ]
        },
        {
            "name": "Customer",
            "description": "Business entity or individual that contracts 3PL services. Master data entity containing contact information, shipping addresses, billing details, and SLA agreements. Used across all logistics processes.",
            "acronyms": ["CUST"],
            "resources": [
                {
                    "name": "Customer Master Data",
                    "url": "https://internal-wiki.example.com/customer-mdm"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Master Data"},
                {"name": "businessProcess", "value": "Customer Relationship Management"},
                {"name": "sensitivityLevel", "value": "Confidential"},
                {"name": "compliance", "value": "GDPR"}
            ]
        },
        {
            "name": "Carrier",
            "description": "Transportation service provider responsible for physical delivery of shipments. Includes freight forwarders, courier services, and last-mile delivery partners. Performance tracked via on-time delivery metrics.",
            "acronyms": ["CSP", "LSP"],
            "resources": [
                {
                    "name": "Carrier Master Data",
                    "url": "https://internal-wiki.example.com/carrier-mdm"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Master Data"},
                {"name": "businessProcess", "value": "Transportation Management"},
                {"name": "sensitivityLevel", "value": "Internal"}
            ]
        },
        {
            "name": "SLA Compliance",
            "description": "Measurement of adherence to Service Level Agreements between 3PL provider and customers. Includes metrics like on-time delivery percentage, order accuracy, and response times. Critical KPI for customer satisfaction and contract renewal.",
            "acronyms": ["SLA"],
            "resources": [
                {
                    "name": "SLA Dashboard",
                    "url": "https://internal-wiki.example.com/sla-metrics"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Performance Metric"},
                {"name": "businessProcess", "value": "Quality Management"},
                {"name": "updateFrequency", "value": "Real-time"}
            ]
        },
        {
            "name": "Delivery Performance",
            "description": "Aggregate measure of delivery execution quality including on-time delivery rate, delivery accuracy, customer satisfaction scores, and damage/loss rates. Primary operational KPI for 3PL operations.",
            "acronyms": ["OTD", "OTIF"],
            "resources": [
                {
                    "name": "Delivery Metrics Dashboard",
                    "url": "https://internal-wiki.example.com/delivery-metrics"
                }
            ],
            "managedAttributes": [
                {"name": "dataCategory", "value": "Performance Metric"},
                {"name": "businessProcess", "value": "Logistics Operations"},
                {"name": "updateFrequency", "value": "Hourly"}
            ]
        }
    ]
    
    # Create terms
    print("\n📚 Création des termes du glossaire...")
    print("=" * 80)
    
    created_terms = []
    
    for i, term_data in enumerate(terms, 1):
        print(f"\n{i}. {term_data['name']}")
        result = create_term(credential, domain_id, term_data)
        if result:
            created_terms.append(result)
        time.sleep(1)  # Rate limiting
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ")
    print("=" * 80)
    
    print(f"\n✅ Termes créés avec succès: {len(created_terms)}/{len(terms)}")
    
    if created_terms:
        print("\n📋 Termes du glossaire:")
        for term in created_terms:
            print(f"   • {term.get('name')} (ID: {term.get('id')})")
    
    # Save results
    if created_terms:
        with open("glossary_terms_created.json", "w") as f:
            json.dump(created_terms, f, indent=2)
        print(f"\n💾 Résultats sauvegardés: glossary_terms_created.json")
    
    print("\n🌐 Visualiser dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    print(f"   Unified Catalog → Business glossary")
    
    print("\n" + "=" * 80)
    print("\n✨ Business Glossary créé avec succès !\n")

if __name__ == "__main__":
    main()
