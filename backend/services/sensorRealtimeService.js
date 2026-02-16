const mongoose = require('mongoose');
const loxoneStorageService = require('./loxoneStorageService');
const { getSensorIdsForLocalRoom } = require('../utils/sensorLookup');
const { validateRoomAccess, validateSensorAccess } = require('../utils/realtimeAuth');
const Sensor = require('../models/Sensor');

/**
 * Sensor Realtime Service
 * 
 * Manages real-time sensor data subscriptions and broadcasting to frontend clients.
 * Intercepts measurements from Loxone stream before storage and broadcasts to subscribed clients.
 */
class SensorRealtimeService {
    constructor() {
        // Map<clientId, Set<sensorId>> - What each client subscribes to
        this.clientSubscriptions = new Map();
        
        // Map<sensorId, Set<clientId>> - Which clients want each sensor
        this.sensorSubscribers = new Map();
        
        // Map<roomId, Set<clientId>> - Which clients want each room
        this.roomSubscribers = new Map();
        
        // Map<roomId, Set<sensorId>> - Sensors in each room (cached)
        this.roomSensorCache = new Map();
        
        // Map<clientId, { userId, ws, subscriptions: Set<sensorId> }> - Client metadata
        this.clientMetadata = new Map();
        
        // Cache for initial state queries (timestamp -> result)
        this.initialStateCache = new Map();
        const INITIAL_STATE_CACHE_TTL = 5000; // 5 seconds
        
        // Normalize UUID format (same as loxoneStorageService)
        this.normalizeUUID = (uuid) => {
            if (!uuid) return uuid;
            const clean = uuid.replace(/-/g, '');
            if (clean.length !== 32) return uuid;
            return [
                clean.substring(0, 8),
                clean.substring(8, 12),
                clean.substring(12, 16),
                clean.substring(16, 20),
                clean.substring(20, 32)
            ].join('-');
        };
    }

    /**
     * Register a client connection
     * @param {string} clientId - Unique client identifier
     * @param {string} userId - User ID
     * @param {WebSocket} ws - WebSocket connection
     */
    registerClient(clientId, userId, ws) {
        this.clientMetadata.set(clientId, {
            userId,
            ws,
            subscriptions: new Set()
        });
    }

    /**
     * Unregister a client and clean up all subscriptions
     * @param {string} clientId - Client identifier
     */
    disconnectClient(clientId) {
        const metadata = this.clientMetadata.get(clientId);
        if (!metadata) return;

        // Remove from all subscription maps
        for (const sensorId of metadata.subscriptions) {
            const subscribers = this.sensorSubscribers.get(sensorId);
            if (subscribers) {
                subscribers.delete(clientId);
                if (subscribers.size === 0) {
                    this.sensorSubscribers.delete(sensorId);
                }
            }
        }

        // Remove from room subscribers
        for (const [roomId, clients] of this.roomSubscribers.entries()) {
            clients.delete(clientId);
            if (clients.size === 0) {
                this.roomSubscribers.delete(roomId);
            }
        }

        // Clean up
        this.clientSubscriptions.delete(clientId);
        this.clientMetadata.delete(clientId);
    }

    /**
     * Subscribe client to all sensors in a room
     * @param {string} clientId - Client identifier
     * @param {string} roomId - LocalRoom ID
     * @param {string} userId - User ID
     * @returns {Promise<Object>} Subscription result with initial state
     */
    async subscribeToRoom(clientId, roomId, userId) {
        // Validate access
        const hasAccess = await validateRoomAccess(userId, roomId);
        if (!hasAccess) {
            throw new Error('Access denied to this room');
        }

        // Get sensor IDs for this room
        let sensorIds = this.roomSensorCache.get(roomId);
        if (!sensorIds) {
            const sensorIdArray = await getSensorIdsForLocalRoom(roomId);
            sensorIds = new Set(sensorIdArray);
            this.roomSensorCache.set(roomId, sensorIds);
        }

        if (sensorIds.size === 0) {
            return {
                success: true,
                message: 'Room has no sensors',
                sensors: []
            };
        }

        const metadata = this.clientMetadata.get(clientId);
        if (!metadata) {
            throw new Error('Client not registered');
        }

        // Add to room subscribers
        if (!this.roomSubscribers.has(roomId)) {
            this.roomSubscribers.set(roomId, new Set());
        }
        this.roomSubscribers.get(roomId).add(clientId);

        // Subscribe to each sensor
        for (const sensorId of sensorIds) {
            this._subscribeToSensor(clientId, sensorId);
        }

        // Get initial state
        const initialValues = await this.getCurrentSensorValues(Array.from(sensorIds));

        return {
            success: true,
            message: `Subscribed to ${sensorIds.size} sensor(s)`,
            sensors: initialValues
        };
    }

    /**
     * Subscribe client to a single sensor
     * @param {string} clientId - Client identifier
     * @param {string} sensorId - Sensor ID
     * @param {string} userId - User ID
     * @returns {Promise<Object>} Subscription result with initial state
     */
    async subscribeToSensor(clientId, sensorId, userId) {
        // Validate access
        const hasAccess = await validateSensorAccess(userId, sensorId);
        if (!hasAccess) {
            throw new Error('Access denied to this sensor');
        }

        const metadata = this.clientMetadata.get(clientId);
        if (!metadata) {
            throw new Error('Client not registered');
        }

        this._subscribeToSensor(clientId, sensorId);

        // Get initial state
        const initialValues = await this.getCurrentSensorValues([sensorId]);

        return {
            success: true,
            message: 'Subscribed to sensor',
            sensors: initialValues
        };
    }

    /**
     * Internal method to subscribe to a sensor
     * @private
     */
    _subscribeToSensor(clientId, sensorId) {
        const metadata = this.clientMetadata.get(clientId);
        if (!metadata) return;

        // Add to client subscriptions
        if (!this.clientSubscriptions.has(clientId)) {
            this.clientSubscriptions.set(clientId, new Set());
        }
        this.clientSubscriptions.get(clientId).add(sensorId);
        metadata.subscriptions.add(sensorId);

        // Add to sensor subscribers
        if (!this.sensorSubscribers.has(sensorId)) {
            this.sensorSubscribers.set(sensorId, new Set());
        }
        this.sensorSubscribers.get(sensorId).add(clientId);
    }

    /**
     * Unsubscribe from a room or sensor
     * @param {string} clientId - Client identifier
     * @param {string} roomId - Optional room ID
     * @param {string} sensorId - Optional sensor ID
     */
    unsubscribe(clientId, roomId = null, sensorId = null) {
        const metadata = this.clientMetadata.get(clientId);
        if (!metadata) return;

        if (roomId) {
            // Unsubscribe from all sensors in room
            const sensorIds = this.roomSensorCache.get(roomId);
            if (sensorIds) {
                for (const sid of sensorIds) {
                    this._unsubscribeFromSensor(clientId, sid);
                }
            }
            const roomClients = this.roomSubscribers.get(roomId);
            if (roomClients) {
                roomClients.delete(clientId);
                if (roomClients.size === 0) {
                    this.roomSubscribers.delete(roomId);
                }
            }
        } else if (sensorId) {
            this._unsubscribeFromSensor(clientId, sensorId);
        }
    }

    /**
     * Internal method to unsubscribe from a sensor
     * @private
     */
    _unsubscribeFromSensor(clientId, sensorId) {
        const metadata = this.clientMetadata.get(clientId);
        if (!metadata) return;

        metadata.subscriptions.delete(sensorId);
        const clientSubs = this.clientSubscriptions.get(clientId);
        if (clientSubs) {
            clientSubs.delete(sensorId);
            if (clientSubs.size === 0) {
                this.clientSubscriptions.delete(clientId);
            }
        }

        const sensorSubs = this.sensorSubscribers.get(sensorId);
        if (sensorSubs) {
            sensorSubs.delete(clientId);
            if (sensorSubs.size === 0) {
                this.sensorSubscribers.delete(sensorId);
            }
        }
    }

    /**
     * Broadcast measurements to subscribed clients
     * @param {string} serialNumber - Server serial number
     * @param {Array} measurements - Array of { uuid, value, timestamp }
     */
    async broadcastMeasurement(serialNumber, measurements) {
        if (measurements.length === 0) return;

        // Get UUID map for this server
        const uuidMap = loxoneStorageService.getUuidMap(serialNumber);
        if (!uuidMap || uuidMap.size === 0) {
            return; // No mapping available, skip broadcast
        }

        // Process each measurement
        const updatesByClient = new Map(); // clientId -> Array<{sensorId, value, unit, timestamp}>

        for (const measurement of measurements) {
            const normalizedUUID = this.normalizeUUID(measurement.uuid);
            const mapping = uuidMap.get(normalizedUUID);

            if (!mapping || !mapping.sensor_id) {
                continue; // No sensor mapping for this UUID
            }

            // Skip total* states - only send instantaneous (actual*) values
            // total* states represent cumulative values (e.g., totalDay, totalWeek for Energy, 
            // or cumulative temperature in degree-hours) which don't make sense for real-time display
            if (mapping.stateType && 
                (mapping.stateType.startsWith('total') || mapping.stateType.startsWith('totalNeg'))) {
                continue; // Skip cumulative states
            }

            const sensorId = mapping.sensor_id.toString();
            const subscribers = this.sensorSubscribers.get(sensorId);

            if (!subscribers || subscribers.size === 0) {
                continue; // No subscribers for this sensor
            }

            // Get sensor info for unit
            const sensor = await this._getSensorInfo(sensorId);
            const unit = sensor ? sensor.unit : '';

            // Add update for each subscriber
            for (const clientId of subscribers) {
                if (!updatesByClient.has(clientId)) {
                    updatesByClient.set(clientId, []);
                }
                updatesByClient.get(clientId).push({
                    sensorId,
                    value: measurement.value,
                    unit,
                    timestamp: measurement.timestamp
                });
            }
        }

        // Send updates to each client
        for (const [clientId, updates] of updatesByClient.entries()) {
            const metadata = this.clientMetadata.get(clientId);
            if (!metadata || !metadata.ws || metadata.ws.readyState !== 1) {
                // Client disconnected, clean up
                this.disconnectClient(clientId);
                continue;
            }

            try {
                // Send each update as separate message (frontend can batch if needed)
                for (const update of updates) {
                    metadata.ws.send(JSON.stringify({
                        type: 'sensor_update',
                        sensorId: update.sensorId,
                        value: update.value,
                        unit: update.unit,
                        timestamp: update.timestamp.toISOString()
                    }));
                }
            } catch (error) {
                console.error(`[REALTIME] Error sending update to client ${clientId}:`, error.message);
                // Clean up disconnected client
                this.disconnectClient(clientId);
            }
        }
    }

    /**
     * Get current sensor values for initial state
     * @param {Array<string>} sensorIds - Array of sensor IDs
     * @returns {Promise<Array>} Array of { sensorId, value, unit, timestamp }
     */
    async getCurrentSensorValues(sensorIds) {
        if (sensorIds.length === 0) return [];

        const db = mongoose.connection.db;
        if (!db) {
            return [];
        }

        try {
            // Convert to ObjectIds
            const objectIds = sensorIds.map(id => new mongoose.Types.ObjectId(id));

            // Get latest measurement for each sensor (only actual* states - instantaneous values)
            const results = await db.collection('measurements_raw').aggregate([
                {
                    $match: {
                        'meta.sensorId': { $in: objectIds },
                        'meta.stateType': { $regex: '^actual' } // Only actual* states (skip total*, totalNeg*)
                    }
                },
                {
                    $sort: { timestamp: -1 }
                },
                {
                    $group: {
                        _id: '$meta.sensorId',
                        value: { $first: '$value' },
                        unit: { $first: '$unit' },
                        timestamp: { $first: '$timestamp' }
                    }
                }
            ]).toArray();

            // Format results
            return results.map(result => ({
                sensorId: result._id.toString(),
                value: result.value,
                unit: result.unit || '',
                timestamp: result.timestamp ? new Date(result.timestamp).toISOString() : null
            }));
        } catch (error) {
            console.error('[REALTIME] Error fetching initial state:', error.message);
            return [];
        }
    }

    /**
     * Get sensor info (cached)
     * @private
     */
    async _getSensorInfo(sensorId) {
        try {
            const sensor = await Sensor.findById(sensorId).select('unit name').lean();
            return sensor;
        } catch (error) {
            return null;
        }
    }

    /**
     * Get subscription statistics
     * @returns {Object} Statistics
     */
    getStats() {
        return {
            totalClients: this.clientMetadata.size,
            totalSensorSubscriptions: this.sensorSubscribers.size,
            totalRoomSubscriptions: this.roomSubscribers.size,
            clients: Array.from(this.clientMetadata.keys()).map(clientId => {
                const metadata = this.clientMetadata.get(clientId);
                return {
                    clientId,
                    userId: metadata.userId,
                    subscriptionCount: metadata.subscriptions.size
                };
            })
        };
    }
}

module.exports = new SensorRealtimeService();
