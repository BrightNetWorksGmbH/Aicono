const floorService = require('../services/floorService');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * POST /api/floors/building/:buildingId
 * Create a floor with local rooms
 */
exports.createFloorWithRooms = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const { name, floor_plan_link, rooms } = req.body;

  if (!name) {
    return res.status(400).json({
      success: false,
      error: 'Floor name is required'
    });
  }

  const result = await floorService.createFloorWithRooms(
    buildingId,
    { name, floor_plan_link },
    rooms || []
  );

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

  const allowedFields = ['name', 'floor_plan_link'];
  const filteredData = {};
  for (const field of allowedFields) {
    if (updateData[field] !== undefined) {
      filteredData[field] = updateData[field];
    }
  }

  const floor = await floorService.updateFloor(floorId, filteredData);

  res.json({
    success: true,
    message: 'Floor updated successfully',
    data: floor
  });
});

/**
 * POST /api/floors/:floorId/rooms
 * Add a room to a floor
 */
exports.addRoomToFloor = asyncHandler(async (req, res) => {
  const { floorId } = req.params;
  const { name, color, loxone_room_id } = req.body;

  if (!name) {
    return res.status(400).json({
      success: false,
      error: 'Room name is required'
    });
  }

  const room = await floorService.addRoomToFloor(floorId, {
    name,
    color,
    loxone_room_id
  });

  res.status(201).json({
    success: true,
    message: 'Room added successfully',
    data: room
  });
});

/**
 * PATCH /api/floors/rooms/:roomId
 * Update a local room
 */
exports.updateLocalRoom = asyncHandler(async (req, res) => {
  const { roomId } = req.params;
  const updateData = req.body;

  const allowedFields = ['name', 'color', 'loxone_room_id'];
  const filteredData = {};
  for (const field of allowedFields) {
    if (updateData[field] !== undefined) {
      filteredData[field] = updateData[field];
    }
  }

  const room = await floorService.updateLocalRoom(roomId, filteredData);

  res.json({
    success: true,
    message: 'Room updated successfully',
    data: room
  });
});

/**
 * DELETE /api/floors/rooms/:roomId
 * Delete a local room
 */
exports.deleteLocalRoom = asyncHandler(async (req, res) => {
  const { roomId } = req.params;
  await floorService.deleteLocalRoom(roomId);

  res.json({
    success: true,
    message: 'Room deleted successfully'
  });
});

