# Project Structure

This document provides an overview of the complete project structure for the SAP IDoc to Microsoft Fabric Data Product.

## Directory Tree

```
Fabric+SAP+Idocs/
│
├── README.md                           # Main project documentation
├── .gitignore                          # Git ignore rules
├── LICENSE                             # Project license
│
├── docs/                               # Documentation
│   ├── architecture.md                 # Architecture documentation
│   ├── api-documentation.md            # API reference guide
│   └── governance-guide.md             # Data governance guide
│
├── simulator/                          # SAP IDoc Simulator
│   ├── README.md                       # Simulator documentation
│   ├── requirements.txt                # Python dependencies
│   ├── .env.example                    # Environment variables template
│   ├── src/
│   │   ├── __init__.py
│   │   ├── idoc_generator.py          # Main IDoc generation logic
│   │   ├── eventstream_publisher.py   # Event Hub publisher
│   │   ├── idoc_schemas/              # IDoc schema definitions
│   │   │   ├── __init__.py
│   │   │   ├── base_schema.py         # Base IDoc schema class
│   │   │   ├── desadv_schema.py       # Delivery notification
│   │   │   ├── shpmnt_schema.py       # Shipment
│   │   │   ├── invoice_schema.py      # Invoice
│   │   │   ├── orders_schema.py       # Purchase order
│   │   │   └── whscon_schema.py       # Warehouse confirmation
│   │   └── utils/
│   │       ├── __init__.py
│   │       ├── data_generator.py      # Helper functions
│   │       └── logger.py              # Logging configuration
│   ├── config/
│   │   ├── config.yaml                # Main configuration
│   │   └── scenarios.yaml             # Business scenarios
│   └── tests/
│       ├── __init__.py
│       ├── test_generator.py
│       ├── test_publisher.py
│       └── test_schemas.py
│
├── fabric/                             # Microsoft Fabric components
│   ├── README.md                       # Fabric documentation
│   ├── eventstream/
│   │   ├── eventstream-config.json    # Eventstream configuration
│   │   └── transformation-rules.json  # Data transformation rules
│   ├── data-engineering/
│   │   ├── notebooks/                 # Spark notebooks
│   │   │   ├── bronze_to_silver.ipynb # Bronze → Silver transformation
│   │   │   ├── silver_to_gold.ipynb   # Silver → Gold transformation
│   │   │   ├── data_quality_checks.ipynb # Quality validation
│   │   │   └── data_enrichment.ipynb  # Data enrichment
│   │   └── pipelines/                 # Pipeline definitions
│   │       ├── ingestion_pipeline.json
│   │       ├── transformation_pipeline.json
│   │       └── quality_pipeline.json
│   └── warehouse/
│       └── schema/                    # SQL DDL scripts
│           ├── bronze_tables.sql      # Bronze layer tables
│           ├── silver_tables.sql      # Silver layer tables
│           ├── gold_dimensions.sql    # Dimension tables
│           ├── gold_facts.sql         # Fact tables
│           └── views.sql              # Analytical views
│
├── api/                                # API Layer
│   ├── README.md                       # API documentation
│   ├── graphql/                        # GraphQL API
│   │   ├── README.md
│   │   ├── package.json               # Node.js dependencies (or .csproj for .NET)
│   │   ├── .env.example
│   │   ├── schema/
│   │   │   ├── schema.graphql         # GraphQL schema definition
│   │   │   └── types.graphql          # Type definitions
│   │   ├── resolvers/                 # Resolver implementations
│   │   │   ├── shipment.js (or .cs)
│   │   │   ├── customer.js (or .cs)
│   │   │   ├── delivery.js (or .cs)
│   │   │   ├── location.js (or .cs)
│   │   │   └── metrics.js (or .cs)
│   │   ├── dataloaders/               # Data loaders for batching
│   │   │   ├── shipment-loader.js
│   │   │   └── customer-loader.js
│   │   ├── middleware/                # Middleware functions
│   │   │   ├── auth.js
│   │   │   ├── error-handler.js
│   │   │   └── logging.js
│   │   ├── server.js                  # Server entry point (Node.js)
│   │   ├── Program.cs                 # Program entry point (.NET)
│   │   ├── Dockerfile                 # Container image
│   │   └── tests/
│   │       ├── resolvers.test.js
│   │       └── integration.test.js
│   └── apim/                          # API Management
│       ├── README.md
│       ├── policies/                  # APIM policies
│       │   ├── graphql-policy.xml    # GraphQL endpoint policy
│       │   ├── rest-transform.xml    # GraphQL to REST transformation
│       │   ├── rate-limit.xml        # Rate limiting
│       │   ├── auth-policy.xml       # Authentication
│       │   └── cors-policy.xml       # CORS configuration
│       └── api-definitions/          # API definitions
│           ├── graphql-api.json      # GraphQL API definition
│           ├── rest-api.json         # REST API definition
│           └── openapi.yaml          # OpenAPI specification
│
├── governance/                        # Data Governance
│   ├── README.md                      # Governance documentation
│   ├── purview/                       # Purview configurations
│   │   ├── data-product-definition.json    # Data product metadata
│   │   ├── data-quality-rules.json         # Quality rules
│   │   ├── catalog-registration.json       # Asset registration
│   │   ├── business-glossary.json          # Business terms
│   │   ├── classification-rules.json       # Classification rules
│   │   └── lineage-config.json             # Lineage configuration
│   └── scripts/                       # Governance scripts
│       ├── requirements.txt
│       ├── .env.example
│       ├── register_data_product.py   # Register in Purview
│       ├── setup_quality_rules.py     # Configure quality rules
│       ├── scan_assets.py             # Trigger scans
│       ├── apply_classifications.py   # Apply classifications
│       ├── register_lineage.py        # Register lineage
│       ├── register_api.py            # Register APIs
│       ├── import_glossary.py         # Import glossary
│       ├── export_glossary.py         # Export glossary
│       ├── run_quality_checks.py      # Execute quality checks
│       └── generate_reports.py        # Generate reports
│
└── infrastructure/                    # Infrastructure as Code
    ├── README.md                      # IaC documentation
    ├── bicep/                         # Azure Bicep templates
    │   ├── main.bicep                # Main deployment
    │   ├── modules/                  # Reusable modules
    │   │   ├── eventhub.bicep       # Event Hub namespace
    │   │   ├── fabric-workspace.bicep # Fabric workspace
    │   │   ├── apim.bicep           # API Management
    │   │   ├── purview.bicep        # Purview account
    │   │   ├── container-apps.bicep # Container Apps
    │   │   ├── monitoring.bicep     # Application Insights
    │   │   ├── keyvault.bicep       # Key Vault
    │   │   └── networking.bicep     # Virtual Network
    │   └── parameters/              # Parameter files
    │       ├── dev.parameters.json  # Development
    │       ├── test.parameters.json # Test
    │       └── prod.parameters.json # Production
    └── terraform/                    # Terraform templates
        ├── main.tf                   # Main configuration
        ├── variables.tf              # Variable definitions
        ├── outputs.tf                # Output values
        ├── providers.tf              # Provider configuration
        ├── modules/                  # Reusable modules
        │   ├── eventhub/
        │   │   ├── main.tf
        │   │   ├── variables.tf
        │   │   └── outputs.tf
        │   ├── fabric/
        │   ├── apim/
        │   ├── purview/
        │   ├── container-apps/
        │   └── monitoring/
        └── environments/             # Environment configs
            ├── dev.tfvars
            ├── test.tfvars
            └── prod.tfvars
```

## Key Components

### 1. Simulator (Python)
Python-based SAP IDoc message generator that publishes to Azure Event Hubs.

### 2. Fabric (Cloud)
Microsoft Fabric components including Eventstream, Lakehouse, and SQL Warehouse.

### 3. API (Node.js/.NET)
GraphQL API layer with APIM for governance and REST transformation.

### 4. Governance (Python)
Microsoft Purview integration for data catalog, quality, and lineage.

### 5. Infrastructure (Bicep/Terraform)
Infrastructure as Code for automated deployment to Azure.

## File Naming Conventions

- **Python files**: `snake_case.py`
- **JavaScript/TypeScript**: `kebab-case.js` or `camelCase.js`
- **C# files**: `PascalCase.cs`
- **Configuration**: `kebab-case.json|yaml|xml`
- **Documentation**: `kebab-case.md`
- **SQL scripts**: `snake_case.sql`
- **IaC templates**: `kebab-case.bicep|tf`

## Development Workflow

1. **Local Development**
   - Simulator: Run locally with Python venv
   - GraphQL API: Run locally with Node.js or .NET
   - Test against dev Event Hub and Fabric workspace

2. **Testing**
   - Unit tests for each component
   - Integration tests for end-to-end flow
   - Quality tests for data validation

3. **Deployment**
   - Infrastructure: Deploy via Bicep/Terraform
   - Applications: Deploy via CI/CD pipelines
   - Governance: Configure Purview via scripts

4. **Monitoring**
   - Application Insights for API telemetry
   - Fabric monitoring for data pipelines
   - Purview for data quality metrics

## Getting Started

1. Clone the repository
2. Follow setup instructions in each component's README
3. Deploy infrastructure (infrastructure/)
4. Configure Fabric components (fabric/)
5. Set up governance (governance/)
6. Deploy GraphQL API (api/graphql/)
7. Run IDoc simulator (simulator/)

## Support

- Technical Documentation: See `docs/` directory
- Component-specific help: See each component's README.md
- Issues: Create GitHub issue or contact support team
