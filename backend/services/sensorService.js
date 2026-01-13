const Sensor = require('../models/Sensor');
const Room = require('../models/Room');
const Building = require('../models/Building');
const Site = require('../models/Site');

class SensorService {
    /**
     * Get all sensors for a building
     * @param {String} buildingId - Building ID
     * @returns {Promise<Array>} Array of sensors with room information
     */
    async getSensorsByBuilding(buildingId) {
        // Verify building exists
        const building = await Building.findById(buildingId);
        if (!building) {
            throw new Error('Building not found');
        }

        // Get all rooms for this building
        const rooms = await Room.find({ building_id: buildingId });
        const roomIds = rooms.map(room => room._id);

        // Get all sensors for these rooms
        const sensors = await Sensor.find({ room_id: { $in: roomIds } })
            .populate('room_id', 'name loxone_room_uuid building_id')
            .sort({ name: 1 });

        return sensors.map(sensor => ({
            _id: sensor._id,
            name: sensor.name,
            unit: sensor.unit,
            room_id: sensor.room_id,
            loxone_control_uuid: sensor.loxone_control_uuid,
            loxone_category_uuid: sensor.loxone_category_uuid,
            loxone_category_name: sensor.loxone_category_name,
            loxone_category_type: sensor.loxone_category_type,
            threshold_min: sensor.threshold_min,
            threshold_max: sensor.threshold_max,
            created_at: sensor.created_at,
            updated_at: sensor.updated_at
        }));
    }

    /**
     * Get all sensors for a site (across all buildings)
     * @param {String} siteId - Site ID
     * @returns {Promise<Array>} Array of sensors with room and building information
     */
    async getSensorsBySite(siteId) {
        // Verify site exists
        const site = await Site.findById(siteId);
        if (!site) {
            throw new Error('Site not found');
        }

        // Get all buildings for this site
        const buildings = await Building.find({ site_id: siteId });
        const buildingIds = buildings.map(building => building._id);

        // Get all rooms for these buildings
        const rooms = await Room.find({ building_id: { $in: buildingIds } })
            .populate('building_id', 'name site_id');
        const roomIds = rooms.map(room => room._id);

        // Get all sensors for these rooms
        const sensors = await Sensor.find({ room_id: { $in: roomIds } })
            .populate({
                path: 'room_id',
                select: 'name loxone_room_uuid building_id',
                populate: {
                    path: 'building_id',
                    select: 'name site_id'
                }
            })
            .sort({ name: 1 });

        return sensors.map(sensor => ({
            _id: sensor._id,
            name: sensor.name,
            unit: sensor.unit,
            room_id: sensor.room_id,
            loxone_control_uuid: sensor.loxone_control_uuid,
            loxone_category_uuid: sensor.loxone_category_uuid,
            loxone_category_name: sensor.loxone_category_name,
            loxone_category_type: sensor.loxone_category_type,
            threshold_min: sensor.threshold_min,
            threshold_max: sensor.threshold_max,
            created_at: sensor.created_at,
            updated_at: sensor.updated_at
        }));
    }

    /**
     * Bulk update threshold and peak values for multiple sensors
     * @param {Array<Object>} sensorUpdates - Array of { sensorId, threshold_min, threshold_max }
     * @returns {Promise<Object>} Update result with updated sensors
     */
    async bulkUpdateThresholds(sensorUpdates) {
        if (!Array.isArray(sensorUpdates) || sensorUpdates.length === 0) {
            throw new Error('sensorUpdates must be a non-empty array');
        }

        const updatePromises = sensorUpdates.map(async (update) => {
            const { sensorId, threshold_min, threshold_max } = update;

            if (!sensorId) {
                throw new Error('sensorId is required for each update');
            }

            // Find the sensor first to check existing values
            const sensor = await Sensor.findById(sensorId);
            if (!sensor) {
                throw new Error(`Sensor with ID ${sensorId} not found`);
            }

            // Validate threshold values if provided
            if (threshold_min !== undefined && threshold_min !== null && isNaN(threshold_min)) {
                throw new Error(`Invalid threshold_min value for sensor ${sensorId}`);
            }

            if (threshold_max !== undefined && threshold_max !== null && isNaN(threshold_max)) {
                throw new Error(`Invalid threshold_max value for sensor ${sensorId}`);
            }

            // Determine the values to validate (use existing if not being updated)
            const finalMin = threshold_min !== undefined ? threshold_min : sensor.threshold_min;
            const finalMax = threshold_max !== undefined ? threshold_max : sensor.threshold_max;

            // Validate that min < max if both values exist
            if (
                finalMin !== undefined && finalMin !== null &&
                finalMax !== undefined && finalMax !== null &&
                finalMin >= finalMax
            ) {
                throw new Error(`threshold_min (${finalMin}) must be less than threshold_max (${finalMax}) for sensor ${sensorId}`);
            }

            // Prepare update data
            const updateData = {};
            if (threshold_min !== undefined) {
                updateData.threshold_min = threshold_min;
            }
            if (threshold_max !== undefined) {
                updateData.threshold_max = threshold_max;
            }

            // Update the sensor
            Object.assign(sensor, updateData);
            await sensor.save();

            return sensor;
        });

        const updatedSensors = await Promise.all(updatePromises);

        return {
            updated: updatedSensors.length,
            sensors: updatedSensors.map(sensor => ({
                _id: sensor._id,
                name: sensor.name,
                unit: sensor.unit,
                threshold_min: sensor.threshold_min,
                threshold_max: sensor.threshold_max,
                updated_at: sensor.updated_at
            }))
        };
    }

    /**
     * Get a single sensor by ID
     * @param {String} sensorId - Sensor ID
     * @returns {Promise<Object>} Sensor with room information
     */
    async getSensorById(sensorId) {
        const sensor = await Sensor.findById(sensorId)
            .populate('room_id', 'name loxone_room_uuid building_id');

        if (!sensor) {
            throw new Error('Sensor not found');
        }

        return {
            _id: sensor._id,
            name: sensor.name,
            unit: sensor.unit,
            room_id: sensor.room_id,
            loxone_control_uuid: sensor.loxone_control_uuid,
            loxone_category_uuid: sensor.loxone_category_uuid,
            loxone_category_name: sensor.loxone_category_name,
            loxone_category_type: sensor.loxone_category_type,
            threshold_min: sensor.threshold_min,
            threshold_max: sensor.threshold_max,
            created_at: sensor.created_at,
            updated_at: sensor.updated_at
        };
    }
}

module.exports = new SensorService();

