#!/usr/bin/env python3
"""
Supprimer les Glossary Terms créés au niveau du Domain (erreur - doivent être au niveau Data Product)
"""

from azure.identity import DefaultAzureCredential
import requests
import json

# Configuration
PURVIEW_ACCOUNT = "stpurview"
API_ENDPOINT = f"https://{PURVIEW_ACCOUNT}.purview.azure.com"
API_VERSION = "2025-09-15-preview"

def delete_term(credential, term_id, term_name):
    """Delete a Glossary Term"""
    token = credential.get_token("https://purview.azure.net/.default")
    
    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }
    
    url = f"{API_ENDPOINT}/datagovernance/catalog/terms/{term_id}?api-version={API_VERSION}"
    
    try:
        response = requests.delete(url, headers=headers)
        
        if response.status_code == 204:
            print(f"   ✅ Deleted: {term_name}")
            return True
        else:
            print(f"   ❌ Failed: {term_name} (Status: {response.status_code})")
            print(f"      Response: {response.text}")
            return False
    except Exception as e:
        print(f"   ❌ Error deleting {term_name}: {str(e)}")
        return False

def main():
    print("\n" + "=" * 80)
    print("  SUPPRESSION DES GLOSSARY TERMS (créés au niveau Domain par erreur)")
    print("=" * 80)
    
    # Load terms to delete
    try:
        with open("glossary_terms_supply_chain.json", "r") as f:
            terms = json.load(f)
    except FileNotFoundError:
        print("❌ ERROR: glossary_terms_supply_chain.json not found!")
        exit(1)
    
    print(f"\n📋 Termes à supprimer: {len(terms)}")
    
    # Authenticate
    print("\n🔐 Authentification...")
    credential = DefaultAzureCredential()
    
    # Delete each term
    print(f"\n🗑️  Suppression des {len(terms)} termes...")
    deleted_count = 0
    
    for term in terms:
        term_id = term.get("id")
        term_name = term.get("name")
        if delete_term(credential, term_id, term_name):
            deleted_count += 1
    
    # Summary
    print("\n" + "=" * 80)
    print("  RÉSUMÉ")
    print("=" * 80)
    print(f"\n✅ Termes supprimés: {deleted_count}/{len(terms)}")
    
    if deleted_count == len(terms):
        print("\n✨ Tous les termes ont été supprimés avec succès!")
        print("\nProchaine étape:")
        print("   Recréer les termes au niveau du Data Product (a4f24a45...)")
    else:
        print("\n⚠️  Certains termes n'ont pas pu être supprimés.")
        print("   Vérifiez s'ils sont Published (nécessite unpublish via Portal)")
    
    print("\n" + "=" * 80 + "\n")

if __name__ == "__main__":
    main()
