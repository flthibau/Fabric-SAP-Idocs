#!/usr/bin/env python3
"""
Nettoyage complet de l'ancienne architecture Purview
Supprime dans l'ordre: OKRs → Glossary Terms → Data Product → Domain

Ordre important pour éviter les erreurs de dépendances:
1. OKRs (Objectives + Key Results)
2. Glossary Terms
3. Data Product
4. Domain "3PL Logistics"
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import time

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def delete_okrs(credential, okrs_file="okrs_created.json"):
    """Supprimer tous les Objectives (et leurs Key Results)"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 1: SUPPRESSION DES OKRs")
    print("=" * 80)
    
    try:
        with open(okrs_file, "r") as f:
            data = json.load(f)
            objectives = data.get("objectives", [])
    except FileNotFoundError:
        print("⚠️  Fichier okrs_created.json introuvable - skip")
        return True
    
    token = credential.get_token("https://purview.azure.net/.default")
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print(f"\n📋 {len(objectives)} Objectives à supprimer...")
    
    deleted_count = 0
    for obj in objectives:
        obj_id = obj.get("id")
        obj_def = obj.get("definition", "")[:60]
        
        url = f"{API_ENDPOINT}/datagovernance/catalog/objectives/{obj_id}?api-version={API_VERSION}"
        
        try:
            response = requests.delete(url, headers=headers)
            if response.status_code in [200, 204]:
                print(f"   ✅ Supprimé: {obj_def}... (ID: {obj_id})")
                deleted_count += 1
            elif response.status_code == 404:
                print(f"   ⚠️  Déjà supprimé: {obj_def}...")
            else:
                print(f"   ❌ Erreur {response.status_code}: {obj_def}...")
                print(f"      Response: {response.text[:100]}")
        except Exception as e:
            print(f"   ❌ Exception: {str(e)}")
        
        time.sleep(0.3)
    
    print(f"\n✅ {deleted_count}/{len(objectives)} Objectives supprimés")
    return deleted_count == len(objectives)

def delete_glossary_terms(credential, terms_file="glossary_terms_created.json"):
    """Supprimer tous les Glossary Terms"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 2: SUPPRESSION DES GLOSSARY TERMS")
    print("=" * 80)
    
    try:
        with open(terms_file, "r") as f:
            terms = json.load(f)
    except FileNotFoundError:
        print("⚠️  Fichier glossary_terms_created.json introuvable - skip")
        return True
    
    token = credential.get_token("https://purview.azure.net/.default")
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print(f"\n📋 {len(terms)} Terms à supprimer...")
    
    deleted_count = 0
    for term in terms:
        term_id = term.get("id")
        term_name = term.get("name")
        
        url = f"{API_ENDPOINT}/datagovernance/catalog/terms/{term_id}?api-version={API_VERSION}"
        
        try:
            response = requests.delete(url, headers=headers)
            if response.status_code in [200, 204]:
                print(f"   ✅ Supprimé: {term_name} (ID: {term_id})")
                deleted_count += 1
            elif response.status_code == 404:
                print(f"   ⚠️  Déjà supprimé: {term_name}")
            else:
                print(f"   ❌ Erreur {response.status_code}: {term_name}")
                print(f"      Response: {response.text[:100]}")
        except Exception as e:
            print(f"   ❌ Exception: {str(e)}")
        
        time.sleep(0.3)
    
    print(f"\n✅ {deleted_count}/{len(terms)} Terms supprimés")
    return deleted_count == len(terms)

def delete_data_product(credential, dp_file="data_product_created.json"):
    """Supprimer le Data Product"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 3: SUPPRESSION DU DATA PRODUCT")
    print("=" * 80)
    
    try:
        with open(dp_file, "r") as f:
            data = json.load(f)
            dp_id = data.get("id")
            dp_name = data.get("name")
    except FileNotFoundError:
        print("⚠️  Fichier data_product_created.json introuvable - skip")
        return True
    
    token = credential.get_token("https://purview.azure.net/.default")
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print(f"\n📦 Data Product: {dp_name}")
    print(f"   ID: {dp_id}")
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/dataProducts/{dp_id}?api-version={API_VERSION}"
    
    try:
        response = requests.delete(url, headers=headers)
        if response.status_code in [200, 204]:
            print(f"\n✅ Data Product supprimé: {dp_name}")
            return True
        elif response.status_code == 404:
            print(f"\n⚠️  Data Product déjà supprimé")
            return True
        else:
            print(f"\n❌ Erreur {response.status_code}")
            print(f"Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"\n❌ Exception: {str(e)}")
        return False

def delete_business_domain(credential, domain_file="business_domain_created.json"):
    """Supprimer le Business Domain '3PL Logistics'"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 4: SUPPRESSION DU BUSINESS DOMAIN '3PL LOGISTICS'")
    print("=" * 80)
    
    try:
        with open(domain_file, "r") as f:
            data = json.load(f)
            domain_id = data.get("id")
            domain_name = data.get("name")
    except FileNotFoundError:
        print("⚠️  Fichier business_domain_created.json introuvable - skip")
        return True
    
    token = credential.get_token("https://purview.azure.net/.default")
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    print(f"\n📦 Domain: {domain_name}")
    print(f"   ID: {domain_id}")
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/businessdomains/{domain_id}?api-version={API_VERSION}"
    
    try:
        response = requests.delete(url, headers=headers)
        if response.status_code in [200, 204]:
            print(f"\n✅ Domain supprimé: {domain_name}")
            return True
        elif response.status_code == 404:
            print(f"\n⚠️  Domain déjà supprimé")
            return True
        else:
            print(f"\n❌ Erreur {response.status_code}")
            print(f"Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"\n❌ Exception: {str(e)}")
        return False

def main():
    print("\n" + "=" * 80)
    print("  NETTOYAGE COMPLET DE L'ARCHITECTURE PURVIEW")
    print("  Suppression: OKRs → Glossary → Data Product → Domain")
    print("=" * 80)
    
    print("\n⚠️  ATTENTION: Cette opération est irréversible!")
    print("   - 3 Objectives + 9 Key Results seront supprimés")
    print("   - 8 Glossary Terms seront supprimés")
    print("   - 1 Data Product sera supprimé (les tables resteront)")
    print("   - 1 Business Domain '3PL Logistics' sera supprimé")
    
    # Authenticate
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Execute deletions in order
    results = {
        "okrs": False,
        "glossary": False,
        "dataProduct": False,
        "domain": False
    }
    
    results["okrs"] = delete_okrs(credential)
    time.sleep(1)
    
    results["glossary"] = delete_glossary_terms(credential)
    time.sleep(1)
    
    results["dataProduct"] = delete_data_product(credential)
    time.sleep(1)
    
    results["domain"] = delete_business_domain(credential)
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ DU NETTOYAGE")
    print("=" * 80)
    
    print("\n📊 État:")
    print(f"   {'✅' if results['okrs'] else '❌'} OKRs supprimés")
    print(f"   {'✅' if results['glossary'] else '❌'} Glossary Terms supprimés")
    print(f"   {'✅' if results['dataProduct'] else '❌'} Data Product supprimé")
    print(f"   {'✅' if results['domain'] else '❌'} Domain '3PL Logistics' supprimé")
    
    all_success = all(results.values())
    
    if all_success:
        print("\n✅ Nettoyage complet réussi !")
        print("\n📝 Prochaines étapes:")
        print("   1. Recréer Data Product dans Domain 'Supply Chain'")
        print("   2. Recréer Glossary Terms")
        print("   3. Recréer OKRs")
        print("   4. Re-lier les 9 tables au nouveau Data Product")
    else:
        print("\n⚠️  Nettoyage partiel - vérifier les erreurs ci-dessus")
    
    print("\n🌐 Vérifier dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    print("   Unified Catalog → Domains → Supply Chain")
    
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
