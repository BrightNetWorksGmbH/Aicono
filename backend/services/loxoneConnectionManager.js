const WebSocket = require('ws');
const crypto = require('crypto');
const fs = require('fs');
const fsPromises = require('fs').promises;
const path = require('path');
const mongoose = require('mongoose');
const loxoneStorageService = require('./loxoneStorageService');
const { getPoolStatistics, PRIORITY } = require('../db/connection');

class LoxoneConnectionManager {
    constructor() {
        // Map of serialNumber -> connection state
        this.connections = new Map();
        // Map of serialNumber -> reconnect timers
        this.reconnectTimers = new Map();
        // Health check timer for periodic connection restoration
        this.healthCheckTimer = null;
        // Structure files directory
        // Keep inside backend folder for deployment compatibility
        this.structureFilesDir = path.join(__dirname, '../data/loxone-structure');
        
        // Track lastModified timestamps to prevent redundant structure reprocessing
        // Per Loxone documentation, structure should only be reimported when lastModified changes
        this.structureLastModified = new Map(); // serialNumber -> lastModified string
        
        // Throttle "structure unchanged" log messages to reduce noise (log once per minute per server)
        this.structureUnchangedLogTimestamps = new Map(); // serialNumber -> last log timestamp
        
        // Ensure directory exists (async, but don't await in constructor)
        this.ensureDirectoryExists();

        // Design Decision: One connection per server (identified by miniserver_serial)
        // Multiple buildings using the same server share one connection:
        // 1. One structure file per server (LoxAPP3_<serialNumber>.json)
        // 2. Rooms and sensors are scoped to server (miniserver_serial), not building
        // 3. Connection state is shared, but we track which buildings use it
        // 4. More efficient resource usage and eliminates duplicate data
    }

    /**
     * Ensure structure files directory exists (async)
     */
    async ensureDirectoryExists() {
        try {
            await fsPromises.access(this.structureFilesDir);
        } catch (error) {
            // Directory doesn't exist, create it
            await fsPromises.mkdir(this.structureFilesDir, { recursive: true });
        }
    }

    /**
     * Generate UUID v4
     */
    generateUUID() {
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            const r = Math.random() * 16 | 0;
            const v = c === 'x' ? r : (r & 0x3 | 0x8);
            return v.toString(16);
        });
    }

    /**
     * Hash payload using specified algorithm
     */
    hashPayload(data, algorithm) {
        const hash = crypto.createHash(algorithm.toLowerCase());
        hash.update(data, 'utf8');
        return hash.digest('hex').toUpperCase();
    }

    /**
     * HMAC hash payload using specified algorithm
     */
    hmacPayload(data, key, algorithm) {
        const hmac = crypto.createHmac(algorithm.toLowerCase(), key);
        hmac.update(data);
        return hmac.digest('hex').toUpperCase();
    }

    /**
     * Build WebSocket URL from config
     */
    buildWebSocketURL(config) {
        if (config.externalAddress) {
            if (config.serialNumber) {
                const serial = config.serialNumber.replace(/:/g, '').toUpperCase();
                return `${config.protocol}://${config.externalAddress}/${serial}/ws/rfc6455`;
            } else {
                return `${config.protocol}://${config.externalAddress}/ws/rfc6455`;
            }
        }
        
        const port = config.port || '';
        const portStr = port ? `:${port}` : '';
        return `${config.protocol}://${config.ip}${portStr}/ws/rfc6455`;
    }

    /**
     * Get structure file path for a server
     */
    getStructureFilePath(serialNumber) {
        return path.join(this.structureFilesDir, `LoxAPP3_${serialNumber}.json`);
    }

    /**
     * Get buildings using a server connection
     */
    getBuildingsForServer(serialNumber) {
        const connection = this.connections.get(serialNumber);
        return connection ? Array.from(connection.buildings) : [];
    }

    /**
     * Get server serial number for a building
     */
    getServerForBuilding(buildingId) {
        for (const [serial, state] of this.connections.entries()) {
            if (state.buildings && state.buildings.has(buildingId)) {
                return serial;
            }
        }
        return null;
    }

    /**
     * Update building connection status in database
     * @private
     * @param {string} buildingId - Building ID
     * @param {boolean} connected - Connection status
     */
    async updateBuildingConnectionStatus(buildingId, connected) {
        try {
            const Building = require('../models/Building');
            const updateData = {
                miniserver_connected: connected
            };
            
            if (connected) {
                updateData.miniserver_last_connected = new Date();
            }
            
            await Building.findByIdAndUpdate(buildingId, updateData);
        } catch (err) {
            // Don't throw - connection status update is secondary
            console.warn(`[LOXONE] [${buildingId}] Failed to update building connection status:`, err.message);
        }
    }

    /**
     * Start a connection for a building
     */
    async connect(buildingId, credentials) {
        // Extract serial number from credentials
        const serialNumber = credentials.serialNumber || '';
        if (!serialNumber) {
            return { success: false, message: 'Serial number is required' };
        }

        // Check if connection already exists for this server
        let state = this.connections.get(serialNumber);
        
        if (state) {
            // Connection exists - add building to the set
            if (!state.buildings) {
                state.buildings = new Set();
            }
            if (state.buildings.has(buildingId)) {
                return { success: false, message: 'Building already connected to this server' };
            }
            state.buildings.add(buildingId);
            // Update building connection status
            await this.updateBuildingConnectionStatus(buildingId, true);
            return { success: true, message: 'Building added to existing connection' };
        }

        // Create new connection state
        state = {
            serialNumber: serialNumber,
            buildings: new Set([buildingId]), // Track which buildings use this connection
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
            sensorUuidMap: null,
            pendingBinaryHeader: null,
            reconnectAttempts: 0,
            maxReconnectAttempts: 5,
            reconnectDelay: 5000,
            config: {
                ip: credentials.ip,
                port: credentials.port || '',
                // Default to wss for external addresses, ws for local IPs
                protocol: credentials.protocol || (credentials.externalAddress ? 'wss' : (credentials.port === 443 ? 'wss' : 'ws')),
                user: credentials.user,
                pass: credentials.pass,
                uuid: credentials.clientUuid || this.generateUUID(),
                info: credentials.clientInfo || 'Aicono Backend',
                permission: credentials.permission || 2,
                keepaliveInterval: credentials.keepaliveInterval || 300000,
                externalAddress: credentials.externalAddress || '',
                serialNumber: serialNumber
            }
        };

        this.connections.set(serialNumber, state);
        
        // Ensure directory exists before connecting
        await this.ensureDirectoryExists();
        
        try {
            await this.establishConnection(serialNumber);
            // Update all buildings' connection status in database
            for (const bid of state.buildings) {
                await this.updateBuildingConnectionStatus(bid, true);
            }
            return { success: true, message: 'Connection established' };
        } catch (error) {
            this.connections.delete(serialNumber);
            // Update building connection status on failure
            await this.updateBuildingConnectionStatus(buildingId, false);
            return { success: false, message: error.message };
        }
    }

    /**
     * Establish WebSocket connection
     */
    async establishConnection(serialNumber, redirectUrl = null, redirectCount = 0) {
        const maxRedirects = 5;
        const connectionTimeout = 30000; // 30 seconds timeout
        
        // Always get fresh state reference - don't cache it
        let state = this.connections.get(serialNumber);
        if (!state) {
            throw new Error(`No state found for server ${serialNumber}`);
        }
        if (!state.config) {
            throw new Error(`State exists but config is missing for server ${serialNumber}`);
        }

        if (redirectCount >= maxRedirects) {
            throw new Error('Too many redirects');
        }
        
        // Log state info for debugging
        if (redirectCount > 0) {
            //console.log(`[LOXONE] [${serialNumber}] Redirect attempt ${redirectCount}, state exists: ${!!state}, config exists: ${!!state.config}`);
        }

        const wsUrl = redirectUrl || this.buildWebSocketURL(state.config);
        console.log(`[LOXONE] [${serialNumber}] Connecting to: ${wsUrl}${redirectUrl ? ' (redirect #' + redirectCount + ')' : ' (initial)'}`);
        
        // Warn if using CloudDNS without serial number
        if (state.config.externalAddress && !state.config.serialNumber) {
            //console.warn(`[LOXONE] [${serialNumber}] Warning: CloudDNS connection without serial number. Some Miniservers may require serial in URL format: wss://dns.loxonecloud.com/{serial}/ws/rfc6455`);
        }

        return new Promise((resolve, reject) => {
            let timeoutId = null;
            let resolved = false;
            let isRedirecting = false; // Track if we're handling a redirect

            const cleanup = () => {
                if (timeoutId) {
                    clearTimeout(timeoutId);
                    timeoutId = null;
                }
            };

            const resolveOnce = () => {
                if (!resolved) {
                    resolved = true;
                    cleanup();
                    resolve();
                }
            };

            const rejectOnce = (error) => {
                if (!resolved) {
                    resolved = true;
                    cleanup();
                    reject(error);
                }
            };

            const ws = new WebSocket(wsUrl, 'remotecontrol', {
                rejectUnauthorized: false,
                followRedirects: false,
                maxRedirects: 0
            });

            // Set connection timeout
            timeoutId = setTimeout(() => {
                if (ws.readyState !== WebSocket.OPEN) {
                    // //console.error(`[LOXONE] [${buildingId}] Connection timeout after ${connectionTimeout}ms`);
                    ws.terminate();
                    rejectOnce(new Error(`Connection timeout after ${connectionTimeout}ms. WebSocket state: ${ws.readyState}`));
                }
            }, connectionTimeout);

            ws.on('open', () => {
                //console.log(`[LOXONE] [${serialNumber}] WebSocket connected`);
                // Verify state exists before proceeding - get fresh reference
                const currentState = this.connections.get(serialNumber);
                if (!currentState) {
                    // //console.error(`[LOXONE] [${serialNumber}] State missing after WebSocket open (redirectCount: ${redirectCount})`);
                    rejectOnce(new Error('Connection state lost'));
                    return;
                }
                if (!currentState.config) {
                    // //console.error(`[LOXONE] [${serialNumber}] Config missing after WebSocket open (redirectCount: ${redirectCount})`);
                    // //console.error(`[LOXONE] [${serialNumber}] State keys:`, Object.keys(currentState));
                    rejectOnce(new Error('Connection config lost'));
                    return;
                }
                // //console.log(`[LOXONE] [${serialNumber}] State verified, user: ${currentState.config.user}`);
                currentState.ws = ws;
                this.setupWebSocketHandlers(serialNumber, ws);
                this.startAuthentication(serialNumber);
                resolveOnce();
            });

            ws.on('error', (error) => {
                // Don't reject on redirect-related errors - they're handled by unexpected-response
                if (error.message.includes('Unexpected server response') || isRedirecting) {
                    console.log(`[LOXONE] [${serialNumber}] WebSocket error during redirect (ignored):`, error.message);
                    return;
                }
                console.error(`[LOXONE] [${serialNumber}] WebSocket error:`, error.message);
                rejectOnce(error);
            });

            ws.on('close', (code, reason) => {
                //console.log(`[LOXONE] [${serialNumber}] Connection closed. Code: ${code}`);
                // If we're redirecting, don't handle this as a disconnection or error
                if (isRedirecting) {
                    //console.log(`[LOXONE] [${serialNumber}] Ignoring close event during redirect`);
                    return;
                }
                if (!resolved) {
                    // Only reject if we haven't resolved yet (connection closed before opening)
                    // But don't reject if it's a redirect-related close (code 1006 is common for redirects)
                    if (code === 1006) {
                        // Code 1006 often happens during redirects - wait a bit to see if redirect handler processes it
                        //console.log(`[LOXONE] [${serialNumber}] Connection closed with code 1006 (may be redirect), waiting...`);
                        // Give redirect handler a chance to process
                        setTimeout(() => {
                            if (!isRedirecting && !resolved) {
                                rejectOnce(new Error(`Connection closed before opening. Code: ${code}`));
                            }
                        }, 100);
                    } else {
                        rejectOnce(new Error(`Connection closed before opening. Code: ${code}`));
                    }
                } else {
                    // Connection was established but then closed - handle disconnection
                    this.handleDisconnection(serialNumber, code);
                }
            });

            ws.on('unexpected-response', (_request, response) => {
                if (response.statusCode === 307 || response.statusCode === 301 || response.statusCode === 302) {
                    const location = response.headers.location;
                    if (location) {
                        isRedirecting = true; // Mark that we're redirecting BEFORE terminating
                        let redirectUrl = location;
                        if (location.startsWith('https://')) {
                            redirectUrl = location.replace('https://', 'wss://');
                        } else if (location.startsWith('http://')) {
                            redirectUrl = location.replace('http://', 'ws://');
                        }
                        console.log(`[LOXONE] [${serialNumber}] CloudDNS redirect received: ${location} -> ${redirectUrl}`);
                        
                        // Verify state still exists before redirecting
                        const currentState = this.connections.get(serialNumber);
                        if (!currentState || !currentState.config) {
                            //console.error(`[LOXONE] [${serialNumber}] State lost before redirect!`);
                            rejectOnce(new Error('Connection state lost during redirect'));
                            return;
                        }
                        
                        ws.terminate();
                        cleanup();
                        
                        // Recursively establish connection with redirect URL
                        // This will create a new promise, and we'll resolve/reject that one
                        this.establishConnection(serialNumber, redirectUrl, redirectCount + 1)
                            .then(resolve)
                            .catch(reject);
                    } else {
                        rejectOnce(new Error(`Redirect response without location header. Status: ${response.statusCode}`));
                    }
                } else {
                    rejectOnce(new Error(`Unexpected HTTP response: ${response.statusCode}`));
                }
            });
        });
    }

    /**
     * Setup WebSocket message handlers
     */
    setupWebSocketHandlers(serialNumber, ws) {
        const state = this.connections.get(serialNumber);
        let binaryFileBuffer = null;
        let expectedFileLength = 0;

        ws.on('message', (data, isBinary) => {
            if (isBinary) {
                // Handle fragmented binary messages
                if (state.pendingBinaryHeader) {
                    const completeMessage = Buffer.concat([state.pendingBinaryHeader, data]);
                    state.pendingBinaryHeader = null;
                    this.handleBinaryMessage(serialNumber, completeMessage);
                } else if (data.length === 8) {
                    // Check if this is a header
                    const identifier = data.readUInt8(1);
                    const length = data.readUInt32LE(4);
                    if (length > 0 && length <= 1000000) {
                        state.pendingBinaryHeader = data;
                        // If identifier is 1 (binary file), track expected length
                        if (identifier === 1) {
                            expectedFileLength = length;
                            binaryFileBuffer = Buffer.alloc(0);
                        }
                    } else {
                        this.handleBinaryMessage(serialNumber, data);
                    }
                } else if (binaryFileBuffer !== null) {
                    // Accumulate binary file data
                    binaryFileBuffer = Buffer.concat([binaryFileBuffer, data]);
                    if (binaryFileBuffer.length >= expectedFileLength) {
                        // Complete file received, parse as JSON (async to avoid blocking)
                        const fileData = binaryFileBuffer.toString('utf8');
                        binaryFileBuffer = null;
                        expectedFileLength = 0;
                        
                        // Use setImmediate to yield to event loop before parsing large JSON
                        setImmediate(() => {
                            try {
                                const json = JSON.parse(fileData);
                                this.handleStructureFile(serialNumber, json).catch(err => {
                                    console.error(`[LOXONE] [${serialNumber}] Error handling structure file:`, err.message);
                                });
                            } catch (error) {
                                console.error(`[LOXONE] [${serialNumber}] Error parsing structure file:`, error.message);
                            }
                        });
                    }
                } else {
                    // Complete message (header + payload in one frame)
                    this.handleBinaryMessage(serialNumber, data);
                }
            } else {
                // Text message - could be structure file JSON
                const text = data.toString();
                
                // Use setImmediate for JSON parsing to avoid blocking event loop
                setImmediate(() => {
                    try {
                        const json = JSON.parse(text);
                        // Check if it's a structure file (has lastModified or rooms/controls)
                        if (json.lastModified || json.rooms || json.controls) {
                            this.handleStructureFile(serialNumber, json).catch(err => {
                                console.error(`[LOXONE] [${serialNumber}] Error handling structure file:`, err.message);
                            });
                        } else {
                            this.handleTextMessage(serialNumber, text);
                        }
                    } catch (error) {
                        // Not JSON, handle as plain text
                        this.handleTextMessage(serialNumber, text);
                    }
                });
            }
        });
    }

    /**
     * Send command over WebSocket
     */
    send(serialNumber, cmd) {
        const state = this.connections.get(serialNumber);
        if (state && state.ws && state.ws.readyState === WebSocket.OPEN) {
            //console.log(`[LOXONE] [${serialNumber}] [SEND] ${cmd}`);
            state.ws.send(cmd);
        }
    }

    /**
     * Start authentication flow
     */
    startAuthentication(serialNumber) {
        const state = this.connections.get(serialNumber);
        if (!state || !state.config || !state.config.user) {
            //console.error(`[LOXONE] [${serialNumber}] Cannot start authentication: state or config missing`);
            return;
        }
        //console.log(`[LOXONE] [${serialNumber}] Requesting key and salt...`);
        this.send(serialNumber, `jdev/sys/getkey2/${state.config.user}`);
    }

    /**
     * Handle text messages
     */
    handleTextMessage(serialNumber, msg) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        try {
            const json = JSON.parse(msg);

            if (json.LL && json.LL.control) {
                if (json.LL.control.includes('jdev/sys/getkey2')) {
                    this.handleGetKey2Response(serialNumber, json);
                } else if (json.LL.control.includes('jdev/sys/getjwt')) {
                    this.handleGetJWTResponse(serialNumber, json);
                } else if (json.LL.control.includes('authwithtoken')) {
                    this.handleAuthResponse(serialNumber, json);
                }
            }

            if (json.lastModified || json.LL?.value?.lastModified) {
                this.handleStructureFile(serialNumber, json);
            }
        } catch (error) {
            // Not JSON, might be plain text
            //console.log(`[LOXONE] [${serialNumber}] [RECEIVE TEXT]`, msg);
        }
    }

    /**
     * Handle getkey2 response
     */
    handleGetKey2Response(serialNumber, json) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        try {
            const value = json.LL.value;
            const hexKey = value.key;
            const hexSalt = value.salt;

            state.key = Buffer.from(hexKey, 'hex');
            state.salt = hexSalt;
            state.hashAlg = value.hashAlg || 'SHA1';

            const passwordSaltString = `${state.config.pass}:${state.salt}`;
            const pwHash = this.hashPayload(passwordSaltString, state.hashAlg);
            const userPwHashString = `${state.config.user}:${pwHash}`;
            const authHash = this.hmacPayload(userPwHashString, state.key, state.hashAlg);

            const encodedInfo = encodeURIComponent(state.config.info);
            this.send(serialNumber, `jdev/sys/getjwt/${authHash}/${state.config.user}/${state.config.permission}/${state.config.uuid}/${encodedInfo}`);
        } catch (error) {
            //console.error(`[LOXONE] [${serialNumber}] Error processing getkey2:`, error);
        }
    }

    /**
     * Handle getjwt response
     */
    async handleGetJWTResponse(serialNumber, json) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        try {
            const code = parseInt(json.LL.Code || json.LL.code || '0');
            if (code === 200 && json.LL.value && json.LL.value.token) {
                state.token = json.LL.value.token;
                if (json.LL.value.key) {
                    state.tokenKey = Buffer.from(json.LL.value.key, 'hex');
                }

                state.authenticated = true;
                //console.log(`[LOXONE] [${serialNumber}] ✓ Authentication successful`);

                this.startKeepalive(serialNumber);
                //console.log(`[LOXONE] [${serialNumber}] Fetching structure file...`);
                this.send(serialNumber, 'data/LoxAPP3.json');
            } else {
                //console.error(`[LOXONE] [${serialNumber}] Authentication failed:`, json.LL);
            }
        } catch (error) {
            //console.error(`[LOXONE] [${serialNumber}] Error processing getjwt:`, error);
        }
    }

    /**
     * Handle auth response
     */
    handleAuthResponse(serialNumber, json) {
        // Not needed for modern Loxone - JWT token acquisition is sufficient
        //console.log(`[LOXONE] [${serialNumber}] Auth response received (not needed for JWT auth)`);
    }

    /**
     * Handle structure file
     * Per Loxone documentation, checks lastModified to avoid redundant reimports
     */
    async handleStructureFile(serialNumber, json) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        try {
            // Extract lastModified from structure file (per Loxone StructureFile.pdf documentation)
            const newLastModified = json.lastModified || json.LL?.value?.lastModified;
            const existingLastModified = this.structureLastModified.get(serialNumber);
            
            // Check if structure has actually changed
            if (existingLastModified && newLastModified && existingLastModified === newLastModified) {
                // Structure hasn't changed - skip reprocessing to save database connections
                // This is the key fix for connection pool exhaustion
                
                // Throttle log messages: only log once per minute per server to reduce noise
                const now = Date.now();
                const lastLogTime = this.structureUnchangedLogTimestamps.get(serialNumber) || 0;
                if (now - lastLogTime > 60000) { // Log at most once per minute
                    console.log(`[LOXONE] [${serialNumber}] Structure unchanged (lastModified: ${newLastModified}), skipping reimport`);
                    this.structureUnchangedLogTimestamps.set(serialNumber, now);
                }
                
                // Still enable live updates if not already enabled
                if (!state.structureLoaded) {
                    state.structureLoaded = true;
                    this.send(serialNumber, 'jdev/sps/enablebinstatusupdate');
                }
                return;
            }
            
            // Structure is new or changed - process it
            if (newLastModified) {
                this.structureLastModified.set(serialNumber, newLastModified);
                console.log(`[LOXONE] [${serialNumber}] Structure file received (lastModified: ${newLastModified})`);
            } else {
                console.log(`[LOXONE] [${serialNumber}] Structure file received (no lastModified field)`);
            }

            // Save structure file per server (async to avoid blocking)
            const structureFilePath = this.getStructureFilePath(serialNumber);
            await fsPromises.writeFile(structureFilePath, JSON.stringify(json, null, 2), 'utf8');
            //console.log(`[LOXONE] [${serialNumber}] Structure file saved: ${structureFilePath}`);

            state.structureLoaded = true;
            state.structureData = json;

            // Initialize storage and import structure
            try {
                await loxoneStorageService.initializeForBuilding(serialNumber);
                const uuidMap = await loxoneStorageService.loadStructureMapping(serialNumber, json);
                state.sensorUuidMap = uuidMap;
                
                // Verify structure import completed successfully
                if (!uuidMap || uuidMap.size === 0) {
                    console.warn(`[LOXONE] [${serialNumber}] ⚠️  Structure import completed but UUID mapping is empty! Measurements will be skipped until structure is properly imported.`);
                    console.warn(`[LOXONE] [${serialNumber}] Check if sensors exist in database and are properly linked to Loxone controls.`);
                } else {
                    console.log(`[LOXONE] [${serialNumber}] ✓ Structure imported and mapping loaded (${uuidMap.size} UUID mappings ready)`);
                }
            } catch (error) {
                console.error(`[LOXONE] [${serialNumber}] Error initializing storage:`, error.message);
                console.error(`[LOXONE] [${serialNumber}] Stack trace:`, error.stack);
                // Don't enable live updates if structure import failed
                return;
            }

            // Enable live updates only after structure import is complete
            // console.log(`[LOXONE] [${serialNumber}] Enabling live status updates...`);
            this.send(serialNumber, 'jdev/sps/enablebinstatusupdate');
            
            // Reset reconnect attempts and ping failures on successful connection
            state.reconnectAttempts = 0;
            state.pingFailures = 0;
            
            // console.log(`[LOXONE] [${serialNumber}] ✓ Connection ready - receiving measurements`);
        } catch (error) {
            //console.error(`[LOXONE] [${serialNumber}] Error handling structure file:`, error);
        }
    }

    /**
     * Handle binary messages
     */
    handleBinaryMessage(serialNumber, buffer) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        if (buffer.length < 8) return;

        const identifier = buffer.readUInt8(1);
        const length = buffer.readUInt32LE(4);

        switch (identifier) {
            case 0:
                try {
                    const textPayload = buffer.slice(8).toString('utf8');
                    this.handleTextMessage(serialNumber, textPayload);
                } catch (error) {
                    //console.error(`[LOXONE] [${serialNumber}] Error parsing binary text:`, error);
                }
                break;

            case 1:
                // Binary file (structure file LoxAPP3.json)
                // The structure file comes as binary, but we need to wait for the actual JSON payload
                // It will arrive as a text message after this binary file indicator
                // //console.log(`[LOXONE] [${serialNumber}] Received binary file indicator (structure file)`);
                // The actual JSON will come in a subsequent message
                break;

            case 2:
                const valueStatesBuffer = buffer.slice(8);
                this.handleValueStates(serialNumber, valueStatesBuffer).catch(err => {
                    //console.error(`[LOXONE] [${serialNumber}] Error handling value states:`, err.message);
                });
                break;

            case 3:
                //console.log(`[LOXONE] [${serialNumber}] Received text state update(s)`);
                break;

            default:
                //console.log(`[LOXONE] [${serialNumber}] Unknown identifier: ${identifier}`);
        }
    }

    /**
     * Handle value states
     */
    async handleValueStates(serialNumber, buffer) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        const entrySize = 24;
        const entryCount = Math.floor(buffer.length / entrySize);

        if (entryCount === 0) return;

        const measurements = [];
        for (let i = 0; i < entryCount; i++) {
            const offset = i * entrySize;
            const uuidBytes = buffer.slice(offset, offset + 16);
            const uuid = this.formatUUID(uuidBytes);
            const value = buffer.readDoubleLE(offset + 16);

            measurements.push({
                uuid: uuid,
                value: value,
                timestamp: new Date()
            });
        }

        // Store measurements via queue (non-blocking)
        if (measurements.length > 0) {
            try {
                const measurementQueueService = require('./measurementQueueService');
                // Enqueue measurements for background processing
                // This allows WebSocket handler to return immediately
                measurementQueueService.enqueue(serialNumber, measurements).catch(err => {
                    console.error(`[LOXONE] [${serialNumber}] Error enqueueing measurements:`, err.message);
                });
            } catch (err) {
                console.error(`[LOXONE] [${serialNumber}] Error enqueueing measurements:`, err.message);
            }

            // Broadcast to real-time subscribers (non-blocking)
            try {
                const sensorRealtimeService = require('./sensorRealtimeService');
                sensorRealtimeService.broadcastMeasurement(serialNumber, measurements)
                    .catch(err => {
                        // Silent fail - don't block storage
                        console.error(`[LOXONE] [${serialNumber}] Error broadcasting:`, err.message);
                    });
            } catch (err) {
                // Silent fail
            }
        }
    }

    /**
     * Format UUID from binary
     */
    formatUUID(uuidBytes) {
        if (uuidBytes.length !== 16) {
            throw new Error(`Invalid UUID length: ${uuidBytes.length}`);
        }

        const timeLow = uuidBytes.readUInt32LE(0);
        const timeMid = uuidBytes.readUInt16LE(4);
        const timeHiAndVersion = uuidBytes.readUInt16LE(6);

        const timeLowHex = timeLow.toString(16).padStart(8, '0');
        const timeMidHex = timeMid.toString(16).padStart(4, '0');
        const timeHiAndVersionHex = timeHiAndVersion.toString(16).padStart(4, '0');
        const remainingHex = uuidBytes.slice(8).toString('hex');

        return [
            timeLowHex,
            timeMidHex,
            timeHiAndVersionHex,
            remainingHex.substring(0, 4),
            remainingHex.substring(4)
        ].join('-');
    }

    /**
     * Start keepalive with enhanced ping detection
     */
    startKeepalive(serialNumber) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
        }

        // Track consecutive ping failures
        if (!state.pingFailures) {
            state.pingFailures = 0;
        }
        const maxPingFailures = 5; // Force reconnect after 5 consecutive ping failures (increased from 3 to reduce reconnection churn)

        state.keepaliveTimer = setInterval(() => {
            if (state.authenticated && state.ws && state.ws.readyState === WebSocket.OPEN) {
                // Use WebSocket ping to detect dead connections
                try {
                    const pingSent = state.ws.ping();
                    if (!pingSent) {
                        // Ping failed - connection may be dead
                        state.pingFailures++;
                        if (state.pingFailures >= maxPingFailures) {
                            console.warn(`[LOXONE] [${serialNumber}] Multiple ping failures detected (${state.pingFailures}), forcing reconnection`);
                            // Force disconnection to trigger reconnection logic
                            if (state.ws) {
                                state.ws.terminate();
                            }
                            return;
                        }
                    } else {
                        // Ping sent successfully, reset failure counter
                        state.pingFailures = 0;
                    }
                } catch (error) {
                    // Ping error - connection likely dead
                    state.pingFailures++;
                    if (state.pingFailures >= maxPingFailures) {
                        console.warn(`[LOXONE] [${serialNumber}] Ping error detected (${state.pingFailures} failures), forcing reconnection:`, error.message);
                        if (state.ws) {
                            state.ws.terminate();
                        }
                        return;
                    }
                }
                
                // Also send keepalive command (Loxone protocol)
                this.send(serialNumber, 'keepalive');
            }
        }, state.config.keepaliveInterval);

        // Reset ping failures on successful keepalive start
        state.pingFailures = 0;
        //console.log(`[LOXONE] [${serialNumber}] Keepalive started`);
    }

    /**
     * Handle disconnection
     */
    handleDisconnection(serialNumber, code) {
        const state = this.connections.get(serialNumber);
        if (!state) return;

        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
            state.keepaliveTimer = null;
        }

        state.authenticated = false;
        state.structureLoaded = false;
        state.ws = null;
        state.pendingBinaryHeader = null;
        state.pingFailures = 0; // Reset ping failures

        if (code === 1000) {
            // Manual disconnect - update all buildings and close connection
            for (const buildingId of state.buildings) {
                this.updateBuildingConnectionStatus(buildingId, false).catch(() => {});
            }
            this.connections.delete(serialNumber);
            return;
        }

        // Auto-reconnect
        if (state.reconnectAttempts < state.maxReconnectAttempts) {
            state.reconnectAttempts++;
            const delay = state.reconnectDelay * state.reconnectAttempts;
            //console.log(`[LOXONE] [${serialNumber}] Reconnecting in ${delay}ms (attempt ${state.reconnectAttempts})`);

            const timer = setTimeout(() => {
                this.reconnectTimers.delete(serialNumber);
                this.establishConnection(serialNumber).catch(err => {
                    //console.error(`[LOXONE] [${serialNumber}] Reconnection failed:`, err.message);
                });
            }, delay);

            this.reconnectTimers.set(serialNumber, timer);
        } else {
            //console.error(`[LOXONE] [${serialNumber}] Max reconnection attempts reached`);
            // Don't delete connection - let health check restore it
            // Reset reconnect attempts to allow health check to retry
            state.reconnectAttempts = 0;
            // Update all buildings' connection status when max attempts reached
            for (const buildingId of state.buildings) {
                this.updateBuildingConnectionStatus(buildingId, false).catch(() => {});
            }
        }
    }

    /**
     * Disconnect a building
     */
    async disconnect(buildingId) {
        // Find the connection that has this building
        const serialNumber = this.getServerForBuilding(buildingId);
        if (!serialNumber) {
            return { success: false, message: 'No connection found for building' };
        }

        const state = this.connections.get(serialNumber);
        if (!state) {
            return { success: false, message: 'Connection state not found' };
        }

        // Remove building from the set
        state.buildings.delete(buildingId);
        
        // Update building connection status
        await this.updateBuildingConnectionStatus(buildingId, false);

        // If no more buildings use this connection, close it
        if (state.buildings.size === 0) {
            if (this.reconnectTimers.has(serialNumber)) {
                clearTimeout(this.reconnectTimers.get(serialNumber));
                this.reconnectTimers.delete(serialNumber);
            }

            if (state.ws) {
                state.ws.close(1000, 'Manual disconnect - no buildings using connection');
            }

            if (state.keepaliveTimer) {
                clearInterval(state.keepaliveTimer);
            }

            this.connections.delete(serialNumber);
            
            // Clear lastModified cache so structure is reloaded on reconnect
            this.structureLastModified.delete(serialNumber);
            // Clear log throttle timestamp
            this.structureUnchangedLogTimestamps.delete(serialNumber);
        }
        
        //console.log(`[LOXONE] [${buildingId}] Disconnected from server ${serialNumber}`);
        return { success: true, message: 'Disconnected' };
    }

    /**
     * Get connection status for a building
     */
    getConnectionStatus(buildingId) {
        const serialNumber = this.getServerForBuilding(buildingId);
        if (!serialNumber) {
            return { connected: false, authenticated: false };
        }

        const state = this.connections.get(serialNumber);
        if (!state) {
            return { connected: false, authenticated: false };
        }

        return {
            connected: state.ws && state.ws.readyState === WebSocket.OPEN,
            authenticated: state.authenticated,
            structureLoaded: state.structureLoaded,
            reconnectAttempts: state.reconnectAttempts,
            serialNumber: serialNumber,
            buildings: Array.from(state.buildings)
        };
    }

    /**
     * Get all connections
     */
    getAllConnections() {
        const statuses = {};
        for (const [serialNumber, state] of this.connections.entries()) {
            statuses[serialNumber] = {
                connected: state.ws && state.ws.readyState === WebSocket.OPEN,
                authenticated: state.authenticated,
                structureLoaded: state.structureLoaded,
                buildings: Array.from(state.buildings)
            };
        }
        return statuses;
    }

    /**
     * Restore all connections from database on server startup
     * This ensures connections persist across server restarts/deployments
     * 
     * @returns {Promise<Object>} Restoration result with counts
     */
    async restoreConnections() {
        try {
            // Wait for mongoose to be ready
            if (mongoose.connection.readyState !== 1) {
                console.log('[LOXONE] Database not ready, skipping connection restoration');
                return { restored: 0, failed: 0, results: [] };
            }

            const Building = require('../models/Building');
            
            // Find all buildings with Loxone configuration
            const buildings = await Building.find({
                $and: [
                    { miniserver_user: { $exists: true, $ne: null, $ne: '' } },
                    { miniserver_pass: { $exists: true, $ne: null, $ne: '' } },
                    {
                        $or: [
                            { miniserver_ip: { $exists: true, $ne: null, $ne: '' } },
                            { miniserver_external_address: { $exists: true, $ne: null, $ne: '' } }
                        ]
                    }
                ]
            });

            if (buildings.length === 0) {
                console.log('[LOXONE] No buildings with Loxone configuration found to restore');
                return { restored: 0, failed: 0, results: [] };
            }

            console.log(`[LOXONE] Found ${buildings.length} building(s) with Loxone configuration. Restoring connections...`);

            // Group buildings by serial number
            const buildingsBySerial = new Map();
            for (const building of buildings) {
                const serialNumber = building.miniserver_serial;
                if (!serialNumber) {
                    console.warn(`[LOXONE] Building ${building.name} (${building._id}) has no serial number, skipping`);
                    continue;
                }
                if (!buildingsBySerial.has(serialNumber)) {
                    buildingsBySerial.set(serialNumber, []);
                }
                buildingsBySerial.get(serialNumber).push(building);
            }

            let restored = 0;
            let failed = 0;
            const results = [];
            const failedSerials = []; // Track failed serials for retry

            // First pass: Try to restore all connections (one per serial)
            for (const [serialNumber, serialBuildings] of buildingsBySerial.entries()) {
                try {
                    // Skip if connection already exists for this serial
                    if (this.connections.has(serialNumber)) {
                        const existingState = this.connections.get(serialNumber);
                        if (existingState.ws && existingState.ws.readyState === WebSocket.OPEN) {
                            // Add all buildings to existing connection
                            for (const building of serialBuildings) {
                                const buildingId = building._id.toString();
                                if (!existingState.buildings.has(buildingId)) {
                                    existingState.buildings.add(buildingId);
                                    await this.updateBuildingConnectionStatus(buildingId, true);
                                }
                                restored++;
                                results.push({
                                    buildingId: buildingId,
                                    buildingName: building.name,
                                    success: true,
                                    message: 'Added to existing connection'
                                });
                            }
                            console.log(`[LOXONE] Connection already active for serial ${serialNumber}, added ${serialBuildings.length} building(s)`);
                            continue;
                        } else {
                            // Connection exists but is not open, remove it first
                            this.connections.delete(serialNumber);
                        }
                    }
                    
                    // Use first building's credentials (all should be the same for same serial)
                    const firstBuilding = serialBuildings[0];
                    const credentials = {
                        ip: firstBuilding.miniserver_ip,
                        port: firstBuilding.miniserver_port,
                        protocol: firstBuilding.miniserver_protocol,
                        user: firstBuilding.miniserver_user,
                        pass: firstBuilding.miniserver_pass,
                        externalAddress: firstBuilding.miniserver_external_address,
                        serialNumber: serialNumber
                    };

                    // Connect first building (will create connection for the serial)
                    const firstBuildingId = firstBuilding._id.toString();
                    const result = await this.connect(firstBuildingId, credentials);
                    
                    if (result.success) {
                        // Add remaining buildings to the connection
                        const state = this.connections.get(serialNumber);
                        for (let i = 1; i < serialBuildings.length; i++) {
                            const building = serialBuildings[i];
                            const buildingId = building._id.toString();
                            if (state && !state.buildings.has(buildingId)) {
                                state.buildings.add(buildingId);
                                await this.updateBuildingConnectionStatus(buildingId, true);
                            }
                        }
                        
                        restored += serialBuildings.length;
                        console.log(`[LOXONE] ✓ Restored connection for serial ${serialNumber} with ${serialBuildings.length} building(s)`);
                        for (const building of serialBuildings) {
                            results.push({
                                buildingId: building._id.toString(),
                                buildingName: building.name,
                                success: true,
                                message: result.message
                            });
                        }
                    } else {
                        failed += serialBuildings.length;
                        failedSerials.push({ serialNumber, buildings: serialBuildings, attempt: 1 });
                        console.warn(`[LOXONE] ✗ Failed to restore connection for serial ${serialNumber}: ${result.message}`);
                        for (const building of serialBuildings) {
                            results.push({
                                buildingId: building._id.toString(),
                                buildingName: building.name,
                                success: false,
                                message: result.message
                            });
                        }
                    }

                    // Small delay between connections to avoid overwhelming the server
                    await new Promise(resolve => setTimeout(resolve, 1000));
                } catch (error) {
                    failed += serialBuildings.length;
                    failedSerials.push({ serialNumber, buildings: serialBuildings, attempt: 1 });
                    console.error(`[LOXONE] Error restoring connection for serial ${serialNumber}:`, error.message);
                    for (const building of serialBuildings) {
                        results.push({
                            buildingId: building._id.toString(),
                            buildingName: building.name,
                            success: false,
                            message: error.message
                        });
                    }
                }
            }

            // Retry failed connections with exponential backoff (3-4 attempts)
            const maxRetries = 3;
            if (failedSerials.length > 0) {
                console.log(`[LOXONE] Retrying ${failedSerials.length} failed connection(s) (up to ${maxRetries} attempts)...`);
                
                for (let retryAttempt = 1; retryAttempt <= maxRetries; retryAttempt++) {
                    const delay = Math.pow(2, retryAttempt) * 1000; // 2s, 4s, 8s
                    console.log(`[LOXONE] Retry attempt ${retryAttempt}/${maxRetries} starting in ${delay}ms...`);
                    await new Promise(resolve => setTimeout(resolve, delay));
                    
                    const stillFailed = [];
                    
                    for (const { serialNumber, buildings } of failedSerials) {
                        try {
                            // Skip if already connected (might have been restored by another process)
                            if (this.connections.has(serialNumber)) {
                                const existingState = this.connections.get(serialNumber);
                                if (existingState.ws && existingState.ws.readyState === WebSocket.OPEN) {
                                    // Add all buildings to existing connection
                                    for (const building of buildings) {
                                        const buildingId = building._id.toString();
                                        if (!existingState.buildings.has(buildingId)) {
                                            existingState.buildings.add(buildingId);
                                            await this.updateBuildingConnectionStatus(buildingId, true);
                                        }
                                        restored++;
                                        failed--;
                                        const resultIndex = results.findIndex(r => r.buildingId === buildingId);
                                        if (resultIndex !== -1) {
                                            results[resultIndex].success = true;
                                            results[resultIndex].message = `Restored on retry ${retryAttempt}`;
                                        }
                                    }
                                    console.log(`[LOXONE] ✓ Connection restored on retry ${retryAttempt} for serial ${serialNumber}`);
                                    continue;
                                } else {
                                    // Connection exists but is not open, remove it first
                                    this.connections.delete(serialNumber);
                                }
                            }
                            
                            const firstBuilding = buildings[0];
                            const credentials = {
                                ip: firstBuilding.miniserver_ip,
                                port: firstBuilding.miniserver_port,
                                protocol: firstBuilding.miniserver_protocol,
                                user: firstBuilding.miniserver_user,
                                pass: firstBuilding.miniserver_pass,
                                externalAddress: firstBuilding.miniserver_external_address,
                                serialNumber: serialNumber
                            };

                            const firstBuildingId = firstBuilding._id.toString();
                            const result = await this.connect(firstBuildingId, credentials);
                            
                            if (result.success) {
                                // Add remaining buildings
                                const state = this.connections.get(serialNumber);
                                for (let i = 1; i < buildings.length; i++) {
                                    const building = buildings[i];
                                    const buildingId = building._id.toString();
                                    if (state && !state.buildings.has(buildingId)) {
                                        state.buildings.add(buildingId);
                                        await this.updateBuildingConnectionStatus(buildingId, true);
                                    }
                                }
                                
                                restored += buildings.length;
                                failed -= buildings.length;
                                console.log(`[LOXONE] ✓ Connection restored on retry ${retryAttempt} for serial ${serialNumber}`);
                                
                                for (const building of buildings) {
                                    const buildingId = building._id.toString();
                                    const resultIndex = results.findIndex(r => r.buildingId === buildingId);
                                    if (resultIndex !== -1) {
                                        results[resultIndex].success = true;
                                        results[resultIndex].message = `Restored on retry ${retryAttempt}`;
                                    }
                                }
                            } else {
                                stillFailed.push({ serialNumber, buildings, attempt: retryAttempt + 1 });
                                console.warn(`[LOXONE] ✗ Retry ${retryAttempt} failed for serial ${serialNumber}: ${result.message}`);
                            }
                        } catch (error) {
                            stillFailed.push({ serialNumber, buildings, attempt: retryAttempt + 1 });
                            console.error(`[LOXONE] Error on retry ${retryAttempt} for serial ${serialNumber}:`, error.message);
                        }
                    }
                    
                    failedSerials.length = 0;
                    failedSerials.push(...stillFailed);
                    
                    if (failedSerials.length === 0) {
                        console.log(`[LOXONE] ✓ All connections restored successfully after ${retryAttempt} retry attempt(s)`);
                        break; // All connections restored
                    }
                }
            }

            console.log(`[LOXONE] Connection restoration complete: ${restored} restored, ${failed} failed`);
            return { restored, failed, results };
        } catch (error) {
            console.error('[LOXONE] Error during connection restoration:', error.message);
            // Don't throw - allow server to start even if restoration fails
            return { restored: 0, failed: 0, results: [], error: error.message };
        }
    }

    /**
     * Check and restore connections periodically
     * This method checks all buildings in the database and restores any dead connections
     * Uses LOW priority to avoid interfering with real-time data processing
     */
    async checkAndRestoreConnections() {
        try {
            // Wait for mongoose to be ready
            if (mongoose.connection.readyState !== 1) {
                return;
            }

            // Check pool statistics (LOW priority) - skip if pool is busy
            try {
                const poolStats = await getPoolStatistics(PRIORITY.LOW);
                if (!poolStats.available) {
                    return; // Database not available
                }
                // Skip health check if pool usage is too high (>85% for LOW priority)
                if (poolStats.effectiveUsagePercent > 85) {
                    // Silently skip - don't log to avoid spam
                    return;
                }
            } catch (poolError) {
                // If pool check fails, proceed anyway (non-critical)
                // console.warn('[LOXONE] [HEALTH-CHECK] Error checking pool stats:', poolError.message);
            }

            const Building = require('../models/Building');
            
            // Find all buildings with Loxone configuration (LOW priority operation)
            const buildings = await Building.find({
                $and: [
                    { miniserver_user: { $exists: true, $ne: null, $ne: '' } },
                    { miniserver_pass: { $exists: true, $ne: null, $ne: '' } },
                    {
                        $or: [
                            { miniserver_ip: { $exists: true, $ne: null, $ne: '' } },
                            { miniserver_external_address: { $exists: true, $ne: null, $ne: '' } }
                        ]
                    }
                ]
            });

            if (buildings.length === 0) {
                return;
            }

            // Group buildings by serial number
            const buildingsBySerial = new Map();
            for (const building of buildings) {
                const serialNumber = building.miniserver_serial;
                if (!serialNumber) {
                    continue; // Skip buildings without serial
                }
                if (!buildingsBySerial.has(serialNumber)) {
                    buildingsBySerial.set(serialNumber, []);
                }
                buildingsBySerial.get(serialNumber).push(building);
            }

            let restored = 0;
            let checked = 0;

            // Process servers sequentially with delays to avoid overwhelming the system
            for (const [serialNumber, serialBuildings] of buildingsBySerial.entries()) {
                try {
                    // Yield to event loop before processing each server
                    await new Promise(resolve => setImmediate(resolve));
                    
                    checked++;
                    
                    const state = this.connections.get(serialNumber);
                    // Check if connection is fully ready: WebSocket open, authenticated, and structure loaded
                    const isConnected = state && 
                        state.ws && 
                        state.ws.readyState === WebSocket.OPEN && 
                        state.authenticated && 
                        state.structureLoaded;
                    
                    // Also check if connection is partially ready (authenticated but structure not loaded)
                    const isPartiallyConnected = state && 
                        state.ws && 
                        state.ws.readyState === WebSocket.OPEN && 
                        state.authenticated && 
                        !state.structureLoaded;
                    
                    if (isPartiallyConnected) {
                        // Connection is authenticated but structure not loaded - this means measurements will be skipped
                        console.warn(`[LOXONE] [HEALTH-CHECK] [${serialNumber}] Connection authenticated but structure not loaded. Measurements will be skipped until structure loads.`);
                        // Don't restore - let it complete structure loading, but log the issue
                    }
                    
                    if (!isConnected) {
                        // Connection is dead or missing - attempt to restore
                        if (state) {
                            // Clean up dead connection state
                            if (state.keepaliveTimer) {
                                clearInterval(state.keepaliveTimer);
                                state.keepaliveTimer = null;
                            }
                            if (state.ws) {
                                try {
                                    state.ws.terminate();
                                } catch (err) {
                                    // Ignore errors when terminating dead connection
                                }
                            }
                            // Remove stale state
                            this.connections.delete(serialNumber);
                        }
                        
                        // Use first building's credentials (all should be the same for same serial)
                        const firstBuilding = serialBuildings[0];
                        const credentials = {
                            ip: firstBuilding.miniserver_ip,
                            port: firstBuilding.miniserver_port,
                            protocol: firstBuilding.miniserver_protocol,
                            user: firstBuilding.miniserver_user,
                            pass: firstBuilding.miniserver_pass,
                            externalAddress: firstBuilding.miniserver_external_address,
                            serialNumber: serialNumber
                        };

                        // Fire-and-forget connection attempt (non-blocking)
                        // Don't await to avoid blocking health check
                        const firstBuildingId = firstBuilding._id.toString();
                        this.connect(firstBuildingId, credentials)
                            .then(async result => {
                                if (result.success) {
                                    // Add remaining buildings to the connection
                                    const newState = this.connections.get(serialNumber);
                                    if (newState) {
                                        for (let i = 1; i < serialBuildings.length; i++) {
                                            const building = serialBuildings[i];
                                            const buildingId = building._id.toString();
                                            if (!newState.buildings.has(buildingId)) {
                                                newState.buildings.add(buildingId);
                                                await this.updateBuildingConnectionStatus(buildingId, true);
                                            }
                                        }
                                    }
                                    restored += serialBuildings.length;
                                    console.log(`[LOXONE] [HEALTH-CHECK] ✓ Restored connection for serial ${serialNumber} with ${serialBuildings.length} building(s)`);
                                }
                            })
                            .catch(error => {
                                // Log but don't throw - continue with other servers
                                console.error(`[LOXONE] [HEALTH-CHECK] Error restoring connection for serial ${serialNumber}:`, error.message);
                            });
                    }
                    
                    // Small delay between servers to avoid overwhelming the system
                    await new Promise(resolve => setTimeout(resolve, 1000));
                } catch (error) {
                    // Log but continue checking other servers
                    console.error(`[LOXONE] [HEALTH-CHECK] Error checking serial ${serialNumber}:`, error.message);
                }
            }

            if (restored > 0) {
                console.log(`[LOXONE] [HEALTH-CHECK] Restored ${restored} connection(s) out of ${checked} checked`);
            }
        } catch (error) {
            console.error('[LOXONE] [HEALTH-CHECK] Error during health check:', error.message);
        }
    }

    /**
     * Start periodic health check
     * Checks every 5 minutes for dead connections and restores them
     */
    startHealthCheck() {
        if (this.healthCheckTimer) {
            clearInterval(this.healthCheckTimer);
        }

        // Check every 5 minutes
        const healthCheckInterval = 5 * 60 * 1000; // 5 minutes
        
        this.healthCheckTimer = setInterval(() => {
            // Use setImmediate to yield to event loop before starting health check
            setImmediate(() => {
                this.checkAndRestoreConnections().catch(err => {
                    console.error('[LOXONE] [HEALTH-CHECK] Error in health check:', err.message);
                });
            });
        }, healthCheckInterval);

        console.log('[LOXONE] [HEALTH-CHECK] Periodic health check started (every 5 minutes)');
    }

    /**
     * Stop periodic health check
     */
    stopHealthCheck() {
        if (this.healthCheckTimer) {
            clearInterval(this.healthCheckTimer);
            this.healthCheckTimer = null;
            console.log('[LOXONE] [HEALTH-CHECK] Periodic health check stopped');
        }
    }
}

module.exports = new LoxoneConnectionManager();

