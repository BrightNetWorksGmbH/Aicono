/**
 * Zero Consumption Tracker
 * 
 * Tracks zero consumption values to detect "dead sensors" after sustained zero readings.
 * Alerts when zero consumption persists for more than 2 hours.
 */

class ZeroConsumptionTracker {
    constructor() {
        // In-memory cache: sensorId -> { firstZeroTimestamp, lastCheckedTimestamp }
        this.zeroTracking = new Map();
        // Zero consumption threshold: 2 hours in milliseconds
        this.ZERO_THRESHOLD_MS = 2 * 60 * 60 * 1000; // 2 hours
    }

    /**
     * Check if a sensor value indicates zero consumption violation
     * @param {string|ObjectId} sensorId - Sensor ID
     * @param {number} value - Current measurement value
     * @param {Date} timestamp - Current timestamp
     * @returns {Object|null} Violation object if detected, null otherwise
     */
    checkZeroConsumption(sensorId, value, timestamp) {
        // console.log('checkZeroConsumption', sensorId, value, timestamp);
        const sensorIdStr = sensorId.toString();
        const now = timestamp || new Date();
        const nowMs = now.getTime();

        // If value is non-zero, reset tracking
        if (value !== 0 && value !== null && value !== undefined) {
            this.resetTracking(sensorId);
            return null;
        }

        // Value is zero - check tracking
        const tracking = this.zeroTracking.get(sensorIdStr);
        if (!tracking) {
            // First zero value detected - start tracking
            this.zeroTracking.set(sensorIdStr, {
                firstZeroTimestamp: now,
                lastCheckedTimestamp: now,
            });
            return null; // Not a violation yet, just started tracking
        }

        // Update last checked timestamp
        tracking.lastCheckedTimestamp = now;

        // Calculate duration of zero consumption
        const zeroDuration = nowMs - tracking.firstZeroTimestamp.getTime();

        // Check if threshold exceeded
        if (zeroDuration >= this.ZERO_THRESHOLD_MS) {
            // Violation detected - sustained zero consumption for 2+ hours
            return {
                type: 'zero_consumption',
                severity: 'High',
                message: 'Zero Consumption Detected',
                description: `Sensor has been reporting zero consumption for ${Math.round(zeroDuration / (60 * 60 * 1000) * 10) / 10} hours. This may indicate a dead sensor.`,
                firstZeroTimestamp: tracking.firstZeroTimestamp,
                duration: zeroDuration,
            };
        }

        // Still within threshold - no violation yet
        return null;
    }

    /**
     * Reset tracking for a sensor (when non-zero value detected)
     * @param {string|ObjectId} sensorId - Sensor ID
     */
    resetTracking(sensorId) {
        const sensorIdStr = sensorId.toString();
        this.zeroTracking.delete(sensorIdStr);
    }

    /**
     * Get current tracking status for a sensor
     * @param {string|ObjectId} sensorId - Sensor ID
     * @returns {Object|null} Tracking object or null
     */
    getTracking(sensorId) {
        const sensorIdStr = sensorId.toString();
        return this.zeroTracking.get(sensorIdStr) || null;
    }

    /**
     * Clean up old tracking entries (optional maintenance)
     * Removes entries older than 24 hours
     */
    cleanup() {
        const now = new Date();
        const maxAge = 24 * 60 * 60 * 1000; // 24 hours

        for (const [sensorId, tracking] of this.zeroTracking.entries()) {
            const age = now.getTime() - tracking.lastCheckedTimestamp.getTime();
            if (age > maxAge) {
                this.zeroTracking.delete(sensorId);
            }
        }
    }
}

module.exports = new ZeroConsumptionTracker();

