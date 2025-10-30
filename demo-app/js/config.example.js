// EXAMPLE CONFIGURATION FILE
// Copy this to config.js and fill in your values

const CONFIG = {
    // APIM Gateway URL
    apimGateway: 'https://apim-3pl-flt.azure-api.net',
    
    // Azure AD Tenant
    tenantId: '38de1b20-8309-40ba-9584-5d9fcb7203b4',
    
    // Fabric Resource
    fabricResource: 'https://analysis.windows.net/powerbi/api',
    
    // Service Principals Configuration
    // ⚠️ NEVER commit secrets to source control!
    servicePrincipals: {
        fedex: {
            name: 'FedEx Carrier API',
            appId: '94a9edcc-7a22-4d89-b001-799e8414711a',
            objectId: 'fa86b10b-792c-495b-af85-bc8a765b44a1',
            secret: '', // ⚠️ ADD YOUR SECRET HERE (for demo only - use backend in production)
            description: 'Transporteur - Voit uniquement ses shipments',
            icon: '🚚',
            color: '#ff6b6b'
        },
        warehouse: {
            name: 'Warehouse Partner API',
            appId: '1de3dcee-f7eb-4701-8cd9-ed65f3792fe0',
            objectId: 'bf7ca9fa-eb65-4261-91f2-08d2b360e919',
            secret: '', // ⚠️ ADD YOUR SECRET HERE
            description: 'Entrepôt WH003 - Voit sa productivité',
            icon: '🏭',
            color: '#4ecdc4'
        },
        acme: {
            name: 'ACME Customer API',
            appId: 'a3e88682-8bef-4712-9cc5-031d109cefca',
            objectId: 'efae8acd-de55-4c89-96b6-7f031a954ae6',
            secret: '', // ⚠️ ADD YOUR SECRET HERE
            description: 'Client ACME - Voit ses commandes',
            icon: '🏢',
            color: '#95e1d3'
        }
    },
    
    // API Endpoints
    endpoints: {
        graphql: '/graphql',
        shipments: '/shipments',
        orders: '/orders',
        warehouse: '/warehouse-productivity',
        sla: '/sla-performance',
        revenue: '/revenue'
    }
    
    // GraphQL Queries are defined in api.js
};
