const mongoose = require('mongoose');
const LocalRoom = require('../models/LocalRoom');
const Sensor = require('../models/Sensor');
const User = require('../models/User');
const UserRole = require('../models/UserRole');

/**
 * Validate user has access to a LocalRoom
 * Reuses logic from dashboardDiscoveryService
 * 
 * @param {string} userId - User ID
 * @param {string} roomId - LocalRoom ID
 * @returns {Promise<boolean>} True if user has access
 */
async function validateRoomAccess(userId, roomId) {
    try {
        const localRoom = await LocalRoom.findById(roomId).populate({
            path: 'floor_id',
            populate: {
                path: 'building_id',
                populate: {
                    path: 'site_id'
                }
            }
        });

        if (!localRoom || !localRoom.floor_id || !localRoom.floor_id.building_id) {
            return false;
        }

        const site = localRoom.floor_id.building_id.site_id;
        if (!site) {
            return false;
        }

        // Check user role
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });

        if (userRole) {
            return true;
        }

        // Check if superadmin
        const user = await User.findById(userId);
        if (user && user.is_superadmin) {
            return true;
        }

        return false;
    } catch (error) {
        console.error('[REALTIME-AUTH] Error validating room access:', error.message);
        return false;
    }
}

/**
 * Validate user has access to a sensor
 * Traverses: Sensor -> Room -> LocalRoom -> Floor -> Building -> Site
 * 
 * @param {string} userId - User ID
 * @param {string} sensorId - Sensor ID
 * @returns {Promise<boolean>} True if user has access
 */
async function validateSensorAccess(userId, sensorId) {
    try {
        const sensor = await Sensor.findById(sensorId).populate('room_id');
        if (!sensor || !sensor.room_id) {
            return false;
        }

        // Find LocalRoom linked to this Loxone room
        const localRoom = await LocalRoom.findOne({ loxone_room_id: sensor.room_id._id }).populate({
            path: 'floor_id',
            populate: {
                path: 'building_id',
                populate: {
                    path: 'site_id'
                }
            }
        });

        if (!localRoom || !localRoom.floor_id || !localRoom.floor_id.building_id) {
            return false;
        }

        const site = localRoom.floor_id.building_id.site_id;
        if (!site) {
            return false;
        }

        // Check user role
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });

        if (userRole) {
            return true;
        }

        // Check if superadmin
        const user = await User.findById(userId);
        if (user && user.is_superadmin) {
            return true;
        }

        return false;
    } catch (error) {
        console.error('[REALTIME-AUTH] Error validating sensor access:', error.message);
        return false;
    }
}

module.exports = {
    validateRoomAccess,
    validateSensorAccess
};
