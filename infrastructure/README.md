# Infrastructure as Code

## Overview

Infrastructure as Code (IaC) templates for deploying the SAP 3PL Logistics Data Product to Azure using Bicep or Terraform.

## Structure

```
infrastructure/
├── bicep/
│   ├── main.bicep                    # Main deployment template
│   ├── modules/
│   │   ├── eventhub.bicep            # Event Hub namespace
│   │   ├── fabric-workspace.bicep    # Fabric workspace
│   │   ├── apim.bicep                # API Management
│   │   ├── purview.bicep             # Purview account
│   │   ├── container-apps.bicep      # GraphQL API hosting
│   │   └── monitoring.bicep          # Application Insights
│   ├── parameters/
│   │   ├── dev.parameters.json       # Development environment
│   │   ├── test.parameters.json      # Test environment
│   │   └── prod.parameters.json      # Production environment
│   └── README.md
└── terraform/
    ├── main.tf                        # Main configuration
    ├── variables.tf                   # Variable definitions
    ├── outputs.tf                     # Output values
    ├── modules/
    │   ├── eventhub/
    │   ├── fabric/
    │   ├── apim/
    │   └── purview/
    ├── environments/
    │   ├── dev.tfvars
    │   ├── test.tfvars
    │   └── prod.tfvars
    └── README.md
```

## Prerequisites

### For Bicep
- Azure CLI 2.50+
- Bicep CLI
- Azure subscription
- Appropriate permissions (Contributor or Owner)

### For Terraform
- Terraform 1.5+
- Azure CLI
- Azure subscription
- Service Principal (for automation)

## Quick Start

### Using Bicep

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>

# Deploy to development
az deployment sub create \
  --name sap-3pl-dev \
  --location eastus \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/dev.parameters.json

# Deploy to production
az deployment sub create \
  --name sap-3pl-prod \
  --location eastus \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/prod.parameters.json
```

### Using Terraform

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan deployment (dev)
terraform plan -var-file="environments/dev.tfvars"

# Apply deployment (dev)
terraform apply -var-file="environments/dev.tfvars"

# Deploy to production
terraform apply -var-file="environments/prod.tfvars"
```

## Resources Deployed

### Core Infrastructure

1. **Resource Group**
   - Name: `rg-sap-3pl-{environment}`
   - Location: Configurable per environment

2. **Event Hub Namespace**
   - Name: `evhns-sap-3pl-{environment}`
   - SKU: Standard (dev/test), Premium (prod)
   - Event Hub: `sap-idocs`
   - Partitions: 4 (dev/test), 32 (prod)
   - Retention: 7 days

3. **Microsoft Fabric**
   - Workspace: `sap-3pl-{environment}`
   - Capacity: F64 (dev), F256 (prod)
   - Lakehouse: `sap-idoc-lakehouse`
   - Warehouse: `sap-3pl-warehouse`

4. **Azure API Management**
   - Name: `apim-sap-3pl-{environment}`
   - SKU: Developer (dev/test), Standard (prod)
   - APIs: GraphQL, REST

5. **Container Apps Environment**
   - Name: `cae-sap-3pl-{environment}`
   - GraphQL API container
   - Auto-scaling configuration

6. **Microsoft Purview**
   - Account: `purview-sap-3pl`
   - Collections: Logistics/SAP-3PL-Operations
   - Data sources: Fabric, APIM

7. **Monitoring**
   - Application Insights: `appi-sap-3pl-{environment}`
   - Log Analytics Workspace: `law-sap-3pl-{environment}`

### Networking (Optional - Production)

8. **Virtual Network**
   - Name: `vnet-sap-3pl-{environment}`
   - Address space: 10.0.0.0/16
   - Subnets: Container Apps, APIM, Private Endpoints

9. **Private Endpoints**
   - Event Hub
   - Storage (Fabric)
   - Purview

## Configuration

### Environment Variables

Each environment has different parameters:

**Development**
```json
{
  "environment": "dev",
  "location": "eastus",
  "eventHubSku": "Standard",
  "fabricCapacity": "F64",
  "apimSku": "Developer"
}
```

**Production**
```json
{
  "environment": "prod",
  "location": "eastus",
  "eventHubSku": "Premium",
  "fabricCapacity": "F256",
  "apimSku": "Standard"
}
```

### Naming Convention

Resources follow Azure naming best practices:

- Resource Group: `rg-{project}-{environment}`
- Event Hub: `evhns-{project}-{environment}`
- APIM: `apim-{project}-{environment}`
- Container App: `ca-{project}-{component}-{environment}`

## Deployment Workflows

### CI/CD with Azure DevOps

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop

stages:
  - stage: Validate
    jobs:
      - job: ValidateBicep
        steps:
          - task: AzureCLI@2
            inputs:
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                az bicep build --file infrastructure/bicep/main.bicep

  - stage: DeployDev
    dependsOn: Validate
    jobs:
      - deployment: DeployInfrastructure
        environment: development
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    scriptType: 'bash'
                    scriptLocation: 'inlineScript'
                    inlineScript: |
                      az deployment sub create \
                        --name sap-3pl-dev-$(Build.BuildId) \
                        --location eastus \
                        --template-file infrastructure/bicep/main.bicep \
                        --parameters infrastructure/bicep/parameters/dev.parameters.json

  - stage: DeployProd
    dependsOn: DeployDev
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployInfrastructure
        environment: production
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  # Production deployment steps
```

### CI/CD with GitHub Actions

```yaml
# .github/workflows/infrastructure.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main, develop]
    paths:
      - 'infrastructure/**'

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Validate Bicep
        run: |
          az bicep build --file infrastructure/bicep/main.bicep

  deploy-dev:
    needs: validate
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy to Dev
        run: |
          az deployment sub create \
            --name sap-3pl-dev-${{ github.run_number }} \
            --location eastus \
            --template-file infrastructure/bicep/main.bicep \
            --parameters infrastructure/bicep/parameters/dev.parameters.json

  deploy-prod:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Production
        # Production deployment steps
```

## Cost Estimation

### Development Environment
- Event Hub Standard: ~$50/month
- Fabric F64: ~$500/month
- APIM Developer: ~$50/month
- Container Apps: ~$30/month
- **Total: ~$630/month**

### Production Environment
- Event Hub Premium: ~$500/month
- Fabric F256: ~$2,000/month
- APIM Standard: ~$250/month
- Container Apps: ~$100/month
- Purview: ~$200/month
- **Total: ~$3,050/month**

## Security Configuration

### Managed Identity

All resources use Managed Identity where possible:
- Container Apps → SQL Warehouse
- APIM → Backend services
- Event Hub → Fabric Eventstream

### Key Vault Integration

```bicep
// Store secrets in Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-sap-3pl-${environment}'
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    accessPolicies: []
    enableRbacAuthorization: true
  }
}

// Store connection strings
resource eventHubConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'EventHubConnectionString'
  properties: {
    value: eventHubNamespace.listKeys().primaryConnectionString
  }
}
```

### Network Security

Production environment includes:
- Private endpoints for all PaaS services
- Network Security Groups
- Application Gateway with WAF
- DDoS Protection Standard

## Disaster Recovery

### Backup Strategy

1. **Fabric Data**
   - Delta Lake tables: Geo-redundant storage
   - Warehouse: Automated backups (7 days)

2. **Event Hub**
   - Geo-disaster recovery pairing
   - Automatic failover

3. **APIM**
   - Configuration backup
   - Multi-region deployment (prod)

### Recovery Procedures

```bash
# Restore from backup
az deployment sub create \
  --name restore-sap-3pl \
  --template-file bicep/disaster-recovery.bicep \
  --parameters backupDate=2025-10-22
```

## Monitoring

### Deployed Monitoring Resources

- Application Insights for API telemetry
- Log Analytics for centralized logging
- Alerts for critical failures
- Dashboards for operational metrics

### Key Metrics

- Event Hub: Incoming/Outgoing messages, Throttled requests
- Fabric: Query performance, Storage usage
- APIM: Request rate, Response time, Errors
- Container Apps: CPU/Memory usage, Request latency

## Maintenance

### Regular Tasks

1. **Weekly**
   - Review cost analysis
   - Check resource health
   - Review security alerts

2. **Monthly**
   - Update terraform/bicep modules
   - Review and optimize costs
   - Security vulnerability scanning

3. **Quarterly**
   - Disaster recovery testing
   - Capacity planning review
   - Architecture review

## Troubleshooting

### Common Issues

1. **Deployment Failed**
   ```bash
   # Check deployment logs
   az deployment sub show \
     --name sap-3pl-dev \
     --query properties.error
   ```

2. **Resource Quota Exceeded**
   ```bash
   # Check quotas
   az vm list-usage --location eastus -o table
   ```

3. **Permission Issues**
   ```bash
   # Verify permissions
   az role assignment list --assignee <user-or-sp-id>
   ```

## Clean Up

### Remove All Resources

```bash
# Using Bicep/ARM
az group delete --name rg-sap-3pl-dev --yes

# Using Terraform
terraform destroy -var-file="environments/dev.tfvars"
```

## Best Practices

1. **Use modules** for reusable components
2. **Parameterize** environment-specific values
3. **Tag all resources** for cost tracking
4. **Use managed identities** instead of secrets
5. **Enable diagnostics** on all resources
6. **Implement RBAC** with least privilege
7. **Use private endpoints** in production
8. **Automate deployments** via CI/CD
9. **Version control** all IaC templates
10. **Test in dev** before production deployment

## Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)

## Support

- Infrastructure Team: infrastructure@company.com
- Cloud Architect: cloud-architect@company.com
