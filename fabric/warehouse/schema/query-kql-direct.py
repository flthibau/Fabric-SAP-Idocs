"""
Script pour interroger directement la base KQL avec Azure CLI authentication
"""
import sys
from azure.kusto.data import KustoClient, KustoConnectionStringBuilder
from azure.kusto.data.helpers import dataframe_from_result_table
from azure.identity import AzureCliCredential

# Configuration
CLUSTER_URI = "https://trd-50gjamacvb06uc7dnr.z8.kusto.fabric.microsoft.com"
DATABASE = "kqldbsapidoc"

def query_kusto(kql_query):
    """Exécute une requête KQL et affiche les résultats"""
    try:
        # Authentification avec Azure CLI
        credential = AzureCliCredential()
        
        # Connexion au cluster Kusto
        kcsb = KustoConnectionStringBuilder.with_azure_token_credential(
            CLUSTER_URI, 
            credential
        )
        
        client = KustoClient(kcsb)
        
        # Exécution de la requête
        print(f"\n{'='*70}")
        print(f"Exécution: {kql_query[:100]}...")
        print(f"{'='*70}\n")
        
        response = client.execute(DATABASE, kql_query)
        
        # Affichage des résultats
        for row in response.primary_results[0]:
            print(row)
            
        print(f"\n{'='*70}")
        print(f"✓ Requête terminée - {response.primary_results[0].rows_count} lignes")
        print(f"{'='*70}\n")
        
    except Exception as e:
        print(f"❌ Erreur: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        query = sys.argv[1]
    else:
        # Requête par défaut: afficher un échantillon
        query = "idoc_raw | take 1 | project RawPayload"
    
    query_kusto(query)
