#!/usr/bin/env python3
"""
Enrichir le domaine Supply Chain avec OKRs et Glossary Terms génériques
En plus du Data Product 3PL Logistics Analytics
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import uuid
import time
from datetime import datetime, timedelta

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

# OKRs génériques du domaine Supply Chain
SUPPLY_CHAIN_DOMAIN_OBJECTIVES = [
    {
        "name": "Supply Chain Resilience",
        "definition": "Build a resilient and agile supply chain capable of withstanding disruptions, managing risks, and adapting to changing market conditions.",
        "keyResults": [
            {
                "name": "Supplier Diversification",
                "definition": "Reduce dependency on single-source suppliers to less than 20% of critical components",
                "progress": 28,
                "goal": 20,
                "status": "Behind"
            },
            {
                "name": "Inventory Turns",
                "definition": "Achieve inventory turnover ratio of 8 or higher",
                "progress": 6.5,
                "goal": 8.0,
                "status": "OnTrack"
            },
            {
                "name": "Supply Chain Visibility",
                "definition": "Achieve 100% end-to-end visibility for Tier 1 and Tier 2 suppliers",
                "progress": 85,
                "goal": 100,
                "status": "OnTrack"
            }
        ]
    },
    {
        "name": "Logistics Cost Optimization",
        "definition": "Optimize transportation, warehousing, and distribution costs while maintaining service levels and sustainability commitments.",
        "keyResults": [
            {
                "name": "Freight Cost per Unit",
                "definition": "Reduce freight cost per unit shipped by 10% through route optimization and carrier consolidation",
                "progress": 6.5,
                "goal": 10.0,
                "status": "OnTrack"
            },
            {
                "name": "Warehouse Utilization",
                "definition": "Increase warehouse space utilization to 85% or higher",
                "progress": 78,
                "goal": 85,
                "status": "OnTrack"
            },
            {
                "name": "Empty Miles Reduction",
                "definition": "Reduce empty miles to less than 15% of total miles driven",
                "progress": 18,
                "goal": 15,
                "status": "Behind"
            }
        ]
    },
    {
        "name": "Sustainability & Carbon Footprint",
        "definition": "Reduce environmental impact of supply chain operations and achieve carbon neutrality goals through sustainable practices.",
        "keyResults": [
            {
                "name": "Carbon Emissions Reduction",
                "definition": "Reduce Scope 3 carbon emissions by 15% year-over-year",
                "progress": 9,
                "goal": 15,
                "status": "OnTrack"
            },
            {
                "name": "Green Fleet Percentage",
                "definition": "Increase percentage of electric/hybrid vehicles in fleet to 25%",
                "progress": 12,
                "goal": 25,
                "status": "Behind"
            },
            {
                "name": "Packaging Waste Reduction",
                "definition": "Reduce packaging waste by 20% through reusable and recyclable materials",
                "progress": 14,
                "goal": 20,
                "status": "OnTrack"
            }
        ]
    },
    {
        "name": "Digital Supply Chain Transformation",
        "definition": "Accelerate digital transformation initiatives to enable real-time decision making, automation, and predictive analytics across the supply chain.",
        "keyResults": [
            {
                "name": "Process Automation",
                "definition": "Automate 50% of manual supply chain processes",
                "progress": 32,
                "goal": 50,
                "status": "OnTrack"
            },
            {
                "name": "IoT Device Deployment",
                "definition": "Deploy 500 IoT sensors for real-time tracking and monitoring",
                "progress": 285,
                "goal": 500,
                "status": "OnTrack"
            },
            {
                "name": "Predictive Analytics Adoption",
                "definition": "Implement predictive analytics for 80% of demand planning processes",
                "progress": 55,
                "goal": 80,
                "status": "OnTrack"
            }
        ]
    }
]

# Glossary Terms génériques Supply Chain
SUPPLY_CHAIN_GLOSSARY_TERMS = [
    {
        "name": "Bill of Lading",
        "acronym": "BOL",
        "definition": "A legal document between shipper and carrier detailing the type, quantity, and destination of goods being carried. Serves as a shipment receipt and title of goods."
    },
    {
        "name": "Just-In-Time",
        "acronym": "JIT",
        "definition": "An inventory management strategy where materials and products arrive exactly when needed in the production process, minimizing inventory holding costs and waste."
    },
    {
        "name": "Cross-Docking",
        "acronym": "XD",
        "definition": "A logistics practice where incoming goods are directly transferred from inbound to outbound transportation with minimal or no warehousing time."
    },
    {
        "name": "Demand Planning",
        "acronym": "DP",
        "definition": "The process of forecasting customer demand to ensure products can be delivered and satisfy customers while minimizing excess inventory."
    },
    {
        "name": "Safety Stock",
        "acronym": "SS",
        "definition": "Extra inventory held to guard against stockouts caused by uncertainties in supply and demand. Acts as a buffer to maintain service levels."
    },
    {
        "name": "Lead Time",
        "acronym": "LT",
        "definition": "The time between initiating a process (e.g., placing an order) and its completion (e.g., receiving goods). Critical for inventory planning and customer commitments."
    },
    {
        "name": "Freight Forwarder",
        "acronym": "FF",
        "definition": "A company that arranges the storage and shipping of goods on behalf of shippers, coordinating logistics across multiple carriers and modes of transport."
    },
    {
        "name": "Landed Cost",
        "acronym": "LC",
        "definition": "The total cost of a product to arrive at a buyer's door, including purchase price, shipping, insurance, customs, taxes, and other fees."
    },
    {
        "name": "Backorder",
        "acronym": "BO",
        "definition": "An order for a product that is temporarily out of stock and will be fulfilled when inventory becomes available."
    },
    {
        "name": "Cycle Count",
        "acronym": "CC",
        "definition": "A periodic physical count of a subset of inventory items to verify accuracy of inventory records without requiring a full physical inventory."
    },
    {
        "name": "Freight Class",
        "acronym": "FC",
        "definition": "A standardized classification system (50-500) for freight based on density, handling, stowability, and liability. Used to determine shipping rates."
    },
    {
        "name": "Vendor Managed Inventory",
        "acronym": "VMI",
        "definition": "A supply chain practice where the supplier manages inventory levels at the customer's location based on agreed service levels and demand forecasts."
    }
]

def get_domain_id():
    """Charger l'ID du domaine Supply Chain"""
    try:
        with open("data_product_supply_chain.json", "r") as f:
            data = json.load(f)
            return data.get("domain")
    except FileNotFoundError:
        print("❌ ERROR: data_product_supply_chain.json not found!")
        exit(1)

def create_objective(credential, domain_id, obj_data):
    """Créer un Objective"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    target_date = (datetime.now() + timedelta(days=180)).isoformat() + "Z"
    
    objective_payload = {
        "id": str(uuid.uuid4()),
        "definition": obj_data["definition"],
        "domain": domain_id,
        "status": "Published",
        "targetDate": target_date
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=objective_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ {obj_data['name']}")
            return result
        else:
            print(f"   ❌ Failed: {obj_data['name']}")
            return None
    except Exception as e:
        print(f"   ❌ Error: {str(e)}")
        return None

def create_key_result(credential, objective_id, domain_id, kr_data):
    """Créer un Key Result"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    kr_payload = {
        "id": str(uuid.uuid4()),
        "domainId": domain_id,
        "definition": kr_data["definition"],
        "progress": kr_data["progress"],
        "goal": kr_data["goal"],
        "max": kr_data.get("max", kr_data["goal"]),
        "status": kr_data["status"]
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives/{objective_id}/keyResults?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=kr_payload)
        return response.json() if response.status_code == 201 else None
    except Exception as e:
        return None

def create_glossary_term(credential, domain_id, term_data):
    """Créer un Glossary Term"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    term_payload = {
        "id": str(uuid.uuid4()),
        "name": term_data["name"],
        "domain": domain_id,
        "definition": term_data["definition"],
        "status": "Published"
    }
    
    if term_data.get("acronym"):
        term_payload["acronym"] = term_data["acronym"]
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/terms?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=term_payload)
        
        if response.status_code == 201:
            result = response.json()
            acronym_str = f" ({term_data['acronym']})" if term_data.get('acronym') else ""
            print(f"      ✅ {term_data['name']}{acronym_str}")
            return result
        else:
            return None
    except Exception as e:
        return None

def main():
    print("\n" + "=" * 80)
    print("  ENRICHISSEMENT DOMAINE SUPPLY CHAIN")
    print("  OKRs et Glossary Terms génériques du domaine")
    print("=" * 80)
    
    credential = DefaultAzureCredential()
    domain_id = get_domain_id()
    
    print(f"\n📦 Supply Chain Domain ID: {domain_id}")
    
    all_results = {
        "domainId": domain_id,
        "objectives": [],
        "keyResults": [],
        "glossaryTerms": [],
        "createdAt": datetime.now().isoformat()
    }
    
    # Créer les Objectives
    print(f"\n🎯 Création de {len(SUPPLY_CHAIN_DOMAIN_OBJECTIVES)} Objectives génériques...")
    print("=" * 80)
    
    for obj_data in SUPPLY_CHAIN_DOMAIN_OBJECTIVES:
        objective = create_objective(credential, domain_id, obj_data)
        if objective:
            all_results["objectives"].append(objective)
            objective_id = objective.get("id")
            
            # Créer les Key Results
            kr_count = 0
            for kr_data in obj_data["keyResults"]:
                kr = create_key_result(credential, objective_id, domain_id, kr_data)
                if kr:
                    all_results["keyResults"].append(kr)
                    kr_count += 1
                time.sleep(0.3)
            
            print(f"      → {kr_count} Key Results créés")
        time.sleep(0.5)
    
    # Créer les Glossary Terms
    print(f"\n📚 Création de {len(SUPPLY_CHAIN_GLOSSARY_TERMS)} Glossary Terms génériques...")
    print("=" * 80)
    
    for term_data in SUPPLY_CHAIN_GLOSSARY_TERMS:
        term = create_glossary_term(credential, domain_id, term_data)
        if term:
            all_results["glossaryTerms"].append(term)
        time.sleep(0.3)
    
    # Sauvegarder les résultats
    with open("supply_chain_domain_enrichment.json", "w") as f:
        json.dump(all_results, f, indent=2)
    
    # Résumé
    print("\n" + "=" * 80)
    print("  RÉSUMÉ")
    print("=" * 80)
    print(f"\n✅ Objectives créés: {len(all_results['objectives'])}")
    print(f"✅ Key Results créés: {len(all_results['keyResults'])}")
    print(f"✅ Glossary Terms créés: {len(all_results['glossaryTerms'])}")
    
    print(f"\n💾 Résultats sauvegardés: supply_chain_domain_enrichment.json")
    
    print("\n📊 Domaine Supply Chain maintenant contient:")
    print("   • 4 Objectives génériques du domaine (+ 3 du Data Product)")
    print("   • 12 Glossary Terms génériques (+ 8 du Data Product)")
    print("   • 1 Data Product: 3PL Logistics Analytics")
    
    print("\n🌐 Visualiser dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    
    print("\n" + "=" * 80)
    print("\n✨ Supply Chain enrichi avec succès !\n")

if __name__ == "__main__":
    main()
