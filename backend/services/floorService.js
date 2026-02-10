const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const Building = require('../models/Building');
const loxoneStorageService = require('./loxoneStorageService');
const { NotFoundError } = require('../utils/errors');
const { checkBuildingPermission } = require('../utils/buildingPermissions');

class FloorService {
    /**
     * Create a floor with local rooms
     * @param {String} buildingId - Building ID
     * @param {Object} floorData - Floor data (name, floor_plan_link)
     * @param {Array<Object>} rooms - Array of local rooms [{ name, color, loxone_room_id }]
     * @param {String} userId - User ID (for permission check)
     * @returns {Promise<Object>} Created floor with rooms and building info
     */
    async createFloorWithRooms(buildingId, floorData, rooms = [], userId) {
        // Verify building exists and get site for permission check
        const building = await Building.findById(buildingId).populate('site_id');
        if (!building) {
            throw new NotFoundError('Building');
        }

        // Check permissions using utility function
        await checkBuildingPermission(userId, building.site_id.bryteswitch_id);

        // Create floor
        const floor = new Floor({
            building_id: buildingId,
            name: floorData.name,
            floor_plan_link: floorData.floor_plan_link || null
        });
        await floor.save();

        // Create local rooms
        const createdRooms = [];
        let hasLoxoneMapping = false;
        for (const roomData of rooms) {
            const localRoom = new LocalRoom({
                floor_id: floor._id,
                name: roomData.name,
                color: roomData.color || null,
                loxone_room_id: roomData.loxone_room_id || null
            });
            await localRoom.save();
            createdRooms.push(localRoom);
            if (roomData.loxone_room_id) {
                hasLoxoneMapping = true;
            }
        }

        // Invalidate allowed sensor IDs cache if any room has Loxone mapping
        if (hasLoxoneMapping) {
            loxoneStorageService.invalidateAllowedSensorIdsCache();
        }

        return {
            floor: floor,
            rooms: createdRooms,
            building: building
        };
    }

    /**
     * Get all floors for a building
     * @param {String} buildingId - Building ID
     * @returns {Promise<Array>} Floors with their local rooms
     */
    async getFloorsByBuilding(buildingId) {
        const floors = await Floor.find({ building_id: buildingId }).sort({ name: 1 });
        
        // Populate local rooms for each floor
        const floorsWithRooms = await Promise.all(
            floors.map(async (floor) => {
                const rooms = await LocalRoom.find({ floor_id: floor._id });
                return {
                    ...floor.toObject(),
                    rooms: rooms
                };
            })
        );

        return floorsWithRooms;
    }

    /**
     * Get a floor by ID with rooms
     * @param {String} floorId - Floor ID
     * @returns {Promise<Object>} Floor with rooms
     */
    async getFloorById(floorId) {
        const floor = await Floor.findById(floorId);
        if (!floor) {
            throw new NotFoundError('Floor');
        }

        const rooms = await LocalRoom.find({ floor_id: floorId });
        return {
            ...floor.toObject(),
            rooms: rooms
        };
    }

    /**
     * Update a floor
     * @param {String} floorId - Floor ID
     * @param {Object} updateData - Data to update
     * @param {String} userId - User ID (for permission check)
     * @returns {Promise<Object>} Updated floor with building info
     */
    async updateFloor(floorId, updateData, userId) {
        const floor = await Floor.findById(floorId).populate({
            path: 'building_id',
            populate: { path: 'site_id' }
        });
        if (!floor) {
            throw new NotFoundError('Floor');
        }

        // Check permissions using utility function
        await checkBuildingPermission(userId, floor.building_id.site_id.bryteswitch_id);

        Object.assign(floor, updateData);
        await floor.save();
        return {
            floor: floor,
            building: floor.building_id
        };
    }

    /**
     * Add a local room to a floor
     * @param {String} floorId - Floor ID
     * @param {Object} roomData - Room data
     * @param {String} userId - User ID (for permission check)
     * @returns {Promise<Object>} Created room with floor and building info
     */
    async addRoomToFloor(floorId, roomData, userId) {
        const floor = await Floor.findById(floorId).populate({
            path: 'building_id',
            populate: { path: 'site_id' }
        });
        if (!floor) {
            throw new NotFoundError('Floor');
        }

        // Check permissions using utility function
        await checkBuildingPermission(userId, floor.building_id.site_id.bryteswitch_id);

        const localRoom = new LocalRoom({
            floor_id: floorId,
            name: roomData.name,
            color: roomData.color || null,
            loxone_room_id: roomData.loxone_room_id || null
        });
        await localRoom.save();

        // Invalidate allowed sensor IDs cache if room has Loxone mapping
        if (roomData.loxone_room_id) {
            loxoneStorageService.invalidateAllowedSensorIdsCache();
        }

        return {
            room: localRoom,
            floor: floor,
            building: floor.building_id
        };
    }

    /**
     * Update a local room
     * @param {String} roomId - Local room ID
     * @param {Object} updateData - Data to update
     * @param {String} userId - User ID (for permission check)
     * @returns {Promise<Object>} Updated room with floor and building info
     */
    async updateLocalRoom(roomId, updateData, userId) {
        const room = await LocalRoom.findById(roomId).populate({
            path: 'floor_id',
            populate: {
                path: 'building_id',
                populate: { path: 'site_id' }
            }
        });
        if (!room) {
            throw new NotFoundError('Local room');
        }

        // Check permissions using utility function
        await checkBuildingPermission(userId, room.floor_id.building_id.site_id.bryteswitch_id);

        // Check if loxone_room_id is being changed
        const loxoneMappingChanged = 'loxone_room_id' in updateData && 
            String(room.loxone_room_id || '') !== String(updateData.loxone_room_id || '');

        Object.assign(room, updateData);
        await room.save();

        // Invalidate allowed sensor IDs cache if Loxone mapping changed
        if (loxoneMappingChanged) {
            loxoneStorageService.invalidateAllowedSensorIdsCache();
        }

        return {
            room: room,
            floor: room.floor_id,
            building: room.floor_id.building_id
        };
    }

    /**
     * Delete a local room
     * @param {String} roomId - Local room ID
     * @param {String} userId - User ID (for permission check)
     * @returns {Promise<Object>} Deletion summary with room, floor, and building info
     */
    async deleteLocalRoom(roomId, userId) {
        const room = await LocalRoom.findById(roomId).populate({
            path: 'floor_id',
            populate: {
                path: 'building_id',
                populate: { path: 'site_id' }
            }
        });
        if (!room) {
            throw new NotFoundError('Local room');
        }

        // Check permissions using utility function
        await checkBuildingPermission(userId, room.floor_id.building_id.site_id.bryteswitch_id);

        const hadLoxoneMapping = !!room.loxone_room_id;
        const roomName = room.name;
        const floorId = room.floor_id._id;
        const buildingId = room.floor_id.building_id._id;
        const buildingName = room.floor_id.building_id.name;

        await LocalRoom.findByIdAndDelete(roomId);

        // Invalidate allowed sensor IDs cache if room had Loxone mapping
        if (hadLoxoneMapping) {
            loxoneStorageService.invalidateAllowedSensorIdsCache();
        }

        return {
            roomId: roomId,
            roomName: roomName,
            floorId: floorId,
            buildingId: buildingId,
            buildingName: buildingName,
            hadLoxoneMapping: hadLoxoneMapping
        };
    }

    /**
     * Delete a floor and all its local rooms
     * @param {String} floorId - Floor ID
     * @param {String} userId - User ID (for permission check)
     * @returns {Promise<Object>} Deletion summary
     */
    async deleteFloor(floorId, userId) {
        const floor = await Floor.findById(floorId).populate({
            path: 'building_id',
            populate: { path: 'site_id' }
        });
        if (!floor) {
            throw new NotFoundError('Floor');
        }

        // Check permissions using utility function
        await checkBuildingPermission(userId, floor.building_id.site_id.bryteswitch_id);

        const deletionSummary = {
            floorId: floorId,
            floorName: floor.name,
            buildingId: floor.building_id._id,
            buildingName: floor.building_id.name,
            deletedItems: {}
        };

        // Get all local rooms for this floor
        const localRooms = await LocalRoom.find({ floor_id: floorId });
        deletionSummary.deletedItems.localRooms = localRooms.length;

        // Check if any rooms have Loxone mappings (for cache invalidation)
        const hadLoxoneMappings = localRooms.some(r => r.loxone_room_id);

        // Delete all local rooms
        await LocalRoom.deleteMany({ floor_id: floorId });

        // Invalidate allowed sensor IDs cache if any room had Loxone mapping
        if (hadLoxoneMappings) {
            loxoneStorageService.invalidateAllowedSensorIdsCache();
        }

        // Delete the floor
        await Floor.findByIdAndDelete(floorId);

        return deletionSummary;
    }
}

module.exports = new FloorService();

