const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const Building = require('../models/Building');

class FloorService {
    /**
     * Create a floor with local rooms
     * @param {String} buildingId - Building ID
     * @param {Object} floorData - Floor data (name, floor_plan_link)
     * @param {Array<Object>} rooms - Array of local rooms [{ name, color, loxone_room_id }]
     * @returns {Promise<Object>} Created floor with rooms
     */
    async createFloorWithRooms(buildingId, floorData, rooms = []) {
        // Verify building exists
        const building = await Building.findById(buildingId);
        if (!building) {
            throw new Error('Building not found');
        }

        // Create floor
        const floor = new Floor({
            building_id: buildingId,
            name: floorData.name,
            floor_plan_link: floorData.floor_plan_link || null
        });
        await floor.save();

        // Create local rooms
        const createdRooms = [];
        for (const roomData of rooms) {
            const localRoom = new LocalRoom({
                floor_id: floor._id,
                name: roomData.name,
                color: roomData.color || null,
                loxone_room_id: roomData.loxone_room_id || null
            });
            await localRoom.save();
            createdRooms.push(localRoom);
        }

        return {
            floor: floor,
            rooms: createdRooms
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
            throw new Error('Floor not found');
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
     * @returns {Promise<Object>} Updated floor
     */
    async updateFloor(floorId, updateData) {
        const floor = await Floor.findById(floorId);
        if (!floor) {
            throw new Error('Floor not found');
        }

        Object.assign(floor, updateData);
        await floor.save();
        return floor;
    }

    /**
     * Add a local room to a floor
     * @param {String} floorId - Floor ID
     * @param {Object} roomData - Room data
     * @returns {Promise<Object>} Created room
     */
    async addRoomToFloor(floorId, roomData) {
        const floor = await Floor.findById(floorId);
        if (!floor) {
            throw new Error('Floor not found');
        }

        const localRoom = new LocalRoom({
            floor_id: floorId,
            name: roomData.name,
            color: roomData.color || null,
            loxone_room_id: roomData.loxone_room_id || null
        });
        await localRoom.save();
        return localRoom;
    }

    /**
     * Update a local room
     * @param {String} roomId - Local room ID
     * @param {Object} updateData - Data to update
     * @returns {Promise<Object>} Updated room
     */
    async updateLocalRoom(roomId, updateData) {
        const room = await LocalRoom.findById(roomId);
        if (!room) {
            throw new Error('Local room not found');
        }

        Object.assign(room, updateData);
        await room.save();
        return room;
    }

    /**
     * Delete a local room
     * @param {String} roomId - Local room ID
     * @returns {Promise<void>}
     */
    async deleteLocalRoom(roomId) {
        const room = await LocalRoom.findById(roomId);
        if (!room) {
            throw new Error('Local room not found');
        }

        await LocalRoom.findByIdAndDelete(roomId);
    }
}

module.exports = new FloorService();

