// Configuration for APIM and Service Principals
const CONFIG = {
    // APIM Gateway URL
    apimGateway: 'https://apim-3pl-flt.azure-api.net',
    
    // Azure AD Tenant
    tenantId: '38de1b20-8309-40ba-9584-5d9fcb7203b4',
    
    // Fabric Resource
    fabricResource: 'https://analysis.windows.net/powerbi/api',
    
    // Service Principals Configuration
    servicePrincipals: {
        fedex: {
            name: 'FedEx Carrier API',
            appId: '94a9edcc-7a22-4d89-b001-799e8414711a',
            objectId: 'fa86b10b-792c-495b-af85-bc8a765b44a1',
            // Secret should be retrieved securely - FOR DEMO ONLY
            secret: '', // TO BE FILLED
            description: 'Transporteur - Voit uniquement ses shipments',
            icon: '🚚',
            color: '#ff6b6b'
        },
        warehouse: {
            name: 'Warehouse Partner API',
            appId: '1de3dcee-f7eb-4701-8cd9-ed65f3792fe0',
            objectId: 'bf7ca9fa-eb65-4261-91f2-08d2b360e919',
            secret: '', // TO BE FILLED
            description: 'Entrepôt WH003 - Voit sa productivité',
            icon: '🏭',
            color: '#4ecdc4'
        },
        acme: {
            name: 'ACME Customer API',
            appId: 'a3e88682-8bef-4712-9cc5-031d109cefca',
            objectId: 'efae8acd-de55-4c89-96b6-7f031a954ae6',
            secret: '', // TO BE FILLED
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
    },
    
    // GraphQL Queries - Using ONLY fields that exist in the schema
    queries: {
        shipments: `query {
            gold_shipments_in_transits(first: 50) {
                items {
                    shipment_number
                    carrier_id
                    customer_id
                    customer_name
                    origin_location
                    destination_location
                    partner_access_scope
                }
            }
        }`,
        
        orders: `query {
            gold_orders_daily_summaries(first: 50) {
                items {
                    customer_id
                    customer_name
                    total_orders
                    partner_access_scope
                }
            }
        }`,
        
        warehouse: `query {
            gold_warehouse_productivity_dailies(first: 50) {
                items {
                    warehouse_id
                    total_movements
                    unique_operators
                    partner_access_scope
                }
            }
        }`,
        
        sla: `query {
            gold_sla_performances(first: 50) {
                items {
                    carrier_id
                    carrier_name
                    order_number
                    customer_id
                    sla_status
                    sla_compliance
                    processing_days
                    on_time_delivery
                    partner_access_scope
                }
            }
        }`,
        
        revenue: `query {
            gold_revenue_recognition_realtimes(first: 50) {
                items {
                    transaction_date
                    customer_id
                    order_id
                    revenue_amount
                    cost_amount
                    profit_margin
                    recognition_status
                }
            }
        }`
    }
};

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = CONFIG;
}
