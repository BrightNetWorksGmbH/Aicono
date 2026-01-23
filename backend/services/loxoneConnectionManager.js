const WebSocket = require('ws');
const crypto = require('crypto');
const fs = require('fs');
const fsPromises = require('fs').promises;
const path = require('path');
const mongoose = require('mongoose');
const loxoneStorageService = require('./loxoneStorageService');

class LoxoneConnectionManager {
    constructor() {
        // Map of buildingId -> connection state
        this.connections = new Map();
        // Map of buildingId -> reconnect timers
        this.reconnectTimers = new Map();
        // Structure files directory
        // Keep inside backend folder for deployment compatibility
        this.structureFilesDir = path.join(__dirname, '../data/loxone-structure');
        
        // Ensure directory exists (async, but don't await in constructor)
        this.ensureDirectoryExists();

        // Design Decision: One connection per building
        // Even if two buildings use the same Loxone server (same credentials),
        // we create separate connections because:
        // 1. Each building has its own structure file (LoxAPP3_<buildingId>.json)
        // 2. Each building has its own sensor/room mappings in MongoDB
        // 3. Each building maintains independent connection state
        // 4. Simpler error handling and reconnection logic
        // 
        // Future optimization: Could detect matching credentials and reuse connections,
        // but would need to handle structure file routing and state management per building.
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
     * Get structure file path for a building
     */
    getStructureFilePath(buildingId) {
        return path.join(this.structureFilesDir, `LoxAPP3_${buildingId}.json`);
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
        // Prevent duplicate connections
        if (this.connections.has(buildingId)) {
            // //console.log(`[LOXONE] [${buildingId}] Connection already exists`);
            return { success: false, message: 'Connection already exists' };
        }

        const state = {
            buildingId: buildingId,
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
                serialNumber: credentials.serialNumber || ''
            }
        };

        this.connections.set(buildingId, state);
        
        // Ensure directory exists before connecting
        await this.ensureDirectoryExists();
        
        try {
            await this.establishConnection(buildingId);
            // Update building connection status in database
            await this.updateBuildingConnectionStatus(buildingId, true);
            return { success: true, message: 'Connection established' };
        } catch (error) {
            this.connections.delete(buildingId);
            // Update building connection status on failure
            await this.updateBuildingConnectionStatus(buildingId, false);
            return { success: false, message: error.message };
        }
    }

    /**
     * Establish WebSocket connection
     */
    async establishConnection(buildingId, redirectUrl = null, redirectCount = 0) {
        const maxRedirects = 5;
        const connectionTimeout = 30000; // 30 seconds timeout
        
        // Always get fresh state reference - don't cache it
        let state = this.connections.get(buildingId);
        if (!state) {
            throw new Error(`No state found for building ${buildingId}`);
        }
        if (!state.config) {
            throw new Error(`State exists but config is missing for building ${buildingId}`);
        }

        if (redirectCount >= maxRedirects) {
            throw new Error('Too many redirects');
        }
        
        // Log state info for debugging
        if (redirectCount > 0) {
            //console.log(`[LOXONE] [${buildingId}] Redirect attempt ${redirectCount}, state exists: ${!!state}, config exists: ${!!state.config}`);
        }

        const wsUrl = redirectUrl || this.buildWebSocketURL(state.config);
        // //console.log(`[LOXONE] [${buildingId}] Connecting to: ${wsUrl}`);
        
        // Warn if using CloudDNS without serial number
        if (state.config.externalAddress && !state.config.serialNumber) {
            //console.warn(`[LOXONE] [${buildingId}] Warning: CloudDNS connection without serial number. Some Miniservers may require serial in URL format: wss://dns.loxonecloud.com/{serial}/ws/rfc6455`);
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
                //console.log(`[LOXONE] [${buildingId}] WebSocket connected`);
                // Verify state exists before proceeding - get fresh reference
                const currentState = this.connections.get(buildingId);
                if (!currentState) {
                    // //console.error(`[LOXONE] [${buildingId}] State missing after WebSocket open (redirectCount: ${redirectCount})`);
                    rejectOnce(new Error('Connection state lost'));
                    return;
                }
                if (!currentState.config) {
                    // //console.error(`[LOXONE] [${buildingId}] Config missing after WebSocket open (redirectCount: ${redirectCount})`);
                    // //console.error(`[LOXONE] [${buildingId}] State keys:`, Object.keys(currentState));
                    rejectOnce(new Error('Connection config lost'));
                    return;
                }
                // //console.log(`[LOXONE] [${buildingId}] State verified, user: ${currentState.config.user}`);
                currentState.ws = ws;
                this.setupWebSocketHandlers(buildingId, ws);
                this.startAuthentication(buildingId);
                resolveOnce();
            });

            ws.on('error', (error) => {
                // Don't reject on redirect-related errors - they're handled by unexpected-response
                if (error.message.includes('Unexpected server response') || isRedirecting) {
                    // //console.log(`[LOXONE] [${buildingId}] WebSocket error during redirect (ignored):`, error.message);
                    return;
                }
                // //console.error(`[LOXONE] [${buildingId}] WebSocket error:`, error.message);
                rejectOnce(error);
            });

            ws.on('close', (code, reason) => {
                //console.log(`[LOXONE] [${buildingId}] Connection closed. Code: ${code}`);
                // If we're redirecting, don't handle this as a disconnection or error
                if (isRedirecting) {
                    //console.log(`[LOXONE] [${buildingId}] Ignoring close event during redirect`);
                    return;
                }
                if (!resolved) {
                    // Only reject if we haven't resolved yet (connection closed before opening)
                    // But don't reject if it's a redirect-related close (code 1006 is common for redirects)
                    if (code === 1006) {
                        // Code 1006 often happens during redirects - wait a bit to see if redirect handler processes it
                        //console.log(`[LOXONE] [${buildingId}] Connection closed with code 1006 (may be redirect), waiting...`);
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
                    this.handleDisconnection(buildingId, code);
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
                        //console.log(`[LOXONE] [${buildingId}] Redirect to: ${redirectUrl}`);
                        
                        // Verify state still exists before redirecting
                        const currentState = this.connections.get(buildingId);
                        if (!currentState || !currentState.config) {
                            //console.error(`[LOXONE] [${buildingId}] State lost before redirect!`);
                            rejectOnce(new Error('Connection state lost during redirect'));
                            return;
                        }
                        
                        ws.terminate();
                        cleanup();
                        
                        // Recursively establish connection with redirect URL
                        // This will create a new promise, and we'll resolve/reject that one
                        this.establishConnection(buildingId, redirectUrl, redirectCount + 1)
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
    setupWebSocketHandlers(buildingId, ws) {
        const state = this.connections.get(buildingId);
        let binaryFileBuffer = null;
        let expectedFileLength = 0;

        ws.on('message', (data, isBinary) => {
            if (isBinary) {
                // Handle fragmented binary messages
                if (state.pendingBinaryHeader) {
                    const completeMessage = Buffer.concat([state.pendingBinaryHeader, data]);
                    state.pendingBinaryHeader = null;
                    this.handleBinaryMessage(buildingId, completeMessage);
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
                        this.handleBinaryMessage(buildingId, data);
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
                                this.handleStructureFile(buildingId, json).catch(err => {
                                    console.error(`[LOXONE] [${buildingId}] Error handling structure file:`, err.message);
                                });
                            } catch (error) {
                                console.error(`[LOXONE] [${buildingId}] Error parsing structure file:`, error.message);
                            }
                        });
                    }
                } else {
                    // Complete message (header + payload in one frame)
                    this.handleBinaryMessage(buildingId, data);
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
                            this.handleStructureFile(buildingId, json).catch(err => {
                                console.error(`[LOXONE] [${buildingId}] Error handling structure file:`, err.message);
                            });
                        } else {
                            this.handleTextMessage(buildingId, text);
                        }
                    } catch (error) {
                        // Not JSON, handle as plain text
                        this.handleTextMessage(buildingId, text);
                    }
                });
            }
        });
    }

    /**
     * Send command over WebSocket
     */
    send(buildingId, cmd) {
        const state = this.connections.get(buildingId);
        if (state && state.ws && state.ws.readyState === WebSocket.OPEN) {
            //console.log(`[LOXONE] [${buildingId}] [SEND] ${cmd}`);
            state.ws.send(cmd);
        }
    }

    /**
     * Start authentication flow
     */
    startAuthentication(buildingId) {
        const state = this.connections.get(buildingId);
        if (!state || !state.config || !state.config.user) {
            //console.error(`[LOXONE] [${buildingId}] Cannot start authentication: state or config missing`);
            return;
        }
        //console.log(`[LOXONE] [${buildingId}] Requesting key and salt...`);
        this.send(buildingId, `jdev/sys/getkey2/${state.config.user}`);
    }

    /**
     * Handle text messages
     */
    handleTextMessage(buildingId, msg) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        try {
            const json = JSON.parse(msg);

            if (json.LL && json.LL.control) {
                if (json.LL.control.includes('jdev/sys/getkey2')) {
                    this.handleGetKey2Response(buildingId, json);
                } else if (json.LL.control.includes('jdev/sys/getjwt')) {
                    this.handleGetJWTResponse(buildingId, json);
                } else if (json.LL.control.includes('authwithtoken')) {
                    this.handleAuthResponse(buildingId, json);
                }
            }

            if (json.lastModified || json.LL?.value?.lastModified) {
                this.handleStructureFile(buildingId, json);
            }
        } catch (error) {
            // Not JSON, might be plain text
            //console.log(`[LOXONE] [${buildingId}] [RECEIVE TEXT]`, msg);
        }
    }

    /**
     * Handle getkey2 response
     */
    handleGetKey2Response(buildingId, json) {
        const state = this.connections.get(buildingId);
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
            this.send(buildingId, `jdev/sys/getjwt/${authHash}/${state.config.user}/${state.config.permission}/${state.config.uuid}/${encodedInfo}`);
        } catch (error) {
            //console.error(`[LOXONE] [${buildingId}] Error processing getkey2:`, error);
        }
    }

    /**
     * Handle getjwt response
     */
    async handleGetJWTResponse(buildingId, json) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        try {
            const code = parseInt(json.LL.Code || json.LL.code || '0');
            if (code === 200 && json.LL.value && json.LL.value.token) {
                state.token = json.LL.value.token;
                if (json.LL.value.key) {
                    state.tokenKey = Buffer.from(json.LL.value.key, 'hex');
                }

                state.authenticated = true;
                //console.log(`[LOXONE] [${buildingId}] ✓ Authentication successful`);

                this.startKeepalive(buildingId);
                //console.log(`[LOXONE] [${buildingId}] Fetching structure file...`);
                this.send(buildingId, 'data/LoxAPP3.json');
            } else {
                //console.error(`[LOXONE] [${buildingId}] Authentication failed:`, json.LL);
            }
        } catch (error) {
            //console.error(`[LOXONE] [${buildingId}] Error processing getjwt:`, error);
        }
    }

    /**
     * Handle auth response
     */
    handleAuthResponse(buildingId, json) {
        // Not needed for modern Loxone - JWT token acquisition is sufficient
        //console.log(`[LOXONE] [${buildingId}] Auth response received (not needed for JWT auth)`);
    }

    /**
     * Handle structure file
     */
    async handleStructureFile(buildingId, json) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        try {
            //console.log(`[LOXONE] [${buildingId}] Structure file received`);

            // Save structure file per building (async to avoid blocking)
            const structureFilePath = this.getStructureFilePath(buildingId);
            await fsPromises.writeFile(structureFilePath, JSON.stringify(json, null, 2), 'utf8');
            //console.log(`[LOXONE] [${buildingId}] Structure file saved: ${structureFilePath}`);

            state.structureLoaded = true;
            state.structureData = json;

            // Initialize storage and import structure
            try {
                await loxoneStorageService.initializeForBuilding(buildingId);
                const uuidMap = await loxoneStorageService.loadStructureMapping(buildingId, json);
                state.sensorUuidMap = uuidMap;
                
                // Verify structure import completed successfully
                if (!uuidMap || uuidMap.size === 0) {
                    console.warn(`[LOXONE] [${buildingId}] ⚠️  Structure import completed but UUID mapping is empty! Measurements will be skipped until structure is properly imported.`);
                } else {
                    console.log(`[LOXONE] [${buildingId}] ✓ Structure imported and mapping loaded (${uuidMap.size} UUID mappings ready)`);
                }
            } catch (error) {
                console.error(`[LOXONE] [${buildingId}] Error initializing storage:`, error.message);
                // Don't enable live updates if structure import failed
                return;
            }

            // Enable live updates only after structure import is complete
            console.log(`[LOXONE] [${buildingId}] Enabling live status updates...`);
            this.send(buildingId, 'jdev/sps/enablebinstatusupdate');
            console.log(`[LOXONE] [${buildingId}] ✓ Connection ready - receiving measurements`);
        } catch (error) {
            //console.error(`[LOXONE] [${buildingId}] Error handling structure file:`, error);
        }
    }

    /**
     * Handle binary messages
     */
    handleBinaryMessage(buildingId, buffer) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        if (buffer.length < 8) return;

        const identifier = buffer.readUInt8(1);
        const length = buffer.readUInt32LE(4);

        switch (identifier) {
            case 0:
                try {
                    const textPayload = buffer.slice(8).toString('utf8');
                    this.handleTextMessage(buildingId, textPayload);
                } catch (error) {
                    //console.error(`[LOXONE] [${buildingId}] Error parsing binary text:`, error);
                }
                break;

            case 1:
                // Binary file (structure file LoxAPP3.json)
                // The structure file comes as binary, but we need to wait for the actual JSON payload
                // It will arrive as a text message after this binary file indicator
                // //console.log(`[LOXONE] [${buildingId}] Received binary file indicator (structure file)`);
                // The actual JSON will come in a subsequent message
                break;

            case 2:
                const valueStatesBuffer = buffer.slice(8);
                this.handleValueStates(buildingId, valueStatesBuffer).catch(err => {
                    //console.error(`[LOXONE] [${buildingId}] Error handling value states:`, err.message);
                });
                break;

            case 3:
                //console.log(`[LOXONE] [${buildingId}] Received text state update(s)`);
                break;

            default:
                //console.log(`[LOXONE] [${buildingId}] Unknown identifier: ${identifier}`);
        }
    }

    /**
     * Handle value states
     */
    async handleValueStates(buildingId, buffer) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        const entrySize = 24;
        const entryCount = Math.floor(buffer.length / entrySize);

        if (entryCount === 0) return;

        //console.log(`[LOXONE] [${buildingId}] Received ${entryCount} value state update(s)`);

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
                measurementQueueService.enqueue(buildingId, measurements).catch(err => {
                    console.error(`[LOXONE] [${buildingId}] Error enqueueing measurements:`, err.message);
                });
            } catch (err) {
                console.error(`[LOXONE] [${buildingId}] Error enqueueing measurements:`, err.message);
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
     * Start keepalive
     */
    startKeepalive(buildingId) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
        }

        state.keepaliveTimer = setInterval(() => {
            if (state.authenticated && state.ws && state.ws.readyState === WebSocket.OPEN) {
                this.send(buildingId, 'keepalive');
            }
        }, state.config.keepaliveInterval);

        //console.log(`[LOXONE] [${buildingId}] Keepalive started`);
    }

    /**
     * Handle disconnection
     */
    handleDisconnection(buildingId, code) {
        const state = this.connections.get(buildingId);
        if (!state) return;

        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
            state.keepaliveTimer = null;
        }

        state.authenticated = false;
        state.structureLoaded = false;
        state.ws = null;
        state.pendingBinaryHeader = null;

        if (code === 1000) {
            // Manual disconnect
            this.connections.delete(buildingId);
            return;
        }

        // Auto-reconnect
        if (state.reconnectAttempts < state.maxReconnectAttempts) {
            state.reconnectAttempts++;
            const delay = state.reconnectDelay * state.reconnectAttempts;
            //console.log(`[LOXONE] [${buildingId}] Reconnecting in ${delay}ms (attempt ${state.reconnectAttempts})`);

            const timer = setTimeout(() => {
                this.reconnectTimers.delete(buildingId);
                this.establishConnection(buildingId).catch(err => {
                    //console.error(`[LOXONE] [${buildingId}] Reconnection failed:`, err.message);
                });
            }, delay);

            this.reconnectTimers.set(buildingId, timer);
        } else {
            //console.error(`[LOXONE] [${buildingId}] Max reconnection attempts reached`);
            this.connections.delete(buildingId);
            // Update building connection status when max attempts reached
            this.updateBuildingConnectionStatus(buildingId, false).catch(() => {});
        }
    }

    /**
     * Disconnect a building
     */
    async disconnect(buildingId) {
        const state = this.connections.get(buildingId);
        if (!state) {
            return { success: false, message: 'No connection found' };
        }

        if (this.reconnectTimers.has(buildingId)) {
            clearTimeout(this.reconnectTimers.get(buildingId));
            this.reconnectTimers.delete(buildingId);
        }

        if (state.ws) {
            state.ws.close(1000, 'Manual disconnect');
        }

        if (state.keepaliveTimer) {
            clearInterval(state.keepaliveTimer);
        }

        this.connections.delete(buildingId);
        
        // Update building connection status in database
        await this.updateBuildingConnectionStatus(buildingId, false);
        
        //console.log(`[LOXONE] [${buildingId}] Disconnected`);
        return { success: true, message: 'Disconnected' };
    }

    /**
     * Get connection status
     */
    getConnectionStatus(buildingId) {
        const state = this.connections.get(buildingId);
        if (!state) {
            return { connected: false, authenticated: false };
        }

        return {
            connected: state.ws && state.ws.readyState === WebSocket.OPEN,
            authenticated: state.authenticated,
            structureLoaded: state.structureLoaded,
            reconnectAttempts: state.reconnectAttempts
        };
    }

    /**
     * Get all connections
     */
    getAllConnections() {
        const statuses = {};
        for (const [buildingId, state] of this.connections.entries()) {
            statuses[buildingId] = {
                connected: state.ws && state.ws.readyState === WebSocket.OPEN,
                authenticated: state.authenticated,
                structureLoaded: state.structureLoaded
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

            let restored = 0;
            let failed = 0;
            const results = [];

            // Restore each connection
            for (const building of buildings) {
                try {
                    const buildingId = building._id.toString();
                    
                    // Skip if connection already exists (from previous restore attempt or manual connection)
                    if (this.connections.has(buildingId)) {
                        const existingState = this.connections.get(buildingId);
                        if (existingState.ws && existingState.ws.readyState === WebSocket.OPEN) {
                            console.log(`[LOXONE] Connection already active for building: ${building.name} (${buildingId}), skipping restore`);
                            restored++;
                            results.push({
                                buildingId: buildingId,
                                buildingName: building.name,
                                success: true,
                                message: 'Connection already active'
                            });
                            continue;
                        } else {
                            // Connection exists but is not open, remove it first
                            this.connections.delete(buildingId);
                        }
                    }
                    
                    const credentials = {
                        ip: building.miniserver_ip,
                        port: building.miniserver_port,
                        protocol: building.miniserver_protocol,
                        user: building.miniserver_user,
                        pass: building.miniserver_pass,
                        externalAddress: building.miniserver_external_address,
                        serialNumber: building.miniserver_serial
                    };

                    const result = await this.connect(buildingId, credentials);
                    
                    if (result.success) {
                        restored++;
                        console.log(`[LOXONE] ✓ Restored connection for building: ${building.name} (${buildingId})`);
                    } else {
                        failed++;
                        console.warn(`[LOXONE] ✗ Failed to restore connection for building: ${building.name} (${buildingId}): ${result.message}`);
                    }
                    
                    results.push({
                        buildingId: buildingId,
                        buildingName: building.name,
                        success: result.success,
                        message: result.message
                    });

                    // Small delay between connections to avoid overwhelming the server
                    await new Promise(resolve => setTimeout(resolve, 1000));
                } catch (error) {
                    failed++;
                    const buildingId = building._id.toString();
                    console.error(`[LOXONE] Error restoring connection for building ${buildingId}:`, error.message);
                    results.push({
                        buildingId: buildingId,
                        buildingName: building.name,
                        success: false,
                        message: error.message
                    });
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
}

module.exports = new LoxoneConnectionManager();

