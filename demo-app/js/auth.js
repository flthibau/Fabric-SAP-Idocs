// Authentication Module
let currentToken = null;
let currentSP = null;

/**
 * Connect with a Service Principal
 * In production, this should use OAuth flow with Azure AD
 * For demo, we'll use Azure CLI to get token
 */
async function connectSP(spKey) {
    const sp = CONFIG.servicePrincipals[spKey];
    
    if (!sp) {
        showError('Service Principal configuration not found');
        return;
    }
    
    try {
        // Show loading state
        showConnectionStatus(`Connecting as ${sp.name}...`, 'loading');
        
        // For demo purposes, we'll use a manual token input
        // In production, implement proper OAuth flow
        const token = await getTokenForSP(sp);
        
        if (token) {
            currentToken = token;
            currentSP = spKey;
            
            // Update UI
            const statusDiv = document.getElementById('connection-status');
            if (statusDiv) {
                const spNameSpan = document.getElementById('connected-sp-name');
                if (spNameSpan) {
                    spNameSpan.textContent = `Connected: ${sp.name}`;
                }
                statusDiv.style.display = 'block';
                statusDiv.className = 'connection-status success';
                statusDiv.innerHTML = `
                    <div class="status-info">
                        <span>✅ Connected: ${sp.name}</span>
                        <button class="btn btn-secondary btn-small" onclick="disconnect()">Disconnect</button>
                    </div>
                `;
            }
            
            const dashboard = document.getElementById('dashboard');
            if (dashboard) {
                dashboard.style.display = 'block';
            }
            
            // Hide connection panel options
            document.querySelectorAll('.sp-option').forEach(option => {
                option.style.opacity = '0.5';
                option.style.pointerEvents = 'none';
            });
            
            // Load initial data
            loadAllData();
        }
    } catch (error) {
        console.error('Connection error:', error);
        showError('Connection error: ' + error.message);
    }
}

/**
 * Get token for Service Principal
 * This is a simplified version for demo
 */
async function getTokenForSP(sp) {
    // Simplified for demo - use get-token.ps1 script
    const message = 
        `To get a token for ${sp.name}:\n\n` +
        `1. Open PowerShell in demo-app folder\n` +
        `2. Run: .\\get-token.ps1 -ServicePrincipal ${sp.name.toLowerCase().split(' ')[0]}\n` +
        `3. Token will be copied to clipboard\n\n` +
        `Paste the token below:`;
    
    const token = prompt(message);
    
    if (token && token.trim()) {
        return token.trim();
    }
    
    throw new Error('Token input cancelled');
}

/**
 * Disconnect current session
 */
function disconnect() {
    currentToken = null;
    currentSP = null;
    
    // Reset UI
    document.getElementById('connection-status').style.display = 'none';
    document.getElementById('dashboard').style.display = 'none';
    
    // Re-enable connection panel
    document.querySelectorAll('.sp-option').forEach(option => {
        option.style.opacity = '1';
        option.style.pointerEvents = 'auto';
    });
    
    // Clear all data
    clearAllData();
}

/**
 * Show connection status message
 */
function showConnectionStatus(message, type) {
    const statusDiv = document.getElementById('connection-status');
    statusDiv.innerHTML = `<div class="status-info">${message}</div>`;
    statusDiv.className = `connection-status ${type}`;
    statusDiv.style.display = 'block';
}

/**
 * Check if user is authenticated
 */
function isAuthenticated() {
    return currentToken !== null;
}

/**
 * Get current bearer token
 */
function getBearerToken() {
    return currentToken;
}

/**
 * Get current Service Principal key
 */
function getCurrentSP() {
    return currentSP;
}
