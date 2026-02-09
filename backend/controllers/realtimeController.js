const sensorRealtimeService = require('../services/sensorRealtimeService');
const { asyncHandler } = require('../middleware/errorHandler');
const { requireAuth } = require('../middleware/auth');

/**
 * Get WebSocket connection information
 * GET /api/v1/realtime/test
 */
exports.getConnectionInfo = asyncHandler(async (req, res) => {
    const protocol = req.protocol === 'https' ? 'wss' : 'ws';
    const host = req.get('host');
    const wsUrl = `${protocol}://${host}/realtime`;

    res.json({
        success: true,
        data: {
            websocketUrl: wsUrl,
            message: 'Connect to this URL with ?token=YOUR_JWT_TOKEN',
            example: `${wsUrl}?token=YOUR_JWT_TOKEN`,
            messageFormat: {
                subscribe: {
                    type: 'subscribe',
                    roomId: 'LOCAL_ROOM_ID' // OR sensorId: 'SENSOR_ID'
                },
                unsubscribe: {
                    type: 'unsubscribe',
                    roomId: 'LOCAL_ROOM_ID' // OR sensorId: 'SENSOR_ID'
                },
                disconnect: {
                    type: 'disconnect'
                }
            },
            responseFormat: {
                connected: {
                    type: 'connected',
                    clientId: '...',
                    message: '...'
                },
                initial_state: {
                    type: 'initial_state',
                    sensors: [
                        {
                            sensorId: '...',
                            value: 123.45,
                            unit: '°C',
                            timestamp: '2024-01-01T12:00:00Z'
                        }
                    ]
                },
                sensor_update: {
                    type: 'sensor_update',
                    sensorId: '...',
                    value: 123.45,
                    unit: '°C',
                    timestamp: '2024-01-01T12:00:00Z'
                },
                error: {
                    type: 'error',
                    message: '...'
                }
            }
        }
    });
});

/**
 * Get subscription statistics (admin only)
 * GET /api/v1/realtime/subscriptions
 */
exports.getSubscriptions = [requireAuth, asyncHandler(async (req, res) => {
    const stats = sensorRealtimeService.getStats();
    
    res.json({
        success: true,
        data: stats
    });
})];
