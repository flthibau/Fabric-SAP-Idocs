#!/usr/bin/env python3
"""
Créer les OKRs (Objectives & Key Results) pour le DATA PRODUCT "3PL Logistics Analytics"
3 Objectives avec 9 Key Results au total
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

def get_data_product_info():
    """Load Data Product ID and Domain ID"""
    try:
        with open("data_product_supply_chain.json", "r") as f:
            data = json.load(f)
            return data.get("id"), data.get("domain")
    except FileNotFoundError:
        print("❌ ERROR: data_product_supply_chain.json not found!")
        exit(1)

def create_objective(credential, data_product_id, domain_id, objective_data):
    """Create an Objective (O in OKR) linked to Data Product"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Target date: Q2 2026 (6 months from now)
    target_date = (datetime.now() + timedelta(days=180)).isoformat() + "Z"
    
    # Create objective payload - LINKED TO BOTH DATA PRODUCT AND DOMAIN
    objective_payload = {
        "id": str(uuid.uuid4()),
        "definition": objective_data["definition"],
        "domain": domain_id,  # ← Requis par l'API
        "dataProduct": data_product_id,  # ← Lié au Data Product
        "status": "Published",
        "targetDate": target_date,
        "contacts": {
            "owner": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "3PL Operations Manager"
                }
            ]
        },
        "additionalProperties": {
            "overallStatus": objective_data.get("overallStatus", "OnTrack"),
            "keyResultsCount": len(objective_data.get("keyResults", []))
        }
    }
    
    # POST to create objective
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=objective_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ Created Objective: {objective_data['name']}")
            print(f"      ID: {result.get('id')}")
            print(f"      Target: {target_date[:10]}")
            return result
        else:
            print(f"   ❌ Failed: {objective_data['name']} (Status: {response.status_code})")
            print(f"      Response: {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ Error creating {objective_data['name']}: {str(e)}")
        return None

def create_key_result(credential, objective_id, data_product_id, domain_id, kr_data):
    """Create a Key Result (KR in OKR) under an Objective"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Create key result payload
    kr_payload = {
        "id": str(uuid.uuid4()),
        "domainId": domain_id,  # ← Requis par l'API
        "dataProductId": data_product_id,  # ← Lié au Data Product
        "definition": kr_data["definition"],
        "progress": kr_data.get("progress", 0),
        "goal": kr_data["goal"],
        "max": kr_data.get("max", kr_data["goal"]),
        "status": kr_data.get("status", "OnTrack")
    }
    
    # POST to create key result
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives/{objective_id}/keyResults?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=kr_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"      ✅ KR: {kr_data['name']} (Progress: {kr_data.get('progress', 0)}/{kr_data['goal']})")
            return result
        else:
            print(f"      ❌ Failed: {kr_data['name']} (Status: {response.status_code})")
            print(f"         Response: {response.text[:100]}")
            return None
    except Exception as e:
        print(f"      ❌ Error creating {kr_data['name']}: {str(e)}")
        return None

def main():
    print("\n" + "=" * 80)
    print("  CRÉATION DES OKRs - DATA PRODUCT")
    print("  3PL Logistics Analytics (a4f24a45...)")
    print("=" * 80)
    
    # Authenticate
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Get Data Product ID and Domain ID
    data_product_id, domain_id = get_data_product_info()
    print(f"\n📦 Data Product ID: {data_product_id}")
    print(f"📦 Domain ID: {domain_id}")
    
    # Define OKRs
    objectives = [
        {
            "name": "Operational Excellence",
            "definition": "Achieve operational excellence in 3PL logistics operations through real-time monitoring, SLA compliance, and data-driven decision making. Ensure high-quality service delivery with minimal delays and maximum efficiency.",
            "overallStatus": "OnTrack",
            "keyResults": [
                {
                    "name": "SLA Compliance Rate",
                    "definition": "Maintain Service Level Agreement compliance rate at or above 95% across all customers and service types. Measured by comparing actual delivery times against committed SLAs.",
                    "progress": 92,
                    "goal": 95,
                    "max": 100,
                    "status": "OnTrack"
                },
                {
                    "name": "On-Time Delivery Rate",
                    "definition": "Achieve on-time delivery rate of 92% or higher. Measured as percentage of shipments delivered within the promised time window.",
                    "progress": 89,
                    "goal": 92,
                    "max": 100,
                    "status": "Behind"
                },
                {
                    "name": "Data Freshness",
                    "definition": "Maintain real-time data freshness with end-to-end latency below 5 minutes from source system to analytics layer. Critical for operational decision-making.",
                    "progress": 4.2,
                    "goal": 5.0,
                    "max": 5.0,
                    "status": "OnTrack"
                }
            ]
        },
        {
            "name": "Customer Satisfaction",
            "definition": "Maximize customer satisfaction by providing accurate, timely, and transparent logistics data. Enable customers and partners to track their shipments, monitor performance, and resolve issues quickly.",
            "overallStatus": "OnTrack",
            "keyResults": [
                {
                    "name": "Customer Satisfaction Score",
                    "definition": "Achieve customer satisfaction score of 4.5 out of 5 or higher based on quarterly surveys measuring data quality, timeliness, and usability of the analytics platform.",
                    "progress": 4.3,
                    "goal": 4.5,
                    "max": 5.0,
                    "status": "OnTrack"
                },
                {
                    "name": "Data Quality Score",
                    "definition": "Maintain data quality score at 95% or above, measured by completeness, accuracy, consistency, and timeliness of data across all tables (Silver and Gold layers).",
                    "progress": 94,
                    "goal": 95,
                    "max": 100,
                    "status": "OnTrack"
                },
                {
                    "name": "Invoice Accuracy",
                    "definition": "Achieve invoice accuracy rate of 99% or higher, reducing billing disputes and improving cash flow. Measured as percentage of invoices issued without errors.",
                    "progress": 98,
                    "goal": 99,
                    "max": 100,
                    "status": "OnTrack"
                }
            ]
        },
        {
            "name": "Platform Adoption",
            "definition": "Drive adoption of the 3PL Real-Time Analytics Data Product across internal teams and external partners. Increase usage, onboard new partners, and demonstrate business value through measurable outcomes.",
            "overallStatus": "Behind",
            "keyResults": [
                {
                    "name": "Active Users",
                    "definition": "Grow active monthly users to 50 or more, including internal analysts, customer service teams, and external partner users accessing the data product.",
                    "progress": 35,
                    "goal": 50,
                    "max": 100,
                    "status": "Behind"
                },
                {
                    "name": "Data Product Usage",
                    "definition": "Achieve 1000+ queries per day against the Data Product, demonstrating active usage and business value. Track via Fabric/Purview usage metrics.",
                    "progress": 650,
                    "goal": 1000,
                    "max": 2000,
                    "status": "Behind"
                },
                {
                    "name": "Partner Onboarding",
                    "definition": "Onboard 10 or more B2B partners (customers, carriers, warehouse operators) with governed access to the Data Product for self-service analytics.",
                    "progress": 6,
                    "goal": 10,
                    "max": 20,
                    "status": "OnTrack"
                }
            ]
        }
    ]
    
    # Create objectives and key results
    print("\n🎯 Création des Objectives et Key Results...")
    print("=" * 80)
    
    created_objectives = []
    all_key_results = []
    
    for i, obj_data in enumerate(objectives, 1):
        print(f"\n{i}. Objective: {obj_data['name']}")
        objective = create_objective(credential, data_product_id, domain_id, obj_data)
        
        if objective:
            created_objectives.append(objective)
            objective_id = objective.get('id')
            
            # Create key results for this objective
            print(f"   Creating {len(obj_data['keyResults'])} Key Results...")
            
            for kr_data in obj_data['keyResults']:
                kr_result = create_key_result(credential, objective_id, data_product_id, domain_id, kr_data)
                if kr_result:
                    all_key_results.append(kr_result)
                time.sleep(0.5)  # Rate limiting
        
        time.sleep(1)
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ")
    print("=" * 80)
    
    print(f"\n✅ Objectives créés: {len(created_objectives)}/{len(objectives)}")
    print(f"✅ Key Results créés: {len(all_key_results)}")
    
    if created_objectives:
        print("\n📋 Objectives:")
        for obj in created_objectives:
            print(f"   • {obj.get('definition', '')[:60]}...")
            print(f"     ID: {obj.get('id')}")
            print(f"     Target: {obj.get('targetDate', '')[:10]}")
    
    # Save results
    if created_objectives:
        results = {
            "objectives": created_objectives,
            "keyResults": all_key_results,
            "summary": {
                "totalObjectives": len(created_objectives),
                "totalKeyResults": len(all_key_results),
                "createdAt": datetime.now().isoformat()
            }
        }
        
        with open("okrs_data_product.json", "w") as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Résultats sauvegardés: okrs_data_product.json")
    
    print("\n🌐 Visualiser dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    print(f"   Unified Catalog → Data Products → 3PL Logistics Analytics → Objectives")
    
    print("\n📊 Status des OKRs:")
    print("   • Operational Excellence: OnTrack (2/3 KRs on track)")
    print("   • Customer Satisfaction: OnTrack (3/3 KRs on track)")
    print("   • Platform Adoption: Behind (1/3 KRs on track)")
    
    print("\n" + "=" * 80)
    print("\n✨ OKRs créés avec succès au niveau Data Product!\n")

if __name__ == "__main__":
    main()
