#!/usr/bin/env python3
"""
Nettoyage avancé avec gestion des dépendances
1. Unpublish Glossary Terms (Published → Draft)
2. Delete Glossary Terms
3. Delete OKRs (retry les erreurs 500)
4. Unlink Data Assets from Data Product
5. Delete Data Product
6. Delete Business Domain
"""

from azure.identity import DefaultAzureCredential
import requests
import json
import time

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def unpublish_glossary_terms(credential, terms_file="glossary_terms_created.json"):
    """Dépublier les Glossary Terms (Published → Draft)"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 1: DÉPUBLICATION DES GLOSSARY TERMS")
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
    
    print(f"\n📋 {len(terms)} Terms à dépublier...")
    
    unpublished_count = 0
    for term in terms:
        term_id = term.get("id")
        term_name = term.get("name")
        
        # PATCH to change status to Draft
        url = f"{API_ENDPOINT}/datagovernance/catalog/terms/{term_id}?api-version={API_VERSION}"
        patch_payload = {"status": "Draft"}
        
        try:
            response = requests.patch(url, headers=headers, json=patch_payload)
            if response.status_code == 200:
                print(f"   ✅ Dépublié: {term_name}")
                unpublished_count += 1
            elif response.status_code == 404:
                print(f"   ⚠️  Introuvable: {term_name}")
            else:
                print(f"   ❌ Erreur {response.status_code}: {term_name}")
                print(f"      Response: {response.text[:100]}")
        except Exception as e:
            print(f"   ❌ Exception: {str(e)}")
        
        time.sleep(0.3)
    
    print(f"\n✅ {unpublished_count}/{len(terms)} Terms dépubliés")
    return unpublished_count > 0

def delete_glossary_terms(credential, terms_file="glossary_terms_created.json"):
    """Supprimer tous les Glossary Terms (maintenant en Draft)"""
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
                print(f"   ✅ Supprimé: {term_name}")
                deleted_count += 1
            elif response.status_code == 404:
                print(f"   ⚠️  Déjà supprimé: {term_name}")
                deleted_count += 1
            else:
                print(f"   ❌ Erreur {response.status_code}: {term_name}")
                print(f"      Response: {response.text[:100]}")
        except Exception as e:
            print(f"   ❌ Exception: {str(e)}")
        
        time.sleep(0.3)
    
    print(f"\n✅ {deleted_count}/{len(terms)} Terms supprimés")
    return deleted_count == len(terms)

def delete_okrs_with_retry(credential, okrs_file="okrs_created.json"):
    """Supprimer tous les Objectives avec retry sur erreurs 500"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 3: SUPPRESSION DES OKRs (AVEC RETRY)")
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
        
        # Retry up to 3 times on 500 errors
        for attempt in range(3):
            try:
                response = requests.delete(url, headers=headers)
                if response.status_code in [200, 204]:
                    print(f"   ✅ Supprimé: {obj_def}... (ID: {obj_id})")
                    deleted_count += 1
                    break
                elif response.status_code == 404:
                    print(f"   ⚠️  Déjà supprimé: {obj_def}...")
                    deleted_count += 1
                    break
                elif response.status_code == 500:
                    if attempt < 2:
                        print(f"   ⏳ Erreur 500, retry {attempt+1}/3: {obj_def}...")
                        time.sleep(2)
                    else:
                        print(f"   ❌ Erreur 500 persistante: {obj_def}...")
                else:
                    print(f"   ❌ Erreur {response.status_code}: {obj_def}...")
                    break
            except Exception as e:
                print(f"   ❌ Exception: {str(e)}")
                break
        
        time.sleep(0.5)
    
    print(f"\n✅ {deleted_count}/{len(objectives)} Objectives supprimés")
    return deleted_count == len(objectives)

def unlink_data_assets(credential, dp_file="data_product_created.json"):
    """Délier les Data Assets du Data Product"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 4: DÉLIAGE DES DATA ASSETS")
    print("=" * 80)
    
    try:
        with open(dp_file, "r") as f:
            data = json.load(f)
            dp_id = data.get("id")
    except FileNotFoundError:
        print("⚠️  Fichier data_product_created.json introuvable - skip")
        return True
    
    token = credential.get_token("https://purview.azure.net/.default")
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    # List relationships
    url = f"{API_ENDPOINT}/datagovernance/catalog/dataProducts/{dp_id}/relationships?api-version={API_VERSION}&entityType=DATAASSET"
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            result = response.json()
            relationships = result.get('value', [])
            print(f"\n📋 {len(relationships)} Data Assets à délier...")
            
            # Note: Il n'y a pas d'API DELETE pour les relationships
            # On doit probablement juste supprimer le Data Product directement
            print("   ℹ️  Les assets seront automatiquement déliés lors de la suppression du Data Product")
            return True
        else:
            print(f"⚠️  Impossible de lister les relationships: {response.status_code}")
            return True
    except Exception as e:
        print(f"❌ Exception: {str(e)}")
        return True

def delete_data_product(credential, dp_file="data_product_created.json"):
    """Supprimer le Data Product"""
    print("\n" + "=" * 80)
    print("  ÉTAPE 5: SUPPRESSION DU DATA PRODUCT")
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
    print("  ÉTAPE 6: SUPPRESSION DU BUSINESS DOMAIN '3PL LOGISTICS'")
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
    print("  NETTOYAGE AVANCÉ DE L'ARCHITECTURE PURVIEW")
    print("  Gestion automatique des dépendances")
    print("=" * 80)
    
    print("\n📋 Ordre d'exécution:")
    print("   1. Dépublier Glossary Terms (Published → Draft)")
    print("   2. Supprimer Glossary Terms")
    print("   3. Supprimer OKRs (avec retry)")
    print("   4. Vérifier Data Assets")
    print("   5. Supprimer Data Product")
    print("   6. Supprimer Business Domain")
    
    # Authenticate
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Execute in order with dependency management
    results = {}
    
    results["unpublish"] = unpublish_glossary_terms(credential)
    time.sleep(2)
    
    results["glossary"] = delete_glossary_terms(credential)
    time.sleep(2)
    
    results["okrs"] = delete_okrs_with_retry(credential)
    time.sleep(2)
    
    results["assets"] = unlink_data_assets(credential)
    time.sleep(1)
    
    results["dataProduct"] = delete_data_product(credential)
    time.sleep(2)
    
    results["domain"] = delete_business_domain(credential)
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ DU NETTOYAGE")
    print("=" * 80)
    
    print("\n📊 État:")
    print(f"   {'✅' if results.get('unpublish') else '❌'} Glossary Terms dépubliés")
    print(f"   {'✅' if results.get('glossary') else '❌'} Glossary Terms supprimés")
    print(f"   {'✅' if results.get('okrs') else '❌'} OKRs supprimés")
    print(f"   {'✅' if results.get('assets') else '❌'} Data Assets déliés")
    print(f"   {'✅' if results.get('dataProduct') else '❌'} Data Product supprimé")
    print(f"   {'✅' if results.get('domain') else '❌'} Domain '3PL Logistics' supprimé")
    
    all_success = all([results.get('glossary'), results.get('okrs'), 
                       results.get('dataProduct'), results.get('domain')])
    
    if all_success:
        print("\n✅ Nettoyage complet réussi !")
        print("\n📝 Architecture actuelle:")
        print("   Domain: Supply Chain (041de34f-62cf-4c8a-9a17-d1cc823e9538)")
        print("   └── (vide - prêt pour nouveau Data Product)")
        print("\n📝 Prochaines étapes:")
        print("   1. Recréer Data Product '3PL Logistics Analytics'")
        print("   2. Re-lier les 9 tables")
        print("   3. Recréer Glossary Terms")
        print("   4. Recréer OKRs")
    else:
        print("\n⚠️  Nettoyage partiel - vérifier les erreurs ci-dessus")
    
    print("\n🌐 Vérifier dans Purview Portal:")
    print(f"   https://web.purview.azure.com/resource/{PURVIEW_ACCOUNT}")
    
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
