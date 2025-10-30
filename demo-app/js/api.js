// API Module - Handles all API calls to APIM

/**
 * Call APIM GraphQL API
 * Uses the same format as the PowerShell test scripts
 */
async function callAPI(query) {
    if (!isAuthenticated()) {
        throw new Error('Not authenticated');
    }
    
    // Always use /graphql endpoint for all queries
    const url = `${CONFIG.apimGateway}/graphql`;
    const token = getBearerToken();
    
    console.log('Calling API:', url);
    console.log('Query:', query);
    
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ query: query })
        });
        
        console.log('Response status:', response.status);
        
        if (!response.ok) {
            const errorText = await response.text();
            console.error('API Error:', errorText);
            throw new Error(`API Error ${response.status}: ${errorText}`);
        }
        
        const data = await response.json();
        console.log('Response data:', data);
        
        // Check for GraphQL errors
        if (data.errors) {
            console.error('GraphQL Errors:', data.errors);
            throw new Error(`GraphQL Error: ${JSON.stringify(data.errors)}`);
        }
        
        return data.data;
    } catch (error) {
        console.error('API call failed:', error);
        throw error;
    }
}

/**
 * Load Shipments data
 */
async function loadShipments() {
    const loadingEl = document.getElementById('shipments-loading');
    const errorEl = document.getElementById('shipments-error');
    const contentEl = document.getElementById('shipments-content');
    
    try {
        loadingEl.style.display = 'block';
        errorEl.style.display = 'none';
        contentEl.innerHTML = '';
        
        const data = await callAPI(CONFIG.queries.shipments);
        const items = data.gold_shipments_in_transits?.items || [];
        
        loadingEl.style.display = 'none';
        
        if (items.length === 0) {
            contentEl.innerHTML = getEmptyState('Aucun shipment trouvé', '📦');
        } else {
            contentEl.innerHTML = renderShipmentsTable(items);
            updateStat('stat-shipments', items.length);
        }
    } catch (error) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Erreur: ${error.message}`;
        errorEl.style.display = 'block';
        updateStat('stat-shipments', 'Error');
    }
}

/**
 * Load Orders data
 */
async function loadOrders() {
    const loadingEl = document.getElementById('orders-loading');
    const errorEl = document.getElementById('orders-error');
    const contentEl = document.getElementById('orders-content');
    
    try {
        loadingEl.style.display = 'block';
        errorEl.style.display = 'none';
        contentEl.innerHTML = '';
        
        const data = await callAPI(CONFIG.queries.orders);
        const items = data.gold_orders_daily_summaries?.items || [];
        
        loadingEl.style.display = 'none';
        
        if (items.length === 0) {
            contentEl.innerHTML = getEmptyState('Aucune commande trouvée', '📋');
        } else {
            contentEl.innerHTML = renderOrdersTable(items);
            updateStat('stat-orders', items.length);
        }
    } catch (error) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Erreur: ${error.message}`;
        errorEl.style.display = 'block';
        updateStat('stat-orders', 'Error');
    }
}

/**
 * Load Warehouse data
 */
async function loadWarehouse() {
    const loadingEl = document.getElementById('warehouse-loading');
    const errorEl = document.getElementById('warehouse-error');
    const contentEl = document.getElementById('warehouse-content');
    
    try {
        loadingEl.style.display = 'block';
        errorEl.style.display = 'none';
        contentEl.innerHTML = '';
        
        const data = await callAPI(CONFIG.queries.warehouse);
        const items = data.gold_warehouse_productivity_dailies?.items || [];
        
        loadingEl.style.display = 'none';
        
        if (items.length === 0) {
            contentEl.innerHTML = getEmptyState('Aucune donnée d\'entrepôt', '🏭');
        } else {
            contentEl.innerHTML = renderWarehouseTable(items);
            updateStat('stat-warehouse', items.length);
        }
    } catch (error) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Erreur: ${error.message}`;
        errorEl.style.display = 'block';
        updateStat('stat-warehouse', 'Error');
    }
}

/**
 * Load SLA data
 */
async function loadSLA() {
    const loadingEl = document.getElementById('sla-loading');
    const errorEl = document.getElementById('sla-error');
    const contentEl = document.getElementById('sla-content');
    
    try {
        loadingEl.style.display = 'block';
        errorEl.style.display = 'none';
        contentEl.innerHTML = '';
        
        const data = await callAPI(CONFIG.queries.sla);
        const items = data.gold_sla_performances?.items || [];
        
        loadingEl.style.display = 'none';
        
        if (items.length === 0) {
            contentEl.innerHTML = getEmptyState('Aucune donnée SLA', '⏱️');
        } else {
            contentEl.innerHTML = renderSLATable(items);
            updateStat('stat-sla', items.length);
        }
    } catch (error) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Erreur: ${error.message}`;
        errorEl.style.display = 'block';
        updateStat('stat-sla', 'Error');
    }
}

/**
 * Load Revenue data
 */
async function loadRevenue() {
    const loadingEl = document.getElementById('revenue-loading');
    const errorEl = document.getElementById('revenue-error');
    const contentEl = document.getElementById('revenue-content');
    
    try {
        loadingEl.style.display = 'block';
        errorEl.style.display = 'none';
        contentEl.innerHTML = '';
        
        const data = await callAPI(CONFIG.queries.revenue);
        const items = data.gold_revenue_recognition_realtimes?.items || [];
        
        loadingEl.style.display = 'none';
        
        if (items.length === 0) {
            contentEl.innerHTML = getEmptyState('Aucune donnée de revenus', '💰');
        } else {
            contentEl.innerHTML = renderRevenueTable(items);
        }
    } catch (error) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Erreur: ${error.message}`;
        errorEl.style.display = 'block';
    }
}

/**
 * Render Shipments table
 */
function renderShipmentsTable(items) {
    return `
        <table>
            <thead>
                <tr>
                    <th>Shipment #</th>
                    <th>Carrier</th>
                    <th>Origin</th>
                    <th>Destination</th>
                    <th>Status</th>
                    <th>Current Location</th>
                    <th>ETA</th>
                </tr>
            </thead>
            <tbody>
                ${items.map(item => `
                    <tr>
                        <td><strong>${item.shipment_number || '-'}</strong></td>
                        <td>${item.carrier_id || '-'}</td>
                        <td>${item.origin_location || '-'}</td>
                        <td>${item.destination_location || '-'}</td>
                        <td><span class="badge ${getStatusBadge(item.status)}">${item.status || '-'}</span></td>
                        <td>${item.current_location || '-'}</td>
                        <td>${formatDate(item.estimated_delivery_date)}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Render Orders table
 */
function renderOrdersTable(items) {
    return `
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Warehouse</th>
                    <th>Total Orders</th>
                    <th>Total Lines</th>
                    <th>Revenue</th>
                    <th>Avg Order Value</th>
                    <th>Avg Processing Time</th>
                </tr>
            </thead>
            <tbody>
                ${items.map(item => `
                    <tr>
                        <td>${formatDate(item.order_date)}</td>
                        <td>${item.warehouse_id || '-'}</td>
                        <td>${item.total_orders || 0}</td>
                        <td>${item.total_lines || 0}</td>
                        <td>${formatCurrency(item.total_revenue)}</td>
                        <td>${formatCurrency(item.avg_order_value)}</td>
                        <td>${formatDuration(item.processing_time_avg)}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Render Warehouse table
 */
function renderWarehouseTable(items) {
    return `
        <table>
            <thead>
                <tr>
                    <th>Warehouse</th>
                    <th>Date</th>
                    <th>Total Shipments</th>
                    <th>Avg Processing Time</th>
                    <th>Picking Accuracy</th>
                    <th>On-Time %</th>
                    <th>Staff Count</th>
                </tr>
            </thead>
            <tbody>
                ${items.map(item => `
                    <tr>
                        <td><strong>${item.warehouse_id || '-'}</strong></td>
                        <td>${formatDate(item.productivity_date)}</td>
                        <td>${item.total_shipments || 0}</td>
                        <td>${formatDuration(item.avg_processing_time)}</td>
                        <td>${formatPercentage(item.picking_accuracy)}</td>
                        <td><span class="badge ${getPerformanceBadge(item.on_time_shipments / item.total_shipments)}">${formatPercentage(item.on_time_shipments / item.total_shipments)}</span></td>
                        <td>${item.staff_count || '-'}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Render SLA table
 */
function renderSLATable(items) {
    return `
        <table>
            <thead>
                <tr>
                    <th>Carrier</th>
                    <th>Date</th>
                    <th>On-Time</th>
                    <th>Late</th>
                    <th>Total</th>
                    <th>On-Time %</th>
                    <th>Avg Delay</th>
                </tr>
            </thead>
            <tbody>
                ${items.map(item => `
                    <tr>
                        <td><strong>${item.carrier_id || '-'}</strong></td>
                        <td>${formatDate(item.performance_date)}</td>
                        <td>${item.ontime_shipments || 0}</td>
                        <td>${item.late_shipments || 0}</td>
                        <td>${item.total_shipments || 0}</td>
                        <td><span class="badge ${getPerformanceBadge(item.ontime_percentage / 100)}">${formatPercentage(item.ontime_percentage / 100)}</span></td>
                        <td>${formatDuration(item.avg_delay_hours)}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

/**
 * Render Revenue table
 */
function renderRevenueTable(items) {
    return `
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Customer</th>
                    <th>Order</th>
                    <th>Revenue</th>
                    <th>Cost</th>
                    <th>Profit Margin</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                ${items.map(item => `
                    <tr>
                        <td>${formatDate(item.transaction_date)}</td>
                        <td>${item.customer_id || '-'}</td>
                        <td>${item.order_id || '-'}</td>
                        <td>${formatCurrency(item.revenue_amount)}</td>
                        <td>${formatCurrency(item.cost_amount)}</td>
                        <td><span class="badge ${getPerformanceBadge(item.profit_margin)}">${formatPercentage(item.profit_margin)}</span></td>
                        <td><span class="badge badge-info">${item.recognition_status || '-'}</span></td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

// Helper Functions

function getEmptyState(message, icon) {
    return `
        <div class="empty-state">
            <div class="empty-state-icon">${icon}</div>
            <p>${message}</p>
            <p style="font-size: 0.9rem; color: #999; margin-top: 10px;">
                Les données peuvent être filtrées par RLS selon votre Service Principal
            </p>
        </div>
    `;
}

function getStatusBadge(status) {
    if (!status) return 'badge-info';
    const s = status.toLowerCase();
    if (s.includes('delivered') || s.includes('completed')) return 'badge-success';
    if (s.includes('delay') || s.includes('late')) return 'badge-warning';
    return 'badge-info';
}

function getPerformanceBadge(percentage) {
    if (percentage >= 0.9) return 'badge-success';
    if (percentage >= 0.7) return 'badge-warning';
    return 'badge-info';
}

function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR');
}

function formatCurrency(amount) {
    if (!amount && amount !== 0) return '-';
    return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(amount);
}

function formatPercentage(value) {
    if (!value && value !== 0) return '-';
    return `${(value * 100).toFixed(1)}%`;
}

function formatDuration(minutes) {
    if (!minutes && minutes !== 0) return '-';
    const hours = Math.floor(minutes / 60);
    const mins = Math.round(minutes % 60);
    if (hours > 0) {
        return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
}

function updateStat(elementId, value) {
    document.getElementById(elementId).textContent = value;
}
