/**
 * Sensor Lookup Utility
 * 
 * Provides reusable functions to get sensor IDs for buildings, floors, and sites
 * using the new per-server architecture:
 * 
 * Building -> Floor -> LocalRoom -> Room (Loxone) -> Sensor
 * 
 * This utility centralizes the logic for traversing the entity hierarchy
 * to find sensors, avoiding code duplication across services.
 */

const mongoose = require('mongoose');
const LocalRoom = require('../models/LocalRoom');
const Sensor = require('../models/Sensor');
const Floor = require('../models/Floor');

// Cache for sensor lookups to reduce database queries
const sensorIdCache = new Map(); // key -> { sensorIds: Set, timestamp: number }
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Get sensor IDs for a building
 * Traverses: Building -> Floors -> LocalRooms -> Loxone Rooms -> Sensors
 * 
 * @param {string|ObjectId} buildingId - The building ID
 * @param {Object} options - Options object
 * @param {boolean} options.useCache - Whether to use caching (default: true)
 * @returns {Promise<string[]>} Array of sensor ID strings
 */
async function getSensorIdsForBuilding(buildingId, options = {}) {
    const { useCache = true } = options;
    const cacheKey = `building:${buildingId}`;

    // Check cache first
    if (useCache) {
        const cached = sensorIdCache.get(cacheKey);
        if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
            return Array.from(cached.sensorIds);
        }
    }



    const buildingObjectId = typeof buildingId === 'string' 
        ? new mongoose.Types.ObjectId(buildingId) 
        : buildingId;

    // Get all floors for this building
    const floors = await Floor.find({ building_id: buildingObjectId }).select('_id');
    if (floors.length === 0) {
        return [];
    }

    const floorIds = floors.map(f => f._id);

    // Get all LocalRooms for these floors that have a loxone_room_id
    const localRooms = await LocalRoom.find({
        floor_id: { $in: floorIds },
        loxone_room_id: { $exists: true, $ne: null }
    }).select('loxone_room_id');

    if (localRooms.length === 0) {
        // Cache empty result too
        if (useCache) {
            sensorIdCache.set(cacheKey, { sensorIds: new Set(), timestamp: Date.now() });
        }
        return [];
    }

    const loxoneRoomIds = [...new Set(localRooms.map(lr => lr.loxone_room_id.toString()))];

    // Get all sensors for these Loxone rooms
    const sensors = await Sensor.find({
        room_id: { $in: loxoneRoomIds.map(id => new mongoose.Types.ObjectId(id)) }
    }).select('_id');

    const sensorIds = sensors.map(s => s._id.toString());

    // Cache the result
    if (useCache) {
        sensorIdCache.set(cacheKey, { 
            sensorIds: new Set(sensorIds), 
            timestamp: Date.now() 
        });
    }

    return sensorIds;
}

/**
 * Get sensor IDs for a floor
 * Traverses: Floor -> LocalRooms -> Loxone Rooms -> Sensors
 * 
 * @param {string|ObjectId} floorId - The floor ID
 * @param {Object} options - Options object
 * @param {boolean} options.useCache - Whether to use caching (default: true)
 * @returns {Promise<string[]>} Array of sensor ID strings
 */
async function getSensorIdsForFloor(floorId, options = {}) {
    const { useCache = true } = options;
    const cacheKey = `floor:${floorId}`;

    // Check cache first
    if (useCache) {
        const cached = sensorIdCache.get(cacheKey);
        if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
            return Array.from(cached.sensorIds);
        }
    }

  

    const floorObjectId = typeof floorId === 'string' 
        ? new mongoose.Types.ObjectId(floorId) 
        : floorId;

    // Get all LocalRooms for this floor that have a loxone_room_id
    const localRooms = await LocalRoom.find({
        floor_id: floorObjectId,
        loxone_room_id: { $exists: true, $ne: null }
    }).select('loxone_room_id');

    if (localRooms.length === 0) {
        if (useCache) {
            sensorIdCache.set(cacheKey, { sensorIds: new Set(), timestamp: Date.now() });
        }
        return [];
    }

    const loxoneRoomIds = [...new Set(localRooms.map(lr => lr.loxone_room_id.toString()))];

    // Get all sensors for these Loxone rooms
    const sensors = await Sensor.find({
        room_id: { $in: loxoneRoomIds.map(id => new mongoose.Types.ObjectId(id)) }
    }).select('_id');

    const sensorIds = sensors.map(s => s._id.toString());

    // Cache the result
    if (useCache) {
        sensorIdCache.set(cacheKey, { 
            sensorIds: new Set(sensorIds), 
            timestamp: Date.now() 
        });
    }

    return sensorIds;
}

/**
 * Get sensor IDs for a site (all buildings in the site)
 * Traverses: Site -> Buildings -> Floors -> LocalRooms -> Loxone Rooms -> Sensors
 * 
 * @param {string|ObjectId} siteId - The site ID
 * @param {Object} options - Options object
 * @param {boolean} options.useCache - Whether to use caching (default: true)
 * @returns {Promise<string[]>} Array of sensor ID strings
 */
async function getSensorIdsForSite(siteId, options = {}) {
    const { useCache = true } = options;
    const cacheKey = `site:${siteId}`;

    // Check cache first
    if (useCache) {
        const cached = sensorIdCache.get(cacheKey);
        if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
            return Array.from(cached.sensorIds);
        }
    }

    const Building = require('../models/Building');

    const siteObjectId = typeof siteId === 'string' 
        ? new mongoose.Types.ObjectId(siteId) 
        : siteId;

    // Get all buildings for this site
    const buildings = await Building.find({ site_id: siteObjectId }).select('_id');
    if (buildings.length === 0) {
        return [];
    }

    // Get sensor IDs for all buildings (don't use cache for individual lookups)
    const sensorIdArrays = await Promise.all(
        buildings.map(b => getSensorIdsForBuilding(b._id, { useCache: false }))
    );

    // Combine and dedupe sensor IDs
    const allSensorIds = [...new Set(sensorIdArrays.flat())];

    // Cache the result
    if (useCache) {
        sensorIdCache.set(cacheKey, { 
            sensorIds: new Set(allSensorIds), 
            timestamp: Date.now() 
        });
    }

    return allSensorIds;
}

/**
 * Get sensor IDs for a LocalRoom
 * Traverses: LocalRoom -> Loxone Room -> Sensors
 * 
 * @param {string|ObjectId} localRoomId - The local room ID
 * @returns {Promise<string[]>} Array of sensor ID strings
 */
async function getSensorIdsForLocalRoom(localRoomId) {
   

    const localRoom = await LocalRoom.findById(localRoomId).select('loxone_room_id');
    if (!localRoom || !localRoom.loxone_room_id) {
        return [];
    }

    const sensors = await Sensor.find({ room_id: localRoom.loxone_room_id }).select('_id');
    return sensors.map(s => s._id.toString());
}

/**
 * Get sensor IDs for a Loxone Room directly
 * 
 * @param {string|ObjectId} loxoneRoomId - The Loxone room ID
 * @returns {Promise<string[]>} Array of sensor ID strings
 */
async function getSensorIdsForLoxoneRoom(loxoneRoomId) {

    const roomObjectId = typeof loxoneRoomId === 'string' 
        ? new mongoose.Types.ObjectId(loxoneRoomId) 
        : loxoneRoomId;

    const sensors = await Sensor.find({ room_id: roomObjectId }).select('_id');
    return sensors.map(s => s._id.toString());
}

/**
 * Get sensor IDs for multiple buildings
 * 
 * @param {Array<string|ObjectId>} buildingIds - Array of building IDs
 * @param {Object} options - Options object
 * @param {boolean} options.useCache - Whether to use caching (default: true)
 * @returns {Promise<string[]>} Array of unique sensor ID strings
 */
async function getSensorIdsForBuildings(buildingIds, options = {}) {
    const sensorIdArrays = await Promise.all(
        buildingIds.map(id => getSensorIdsForBuilding(id, options))
    );
    return [...new Set(sensorIdArrays.flat())];
}

/**
 * Get a mapping of building ID to sensor IDs for multiple buildings
 * Useful for dashboard queries that need to aggregate by building
 * 
 * @param {Array<string|ObjectId>} buildingIds - Array of building IDs
 * @param {Object} options - Options object
 * @param {boolean} options.useCache - Whether to use caching (default: true)
 * @returns {Promise<Map<string, string[]>>} Map of building ID -> sensor IDs
 */
async function getBuildingToSensorIdsMap(buildingIds, options = {}) {
    const results = await Promise.all(
        buildingIds.map(async (id) => {
            const sensorIds = await getSensorIdsForBuilding(id, options);
            return [id.toString(), sensorIds];
        })
    );
    return new Map(results);
}

/**
 * Invalidate cache for a specific entity
 * Call this when LocalRooms are modified
 * 
 * @param {string} entityType - 'building', 'floor', or 'site'
 * @param {string|ObjectId} entityId - The entity ID
 */
function invalidateCache(entityType, entityId) {
    const key = `${entityType}:${entityId}`;
    sensorIdCache.delete(key);
}

/**
 * Invalidate all sensor lookup caches
 * Call this when significant changes occur to room mappings
 */
function invalidateAllCaches() {
    sensorIdCache.clear();
}

/**
 * Get building ID from a sensor ID by reverse lookup
 * Traverses: Sensor -> Room -> LocalRoom -> Floor -> Building
 * 
 * @param {string|ObjectId} sensorId - The sensor ID
 * @returns {Promise<string|null>} Building ID or null if not found
 */
async function getBuildingIdFromSensor(sensorId) {
   

    const sensorObjectId = typeof sensorId === 'string' 
        ? new mongoose.Types.ObjectId(sensorId) 
        : sensorId;

    // Get the sensor's room
    const sensor = await Sensor.findById(sensorObjectId).select('room_id');
    if (!sensor || !sensor.room_id) {
        return null;
    }

    // Find LocalRoom linked to this Loxone room
    const localRoom = await LocalRoom.findOne({ loxone_room_id: sensor.room_id }).select('floor_id');
    if (!localRoom) {
        return null;
    }

    // Get the floor to find building
    const floor = await Floor.findById(localRoom.floor_id).select('building_id');
    if (!floor) {
        return null;
    }

    return floor.building_id.toString();
}

/**
 * Get building IDs that use a specific Loxone room
 * A Loxone room can be mapped to LocalRooms in multiple buildings
 * 
 * @param {string|ObjectId} loxoneRoomId - The Loxone room ID
 * @returns {Promise<string[]>} Array of building IDs
 */
async function getBuildingIdsForLoxoneRoom(loxoneRoomId) {
   

    const roomObjectId = typeof loxoneRoomId === 'string' 
        ? new mongoose.Types.ObjectId(loxoneRoomId) 
        : loxoneRoomId;

    // Find all LocalRooms linked to this Loxone room
    const localRooms = await LocalRoom.find({ loxone_room_id: roomObjectId }).select('floor_id');
    if (localRooms.length === 0) {
        return [];
    }

    const floorIds = localRooms.map(lr => lr.floor_id);

    // Get floors to find buildings
    const floors = await Floor.find({ _id: { $in: floorIds } }).select('building_id');
    
    return [...new Set(floors.map(f => f.building_id.toString()))];
}

module.exports = {
    getSensorIdsForBuilding,
    getSensorIdsForFloor,
    getSensorIdsForSite,
    getSensorIdsForLocalRoom,
    getSensorIdsForLoxoneRoom,
    getSensorIdsForBuildings,
    getBuildingToSensorIdsMap,
    getBuildingIdFromSensor,
    getBuildingIdsForLoxoneRoom,
    invalidateCache,
    invalidateAllCaches,
};
