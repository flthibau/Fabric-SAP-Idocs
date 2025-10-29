"""
Automate OneLake Availability activation and Lakehouse shortcuts creation
Uses Fabric REST API to configure the entire integration
"""
import requests
from azure.identity import DefaultAzureCredential
import json
import time

class FabricOneLakeAutomation:
    """Automate OneLake Availability and Shortcuts"""
    
    def __init__(self, workspace_id: str):
        self.workspace_id = workspace_id
        self.base_url = "https://api.fabric.microsoft.com/v1"
        
        # Get Azure AD token
        self.credential = DefaultAzureCredential()
        self.token = self._get_token()
        
        print(f"✅ Authenticated to Fabric API")
        print(f"   Workspace ID: {workspace_id}\n")
    
    def _get_token(self) -> str:
        """Get Azure AD access token for Fabric API"""
        token = self.credential.get_token("https://api.fabric.microsoft.com/.default")
        return token.token
    
    def _make_request(
        self, 
        method: str, 
        endpoint: str, 
        data: dict = None
    ) -> requests.Response:
        """Make authenticated REST API request"""
        url = f"{self.base_url}{endpoint}"
        
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json"
        }
        
        response = requests.request(
            method=method,
            url=url,
            headers=headers,
            json=data
        )
        
        return response
    
    def enable_onelake_availability_kql(
        self, 
        eventhouse_id: str,
        database_name: str,
        table_names: list
    ):
        """
        Enable OneLake Availability for KQL tables
        
        Note: L'API pour activer OneLake Availability sur les tables KQL
        n'est pas encore publique. Il faut utiliser le Fabric Portal.
        
        Cette fonction affiche les instructions manuelles.
        """
        print("="*80)
        print("ACTIVATION ONELAKE AVAILABILITY (Manuel)")
        print("="*80)
        print("\n⚠️ L'API OneLake Availability n'est pas encore publique.")
        print("   Activation manuelle requise via Fabric Portal:\n")
        
        eventhouse_url = f"https://app.fabric.microsoft.com/groups/{self.workspace_id}/databases/{eventhouse_id}"
        
        print(f"1. Ouvrez l'Eventhouse:")
        print(f"   {eventhouse_url}\n")
        
        print(f"2. Menu 'Settings' → 'OneLake availability'\n")
        
        print(f"3. Activez pour toutes les tables ou individuellement:")
        for table in table_names:
            print(f"   ✅ {table}")
        
        print(f"\n4. Cliquez 'Save' et attendez 2-5 minutes\n")
        
        print("="*80)
        print("\nAppuyez sur Entrée une fois l'activation terminée...")
        input()
    
    def create_lakehouse_shortcut(
        self,
        lakehouse_id: str,
        shortcut_name: str,
        target_path: str,
        target_workspace_id: str = None,
        target_item_id: str = None
    ):
        """
        Create a shortcut in Lakehouse pointing to OneLake location
        
        Args:
            lakehouse_id: Lakehouse GUID
            shortcut_name: Name for the shortcut
            target_path: Path to the target (e.g., /Tables/idoc_raw)
            target_workspace_id: Source workspace ID (default: same workspace)
            target_item_id: Source item ID (Eventhouse ID)
        """
        if not target_workspace_id:
            target_workspace_id = self.workspace_id
        
        endpoint = f"/workspaces/{self.workspace_id}/lakehouses/{lakehouse_id}/shortcuts"
        
        # Fabric Shortcuts API payload
        payload = {
            "name": shortcut_name,
            "path": target_path,
            "target": {
                "oneLake": {
                    "workspaceId": target_workspace_id,
                    "itemId": target_item_id,
                    "path": target_path
                }
            }
        }
        
        print(f"   Creating shortcut: {shortcut_name}")
        print(f"   Target: {target_path}")
        
        response = self._make_request("POST", endpoint, data=payload)
        
        if response.status_code in [200, 201, 202]:
            print(f"   ✅ Created successfully\n")
            return response.json() if response.text else {"name": shortcut_name}
        else:
            print(f"   ❌ Error {response.status_code}: {response.text}\n")
            return None
    
    def create_all_shortcuts(
        self,
        lakehouse_id: str,
        eventhouse_id: str,
        tables: list
    ):
        """Create shortcuts for all tables"""
        print("="*80)
        print("CRÉATION DES SHORTCUTS LAKEHOUSE")
        print("="*80)
        print(f"\nLakehouse ID: {lakehouse_id}")
        print(f"Eventhouse ID: {eventhouse_id}")
        print(f"Nombre de tables: {len(tables)}\n")
        
        shortcuts_created = []
        
        for table_name in tables:
            # Le path OneLake pour une table Eventhouse est:
            # /Tables/{table_name}
            target_path = f"/Tables/{table_name}"
            
            shortcut = self.create_lakehouse_shortcut(
                lakehouse_id=lakehouse_id,
                shortcut_name=table_name,
                target_path=target_path,
                target_item_id=eventhouse_id
            )
            
            if shortcut:
                shortcuts_created.append(shortcut)
            
            # Petit délai pour éviter le rate limiting
            time.sleep(0.5)
        
        print("="*80)
        print(f"✅ {len(shortcuts_created)}/{len(tables)} shortcuts créés")
        print("="*80)
        
        return shortcuts_created
    
    def verify_lakehouse_tables(self, lakehouse_id: str):
        """List tables in Lakehouse to verify shortcuts"""
        print("\n" + "="*80)
        print("VÉRIFICATION DES TABLES LAKEHOUSE")
        print("="*80)
        
        endpoint = f"/workspaces/{self.workspace_id}/lakehouses/{lakehouse_id}/tables"
        response = self._make_request("GET", endpoint)
        
        if response.status_code == 200:
            result = response.json()
            tables = result.get('value', [])
            
            print(f"\n📊 Tables trouvées: {len(tables)}\n")
            for table in tables:
                table_name = table.get('name', 'N/A')
                table_type = table.get('type', 'N/A')
                print(f"   ✅ {table_name} ({table_type})")
            
            return tables
        else:
            print(f"❌ Erreur {response.status_code}: {response.text}")
            return []


def main():
    """Main execution"""
    
    print("\n" + "="*80)
    print("FABRIC ONELAKE AUTOMATION - EVENTHOUSE → LAKEHOUSE")
    print("="*80)
    
    # Configuration
    WORKSPACE_ID = "ad53e547-23dc-46b0-ab5f-2acbaf0eec64"  # JAc
    EVENTHOUSE_ID = "5c2c08ee-cb8f-4248-a1c8-ea35a4e6e057"  # kqldbsapidoc
    LAKEHOUSE_ID = "21a1bc2d-92e4-41fb-8ca8-1c16569fc483"  # Lakehouse3PLAnalytics
    DATABASE_NAME = "kqldbsapidoc"
    
    # Tables à configurer
    TABLES = [
        # Bronze
        "idoc_raw",
        
        # Silver
        "idoc_orders_silver",
        "idoc_shipments_silver",
        "idoc_warehouse_silver",
        "idoc_invoices_silver",
        
        # Gold (Materialized Views)
        "orders_daily_summary",
        "sla_performance",
        "shipments_in_transit",
        "warehouse_productivity_daily",
        "revenue_recognition_realtime"
    ]
    
    print(f"\nWorkspace: JAc")
    print(f"Eventhouse: kqldbsapidoc ({EVENTHOUSE_ID})")
    print(f"Lakehouse: Lakehouse3PLAnalytics ({LAKEHOUSE_ID})")
    print(f"Tables: {len(TABLES)}")
    print("\n" + "="*80)
    
    try:
        # Initialize automation
        fabric = FabricOneLakeAutomation(workspace_id=WORKSPACE_ID)
        
        # ÉTAPE 1: Activer OneLake Availability (Manuel)
        print("\n🔄 ÉTAPE 1: Activation OneLake Availability\n")
        fabric.enable_onelake_availability_kql(
            eventhouse_id=EVENTHOUSE_ID,
            database_name=DATABASE_NAME,
            table_names=TABLES
        )
        
        # ÉTAPE 2: Créer les shortcuts (Automatique)
        print("\n🔄 ÉTAPE 2: Création des shortcuts Lakehouse\n")
        
        # Note: L'API Shortcuts est en preview et peut ne pas fonctionner
        # Tentons quand même
        
        try:
            shortcuts = fabric.create_all_shortcuts(
                lakehouse_id=LAKEHOUSE_ID,
                eventhouse_id=EVENTHOUSE_ID,
                tables=TABLES
            )
            
            if shortcuts:
                print(f"\n✅ Shortcuts créés avec succès!")
            else:
                print(f"\n⚠️ Création des shortcuts via API a échoué")
                print(f"   Utilisez le Fabric Portal pour créer manuellement:")
                print(f"\n   1. Ouvrez le Lakehouse:")
                print(f"      https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/lakehouses/{LAKEHOUSE_ID}")
                print(f"\n   2. Tables → ... → New shortcut → OneLake")
                print(f"\n   3. Sélectionnez: JAc / kqldbsapidoc / Tables/")
                print(f"\n   4. Créez un shortcut pour chaque table:")
                for table in TABLES:
                    print(f"      - {table}")
        
        except Exception as e:
            print(f"\n⚠️ API Shortcuts non disponible: {e}")
            print(f"\n📋 CRÉATION MANUELLE DES SHORTCUTS REQUISE:")
            print(f"\n1. Ouvrez le Lakehouse:")
            print(f"   https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/lakehouses/{LAKEHOUSE_ID}")
            print(f"\n2. Section 'Tables':")
            print(f"   - Cliquez '...' → 'New shortcut'")
            print(f"   - Source: OneLake")
            print(f"   - Workspace: JAc")
            print(f"   - Item: kqldbsapidoc")
            print(f"   - Path: Tables/")
            print(f"\n3. Créez shortcuts pour {len(TABLES)} tables:")
            for i, table in enumerate(TABLES, 1):
                print(f"   {i}. {table}")
            
            print(f"\n4. Ou créez un shortcut global:")
            print(f"   - Name: eventhouse_tables")
            print(f"   - Path: /Tables/ (toutes les tables)")
        
        # ÉTAPE 3: Vérifier les tables
        print(f"\n🔄 ÉTAPE 3: Vérification des tables Lakehouse")
        
        # Attendre un peu pour que les shortcuts se propagent
        print(f"\n⏳ Attente de 10 secondes pour la propagation...")
        time.sleep(10)
        
        tables = fabric.verify_lakehouse_tables(lakehouse_id=LAKEHOUSE_ID)
        
        # RÉSUMÉ
        print("\n" + "="*80)
        print("RÉSUMÉ DE LA CONFIGURATION")
        print("="*80)
        
        print(f"\n✅ Lakehouse: Lakehouse3PLAnalytics")
        print(f"   URL: https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/lakehouses/{LAKEHOUSE_ID}")
        
        print(f"\n✅ Eventhouse: kqldbsapidoc")
        print(f"   URL: https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/databases/{EVENTHOUSE_ID}")
        
        print(f"\n📊 Configuration attendue:")
        print(f"   - OneLake Availability: {len(TABLES)} tables")
        print(f"   - Lakehouse Shortcuts: {len(TABLES)} shortcuts")
        print(f"   - Tables découvertes: {len(tables)}")
        
        print("\n" + "="*80)
        print("PROCHAINES ÉTAPES")
        print("="*80)
        
        print("\n1. Vérifier les shortcuts dans Lakehouse:")
        print(f"   https://app.fabric.microsoft.com/groups/{WORKSPACE_ID}/lakehouses/{LAKEHOUSE_ID}")
        
        print("\n2. Tester les tables via SQL Endpoint:")
        print(f"   SELECT * FROM INFORMATION_SCHEMA.TABLES;")
        
        print("\n3. Déclencher scan Purview:")
        print(f"   cd governance/purview")
        print(f"   python purview_automation.py")
        
        print("\n4. Vérifier assets découverts:")
        print(f"   python list_discovered_assets.py --filter 'Lakehouse3PLAnalytics'")
        
        print("\n5. Créer Business Domain et Data Product dans Purview Portal")
        
        print("\n" + "="*80)
        
        return True
        
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    success = main()
    
    if success:
        print(f"\n✅ Configuration terminée!")
    else:
        print(f"\n❌ Configuration échouée - vérifiez les erreurs ci-dessus")
