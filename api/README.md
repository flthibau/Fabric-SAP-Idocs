# API Layer

## Overview

This directory contains the GraphQL API implementation and Azure API Management configuration for the SAP 3PL Logistics Data Product.

## Structure

```
api/
├── graphql/
│   ├── schema/
│   │   └── schema.graphql         # GraphQL schema definition
│   ├── resolvers/
│   │   ├── shipment.js/cs         # Shipment resolvers
│   │   ├── customer.js/cs         # Customer resolvers
│   │   └── metrics.js/cs          # Metrics resolvers
│   ├── server.js / Program.cs     # GraphQL server entry point
│   ├── package.json / *.csproj    # Dependencies
│   └── README.md
└── apim/
    ├── policies/
    │   ├── graphql-policy.xml     # GraphQL endpoint policy
    │   ├── rest-transform.xml     # GraphQL to REST transformation
    │   └── rate-limit.xml         # Rate limiting policy
    ├── api-definitions/
    │   ├── graphql-api.json       # APIM GraphQL API definition
    │   └── rest-api.json          # APIM REST API definition
    └── README.md
```

## Technology Stack

### Option 1: Node.js + Apollo Server
- Node.js 20+
- Apollo Server 4
- TypeScript
- Azure Functions or Container Apps

### Option 2: .NET + Hot Chocolate
- .NET 8
- Hot Chocolate 13+
- C#
- Azure Functions or Container Apps

## GraphQL API

### Features

- Schema-first design
- Type-safe queries
- Efficient data loading (DataLoader pattern)
- Authentication via Azure AD
- Authorization with role-based access
- Caching strategies
- Comprehensive error handling

### Quick Start

#### Node.js Version

```bash
cd api/graphql

# Install dependencies
npm install

# Configure environment
cp .env.example .env

# Run locally
npm run dev

# Run tests
npm test

# Build for production
npm run build
```

#### .NET Version

```bash
cd api/graphql

# Restore dependencies
dotnet restore

# Run locally
dotnet run

# Run tests
dotnet test

# Build for production
dotnet build --configuration Release
```

### Environment Variables

```bash
# Database
SQL_CONNECTION_STRING=Server=...

# Authentication
AZURE_AD_TENANT_ID=...
AZURE_AD_CLIENT_ID=...
AZURE_AD_CLIENT_SECRET=...

# Application Insights
APPINSIGHTS_INSTRUMENTATIONKEY=...

# Configuration
ENVIRONMENT=development
PORT=4000
```

### GraphQL Schema

The schema is defined in `schema/schema.graphql` and includes:

- **Types**: Shipment, Customer, Location, Carrier, etc.
- **Queries**: Single entity and list queries with filtering
- **Mutations**: Data refresh operations (if applicable)
- **Subscriptions**: Real-time updates (optional)

### Example Query

```graphql
query GetShipments {
  shipments(
    filters: {
      startDate: "2025-10-01"
      endDate: "2025-10-23"
      statuses: [IN_TRANSIT, DELIVERED]
    }
    pagination: { limit: 10 }
  ) {
    edges {
      node {
        id
        shipmentNumber
        status
        customer { name }
      }
    }
    pageInfo { hasNextPage }
  }
}
```

## Azure API Management

### Features

- GraphQL endpoint exposure
- GraphQL to REST transformation
- Rate limiting and throttling
- API versioning
- Developer portal
- Monitoring and analytics

### Setup

1. **Create APIM Instance**
   ```bash
   az apim create \
     --name sap-3pl-apim \
     --resource-group rg-sap-3pl \
     --publisher-email admin@company.com \
     --publisher-name "Company Name" \
     --sku-name Developer
   ```

2. **Import API Definitions**
   ```bash
   # Import GraphQL API
   az apim api import \
     --resource-group rg-sap-3pl \
     --service-name sap-3pl-apim \
     --path /graphql \
     --specification-path api-definitions/graphql-api.json
   ```

3. **Apply Policies**
   - Navigate to APIM portal
   - Import policies from `policies/` directory
   - Configure rate limits and authentication

### API Endpoints

| Endpoint | Type | Description |
|----------|------|-------------|
| `/graphql` | GraphQL | Main GraphQL endpoint |
| `/api/v1/shipments` | REST | List shipments |
| `/api/v1/shipments/{id}` | REST | Get shipment by ID |
| `/api/v1/customers` | REST | List customers |
| `/api/v1/metrics` | REST | Get metrics |

### Policies

#### Authentication Policy
- Validates JWT tokens from Azure AD
- Checks required scopes and roles
- Located in `policies/auth-policy.xml`

#### Rate Limiting
- Standard tier: 1,000 requests/minute
- Premium tier: 5,000 requests/minute
- Configured in `policies/rate-limit.xml`

#### GraphQL to REST Transformation
- Converts REST requests to GraphQL queries
- Handles response mapping
- Defined in `policies/rest-transform.xml`

## Deployment

### Local Development

```bash
# Start GraphQL server
cd api/graphql
npm run dev  # or dotnet run

# Access GraphQL Playground
# Open browser: http://localhost:4000/graphql
```

### Azure Deployment

#### Option 1: Azure Container Apps

```bash
# Build Docker image
docker build -t sap-3pl-graphql:latest .

# Push to Azure Container Registry
az acr build \
  --registry <registry-name> \
  --image sap-3pl-graphql:latest .

# Deploy to Container Apps
az containerapp create \
  --name sap-3pl-graphql \
  --resource-group rg-sap-3pl \
  --environment <environment-name> \
  --image <registry-name>.azurecr.io/sap-3pl-graphql:latest \
  --target-port 4000 \
  --ingress external
```

#### Option 2: Azure Functions

```bash
# Deploy function app
func azure functionapp publish <function-app-name>
```

## Testing

### Unit Tests

```bash
# Node.js
npm test

# .NET
dotnet test
```

### Integration Tests

```bash
# Run integration tests against local server
npm run test:integration
```

### Load Testing

```bash
# Use Apache Bench or Artillery
artillery run load-test-config.yml
```

## Monitoring

### Application Insights

- Request duration and performance
- Dependency tracking
- Exception logging
- Custom metrics

### APIM Analytics

- API call volume
- Response times
- Error rates
- Geographic distribution

### Metrics to Monitor

- GraphQL query complexity
- Resolver execution time
- Cache hit rate
- Error rate by query type
- Authentication failures

## Security

### Authentication
- OAuth 2.0 / Azure AD integration
- JWT token validation
- Role-based access control

### Authorization
- Field-level authorization
- Query complexity limits
- Depth limiting
- Rate limiting

### Best Practices
- Use HTTPS only
- Validate all inputs
- Implement query complexity analysis
- Monitor for suspicious patterns
- Regular security audits

## Performance Optimization

### Caching
- Query result caching in APIM
- DataLoader for batching
- Redis cache for expensive queries

### Query Optimization
- Use projections to fetch only needed fields
- Implement pagination
- Optimize database queries
- Use database indexes

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify Azure AD configuration
   - Check token expiration
   - Validate scopes

2. **Slow Queries**
   - Review query complexity
   - Check database indexes
   - Implement caching
   - Use DataLoader

3. **APIM Issues**
   - Check policy configuration
   - Verify backend connectivity
   - Review rate limit settings

## Contributing

1. Follow GraphQL best practices
2. Write tests for all resolvers
3. Document schema changes
4. Update API documentation
5. Test with APIM policies

## Resources

- [GraphQL Documentation](https://graphql.org/)
- [Apollo Server](https://www.apollographql.com/docs/apollo-server/)
- [Hot Chocolate](https://chillicream.com/docs/hotchocolate/)
- [Azure APIM](https://learn.microsoft.com/azure/api-management/)

## Support

- Technical Issues: api-team@company.com
- API Documentation: https://docs.api.company.com/sap-3pl
