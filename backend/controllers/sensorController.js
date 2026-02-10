const sensorService = require('../services/sensorService');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * GET /api/v1/sensors/building/:buildingId
 * Get all sensors for a building
 */
exports.getSensorsByBuilding = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const sensors = await sensorService.getSensorsByBuilding(buildingId);

  res.json({
    success: true,
    data: sensors,
    count: sensors.length
  });
});

/**
 * GET /api/v1/sensors/site/:siteId
 * Get all sensors for a site (across all buildings)
 */
exports.getSensorsBySite = asyncHandler(async (req, res) => {
  const { siteId } = req.params;
  const sensors = await sensorService.getSensorsBySite(siteId);

  res.json({
    success: true,
    data: sensors,
    count: sensors.length
  });
});

/**
 * GET /api/v1/sensors/local-room/:localRoomId
 * Get all sensors for a local room
 */
exports.getSensorsByLocalRoom = asyncHandler(async (req, res) => {
  const { localRoomId } = req.params;
  const sensors = await sensorService.getSensorsByLocalRoom(localRoomId);

  res.json({
    success: true,
    data: sensors,
    count: sensors.length
  });
});

/**
 * GET /api/v1/sensors/:sensorId
 * Get a single sensor by ID
 */
exports.getSensorById = asyncHandler(async (req, res) => {
  const { sensorId } = req.params;
  const sensor = await sensorService.getSensorById(sensorId);

  res.json({
    success: true,
    data: sensor
  });
});

/**
 * PUT /api/v1/sensors/bulk-update
 * Bulk update threshold and peak values for multiple sensors
 * 
 * Request body:
 * {
 *   "sensors": [
 *     {
 *       "sensorId": "sensor_id_1",
 *       "threshold_min": 10,
 *       "threshold_max": 30
 *     },
 *     {
 *       "sensorId": "sensor_id_2",
 *       "threshold_min": 5,
 *       "threshold_max": 25
 *     }
 *   ]
 * }
 */
exports.bulkUpdateThresholds = asyncHandler(async (req, res) => {
  const { sensors } = req.body;

  if (!sensors || !Array.isArray(sensors) || sensors.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'sensors array is required and must not be empty'
    });
  }

  const result = await sensorService.bulkUpdateThresholds(sensors);

  res.json({
    success: true,
    message: `Successfully updated ${result.updated} sensor(s)`,
    data: result
  });
});

