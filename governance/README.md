# Data Governance

## Overview

This directory contains Microsoft Purview configurations, data quality rules, and governance scripts for the SAP 3PL Logistics Data Product.

## Structure

```
governance/
├── purview/
│   ├── data-product-definition.json    # Data product metadata
│   ├── data-quality-rules.json         # Quality validation rules
│   ├── catalog-registration.json       # Catalog asset registration
│   ├── business-glossary.json          # Business terms and definitions
│   ├── classification-rules.json       # Auto-classification rules
│   └── lineage-config.json             # Lineage tracking configuration
└── scripts/
    ├── register_data_product.py        # Register data product in Purview
    ├── setup_quality_rules.py          # Configure data quality rules
    ├── scan_assets.py                  # Trigger asset scanning
    └── generate_reports.py             # Generate governance reports
```

## Prerequisites

- Microsoft Purview account
- Azure subscription
- Python 3.11+
- Azure CLI
- Appropriate permissions (Data Curator or higher)

## Setup

### 1. Install Dependencies

```bash
cd governance/scripts

# Create virtual environment
python -m venv venv
.\venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Authentication

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>

# Configure environment variables
cp .env.example .env
```

Edit `.env`:
```bash
PURVIEW_ACCOUNT_NAME=your-purview-account
PURVIEW_ENDPOINT=https://your-purview.purview.azure.com
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-client-secret
```

## Data Product Registration

### Register in Purview

```bash
# Register the data product
python scripts/register_data_product.py

# Output:
# ✓ Data product registered: SAP-3PL-Logistics-Operations
# ✓ Assets linked: 12
# ✓ Business glossary updated: 15 terms
```

The registration includes:
- Data product metadata
- Ownership information
- SLA definitions
- Asset relationships
- Business context

### Data Product Metadata

Defined in `purview/data-product-definition.json`:

```json
{
  "name": "SAP-3PL-Logistics-Operations",
  "domain": "Logistics",
  "owner": "data-product-team@company.com",
  "sla": {
    "availability": 99.9,
    "latency": 5,
    "freshness": 1
  }
}
```

## Data Quality Framework

### Configure Quality Rules

```bash
# Set up all quality rules
python scripts/setup_quality_rules.py

# Set up specific dimension
python scripts/setup_quality_rules.py --dimension completeness
```

### Quality Dimensions

1. **Completeness** - Required fields populated
2. **Accuracy** - Data correctly represents reality
3. **Consistency** - Data consistent across systems
4. **Timeliness** - Data available within SLA
5. **Validity** - Data conforms to business rules
6. **Uniqueness** - No duplicate records

### Quality Rules Definition

Edit `purview/data-quality-rules.json`:

```json
{
  "rules": [
    {
      "name": "Shipment Required Fields",
      "dimension": "Completeness",
      "threshold": 99.5,
      "condition": "shipment_id IS NOT NULL",
      "action": "Alert"
    }
  ]
}
```

### Run Quality Checks

```bash
# Run all quality checks
python scripts/run_quality_checks.py

# Run for specific table
python scripts/run_quality_checks.py --table silver_shipments

# Generate quality report
python scripts/run_quality_checks.py --report
```

## Catalog Management

### Register Assets

```bash
# Scan and register all assets
python scripts/scan_assets.py

# Register specific asset
python scripts/scan_assets.py --asset fabric://lakehouse/silver_shipments
```

### Business Glossary

The business glossary is defined in `purview/business-glossary.json`:

- **Shipment**: A collection of goods being transported
- **Delivery**: Transfer of goods to recipient
- **On-Time Delivery**: Delivery by estimated date
- **3PL**: Third-Party Logistics provider

### Update Glossary

```bash
# Import business glossary
python scripts/import_glossary.py --file purview/business-glossary.json

# Export current glossary
python scripts/export_glossary.py --output glossary-export.json
```

## Data Classification

### Auto-Classification Rules

Configured in `purview/classification-rules.json`:

- Email addresses → `MICROSOFT.PERSONAL.EMAIL`
- Phone numbers → `MICROSOFT.PERSONAL.PHONE_NUMBER`
- Addresses → `MICROSOFT.PERSONAL.ADDRESS`

### Apply Classifications

```bash
# Apply classification rules
python scripts/apply_classifications.py

# Scan for PII
python scripts/apply_classifications.py --scan-pii
```

### Sensitivity Labels

| Label | Description | Assets |
|-------|-------------|--------|
| Public | Non-sensitive | Product codes, statuses |
| Internal | Internal use | Shipment volumes, metrics |
| Confidential | Sensitive business | Customer names, pricing |
| Highly Confidential | Critical PII | Contact info, addresses |

## Data Lineage

### Configure Lineage Tracking

Lineage is automatically captured for:
- Eventstream → Lakehouse
- Bronze → Silver → Gold transformations
- SQL queries and views
- API consumption

### Manual Lineage Registration

```bash
# Register custom lineage
python scripts/register_lineage.py \
  --source bronze_idocs \
  --target silver_shipments \
  --process bronze_to_silver_transformation
```

### View Lineage

1. Open Purview portal
2. Navigate to Data Catalog
3. Search for asset (e.g., `silver_shipments`)
4. Click on "Lineage" tab

## API Governance

### Register APIs

```bash
# Register GraphQL API
python scripts/register_api.py \
  --name SAP-3PL-GraphQL-API \
  --endpoint https://api.company.com/sap-3pl/graphql \
  --type GraphQL

# Register REST API
python scripts/register_api.py \
  --name SAP-3PL-REST-API \
  --endpoint https://api.company.com/sap-3pl/api/v1 \
  --type REST
```

### API Metadata

- API version
- Endpoints
- Authentication method
- Schema/OpenAPI spec
- Data assets consumed
- Consumer applications

## Monitoring & Reporting

### Generate Governance Reports

```bash
# Weekly governance report
python scripts/generate_reports.py --type weekly

# Data quality dashboard
python scripts/generate_reports.py --type quality

# Catalog coverage report
python scripts/generate_reports.py --type coverage
```

### Report Types

1. **Weekly Governance Report**
   - Data quality scores
   - Catalog coverage
   - API usage statistics
   - Compliance status

2. **Data Quality Dashboard**
   - Quality trends
   - Failed checks
   - Asset quality scores
   - Issue resolution time

3. **Catalog Coverage Report**
   - Documented vs undocumented assets
   - Glossary term usage
   - Classification coverage

### Automated Alerts

Configure alerts in `scripts/alert_config.yaml`:

```yaml
alerts:
  - name: Quality Below Threshold
    condition: quality_score < 95
    recipients:
      - data-quality-team@company.com
    severity: High
  
  - name: Missing Documentation
    condition: documentation_coverage < 90
    recipients:
      - data-steward@company.com
    severity: Medium
```

## Compliance

### GDPR Compliance

Scripts for GDPR operations:

```bash
# Data subject access request
python scripts/gdpr_access_request.py --subject-id <id>

# Right to erasure
python scripts/gdpr_erasure.py --subject-id <id> --confirm

# Generate compliance report
python scripts/gdpr_compliance_report.py
```

### Data Retention

Configured in data product definition:

- Bronze layer: 90 days
- Silver layer: 2 years
- Gold layer: 7 years

### Audit Logging

All governance operations are logged:
- Who accessed what data
- What changes were made
- When operations occurred
- Why operations were performed

## Best Practices

1. **Regular Scanning**
   - Schedule daily scans for critical assets
   - Weekly full scans for all assets

2. **Quality Monitoring**
   - Run quality checks hourly
   - Review quality dashboard daily
   - Address issues within 24 hours

3. **Documentation**
   - Keep business glossary updated
   - Document all assets
   - Maintain lineage accuracy

4. **Access Control**
   - Review access permissions quarterly
   - Use least privilege principle
   - Audit access logs monthly

5. **Compliance**
   - Review retention policies annually
   - Update classifications as needed
   - Maintain audit trails

## Troubleshooting

### Common Issues

1. **Purview Connection Failed**
   - Verify credentials in `.env`
   - Check network connectivity
   - Ensure proper permissions

2. **Asset Not Found**
   - Run scan to discover assets
   - Verify asset qualifiedName
   - Check collection assignment

3. **Quality Check Failures**
   - Review rule definitions
   - Check data source connectivity
   - Verify SQL query syntax

4. **Classification Not Applied**
   - Check classification rules
   - Verify pattern matches
   - Ensure minimum threshold met

## Maintenance

### Weekly Tasks
- Review quality dashboard
- Check failed quality checks
- Update documentation gaps

### Monthly Tasks
- Generate governance reports
- Review access logs
- Update business glossary
- Audit compliance status

### Quarterly Tasks
- Review and update quality rules
- Assess data product SLA compliance
- Update classification rules
- Conduct governance training

## Resources

- [Microsoft Purview Documentation](https://learn.microsoft.com/purview/)
- [Data Quality Best Practices](https://learn.microsoft.com/purview/concept-data-quality)
- [Purview REST API](https://learn.microsoft.com/rest/api/purview/)

## Support

- Governance Team: governance@company.com
- Data Quality: data-quality@company.com
- Technical Support: data-engineering@company.com
