const AlarmLog = require('../models/AlarmLog');
const AlarmRule = require('../models/AlarmRule');

/**
 * Alarm Service
 * 
 * Handles creation of alarm log entries for plausibility check violations
 */
class AlarmService {
    /**
     * Ensure default alarm rules exist
     * @returns {Promise<Object>} Map of rule_type -> AlarmRule
     */
    async ensureDefaultRules() {
        const defaultRules = [
            {
                name: 'Negative Reading Detected',
                rule_type: 'negative_value',
                sensor_type: null, // Applies to all sensor types
            },
            {
                name: 'Min Threshold Violation',
                rule_type: 'min_threshold',
                sensor_type: null,
            },
            {
                name: 'Max Threshold Violation',
                rule_type: 'max_threshold',
                sensor_type: null,
            },
            {
                name: 'Zero Consumption Detected',
                rule_type: 'zero_consumption',
                sensor_type: null,
            },
        ];

        const ruleMap = {};

        for (const ruleData of defaultRules) {
            let rule = await AlarmRule.findOne({ rule_type: ruleData.rule_type });
            if (!rule) {
                rule = new AlarmRule(ruleData);
                await rule.save();
            }
            ruleMap[ruleData.rule_type] = rule;
        }

        return ruleMap;
    }

    /**
     * Create a plausibility alarm log entry
     * @param {Object} violation - Violation object from plausibility check
     * @param {string|ObjectId} sensorId - Sensor ID
     * @param {number} value - Measurement value that triggered the alarm
     * @param {Date} timestamp - Timestamp of the measurement
     * @returns {Promise<Object>} Created AlarmLog document
     */
    async createPlausibilityAlarm(violation, sensorId, value, timestamp) {
        // Ensure default rules exist
        const ruleMap = await this.ensureDefaultRules();
        
        // Get the appropriate alarm rule
        const alarmRule = ruleMap[violation.type];
        if (!alarmRule) {
            throw new Error(`No alarm rule found for violation type: ${violation.type}`);
        }

        // Determine violated rule description
        let violatedRule = violation.message;
        if (violation.description) {
            violatedRule = `${violation.message}: ${violation.description}`;
        }

        // Create alarm log entry
        const alarmLog = new AlarmLog({
            sensor_id: sensorId,
            alarm_rule_id: alarmRule._id,
            timestamp_start: timestamp || new Date(),
            status: 'Open',
            violatedRule: violatedRule,
            severity: violation.severity,
            value: value,
            threshold_min: violation.threshold_min,
            threshold_max: violation.threshold_max,
        });

        await alarmLog.save();

        return alarmLog;
    }

    /**
     * Create multiple alarm log entries for multiple violations
     * @param {Array} violations - Array of violation objects
     * @param {string|ObjectId} sensorId - Sensor ID
     * @param {number} value - Measurement value
     * @param {Date} timestamp - Timestamp
     * @returns {Promise<Array>} Array of created AlarmLog documents
     */
    async createPlausibilityAlarms(violations, sensorId, value, timestamp) {
        const alarms = [];
        for (const violation of violations) {
            const alarm = await this.createPlausibilityAlarm(violation, sensorId, value, timestamp);
            alarms.push(alarm);
        }
        return alarms;
    }
}

module.exports = new AlarmService();

