#!/usr/bin/env python3
"""
Créer les OKRs au niveau Domain puis tenter de les lier au Data Product
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

def get_ids():
    """Load Data Product and Domain IDs"""
    try:
        with open("data_product_supply_chain.json", "r") as f:
            data = json.load(f)
            return data.get("id"), data.get("domain")
    except FileNotFoundError:
        print("❌ ERROR: data_product_supply_chain.json not found!")
        exit(1)

def create_objective(credential, domain_id, objective_data):
    """Create an Objective at Domain level"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    target_date = (datetime.now() + timedelta(days=180)).isoformat() + "Z"
    
    objective_payload = {
        "id": str(uuid.uuid4()),
        "definition": objective_data["definition"],
        "domain": domain_id,
        "status": "Published",
        "targetDate": target_date,
        "contacts": {
            "owner": [
                {
                    "id": "bd259c61-df2c-4f56-a455-f2c15a86e18f",
                    "description": "3PL Operations Manager"
                }
            ]
        }
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=objective_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"   ✅ Created: {objective_data['name']}")
            print(f"      ID: {result.get('id')}")
            return result
        else:
            print(f"   ❌ Failed: {objective_data['name']} (Status: {response.status_code})")
            print(f"      Response: {response.text[:200]}")
            return None
    except Exception as e:
        print(f"   ❌ Error: {str(e)}")
        return None

def create_key_result(credential, objective_id, domain_id, kr_data):
    """Create a Key Result under an Objective"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    kr_payload = {
        "id": str(uuid.uuid4()),
        "domainId": domain_id,
        "definition": kr_data["definition"],
        "progress": kr_data.get("progress", 0),
        "goal": kr_data["goal"],
        "max": kr_data.get("max", kr_data["goal"]),
        "status": kr_data.get("status", "OnTrack")
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives/{objective_id}/keyResults?api-version={API_VERSION}"
    
    try:
        response = requests.post(url, headers=headers, json=kr_payload)
        
        if response.status_code == 201:
            result = response.json()
            print(f"      ✅ KR: {kr_data['name']} (Progress: {kr_data.get('progress', 0)}/{kr_data['goal']})")
            return result
        else:
            print(f"      ❌ Failed: {kr_data['name']}")
            return None
    except Exception as e:
        print(f"      ❌ Error: {str(e)}")
        return None

def try_link_objective_to_dataproduct(credential, objective_id, data_product_id):
    """Try to link an Objective to a Data Product using PATCH"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # Method: PATCH objective with dataProduct field
    url = f"{API_ENDPOINT}/datagovernance/catalog/objectives/{objective_id}?api-version={API_VERSION}"
    payload = {
        "dataProduct": data_product_id
    }
    
    try:
        response = requests.patch(url, headers=headers, json=payload)
        
        if response.status_code in [200, 204]:
            print(f"      🔗 Linked to Data Product via PATCH")
            return True
        else:
            # PATCH failed, try to verify if link exists
            get_response = requests.get(url, headers=headers)
            if get_response.status_code == 200:
                obj_data = get_response.json()
                if "dataProduct" in obj_data and obj_data["dataProduct"] == data_product_id:
                    print(f"      ✅ Already linked to Data Product")
                    return True
            
            return False
    except Exception as e:
        return False

def main():
    print("\n" + "=" * 80)
    print("  CRÉATION DES OKRs AU NIVEAU DOMAIN")
    print("  Puis tentative de lien avec Data Product")
    print("=" * 80)
    
    credential = DefaultAzureCredential()
    data_product_id, domain_id = get_ids()
    
    print(f"\n📦 Data Product ID: {data_product_id}")
    print(f"📦 Domain ID: {domain_id}")
    
    # Define objectives (same as before)
    objectives = [
        {
            "name": "Operational Excellence",
            "definition": "Achieve operational excellence in 3PL logistics operations through real-time monitoring, SLA compliance, and data-driven decision making. Ensure high-quality service delivery with minimal delays and maximum efficiency.",
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
    
    print("\n🎯 Création des Objectives et Key Results...")
    print("=" * 80)
    
    created_objectives = []
    all_key_results = []
    link_success_count = 0
    
    for i, obj_data in enumerate(objectives, 1):
        print(f"\n{i}. Objective: {obj_data['name']}")
        objective = create_objective(credential, domain_id, obj_data)
        
        if objective:
            created_objectives.append(objective)
            objective_id = objective.get('id')
            
            # Try to link to Data Product
            print(f"      Tentative de lien avec Data Product...")
            if try_link_objective_to_dataproduct(credential, objective_id, data_product_id):
                link_success_count += 1
            else:
                print(f"      ⚠️  Lien non créé (à faire manuellement)")
            
            # Create key results
            print(f"      Création de {len(obj_data['keyResults'])} Key Results...")
            
            for kr_data in obj_data['keyResults']:
                kr_result = create_key_result(credential, objective_id, domain_id, kr_data)
                if kr_result:
                    all_key_results.append(kr_result)
                time.sleep(0.5)
        
        time.sleep(1)
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ")
    print("=" * 80)
    
    print(f"\n✅ Objectives créés: {len(created_objectives)}/{len(objectives)}")
    print(f"✅ Key Results créés: {len(all_key_results)}")
    print(f"🔗 Liens Data Product: {link_success_count}/{len(created_objectives)}")
    
    # Save results
    if created_objectives:
        results = {
            "objectives": created_objectives,
            "keyResults": all_key_results,
            "dataProductId": data_product_id,
            "linkedCount": link_success_count,
            "summary": {
                "totalObjectives": len(created_objectives),
                "totalKeyResults": len(all_key_results),
                "createdAt": datetime.now().isoformat()
            }
        }
        
        with open("okrs_domain_level.json", "w") as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Résultats sauvegardés: okrs_domain_level.json")
    
    # Manual linking instructions if needed
    if link_success_count < len(created_objectives):
        print("\n" + "=" * 80)
        print("  ⚠️  LIEN MANUEL REQUIS")
        print("=" * 80)
        print(f"\n{len(created_objectives) - link_success_count} Objective(s) à lier manuellement au Data Product")
        print("\nÉtapes dans Purview Portal:")
        print("1. Aller à: Unified Catalog → Data Products → 3PL Logistics Analytics")
        print("2. Cliquer sur 'Objectives' ou '+ Add objective'")
        print("3. Sélectionner les Objectives existants:")
        for obj in created_objectives:
            print(f"   • {obj.get('definition', '')[:60]}... (ID: {obj.get('id')})")
    
    print("\n🌐 Visualiser dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    
    print("\n" + "=" * 80)
    print("\n✨ OKRs créés !\n")

if __name__ == "__main__":
    main()
