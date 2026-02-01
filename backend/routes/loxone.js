const express = require('express');
const router = express.Router();
const loxoneController = require('../controllers/loxoneController');
const { requireAuth } = require('../middleware/auth');

// Connect to Loxone Miniserver for a building
router.post('/connect/:buildingId', requireAuth, loxoneController.connect);

// Disconnect from Loxone Miniserver for a building
router.delete('/disconnect/:buildingId', requireAuth, loxoneController.disconnect);

// Get connection status for a building
router.get('/status/:buildingId', requireAuth, loxoneController.getStatus);

// Get all active connections
router.get('/connections', requireAuth, loxoneController.getAllConnections);

// Get Loxone rooms for a building
router.get('/rooms/:buildingId', requireAuth, loxoneController.getLoxoneRooms);

// Aggregation endpoints
router.get('/aggregation/status', requireAuth, loxoneController.getAggregationStatus);
router.get('/aggregation/unaggregated', requireAuth, loxoneController.getUnaggregatedData);
router.post('/aggregation/trigger/15min', requireAuth, loxoneController.trigger15MinAggregation);
router.post('/aggregation/trigger/hourly', requireAuth, loxoneController.triggerHourlyAggregation);
router.post('/aggregation/trigger/daily', requireAuth, loxoneController.triggerDailyAggregation);
router.post('/aggregation/trigger/weekly', requireAuth, loxoneController.triggerWeeklyAggregation);
router.post('/aggregation/trigger/monthly', requireAuth, loxoneController.triggerMonthlyAggregation);
router.post('/aggregation/trigger/daterange', requireAuth, loxoneController.triggerDateRangeAggregation);

// Measurement query endpoints
router.get('/measurements/:sensorId', requireAuth, loxoneController.getSensorMeasurements);
router.get('/measurements/building/:buildingId', requireAuth, loxoneController.getBuildingMeasurements);
router.get('/statistics/:buildingId', requireAuth, loxoneController.getBuildingStatistics);

module.exports = router;

