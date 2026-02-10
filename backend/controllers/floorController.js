const floorService = require('../services/floorService');
const ActivityLog = require('../models/ActivityLog');
const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const Building = require('../models/Building');
const Site = require('../models/Site');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * POST /api/floors/building/:buildingId
 * Create a floor with local rooms
 */
exports.createFloorWithRooms = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const { name, floor_plan_link, rooms } = req.body;
  const userId = req.user._id;

  if (!name) {
    return res.status(400).json({
      success: false,
      error: 'Floor name is required'
    });
  }

  const result = await floorService.createFloorWithRooms(
    buildingId,
    { name, floor_plan_link },
    rooms || [],
    userId
  );

  // Log activity
  try {
    const site = await Site.findById(result.building.site_id._id || result.building.site_id);
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'create',
      resource_type: 'floor',
      resource_id: result.floor._id,
      timestamp: new Date(),
      details: {
        floor_name: result.floor.name,
        building_id: buildingId,
        building_name: result.building.name,
        rooms_count: result.rooms.length,
        action: 'floor_created'
      },
      severity: 'low',
    });

    // Log activity for each room created
    for (const room of result.rooms) {
      await ActivityLog.create({
        bryteswitch_id: site.bryteswitch_id,
        user_id: userId,
        action: 'create',
        resource_type: 'local_room',
        resource_id: room._id,
        timestamp: new Date(),
        details: {
          room_name: room.name,
          floor_id: result.floor._id,
          floor_name: result.floor.name,
          building_id: buildingId,
          building_name: result.building.name,
          has_loxone_mapping: !!room.loxone_room_id,
          action: 'local_room_created'
        },
        severity: 'low',
      });
    }
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.status(201).json({
    success: true,
    message: 'Floor created successfully',
    data: result
  });
});

/**
 * GET /api/floors/building/:buildingId
 * Get all floors for a building
 */
exports.getFloorsByBuilding = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const floors = await floorService.getFloorsByBuilding(buildingId);

  res.json({
    success: true,
    data: floors
  });
});

/**
 * GET /api/floors/:floorId
 * Get a floor by ID
 */
exports.getFloorById = asyncHandler(async (req, res) => {
  const { floorId } = req.params;
  const floor = await floorService.getFloorById(floorId);

  res.json({
    success: true,
    data: floor
  });
});

/**
 * PATCH /api/floors/:floorId
 * Update a floor
 */
exports.updateFloor = asyncHandler(async (req, res) => {
  const { floorId } = req.params;
  const updateData = req.body;
  const userId = req.user._id;

  const allowedFields = ['name', 'floor_plan_link'];
  const filteredData = {};
  for (const field of allowedFields) {
    if (updateData[field] !== undefined) {
      filteredData[field] = updateData[field];
    }
  }

  const result = await floorService.updateFloor(floorId, filteredData, userId);

  // Log activity
  try {
    const site = await Site.findById(result.building.site_id._id || result.building.site_id);
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'update',
      resource_type: 'floor',
      resource_id: floorId,
      timestamp: new Date(),
      details: {
        floor_name: result.floor.name,
        building_id: result.building._id,
        building_name: result.building.name,
        updated_fields: Object.keys(filteredData),
        action: 'floor_updated'
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Floor updated successfully',
    data: result.floor
  });
});

/**
 * POST /api/floors/:floorId/rooms
 * Add a room to a floor
 */
exports.addRoomToFloor = asyncHandler(async (req, res) => {
  const { floorId } = req.params;
  const { name, color, loxone_room_id } = req.body;
  const userId = req.user._id;

  if (!name) {
    return res.status(400).json({
      success: false,
      error: 'Room name is required'
    });
  }

  const result = await floorService.addRoomToFloor(floorId, {
    name,
    color,
    loxone_room_id
  }, userId);

  // Log activity
  try {
    const site = await Site.findById(result.building.site_id._id || result.building.site_id);
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'create',
      resource_type: 'local_room',
      resource_id: result.room._id,
      timestamp: new Date(),
      details: {
        room_name: result.room.name,
        floor_id: floorId,
        floor_name: result.floor.name,
        building_id: result.building._id,
        building_name: result.building.name,
        has_loxone_mapping: !!loxone_room_id,
        action: 'local_room_created'
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.status(201).json({
    success: true,
    message: 'Room added successfully',
    data: result.room
  });
});

/**
 * PATCH /api/floors/rooms/:roomId
 * Update a local room
 */
exports.updateLocalRoom = asyncHandler(async (req, res) => {
  const { roomId } = req.params;
  const updateData = req.body;
  const userId = req.user._id;

  const allowedFields = ['name', 'color', 'loxone_room_id'];
  const filteredData = {};
  for (const field of allowedFields) {
    if (updateData[field] !== undefined) {
      filteredData[field] = updateData[field];
    }
  }

  const result = await floorService.updateLocalRoom(roomId, filteredData, userId);

  // Log activity
  try {
    const site = await Site.findById(result.building.site_id._id || result.building.site_id);
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'update',
      resource_type: 'local_room',
      resource_id: roomId,
      timestamp: new Date(),
      details: {
        room_name: result.room.name,
        floor_id: result.floor._id,
        floor_name: result.floor.name,
        building_id: result.building._id,
        building_name: result.building.name,
        updated_fields: Object.keys(filteredData),
        loxone_mapping_changed: filteredData.loxone_room_id !== undefined,
        action: 'local_room_updated'
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Room updated successfully',
    data: result.room
  });
});

/**
 * DELETE /api/floors/rooms/:roomId
 * Delete a local room
 */
exports.deleteLocalRoom = asyncHandler(async (req, res) => {
  const { roomId } = req.params;
  const userId = req.user._id;

  // Get room info before deletion for activity log
  const room = await LocalRoom.findById(roomId).populate({
    path: 'floor_id',
    populate: {
      path: 'building_id',
      populate: { path: 'site_id' }
    }
  });

  if (!room) {
    return res.status(404).json({
      success: false,
      error: 'Local room not found'
    });
  }

  const deletionSummary = await floorService.deleteLocalRoom(roomId, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: room.floor_id.building_id.site_id.bryteswitch_id,
      user_id: userId,
      action: 'delete',
      resource_type: 'local_room',
      resource_id: roomId,
      timestamp: new Date(),
      details: {
        room_name: deletionSummary.roomName,
        floor_id: deletionSummary.floorId,
        building_id: deletionSummary.buildingId,
        building_name: deletionSummary.buildingName,
        had_loxone_mapping: deletionSummary.hadLoxoneMapping,
        action: 'local_room_deleted'
      },
      severity: 'medium',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Room deleted successfully',
    data: deletionSummary
  });
});

/**
 * DELETE /api/floors/:floorId
 * Delete a floor and all its local rooms
 */
exports.deleteFloor = asyncHandler(async (req, res) => {
  const { floorId } = req.params;
  const userId = req.user._id;

  // Get floor info before deletion for activity log
  const floor = await Floor.findById(floorId).populate({
    path: 'building_id',
    populate: { path: 'site_id' }
  });

  if (!floor) {
    return res.status(404).json({
      success: false,
      error: 'Floor not found'
    });
  }

  const deletionSummary = await floorService.deleteFloor(floorId, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: floor.building_id.site_id.bryteswitch_id,
      user_id: userId,
      action: 'delete',
      resource_type: 'floor',
      resource_id: floorId,
      timestamp: new Date(),
      details: {
        floor_name: deletionSummary.floorName,
        building_id: deletionSummary.buildingId,
        building_name: deletionSummary.buildingName,
        deleted_items: deletionSummary.deletedItems,
        action: 'floor_deleted'
      },
      severity: 'medium',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Floor deleted successfully',
    data: deletionSummary
  });
});

