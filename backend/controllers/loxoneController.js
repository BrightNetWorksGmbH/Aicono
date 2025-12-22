const loxoneConnectionManager = require('../services/loxoneConnectionManager');
const buildingService = require('../services/buildingService');
const Room = require('../models/Room');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * POST /api/loxone/connect/:buildingId
 * Start a Loxone connection for a building
 */
exports.connect = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const credentials = req.body;

  // Validate required fields
  if (!credentials.user || !credentials.pass) {
    return res.status(400).json({
      success: false,
      error: 'User and password are required'
    });
  }

  if (!credentials.ip && !credentials.externalAddress) {
    return res.status(400).json({
      success: false,
      error: 'Either IP address or external address is required'
    });
  }

  // Verify building exists
  try {
    await buildingService.getBuildingById(buildingId);
  } catch (error) {
    return res.status(404).json({
      success: false,
      error: 'Building not found'
    });
  }

  // Update building with Loxone config
  await buildingService.updateLoxoneConfig(buildingId, credentials);

  // Start connection
  const result = await loxoneConnectionManager.connect(buildingId, credentials);

  if (result.success) {
    res.json({
      success: true,
      message: 'Connection started',
      buildingId: buildingId
    });
  } else {
    res.status(400).json({
      success: false,
      error: result.message
    });
  }
});

/**
 * DELETE /api/loxone/disconnect/:buildingId
 * Stop a Loxone connection for a building
 */
exports.disconnect = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const result = await loxoneConnectionManager.disconnect(buildingId);
  res.json(result);
});

/**
 * GET /api/loxone/status/:buildingId
 * Get connection status for a building
 */
exports.getStatus = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const status = loxoneConnectionManager.getConnectionStatus(buildingId);
  res.json({
    success: true,
    data: status
  });
});

/**
 * GET /api/loxone/connections
 * Get all active connections
 */
exports.getAllConnections = asyncHandler(async (req, res) => {
  const connections = loxoneConnectionManager.getAllConnections();
  res.json({
    success: true,
    data: connections
  });
});

/**
 * GET /api/loxone/rooms/:buildingId
 * Get all Loxone rooms for a building
 */
exports.getLoxoneRooms = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const rooms = await Room.find({ building_id: buildingId }).sort({ name: 1 });
  
  res.json({
    success: true,
    data: rooms
  });
});

