const loxoneConnectionManager = require('../services/loxoneConnectionManager');
const buildingService = require('../services/buildingService');
const Room = require('../models/Room');
const aggregationScheduler = require('../services/aggregationScheduler');
const measurementQueryService = require('../services/measurementQueryService');
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

/**
 * GET /api/loxone/aggregation/status
 * Get aggregation scheduler status
 */
exports.getAggregationStatus = asyncHandler(async (req, res) => {
  const status = aggregationScheduler.getStatus();
  res.json({
    success: true,
    data: status
  });
});

/**
 * POST /api/loxone/aggregation/trigger/15min
 * Manually trigger 15-minute aggregation
 */
exports.trigger15MinAggregation = asyncHandler(async (req, res) => {
  const buildingId = req.body?.buildingId || null;
  const result = await aggregationScheduler.trigger15MinuteAggregation(buildingId);
  res.json({
    success: true,
    message: '15-minute aggregation triggered',
    data: result
  });
});

/**
 * POST /api/loxone/aggregation/trigger/hourly
 * Manually trigger hourly aggregation
 */
exports.triggerHourlyAggregation = asyncHandler(async (req, res) => {
  const buildingId = req.body?.buildingId || null;
  const result = await aggregationScheduler.triggerHourlyAggregation(buildingId);
  res.json({
    success: true,
    message: 'Hourly aggregation triggered',
    data: result
  });
});

/**
 * POST /api/loxone/aggregation/trigger/daily
 * Manually trigger daily aggregation
 */
exports.triggerDailyAggregation = asyncHandler(async (req, res) => {
  const buildingId = req.body?.buildingId || null;
  const result = await aggregationScheduler.triggerDailyAggregation(buildingId);
  res.json({
    success: true,
    message: 'Daily aggregation triggered',
    data: result
  });
});

/**
 * POST /api/loxone/aggregation/trigger/weekly
 * Manually trigger weekly aggregation
 */
exports.triggerWeeklyAggregation = asyncHandler(async (req, res) => {
  const buildingId = req.body?.buildingId || null;
  const result = await aggregationScheduler.triggerWeeklyAggregation(buildingId);
  res.json({
    success: true,
    message: 'Weekly aggregation triggered',
    data: result
  });
});

/**
 * POST /api/loxone/aggregation/trigger/monthly
 * Manually trigger monthly aggregation
 */
exports.triggerMonthlyAggregation = asyncHandler(async (req, res) => {
  const buildingId = req.body?.buildingId || null;
  const result = await aggregationScheduler.triggerMonthlyAggregation(buildingId);
  res.json({
    success: true,
    message: 'Monthly aggregation triggered',
    data: result
  });
});

/**
 * GET /api/loxone/measurements/:sensorId
 * Get measurements for a sensor with automatic resolution selection
 */
exports.getSensorMeasurements = asyncHandler(async (req, res) => {
  const { sensorId } = req.params;
  const { startDate, endDate, resolution } = req.query;
  
  if (!startDate || !endDate) {
    return res.status(400).json({
      success: false,
      error: 'startDate and endDate query parameters are required'
    });
  }
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  const options = {};
  if (resolution) {
    options.resolution = parseInt(resolution);
  }
  
  const result = await measurementQueryService.getMeasurements(sensorId, start, end, options);
  
  res.json({
    success: true,
    data: result
  });
});

/**
 * GET /api/loxone/measurements/building/:buildingId
 * Get measurements for a building with automatic resolution selection
 */
exports.getBuildingMeasurements = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const { startDate, endDate, measurementType, resolution } = req.query;
  
  if (!startDate || !endDate) {
    return res.status(400).json({
      success: false,
      error: 'startDate and endDate query parameters are required'
    });
  }
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  const options = {};
  if (measurementType) {
    options.measurementType = measurementType;
  }
  if (resolution) {
    options.resolution = parseInt(resolution);
  }
  
  const result = await measurementQueryService.getMeasurementsByBuilding(buildingId, start, end, options);
  
  res.json({
    success: true,
    data: result
  });
});

/**
 * GET /api/loxone/statistics/:buildingId
 * Get aggregated statistics for a building
 */
exports.getBuildingStatistics = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const { startDate, endDate, measurementType } = req.query;
  
  if (!startDate || !endDate) {
    return res.status(400).json({
      success: false,
      error: 'startDate and endDate query parameters are required'
    });
  }
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  const statistics = await measurementQueryService.getStatistics(buildingId, start, end, measurementType || null);
  
  res.json({
    success: true,
    data: statistics
  });
});

