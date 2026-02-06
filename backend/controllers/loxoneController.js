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

  // Verify building exists and get building data
  let building;
  try {
    building = await buildingService.getBuildingById(buildingId);
  } catch (error) {
    return res.status(404).json({
      success: false,
      error: 'Building not found'
    });
  }

  // Ensure serialNumber is in credentials (use from building if not provided)
  if (!credentials.serialNumber && building.miniserver_serial) {
    credentials.serialNumber = building.miniserver_serial;
  }

  // Validate serialNumber is present
  if (!credentials.serialNumber) {
    return res.status(400).json({
      success: false,
      error: 'Serial number is required (miniserver_serial)'
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
 * Get all Loxone rooms for a building (via server serial)
 */
exports.getLoxoneRooms = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  
  // Get building to find its server serial
  const Building = require('../models/Building');
  const building = await Building.findById(buildingId);
  if (!building) {
    return res.status(404).json({
      success: false,
      error: 'Building not found'
    });
  }
  
  if (!building.miniserver_serial) {
    return res.status(400).json({
      success: false,
      error: 'Building has no Loxone server configured'
    });
  }
  
  // Get rooms for this server
  const rooms = await Room.find({ miniserver_serial: building.miniserver_serial }).sort({ name: 1 });
  
  res.json({
    success: true,
    data: rooms
  });
});

/**
 * GET /api/loxone/aggregation/status
 * Get aggregation scheduler status with detailed diagnostics
 */
exports.getAggregationStatus = asyncHandler(async (req, res) => {
  const status = aggregationScheduler.getStatus();
  
  // Add additional diagnostic information
  const mongoose = require('mongoose');
  const db = mongoose.connection.db;
  let rawDataCount = 0;
  let aggregatedDataCount = 0;
  
  if (db) {
    try {
      // Count raw data (resolution_minutes: 0)
      rawDataCount = await db.collection('measurements_raw').countDocuments({ resolution_minutes: 0 });
      
      // Count aggregated data (resolution_minutes > 0)
      aggregatedDataCount = await db.collection('measurements_aggregated').countDocuments({ 
        resolution_minutes: { $gt: 0 } 
      });
    } catch (error) {
      console.error('[DIAGNOSTIC] Error counting documents:', error.message);
    }
  }
  
  res.json({
    success: true,
    data: {
      ...status,
      diagnostics: {
        rawDataCount,
        aggregatedDataCount,
        databaseConnected: mongoose.connection.readyState === 1,
        databaseName: mongoose.connection.name || db?.databaseName || 'unknown'
      }
    }
  });
});

/**
 * POST /api/loxone/aggregation/trigger/15min
 * Manually trigger 15-minute aggregation
 */
exports.trigger15MinAggregation = asyncHandler(async (req, res) => {
  console.log("this is the first thing that gets printed when the manual trigger is started")
  const buildingId = req.body?.buildingId || null;
  
  // Return immediately, process aggregation in background to avoid API timeouts
  res.json({
    success: true,
    message: '15-minute aggregation triggered (processing in background)',
    buildingId: buildingId || 'all buildings',
    status: 'processing'
  });
  
  // Process aggregation in background (don't await - fire and forget)
  aggregationScheduler.trigger15MinuteAggregation(buildingId)
    .then(result => {
      console.log(`[AGGREGATION] [15-min] Background aggregation completed for ${buildingId || 'all buildings'}:`, {
        count: result.count,
        deleted: result.deleted,
        success: result.success
      });
    })
    .catch(error => {
      console.error(`[AGGREGATION] [15-min] Background aggregation failed for ${buildingId || 'all buildings'}:`, error.message);
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
 * POST /api/loxone/aggregation/trigger/daterange
 * Manually trigger aggregation for a specific date range
 * Body: { startDate: ISO string, endDate: ISO string, buildingId?: string, deleteAfterAggregation?: boolean }
 */
exports.triggerDateRangeAggregation = asyncHandler(async (req, res) => {
  const { startDate, endDate, buildingId, deleteAfterAggregation } = req.body;
  
  if (!startDate || !endDate) {
    return res.status(400).json({
      success: false,
      error: 'startDate and endDate are required (ISO date strings)'
    });
  }
  
  const start = new Date(startDate);
  const end = new Date(endDate);
  
  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    return res.status(400).json({
      success: false,
      error: 'Invalid date format. Use ISO date strings (e.g., "2026-01-29T00:00:00.000Z")'
    });
  }
  
  if (start >= end) {
    return res.status(400).json({
      success: false,
      error: 'startDate must be before endDate'
    });
  }
  
  const measurementAggregationService = require('../services/measurementAggregationService');
  const result = await measurementAggregationService.aggregateDateRange(
    start,
    end,
    buildingId || null,
    deleteAfterAggregation !== false, // Default to true
    30 // bufferMinutes
  );
  
  res.json({
    success: result.success,
    message: result.success 
      ? `Date range aggregation completed: ${result.count} aggregates created`
      : `Date range aggregation completed with errors: ${result.errors?.length || 0} errors`,
    data: result
  });
});

/**
 * GET /api/loxone/aggregation/unaggregated
 * Check for unaggregated raw data
 * Query params: buildingId (optional - filters by building's sensors), startDate (optional), endDate (optional)
 * Note: buildingId filtering requires sensor lookup since measurements no longer contain buildingId
 */
exports.getUnaggregatedData = asyncHandler(async (req, res) => {
  const mongoose = require('mongoose');
  const sensorLookup = require('../utils/sensorLookup');
  const db = mongoose.connection.db;
  
  if (!db) {
    return res.status(500).json({
      success: false,
      error: 'Database connection not available'
    });
  }
  
  const { buildingId, startDate, endDate } = req.query;
  
  const matchStage = {
    resolution_minutes: 0
  };
  
  // Filter by building's sensors if buildingId provided
  if (buildingId) {
    if (!mongoose.Types.ObjectId.isValid(buildingId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid buildingId'
      });
    }
    // Get sensor IDs for this building via sensorLookup
    const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
    if (sensorIdsSet.size > 0) {
      const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));
      matchStage['meta.sensorId'] = { $in: sensorIds };
    } else {
      // No sensors for this building - return empty result
      return res.json({
        success: true,
        data: {
          count: 0,
          dateRange: { oldest: null, newest: null },
          sample: null,
          buildingId: buildingId
        }
      });
    }
  }
  
  if (startDate || endDate) {
    matchStage.timestamp = {};
    if (startDate) {
      matchStage.timestamp.$gte = new Date(startDate);
    }
    if (endDate) {
      matchStage.timestamp.$lt = new Date(endDate);
    }
  }
  
  // Get count and date range of unaggregated data
  const count = await db.collection('measurements_raw').countDocuments(matchStage);
  
  // Get oldest and newest timestamps
  const oldest = await db.collection('measurements_raw')
    .find(matchStage)
    .sort({ timestamp: 1 })
    .limit(1)
    .project({ timestamp: 1, _id: 0 })
    .toArray();
  
  const newest = await db.collection('measurements_raw')
    .find(matchStage)
    .sort({ timestamp: -1 })
    .limit(1)
    .project({ timestamp: 1, _id: 0 })
    .toArray();
  
  // Get sample document to verify structure
  const sample = await db.collection('measurements_raw')
    .findOne(matchStage, {
      projection: {
        timestamp: 1,
        resolution_minutes: 1,
        'meta.sensorId': 1,
        'meta.measurementType': 1,
        source: 1,
        _id: 0
      }
    });
  
  res.json({
    success: true,
    data: {
      count,
      dateRange: {
        oldest: oldest.length > 0 ? oldest[0].timestamp : null,
        newest: newest.length > 0 ? newest[0].timestamp : null
      },
      sample,
      buildingId: buildingId || 'all buildings'
    }
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

