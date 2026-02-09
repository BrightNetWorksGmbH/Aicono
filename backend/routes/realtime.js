const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/User');
const sensorRealtimeService = require('../services/sensorRealtimeService');

/**
 * Generate unique client ID
 */
function generateClientId() {
    return crypto.randomBytes(16).toString('hex');
}

/**
 * WebSocket route handler for real-time sensor data
 * Handles WebSocket upgrade requests and manages client connections
 */
function setupRealtimeWebSocket(server) {
    const wss = new WebSocket.Server({
        server,
        path: '/realtime',
        verifyClient: (info, callback) => {
            // Extract token from query string
            const url = require('url');
            const parsedUrl = url.parse(info.req.url, true);
            const token = parsedUrl.query.token || parsedUrl.query.authorization?.replace('Bearer ', '');

            if (!token) {
                callback(false, 401, 'Unauthorized - No token provided');
                return;
            }

            // Verify token
            try {
                if (!process.env.JWT_SECRET) {
                    callback(false, 500, 'Server configuration error');
                    return;
                }

                const payload = jwt.verify(token, process.env.JWT_SECRET);
                info.req.userId = payload.id || payload.userId;
                callback(true);
            } catch (error) {
                callback(false, 401, 'Unauthorized - Invalid token');
            }
        }
    });

    wss.on('connection', async (ws, req) => {
        const userId = req.userId;
        if (!userId) {
            ws.close(1008, 'User ID not found');
            return;
        }

        // Verify user exists and is active
        try {
            const user = await User.findById(userId);
            if (!user || user.is_active === false) {
                ws.close(1008, 'User not found or inactive');
                return;
            }

            // Generate unique client ID
            const clientId = generateClientId();

            // Register client
            sensorRealtimeService.registerClient(clientId, userId, ws);

            console.log(`[REALTIME] Client connected: ${clientId} (user: ${userId})`);

            // Send connection confirmation
            ws.send(JSON.stringify({
                type: 'connected',
                clientId,
                message: 'Connected to real-time sensor data stream'
            }));

            // Handle messages from client
            ws.on('message', async (data) => {
                try {
                    const message = JSON.parse(data.toString());

                    switch (message.type) {
                        case 'subscribe':
                            await handleSubscribe(clientId, userId, message, ws);
                            break;

                        case 'unsubscribe':
                            handleUnsubscribe(clientId, message);
                            break;

                        case 'disconnect':
                            sensorRealtimeService.disconnectClient(clientId);
                            ws.close(1000, 'Client requested disconnect');
                            break;

                        default:
                            ws.send(JSON.stringify({
                                type: 'error',
                                message: `Unknown message type: ${message.type}`
                            }));
                    }
                } catch (error) {
                    console.error(`[REALTIME] Error handling message from ${clientId}:`, error.message);
                    ws.send(JSON.stringify({
                        type: 'error',
                        message: error.message || 'Invalid message format'
                    }));
                }
            });

            // Handle client disconnect
            ws.on('close', () => {
                console.log(`[REALTIME] Client disconnected: ${clientId}`);
                sensorRealtimeService.disconnectClient(clientId);
            });

            // Handle errors
            ws.on('error', (error) => {
                console.error(`[REALTIME] WebSocket error for ${clientId}:`, error.message);
                sensorRealtimeService.disconnectClient(clientId);
            });

        } catch (error) {
            console.error('[REALTIME] Error setting up connection:', error.message);
            ws.close(1011, 'Internal server error');
        }
    });

    console.log('[REALTIME] WebSocket server started on path /realtime');
    return wss;
}

/**
 * Handle subscribe message
 */
async function handleSubscribe(clientId, userId, message, ws) {
    try {
        let result;

        if (message.roomId) {
            // Validate ObjectId format
            if (!/^[0-9a-fA-F]{24}$/.test(message.roomId)) {
                ws.send(JSON.stringify({
                    type: 'error',
                    message: 'Invalid roomId format'
                }));
                return;
            }

            result = await sensorRealtimeService.subscribeToRoom(clientId, message.roomId, userId);

            // Send initial state
            ws.send(JSON.stringify({
                type: 'initial_state',
                roomId: message.roomId,
                sensors: result.sensors
            }));

            ws.send(JSON.stringify({
                type: 'subscribe_success',
                roomId: message.roomId,
                message: result.message
            }));

        } else if (message.sensorId) {
            // Validate ObjectId format
            if (!/^[0-9a-fA-F]{24}$/.test(message.sensorId)) {
                ws.send(JSON.stringify({
                    type: 'error',
                    message: 'Invalid sensorId format'
                }));
                return;
            }

            result = await sensorRealtimeService.subscribeToSensor(clientId, message.sensorId, userId);

            // Send initial state
            ws.send(JSON.stringify({
                type: 'initial_state',
                sensorId: message.sensorId,
                sensors: result.sensors
            }));

            ws.send(JSON.stringify({
                type: 'subscribe_success',
                sensorId: message.sensorId,
                message: result.message
            }));

        } else {
            ws.send(JSON.stringify({
                type: 'error',
                message: 'Either roomId or sensorId must be provided'
            }));
            return;
        }
    } catch (error) {
        console.error(`[REALTIME] Subscribe error for ${clientId}:`, error.message);
        ws.send(JSON.stringify({
            type: 'error',
            message: error.message || 'Failed to subscribe'
        }));
    }
}

/**
 * Handle unsubscribe message
 */
function handleUnsubscribe(clientId, message) {
    try {
        sensorRealtimeService.unsubscribe(clientId, message.roomId, message.sensorId);
    } catch (error) {
        console.error(`[REALTIME] Unsubscribe error for ${clientId}:`, error.message);
    }
}

module.exports = {
    setupRealtimeWebSocket
};
