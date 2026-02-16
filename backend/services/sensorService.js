const Sensor = require('../models/Sensor');
const Room = require('../models/Room');
const Building = require('../models/Building');
const Site = require('../models/Site');
const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const sensorLookup = require('../utils/sensorLookup');
const { NotFoundError, ValidationError } = require('../utils/errors');

class SensorService {
    /**
     * Get all sensors for a building
     * Uses Floor -> LocalRoom -> Loxone Room -> Sensor path
     * @param {String} buildingId - Building ID
     * @returns {Promise<Array>} Array of sensors with room information
     */
    async getSensorsByBuilding(buildingId) {
        // Verify building exists
        const building = await Building.findById(buildingId);
        if (!building) {
            throw new NotFoundError('Building');
        }

        // Get sensor IDs for this building via sensorLookup
        const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
        const sensorIds = Array.from(sensorIdsSet);

        if (sensorIds.length === 0) {
            return [];
        }

        // Get all sensors with room information
        const sensors = await Sensor.find({ _id: { $in: sensorIds } })
            .populate('room_id', 'name loxone_room_uuid miniserver_serial')
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
     * Uses Floor -> LocalRoom -> Loxone Room -> Sensor path for each building
     * @param {String} siteId - Site ID
     * @returns {Promise<Array>} Array of sensors with room and building information
     */
    async getSensorsBySite(siteId) {
        // Verify site exists
        const site = await Site.findById(siteId);
        if (!site) {
            throw new NotFoundError('Site');
        }

        // Get sensor IDs for this site via sensorLookup
        const sensorIdsSet = await sensorLookup.getSensorIdsForSite(siteId);
        const sensorIds = Array.from(sensorIdsSet);

        if (sensorIds.length === 0) {
            return [];
        }

        // Get all sensors with room information
        const sensors = await Sensor.find({ _id: { $in: sensorIds } })
            .populate('room_id', 'name loxone_room_uuid miniserver_serial')
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
            throw new ValidationError('sensorUpdates must be a non-empty array');
        }

        const updatePromises = sensorUpdates.map(async (update) => {
            const { sensorId, threshold_min, threshold_max } = update;

            if (!sensorId) {
                throw new ValidationError('sensorId is required for each update');
            }

            // Find the sensor first to check existing values
            const sensor = await Sensor.findById(sensorId);
            if (!sensor) {
                throw new NotFoundError(`Sensor ${sensorId}`);
            }

            // Validate threshold values if provided
            if (threshold_min !== undefined && threshold_min !== null && isNaN(threshold_min)) {
                throw new ValidationError(`Invalid threshold_min value for sensor ${sensorId}`);
            }

            if (threshold_max !== undefined && threshold_max !== null && isNaN(threshold_max)) {
                throw new ValidationError(`Invalid threshold_max value for sensor ${sensorId}`);
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
                throw new ValidationError(`threshold_min (${finalMin}) must be less than threshold_max (${finalMax}) for sensor ${sensorId}`);
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

        // Invalidate sensor cache so plausibility checks use the fresh threshold values
        // Without this, the cached sensor objects (missing updated thresholds) would be used
        // for up to 5 minutes (SENSOR_CACHE_TTL), causing Rule 1 (Min/Max) to silently skip
        try {
            const loxoneStorageService = require('./loxoneStorageService');
            loxoneStorageService.invalidateSensorCache();
        } catch (e) {
            // Non-critical - cache will expire naturally after 5 minutes
            console.warn('[SENSOR-SERVICE] Failed to invalidate sensor cache:', e.message);
        }

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
     * Get all sensors for a local room
     * Uses LocalRoom -> Loxone Room -> Sensor path
     * @param {String} localRoomId - Local Room ID
     * @returns {Promise<Array>} Array of sensors with room information
     */
    async getSensorsByLocalRoom(localRoomId) {
        // Verify local room exists
        const localRoom = await LocalRoom.findById(localRoomId);
        if (!localRoom) {
            throw new NotFoundError('Local room');
        }

        // If local room has no Loxone mapping, return empty array
        if (!localRoom.loxone_room_id) {
            return [];
        }

        // Get sensor IDs for this local room via sensorLookup
        const sensorIds = await sensorLookup.getSensorIdsForLocalRoom(localRoomId);

        if (sensorIds.length === 0) {
            return [];
        }

        // Get all sensors with room information
        const sensors = await Sensor.find({ _id: { $in: sensorIds } })
            .populate('room_id', 'name loxone_room_uuid miniserver_serial')
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
     * Get a single sensor by ID
     * @param {String} sensorId - Sensor ID
     * @returns {Promise<Object>} Sensor with room information
     */
    async getSensorById(sensorId) {
        const sensor = await Sensor.findById(sensorId)
            .populate('room_id', 'name loxone_room_uuid miniserver_serial');

        if (!sensor) {
            throw new NotFoundError('Sensor');
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

