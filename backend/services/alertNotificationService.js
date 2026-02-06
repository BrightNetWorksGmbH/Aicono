const AlarmLog = require('../models/AlarmLog');
const Building = require('../models/Building');
const BuildingContact = require('../models/BuildingContact');
const Sensor = require('../models/Sensor');
const Room = require('../models/Room');
const LocalRoom = require('../models/LocalRoom');
const Floor = require('../models/Floor');
const { sendAlertReportEmail } = require('./emailService');

/**
 * Alert Notification Service
 * 
 * Handles sending alert report emails to building contact persons
 * when plausibility check violations are detected.
 */
class AlertNotificationService {
    /**
     * Find building associated with a Loxone Room
     * Traverses Room -> LocalRoom -> Floor -> Building path
     * @param {string} roomId - Loxone Room ID
     * @returns {Promise<Object|null>} Building with populated buildingContact_id or null
     */
    async findBuildingForRoom(roomId) {
        // Find LocalRoom that references this Loxone Room
        const localRoom = await LocalRoom.findOne({ loxone_room_id: roomId });
        if (!localRoom) {
            return null;
        }

        // Find the Floor
        const floor = await Floor.findById(localRoom.floor_id);
        if (!floor) {
            return null;
        }

        // Find the Building with populated buildingContact_id
        const building = await Building.findById(floor.building_id)
            .populate('buildingContact_id');
        
        return building;
    }

    /**
     * Send alert report email for an alarm log entry
     * @param {string|ObjectId} alarmLogId - AlarmLog ID
     * @returns {Promise<Object>} Result object with success status
     */
    async sendAlertReport(alarmLogId) {
        try {
            // Fetch alarm log with populated references
            const alarmLog = await AlarmLog.findById(alarmLogId)
                .populate('sensor_id')
                .populate('alarm_rule_id');

            if (!alarmLog) {
                console.error(`[ALERT] AlarmLog not found: ${alarmLogId}`);
                return { ok: false, error: 'AlarmLog not found' };
            }

            const sensor = alarmLog.sensor_id;
            if (!sensor) {
                console.error(`[ALERT] Sensor not found for alarm: ${alarmLogId}`);
                return { ok: false, error: 'Sensor not found' };
            }

            // Get room (Loxone Room) information
            const room = await Room.findById(sensor.room_id);
            if (!room) {
                console.error(`[ALERT] Room not found for sensor: ${sensor._id}`);
                return { ok: false, error: 'Room not found' };
            }

            // Find building via Room -> LocalRoom -> Floor -> Building path
            const building = await this.findBuildingForRoom(room._id);
            
            if (!building) {
                console.error(`[ALERT] Building not found for room: ${room._id}. The room may not be mapped to a LocalRoom.`);
                return { ok: false, error: 'Building not found' };
            }

            // Check if building has a contact person
            if (!building.buildingContact_id) {
                console.warn(`[ALERT] Building ${building._id} has no contact person configured. Skipping alert.`);
                return { ok: false, error: 'No building contact person configured' };
            }

            const buildingContact = building.buildingContact_id;
            if (!buildingContact || !buildingContact.email) {
                console.warn(`[ALERT] Building ${building._id} has no contact email configured. Skipping alert.`);
                return { ok: false, error: 'No building contact email configured' };
            }

            // Construct alarm details
            const alarmDetails = {
                sensorId: sensor._id.toString(),
                sensorName: sensor.name,
                buildingName: building.name,
                roomName: room.name,
                violatedRule: alarmLog.violatedRule || alarmLog.alarm_rule_id?.name || 'Unknown Rule',
                value: alarmLog.value,
                unit: sensor.unit || '',
                thresholdMin: alarmLog.threshold_min,
                thresholdMax: alarmLog.threshold_max,
                severity: alarmLog.severity,
                timestamp: alarmLog.timestamp_start,
                alarmLogId: alarmLog._id.toString(),
            };

            // Send email
            const emailResult = await sendAlertReportEmail({
                to: buildingContact.email,
                toName: buildingContact.name || buildingContact.email.split('@')[0],
                alarmDetails: alarmDetails,
            });

            if (emailResult.ok) {
                console.log(`[ALERT] Alert report sent successfully to ${buildingContact.email} for alarm ${alarmLogId}`);
            } else {
                console.error(`[ALERT] Failed to send alert report: ${emailResult.error}`);
            }

            return emailResult;
        } catch (error) {
            console.error(`[ALERT] Error sending alert report for alarm ${alarmLogId}:`, error.message);
            // Don't throw - allow system to continue even if email fails
            return { ok: false, error: error.message };
        }
    }

    /**
     * Send alert reports for multiple alarm log entries
     * @param {Array<string|ObjectId>} alarmLogIds - Array of AlarmLog IDs
     * @returns {Promise<Array>} Array of result objects
     */
    async sendAlertReports(alarmLogIds) {
        const results = [];
        for (const alarmLogId of alarmLogIds) {
            const result = await this.sendAlertReport(alarmLogId);
            results.push({ alarmLogId, ...result });
        }
        return results;
    }
}

module.exports = new AlertNotificationService();

