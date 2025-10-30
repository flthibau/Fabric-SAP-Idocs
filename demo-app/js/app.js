// Main Application Logic

/**
 * Show specific tab
 */
function showTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-pane').forEach(pane => {
        pane.classList.remove('active');
    });
    
    // Remove active from all buttons
    document.querySelectorAll('.tab-button').forEach(button => {
        button.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(`tab-${tabName}`).classList.add('active');
    event.target.classList.add('active');
    
    // Load data for the tab if not already loaded
    switch(tabName) {
        case 'shipments':
            loadShipments();
            break;
        case 'orders':
            loadOrders();
            break;
        case 'warehouse':
            loadWarehouse();
            break;
        case 'sla':
            loadSLA();
            break;
        case 'revenue':
            loadRevenue();
            break;
    }
}

/**
 * Load all data at once
 */
function loadAllData() {
    loadShipments();
    // Don't load all tabs immediately to avoid overwhelming the API
    // They will load when user clicks on them
}

/**
 * Clear all displayed data
 */
function clearAllData() {
    ['shipments', 'orders', 'warehouse', 'sla', 'revenue'].forEach(tab => {
        document.getElementById(`${tab}-content`).innerHTML = '';
        document.getElementById(`${tab}-error`).style.display = 'none';
        document.getElementById(`${tab}-loading`).style.display = 'none';
    });
    
    // Reset stats
    ['stat-shipments', 'stat-orders', 'stat-warehouse', 'stat-sla'].forEach(stat => {
        document.getElementById(stat).textContent = '-';
    });
}

/**
 * Show error message
 */
function showError(message) {
    alert(`âŒ Error: ${message}`);
}

/**
 * Initialize app on page load
 */
document.addEventListener('DOMContentLoaded', function() {
    console.log('3PL Partner API Demo - Ready');
    
    // Check if running locally
    if (window.location.protocol === 'file:') {
        console.warn('Running from file:// - CORS may block API calls. Use a local web server instead.');
    }
    
    // Initialize stats with placeholder
    clearAllData();
});

/**
 * Keyboard shortcuts
 */
document.addEventListener('keydown', function(e) {
    // Alt + 1-5 for quick tab switching
    if (e.altKey) {
        switch(e.key) {
            case '1':
                document.querySelector('[onclick*="shipments"]').click();
                break;
            case '2':
                document.querySelector('[onclick*="orders"]').click();
                break;
            case '3':
                document.querySelector('[onclick*="warehouse"]').click();
                break;
            case '4':
                document.querySelector('[onclick*="sla"]').click();
                break;
            case '5':
                document.querySelector('[onclick*="revenue"]').click();
                break;
        }
    }
    
    // Ctrl + R to refresh current tab
    if (e.ctrlKey && e.key === 'r') {
        e.preventDefault();
        const activeTab = document.querySelector('.tab-pane.active');
        if (activeTab) {
            const tabName = activeTab.id.replace('tab-', '');
            switch(tabName) {
                case 'shipments': loadShipments(); break;
                case 'orders': loadOrders(); break;
                case 'warehouse': loadWarehouse(); break;
                case 'sla': loadSLA(); break;
                case 'revenue': loadRevenue(); break;
            }
        }
    }
});
