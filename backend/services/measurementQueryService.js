const mongoose = require('mongoose');

/**
 * Measurement Query Service
 * 
 * Provides optimized queries for measurement data with automatic
 * resolution selection based on time range:
 * - < 1 day: Raw data (resolution_minutes: 0)
 * - 1-7 days: 15-minute aggregates (resolution_minutes: 15)
 * - 7-90 days: Hourly aggregates (resolution_minutes: 60)
 * - > 90 days: Daily aggregates (resolution_minutes: 1440)
 * 
 * This ensures optimal query performance while maintaining data accuracy.
 */
class MeasurementQueryService {
    /**
     * Get measurements with automatic resolution selection
     * 
     * @param {string} sensorId - Sensor ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @param {number} options.resolution - Override automatic resolution (0, 15, 60, 1440)
     * @param {number} options.limit - Limit number of results
     * @param {number} options.skip - Skip number of results
     * @returns {Promise<Array>} Array of measurements
     */
    async getMeasurements(sensorId, startDate, endDate, options = {}) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        if (!mongoose.Types.ObjectId.isValid(sensorId)) {
            throw new Error(`Invalid sensorId: ${sensorId}`);
        }

        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution based on time range
        let resolution = 0; // raw
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440; // daily
            } else if (days > 7) {
                resolution = 60; // hourly
            } else if (days > 1) {
                resolution = 15; // 15-minute
            }
        }
        
        const matchStage = {
            'meta.sensorId': new mongoose.Types.ObjectId(sensorId),
            resolution_minutes: resolution, // Field is at root level, not in meta
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        let query = db.collection('measurements')
            .find(matchStage)
            .sort({ timestamp: 1 });
        
        if (options.limit) {
            query = query.limit(options.limit);
        }
        
        if (options.skip) {
            query = query.skip(options.skip);
        }
        
        const measurements = await query.toArray();
        
        return {
            measurements,
            resolution,
            count: measurements.length,
            resolutionLabel: this.getResolutionLabel(resolution)
        };
    }
    
    /**
     * Get measurements for a building
     * 
     * @param {string} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @param {string} options.measurementType - Filter by measurement type
     * @param {number} options.resolution - Override automatic resolution
     * @returns {Promise<Array>} Array of measurements
     */
    async getMeasurementsByBuilding(buildingId, startDate, endDate, options = {}) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new Error(`Invalid buildingId: ${buildingId}`);
        }

        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        let resolution = 0;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440;
            } else if (days > 7) {
                resolution = 60;
            } else if (days > 1) {
                resolution = 15;
            }
        }
        
        const matchStage = {
            // Match both string and ObjectId for backwards compatibility
            'meta.buildingId': { $in: [new mongoose.Types.ObjectId(buildingId), buildingId] },
            resolution_minutes: resolution, // Field is at root level, not in meta
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
        }
        
        const measurements = await db.collection('measurements')
            .find(matchStage)
            .sort({ timestamp: 1 })
            .toArray();
        
        return {
            measurements,
            resolution,
            count: measurements.length,
            resolutionLabel: this.getResolutionLabel(resolution)
        };
    }
    
    /**
     * Get aggregated statistics for reporting
     * 
     * @param {string} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {string|null} measurementType - Optional measurement type filter
     * @returns {Promise<Array>} Array of statistics grouped by measurement type
     */
    async getStatistics(buildingId, startDate, endDate, measurementType = null) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new Error(`Invalid buildingId: ${buildingId}`);
        }

        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Use appropriate resolution
        let resolution = 15;
        if (days > 90) {
            resolution = 1440;
        } else if (days > 7) {
            resolution = 60;
        }
        
        const matchStage = {
            // Match both string and ObjectId for backwards compatibility
            'meta.buildingId': { $in: [new mongoose.Types.ObjectId(buildingId), buildingId] },
            resolution_minutes: resolution, // Field is at root level, not in meta
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (measurementType) {
            matchStage['meta.measurementType'] = measurementType;
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType'
                    },
                    total: { $sum: '$value' },
                    average: { $avg: '$value' },
                    min: { $min: '$value' },
                    max: { $max: '$value' },
                    count: { $sum: 1 },
                    unit: { $first: '$unit' }
                }
            },
            {
                $project: {
                    _id: 0,
                    measurementType: '$_id.measurementType',
                    stateType: '$_id.stateType',
                    total: 1,
                    average: { $round: ['$average', 2] },
                    min: 1,
                    max: 1,
                    count: 1,
                    unit: 1
                }
            },
            { $sort: { measurementType: 1, stateType: 1 } }
        ];
        
        return await db.collection('measurements').aggregate(pipeline).toArray();
    }
    
    /**
     * Get latest measurement for a sensor
     * 
     * @param {string} sensorId - Sensor ID
     * @param {number} resolution - Resolution to use (default: 0 for raw)
     * @returns {Promise<Object|null>} Latest measurement or null
     */
    async getLatestMeasurement(sensorId, resolution = 0) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        if (!mongoose.Types.ObjectId.isValid(sensorId)) {
            throw new Error(`Invalid sensorId: ${sensorId}`);
        }

        const measurement = await db.collection('measurements')
            .findOne(
                {
                    'meta.sensorId': new mongoose.Types.ObjectId(sensorId),
                    resolution_minutes: resolution // Field is at root level, not in meta
                },
                { sort: { timestamp: -1 } }
            );
        
        return measurement;
    }
    
    /**
     * Get daily summary for a building (for dashboard)
     * 
     * @param {string} buildingId - Building ID
     * @param {Date} date - Date to get summary for
     * @returns {Promise<Object>} Daily summary statistics
     */
    async getDailySummary(buildingId, date) {
        const startDate = new Date(date);
        startDate.setHours(0, 0, 0, 0);
        
        const endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + 1);
        
        // Use daily aggregates if available, otherwise hourly
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        const matchStage = {
            // Match both string and ObjectId for backwards compatibility
            'meta.buildingId': { $in: [new mongoose.Types.ObjectId(buildingId), buildingId] },
            resolution_minutes: { $in: [60, 1440] }, // Hourly or daily (field is at root level)
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: '$meta.measurementType',
                    total: { $sum: '$value' },
                    average: { $avg: '$value' },
                    min: { $min: '$value' },
                    max: { $max: '$value' },
                    unit: { $first: '$unit' }
                }
            },
            {
                $project: {
                    _id: 0,
                    measurementType: '$_id',
                    total: { $round: ['$total', 2] },
                    average: { $round: ['$average', 2] },
                    min: { $round: ['$min', 2] },
                    max: { $round: ['$max', 2] },
                    unit: 1
                }
            }
        ];
        
        const summary = await db.collection('measurements').aggregate(pipeline).toArray();
        
        return {
            date: startDate.toISOString().split('T')[0],
            summary
        };
    }
    
    /**
     * Helper: Get human-readable resolution label
     * 
     * @param {number} resolution - Resolution in minutes
     * @returns {string} Resolution label
     */
    getResolutionLabel(resolution) {
        const labels = {
            0: 'raw',
            15: '15-minute',
            60: 'hourly',
            1440: 'daily'
        };
        return labels[resolution] || `unknown (${resolution}min)`;
    }
}

module.exports = new MeasurementQueryService();

