const Sensor = require('../models/Sensor');
const zeroConsumptionTracker = require('./zeroConsumptionTracker');

/**
 * Plausibility Check Service (M4)
 * 
 * Validates sensor measurements against plausibility rules:
 * 1. Min/Max Range Check
 * 2. Negative Value Detection
 * 3. Zero Consumption Detection
 */
class PlausibilityCheckService {
    /**
     * Validate a measurement against plausibility rules
     * @param {string|ObjectId} sensorId - Sensor ID
     * @param {number} value - Measurement value
     * @param {string} measurementType - Type of measurement (e.g., 'Energy', 'Temperature', 'Power')
     * @param {Date} timestamp - Measurement timestamp
     * @returns {Promise<Object>} Validation result with isValid, violations, and severity
     */
    async validateMeasurement(sensorId, value, measurementType, timestamp) {
        const violations = [];
        let maxSeverity = 'Low';
        // console.log('validateMeasurement', sensorId, value, measurementType, timestamp);

        // Fetch sensor with thresholds
        const sensor = await Sensor.findById(sensorId);
        if (!sensor) {
            // Sensor not found - can't validate, but don't block storage
            return {
                isValid: true,
                violations: [],
                severity: 'Low',
            };
        }

        // Rule 1: Min/Max Range Check
        if (sensor.threshold_min !== null && sensor.threshold_min !== undefined) {
            if (value < sensor.threshold_min) {
                violations.push({
                    type: 'min_threshold',
                    severity: 'Medium',
                    message: 'Min Threshold Violation',
                    description: `Value ${value} is below minimum threshold of ${sensor.threshold_min}`,
                    threshold_min: sensor.threshold_min,
                    threshold_max: sensor.threshold_max,
                });
                maxSeverity = this.getHigherSeverity(maxSeverity, 'Medium');
            }
        }

        if (sensor.threshold_max !== null && sensor.threshold_max !== undefined) {
            if (value > sensor.threshold_max) {
                violations.push({
                    type: 'max_threshold',
                    severity: 'Medium',
                    message: 'Max Threshold Violation',
                    description: `Value ${value} exceeds maximum threshold of ${sensor.threshold_max}`,
                    threshold_min: sensor.threshold_min,
                    threshold_max: sensor.threshold_max,
                });
                maxSeverity = this.getHigherSeverity(maxSeverity, 'Medium');
            }
        }

        // Rule 2: Negative Value Detection (for Energy/Power consumption types)
        const consumptionTypes = ['Energy', 'Power'];
        if (consumptionTypes.includes(measurementType)) {
            if (value < 0) {
                console.log('negative value detected', value);
                violations.push({
                    type: 'negative_value',
                    severity: 'High',
                    message: 'Negative Reading Detected',
                    description: `Impossible negative consumption value detected: ${value}`,
                });
                maxSeverity = this.getHigherSeverity(maxSeverity, 'High');
            }
        }

        // Rule 3: Zero Consumption Detection (for Energy/Power consumption types)
        if (consumptionTypes.includes(measurementType)) {
            const zeroViolation = zeroConsumptionTracker.checkZeroConsumption(
                sensorId,
                value,
                timestamp
            );
            if (zeroViolation) {
                violations.push(zeroViolation);
                maxSeverity = this.getHigherSeverity(maxSeverity, zeroViolation.severity);
            } else if (value === 0) {
                // Track initial zero consumption (low severity, not yet a violation)
                // This is handled by the tracker internally
            }
        }

        // Rule 4: Temperature Range Validation
        // Reasonable temperature range: -50°C to 100°C for indoor/outdoor sensors
        // Values outside this range are implausible and should be flagged
        if (measurementType === 'Temperature') {
            if (value < -50 || value > 100) {
                violations.push({
                    type: 'temperature_range',
                    severity: 'High',
                    message: 'Implausible Temperature Value',
                    description: `Temperature value ${value}°C is outside reasonable range (-50°C to 100°C)`,
                });
                maxSeverity = this.getHigherSeverity(maxSeverity, 'High');
            }
        }

        return {
            isValid: violations.length === 0,
            violations: violations,
            severity: maxSeverity,
            sensor: sensor,
        };
    }

    /**
     * Get the higher severity between two severities
     * @param {string} severity1 - First severity
     * @param {string} severity2 - Second severity
     * @returns {string} Higher severity
     */
    getHigherSeverity(severity1, severity2) {
        const severityOrder = { 'Low': 1, 'Medium': 2, 'High': 3 };
        const order1 = severityOrder[severity1] || 0;
        const order2 = severityOrder[severity2] || 0;
        return order2 > order1 ? severity2 : severity1;
    }

    /**
     * Batch validate multiple measurements
     * @param {Array} measurements - Array of {sensorId, value, measurementType, timestamp}
     * @returns {Promise<Array>} Array of validation results
     */
    async validateMeasurements(measurements) {
        const results = [];
        for (const measurement of measurements) {
            const result = await this.validateMeasurement(
                measurement.sensorId,
                measurement.value,
                measurement.measurementType,
                measurement.timestamp
            );
            results.push({
                ...measurement,
                validation: result,
            });
        }
        return results;
    }
}

module.exports = new PlausibilityCheckService();

