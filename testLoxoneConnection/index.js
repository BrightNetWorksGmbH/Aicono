const WebSocket = require('ws');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// MongoDB Storage (optional - only if MONGODB_URI is set)
let mongodbStorage = null;
let storeMeasurements = null;
if (process.env.MONGODB_URI) {
    try {
        mongodbStorage = require('./mongodbStorage');
        storeMeasurements = mongodbStorage.storeMeasurements;
    } catch (error) {
        console.warn('[WARN] MongoDB storage not available:', error.message);
    }
}

// Generate a UUID v4
function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

// Configuration
const config = {
    ip: process.env.LOXONE_IP || '192.168.1.77',
    port: process.env.LOXONE_PORT || '',
    protocol: process.env.PROTOCOL || 'wss',
    user: process.env.LOXONE_USER || 'admin',
    pass: process.env.LOXONE_PASS || 'A9f!Q2m#R7xP',
    uuid: process.env.CLIENT_UUID || generateUUID(),
    info: process.env.CLIENT_INFO || 'NodeDemoApp',
    permission: parseInt(process.env.PERMISSION || '2'),
    keepaliveInterval: parseInt(process.env.KEEPALIVE_INTERVAL || '300000'),
    structureFilePath: process.env.STRUCTURE_FILE_PATH || './LoxAPP3.json',
    // External/Cloud address (for remote access via Loxone Cloud)
    externalAddress: process.env.LOXONE_EXTERNAL_ADDRESS || '',
    // Serial number for cloud connection
    serialNumber: process.env.LOXONE_SERIAL || ''
};

// State management
let state = {
    ws: null,
    key: null,
    salt: null,
    hashAlg: 'SHA1',
    token: null,
    tokenKey: null,
    authenticated: false,
    structureLoaded: false,
    structureData: null,
    keepaliveTimer: null,
    triedPlaintextToken: false,
    buildingId: null,
    sensorUuidMap: null, // Map Loxone UUID to internal sensor_id
    pendingBinaryHeader: null // Buffer for fragmented binary messages (header + payload)
};

// Hash payload using specified algorithm
function hashPayload(data, algorithm) {
    // According to Loxone docs: {pwHash} is the uppercase result of hashing
    const hash = crypto.createHash(algorithm.toLowerCase());
    hash.update(data, 'utf8');
    return hash.digest('hex').toUpperCase();
}

// HMAC hash payload using specified algorithm
function hmacPayload(data, key, algorithm) {
    const hmac = crypto.createHmac(algorithm.toLowerCase(), key);
    hmac.update(data);
    return hmac.digest('hex').toUpperCase();
}

// Build WebSocket URL
function buildWebSocketURL() {
    // If external address is provided, use it for cloud connection
    if (config.externalAddress) {
        // For Loxone Cloud, the format is typically:
        // wss://dns.loxonecloud.com/{serial}/ws/rfc6455
        // where serial is the MAC address without colons
        if (config.serialNumber) {
            const serial = config.serialNumber.replace(/:/g, '').toUpperCase();
            return `${config.protocol}://${config.externalAddress}/${serial}/ws/rfc6455`;
        } else {
            // Fallback: try direct connection to cloud address
            return `${config.protocol}://${config.externalAddress}/ws/rfc6455`;
        }
    }
    
    // Local connection
    const port = config.port || '';
    const portStr = port ? `:${port}` : '';
    return `${config.protocol}://${config.ip}${portStr}/ws/rfc6455`;
}

// Send command over WebSocket
function send(cmd) {
    if (state.ws && state.ws.readyState === WebSocket.OPEN) {
        console.log(`[SEND] ${cmd}`);
        state.ws.send(cmd);
    } else {
        console.error('[ERROR] WebSocket is not open. Cannot send:', cmd);
    }
}

// Handle text messages
function handleTextMessage(msg) {
    try {
        const json = JSON.parse(msg);
        // console.log('[RECEIVE]', JSON.stringify(json, null, 2));

        // Handle Key/Salt Response
        if (json.LL && json.LL.control && json.LL.control.includes('jdev/sys/getkey2')) {
            handleGetKey2Response(json);
        }
        // Handle Token Response
        else if (json.LL && json.LL.control && json.LL.control.includes('jdev/sys/getjwt')) {
            handleGetJWTResponse(json);
        }
        // Handle Auth Success
        else if (json.LL && json.LL.control && json.LL.control.includes('authwithtoken')) {
            handleAuthResponse(json);
        }
        // Handle Structure File
        else if (json.lastModified || json.LL?.value?.lastModified) {
            handleStructureFile(json);
        }
        // Handle other responses
        else if (json.LL) {
            // console.log('[INFO] Received LL response:', json.LL.control || 'unknown');
        }
    } catch (error) {
        // If not JSON, might be plain text response
        console.log('[RECEIVE TEXT]', msg);
    }
}

// Handle getkey2 response
function handleGetKey2Response(json) {
    try {
        const value = json.LL.value;
        // According to Loxone documentation:
        // - Key is hex-encoded and needs to be converted to binary for HMAC
        // - Salt (userSalt) is hex-encoded and should be used as hex string in password hash
        const hexKey = value.key;
        const hexSalt = value.salt; // This is the userSalt

        // Convert key from hex to Buffer for HMAC (HMAC requires binary key)
        state.key = Buffer.from(hexKey, 'hex');
        // Keep salt as hex string - use it directly in password hash
        state.salt = hexSalt;
        state.hashAlg = value.hashAlg || 'SHA1';

        // console.log(`[AUTH] Received key and salt. Algorithm: ${state.hashAlg}`);
        // console.log(`[AUTH] Key length: ${state.key.length} bytes (from ${hexKey.length} hex chars)`);
        // console.log(`[AUTH] Salt (hex): ${state.salt.substring(0, 32)}... (${state.salt.length} hex chars)`);
        // console.log(`[AUTH] Username: ${config.user}`);
        // console.log(`[AUTH] Password: ${config.pass ? config.pass.substring(0, 2) + '***' : 'NOT SET'} (length: ${config.pass ? config.pass.length : 0} chars)`);

        // Hash password: HASH("{password}:{userSalt}") 
        // According to docs: {pwHash} is uppercase result of hashing "{password}:{userSalt}"
        // where {userSalt} is the hex string from getkey2 response
        const passwordSaltString = `${config.pass}:${state.salt}`;
        const pwHash = hashPayload(passwordSaltString, state.hashAlg);
        console.log(`[AUTH] Password hash: ${pwHash}`);

        // Create auth hash: HMAC_HASH("{user}:{pwHash}", key)
        // According to docs: {hash} is "{user}:{pwHash}" hashed with key using HMAC-SHA1 or HMAC-SHA256
        // "Do not convert the result to upper or lower case, leave it unchanged"
        // However, we convert to uppercase for consistency and URL encoding
        const userPwHashString = `${config.user}:${pwHash}`;
        const authHash = hmacPayload(userPwHashString, state.key, state.hashAlg);
        console.log(`[AUTH] Auth hash: ${authHash}`);

        // Request JWT token: jdev/sys/getjwt/{hash}/{user}/{permission}/{uuid}/{info}
        // Note: According to docs, this request MUST be encrypted for versions < 11.2
        // For Generation 2 with WSS, encryption might not be required (we're using WSS)
        const encodedInfo = encodeURIComponent(config.info);
        send(`jdev/sys/getjwt/${authHash}/${config.user}/${config.permission}/${config.uuid}/${encodedInfo}`);
    } catch (error) {
        console.error('[ERROR] Failed to process getkey2 response:', error);
        console.error('[ERROR] Stack:', error.stack);
    }
}

// Handle getjwt response
function handleGetJWTResponse(json) {
    try {
        // Code can be string "200" or number 200, so check both
        const code = parseInt(json.LL.Code || json.LL.code || '0');
        if (code === 200 && json.LL.value && json.LL.value.token) {
            state.token = json.LL.value.token;
            
            // Store the new key if provided (for future use)
            if (json.LL.value.key) {
                state.tokenKey = Buffer.from(json.LL.value.key, 'hex');
                console.log('[AUTH] New key from getjwt stored for future use');
            }

            console.log('[AUTH] Received JWT token');
            console.log(`[AUTH] Token: ${state.token.substring(0, 50)}...`);

            // According to Loxone documentation:
            // "A websocket connection on which a token was acquired successfully is considered authenticated."
            // So we don't need to send authwithtoken - we're already authenticated!
            state.authenticated = true;
            console.log('[AUTH] ✓ Authentication successful! (Token acquired)');
            
            // Start keepalive
            startKeepalive();
            
            // Fetch structure file
            console.log('[INFO] Fetching structure file...');
            send('data/LoxAPP3.json');
        } else {
            console.error('[ERROR] Failed to get JWT token:', json.LL);
            console.error('');
            console.error('[AUTH TROUBLESHOOTING] Error code 401 - Unauthorized');
            console.error('  Possible causes:');
            console.error('  1. Incorrect username or password');
            console.error('  2. User does not have cloud access permissions');
            console.error('  3. User account is disabled');
            console.error('  4. User does not exist on this Miniserver');
            console.error('');
            console.error('[SOLUTION] Please check:');
            console.error('  1. Verify LOXONE_USER and LOXONE_PASS in .env file');
            console.error('  2. In Loxone Config: Check user permissions (needs "Web Services" permission)');
            console.error('  3. Ensure the user has "Cloud DNS" or "Remote Access" enabled');
            console.error('  4. Try with the main admin account to verify connection works');
            console.error('');
        }
    } catch (error) {
        console.error('[ERROR] Failed to process getjwt response:', error);
    }
}

// Handle auth response
function handleAuthResponse(json) {
    // Code can be string "200" or number 200, and may be "Code" or "code"
    const code = parseInt(json.LL.Code || json.LL.code || '0');
    if (code === 200) {
        state.authenticated = true;
        console.log('[AUTH] ✓ Authentication successful!');
        
        // Start keepalive
        startKeepalive();
        
        // Fetch structure file
        console.log('[INFO] Fetching structure file...');
        send('data/LoxAPP3.json');
    } else if (code === 400) {
        // 400 Bad Request - plaintext didn't work, try hashed version
        // According to docs: For older versions, use HMAC_HASH("{token}", key from getkey2)
        console.log('[AUTH] Plaintext token authentication failed (400), trying hashed version...');
        if (!state.triedPlaintextToken) {
            state.triedPlaintextToken = true;
            // Use original key from getkey2 for token hash (as per documentation)
            const tokenHash = hmacPayload(state.token, state.key, state.hashAlg);
            console.log(`[AUTH] Token hash: ${tokenHash}`);
            send(`authwithtoken/${tokenHash}/${config.user}`);
        } else {
            console.error('[ERROR] Authentication failed with both plaintext and hashed token:', json.LL);
        }
    } else {
        console.error('[ERROR] Authentication failed:', json.LL);
    }
}

// Handle structure file
async function handleStructureFile(json) {
    try {
        console.log('[INFO] Structure file received');
        
        // Save structure file
        const structureData = JSON.stringify(json, null, 2);
        fs.writeFileSync(config.structureFilePath, structureData);
        // console.log(`[INFO] Structure file saved to: ${config.structureFilePath}`);
        
        state.structureLoaded = true;
        state.structureData = json;
        
        // Initialize MongoDB if configured
        if (mongodbStorage && process.env.MONGODB_URI && process.env.BUILDING_ID) {
            try {
                console.log('[MONGODB] Initializing MongoDB connection...');
                await mongodbStorage.connectToMongoDB(process.env.MONGODB_URI);
                await mongodbStorage.createTimeSeriesCollection();
                
                // Load structure mapping for UUID lookup
                const buildingId = process.env.BUILDING_ID;
                const uuidMap = await mongodbStorage.loadStructureMapping(buildingId, json);
                state.buildingId = buildingId;
                state.sensorUuidMap = uuidMap; // Store the UUID map in state
                
                console.log('[MONGODB] ✓ MongoDB initialized and structure mapping loaded');
            } catch (error) {
                console.error('[MONGODB] Failed to initialize:', error.message);
                console.warn('[MONGODB] Continuing without MongoDB storage...');
            }
        } else {
            console.log('[INFO] MongoDB storage not configured (MONGODB_URI or BUILDING_ID not set)');
        }
        
        // Enable live updates
        console.log('[INFO] Enabling live status updates...');
        send('jdev/sps/enablebinstatusupdate');
        
        console.log('[INFO] ✓ Demo app is fully connected and ready!');
        console.log('[INFO] Waiting for live events...');
    } catch (error) {
        console.error('[ERROR] Failed to save structure file:', error);
    }
}

// Handle binary messages
function handleBinaryMessage(buffer) {
    if (buffer.length < 8) {
        console.warn('[WARN] Binary message too short');
        return;
    }

    const identifier = buffer.readUInt8(1);
    // According to Loxone docs: Length is 32-bit unsigned integer in LITTLE ENDIAN
    const length = buffer.readUInt32LE(4);

    console.log(`[BINARY DEBUG] Full buffer length: ${buffer.length}, Identifier: ${identifier}, Length field: ${length}`);

    switch (identifier) {
        case 0:
            // Text message (JSON)
            try {
                const textPayload = buffer.slice(8).toString('utf8');
                console.log('[BINARY TEXT]', textPayload);
                handleTextMessage(textPayload);
            } catch (error) {
                console.error('[ERROR] Failed to parse binary message:', error);
            }
            break;

        case 1:
            // Binary file
            console.log('[BINARY] Received binary file');
            break;

        case 2:
            // Value-States (lights, temperatures, etc.)
            // Payload starts after 8-byte header
            const valueStatesBuffer = buffer.slice(8);
            console.log(`[BINARY DEBUG] Value states - Header length: 8, Payload length: ${valueStatesBuffer.length}, Expected entries: ${Math.floor(valueStatesBuffer.length / 24)}`);
            
            // Handle asynchronously to avoid blocking
            handleValueStates(valueStatesBuffer).catch(err => {
                console.error('[ERROR] Error handling value states:', err.message);
            });
            break;

        case 3:
            // Text-States (song titles, etc.)
            handleTextStates(buffer.slice(8));
            break;

        default:
            console.log(`[BINARY] Unknown identifier: ${identifier}, Buffer length: ${buffer.length}`);
    }
}

// Handle value states (24 bytes per entry: 16-byte UUID + 8-byte float)
async function handleValueStates(buffer) {
    const entrySize = 24; // 16 bytes UUID + 8 bytes float
    const entryCount = Math.floor(buffer.length / entrySize);
    
    console.log(`[VALUE STATES DEBUG] Buffer length: ${buffer.length}, Entry size: ${entrySize}, Entry count: ${entryCount}`);
    
    if (entryCount === 0) {
        console.log(`[VALUE STATES DEBUG] Empty buffer detected. Buffer length: ${buffer.length}, First 32 bytes (hex): ${buffer.slice(0, Math.min(32, buffer.length)).toString('hex')}`);
        // Sometimes we get empty buffers, skip them
        return;
    }

    console.log(`[EVENT] Received ${entryCount} value state update(s)`);

    const measurements = [];

    for (let i = 0; i < entryCount; i++) {
        const offset = i * entrySize;
        
        // Extract UUID (16 bytes) - Loxone uses little endian for UUID components
        const uuidBytes = buffer.slice(offset, offset + 16);
        const uuid = formatUUID(uuidBytes);
        
        // Extract value (8 bytes, double precision float) - LITTLE ENDIAN
        const value = buffer.readDoubleLE(offset + 16);

        // Try to get human-readable name from structure
        let sensorName = 'Unknown';
        if (state.structureData) {
            sensorName = findSensorNameByUUID(uuid, state.structureData);
        }

        console.log(`[VALUE UPDATE] UUID: ${uuid}, Name: ${sensorName}, Value: ${value}`);
        
        // Store measurement for MongoDB
        measurements.push({
            uuid: uuid,
            value: value,
            timestamp: new Date()
        });
        
        // Debug: Check if UUID is in mapping
        if (state.sensorUuidMap && state.sensorUuidMap.has && !state.sensorUuidMap.has(uuid)) {
            // This UUID is not in our mapping - might be a state UUID we haven't mapped yet
            if (state.structureData && state.structureData.controls) {
                // Try to find which control this UUID belongs to
                for (const [controlUUID, controlData] of Object.entries(state.structureData.controls)) {
                    if (controlData.states) {
                        for (const [stateName, stateUUID] of Object.entries(controlData.states)) {
                            if (stateUUID === uuid) {
                                console.log(`[DEBUG] UUID ${uuid.substring(0, 8)}... is state "${stateName}" of control "${controlData.name}" (${controlUUID.substring(0, 8)}...)`);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    // Store measurements in MongoDB if storage is available
    if (storeMeasurements && state.buildingId) {
        try {
            const result = await storeMeasurements(measurements, state.buildingId);
            if (result) {
                console.log(`[MONGODB] Stored ${result.stored} measurements, skipped ${result.skipped}`);
            }
        } catch (err) {
            console.error('[ERROR] Failed to store measurements:', err.message);
        }
    } else if (measurements.length > 0) {
        console.log(`[INFO] ${measurements.length} measurements received (MongoDB storage not configured)`);
    }
}

// Helper: Find sensor name by UUID in structure data
function findSensorNameByUUID(uuid, structureData) {
    // Check in controls and their states
    if (structureData.controls) {
        for (const [controlUUID, controlData] of Object.entries(structureData.controls)) {
            if (controlUUID === uuid) {
                return controlData.name || 'Unnamed Control';
            }
            // Check states
            if (controlData.states) {
                for (const [stateName, stateUUID] of Object.entries(controlData.states)) {
                    if (stateUUID === uuid) {
                        return `${controlData.name || 'Unnamed'} (${stateName})`;
                    }
                }
            }
        }
    }
    return 'Unknown';
}

// Handle text states
function handleTextStates(buffer) {
    // Text states have variable length, need to parse according to Loxone spec
    console.log('[EVENT] Received text state update(s)');
    // TODO: Implement text state parsing based on Loxone documentation
}

// Format UUID bytes to string
// Loxone stores UUIDs in binary with time_low, time_mid, and time_hi_and_version in LITTLE ENDIAN
function formatUUID(uuidBytes) {
    if (uuidBytes.length !== 16) {
        throw new Error(`Invalid UUID length: ${uuidBytes.length} (expected 16)`);
    }
    
    // Loxone UUID format in binary:
    // Bytes 0-3: time_low (little-endian)
    // Bytes 4-5: time_mid (little-endian)
    // Bytes 6-7: time_hi_and_version (little-endian)
    // Bytes 8-15: clock_seq_hi_and_reserved, clock_seq_low, node (big-endian)
    
    const timeLow = uuidBytes.readUInt32LE(0);
    const timeMid = uuidBytes.readUInt16LE(4);
    const timeHiAndVersion = uuidBytes.readUInt16LE(6);
    
    // Format as hex strings with proper padding
    const timeLowHex = timeLow.toString(16).padStart(8, '0');
    const timeMidHex = timeMid.toString(16).padStart(4, '0');
    const timeHiAndVersionHex = timeHiAndVersion.toString(16).padStart(4, '0');
    
    // Remaining 8 bytes are in big-endian (clock_seq + node)
    const remainingHex = uuidBytes.slice(8).toString('hex');
    
    return [
        timeLowHex,
        timeMidHex,
        timeHiAndVersionHex,
        remainingHex.substring(0, 4),
        remainingHex.substring(4)
    ].join('-');
}

// Start keepalive timer
function startKeepalive() {
    if (state.keepaliveTimer) {
        clearInterval(state.keepaliveTimer);
    }

    state.keepaliveTimer = setInterval(() => {
        if (state.authenticated && state.ws && state.ws.readyState === WebSocket.OPEN) {
            console.log('[KEEPALIVE] Sending keepalive...');
            send('keepalive');
        }
    }, config.keepaliveInterval);

    console.log(`[INFO] Keepalive started (interval: ${config.keepaliveInterval}ms)`);
}

// Connect to Loxone Miniserver
function connect(redirectUrl = null, redirectCount = 0) {
    const maxRedirects = 5;

    if (redirectCount >= maxRedirects) {
        console.error('[ERROR] Too many redirects. Aborting connection.');
        return;
    }

    const url = redirectUrl || buildWebSocketURL();
    console.log(`[CONNECT] Connecting to: ${url}`);

    const ws = new WebSocket(url, 'remotecontrol', {
        rejectUnauthorized: false, // Only for local IP testing with self-signed certs
        followRedirects: false,
        maxRedirects: 0
    });

    ws.on('open', () => {
        console.log('[CONNECT] ✓ WebSocket connection established');
        state.ws = ws;

        // Start authentication flow
        console.log('[AUTH] Requesting key and salt...');
        send(`jdev/sys/getkey2/${config.user}`);
    });

    ws.on('message', (data, isBinary) => {
        if (isBinary) {
            // Handle fragmented binary messages
            // Loxone sends: 8-byte header first, then payload in separate frame
            if (state.pendingBinaryHeader) {
                // We have a pending header, this should be the payload
                const completeMessage = Buffer.concat([state.pendingBinaryHeader, data]);
                state.pendingBinaryHeader = null;
                handleBinaryMessage(completeMessage);
            } else if (data.length === 8) {
                // This might be just a header - check if length field indicates more data
                const identifier = data.readUInt8(1);
                const length = data.readUInt32LE(4);
                
                if (length > 0 && length <= 1000000) { // Sanity check: max 1MB payload
                    // Store header and wait for payload
                    state.pendingBinaryHeader = data;
                    console.log(`[WS DEBUG] Received binary header: identifier=${identifier}, expected payload length=${length}, waiting for payload...`);
                } else {
                    // Invalid length or complete small message
                    handleBinaryMessage(data);
                }
            } else {
                // Complete message (header + payload in one frame)
                handleBinaryMessage(data);
            }
        } else {
            handleTextMessage(data.toString());
        }
    });

    ws.on('unexpected-response', (_request, response) => {
        console.log(`[REDIRECT] Received HTTP ${response.statusCode} response`);

        if (response.statusCode === 307 || response.statusCode === 301 || response.statusCode === 302) {
            const location = response.headers.location;
            if (location) {
                // Convert https:// to wss:// and http:// to ws:// for WebSocket connections
                let redirectUrl = location;
                if (location.startsWith('https://')) {
                    redirectUrl = location.replace('https://', 'wss://');
                } else if (location.startsWith('http://')) {
                    redirectUrl = location.replace('http://', 'ws://');
                }

                console.log(`[REDIRECT] Following redirect to: ${redirectUrl}`);

                // Close current connection attempt
                ws.terminate();

                // Follow the redirect
                connect(redirectUrl, redirectCount + 1);
            } else {
                console.error('[ERROR] Redirect response missing Location header');
            }
        } else {
            console.error(`[ERROR] Unexpected HTTP response: ${response.statusCode}`);

            // Read response body for more details
            let body = '';
            response.on('data', (chunk) => {
                body += chunk.toString();
            });
            response.on('end', () => {
                if (body) {
                    console.error('[ERROR] Response body:', body);
                }
            });
        }
    });

    ws.on('error', (error) => {
        // Only log non-redirect errors
        if (!error.message.includes('Unexpected server response')) {
            console.error('[ERROR] WebSocket error:', error.message);

            // Provide helpful error messages
            if (error.message.includes('ETIMEDOUT') || error.message.includes('ECONNREFUSED')) {
                console.error('');
                console.error('[TROUBLESHOOTING] Connection failed. Possible issues:');
                console.error('  1. Not on the same network as Miniserver (192.168.178.x is a local IP)');
                console.error('  2. Need to use external/cloud address (dns.loxonecloud.com)');
                console.error('  3. VPN connection required');
                console.error('  4. Firewall blocking the connection');
                console.error('');
                console.error('[SOLUTION] Try one of these:');
                console.error('  - Connect to the same network as the Miniserver');
                console.error('  - Use VPN if required');
                console.error('  - Configure LOXONE_EXTERNAL_ADDRESS and LOXONE_SERIAL in .env for cloud access');
                console.error('');
            }
        }
    });

    ws.on('close', (code, reason) => {
        console.log(`[DISCONNECT] Connection closed. Code: ${code}, Reason: ${reason || 'none'}`);

        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
            state.keepaliveTimer = null;
        }

        // Reset state
        state.authenticated = false;
        state.structureLoaded = false;
        state.ws = null;
        state.pendingBinaryHeader = null; // Clear any pending fragmented message
    });

    // Handle process termination
    process.on('SIGINT', () => {
        console.log('\n[SHUTDOWN] Shutting down...');
        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
        }
        if (ws) {
            ws.close();
        }
        process.exit(0);
    });
}

// Main entry point
console.log('='.repeat(60));
console.log('Loxone Miniserver Connection Demo');
console.log('='.repeat(60));
console.log('Configuration:');
if (config.externalAddress) {
    console.log(`  Connection: Cloud (${config.externalAddress})`);
    if (config.serialNumber) {
        console.log(`  Serial: ${config.serialNumber}`);
    }
} else {
    console.log(`  IP: ${config.ip}`);
    console.log(`  Port: ${config.port || 'default'}`);
}
console.log(`  Protocol: ${config.protocol}`);
console.log(`  User: ${config.user}`);
console.log(`  Client UUID: ${config.uuid}`);
console.log('='.repeat(60));
console.log('');

// Validate configuration
if (!config.ip || !config.user || !config.pass) {
    console.error('[ERROR] Missing required configuration. Please check your .env file.');
    console.error('[ERROR] Required: LOXONE_IP, LOXONE_USER, LOXONE_PASS');
    process.exit(1);
}

// Connect
connect();

