// Copy this file to config.js and fill in your actual values
// Or use .env file (recommended)

module.exports = {
    // Miniserver IP address or domain name
    LOXONE_IP: '192.168.1.77',
    
    // Miniserver port (default: 443 for HTTPS/WSS, 80 for HTTP/WS)
    // Leave empty to use default ports
    LOXONE_PORT: '',
    
    // Protocol: 'wss' for Generation 2 (HTTPS/WSS) or 'ws' for Generation 1 (HTTP/WS)
    // Recommended: wss (secure)
    PROTOCOL: 'wss',
    
    // Loxone username
    LOXONE_USER: 'admin',
    
    // Loxone password
    LOXONE_PASS: 'password',
    
    // Client UUID (unique identifier for this client installation)
    // Generate a unique UUID for each client
    CLIENT_UUID: '098802e1-02b4-603c-ffffeee000d80cfd',
    
    // Client info/description
    CLIENT_INFO: 'NodeDemoApp',
    
    // Permission level: 2 = Web access, 4 = App access
    PERMISSION: 2,
    
    // Keepalive interval in milliseconds (default: 5 minutes)
    KEEPALIVE_INTERVAL: 300000,
    
    // Path to save the structure file
    STRUCTURE_FILE_PATH: './LoxAPP3.json'
};

