const express = require('express');
const router = express.Router();
const sensorController = require('../controllers/sensorController');
const { requireAuth } = require('../middleware/auth');

/**
 * Sensor Management API Routes
 * 
 * Provides endpoints for:
 * - Retrieving sensors by building or site
 * - Updating threshold and peak values for plausibility checks
 */

// Get all sensors for a building
router.get('/building/:buildingId', requireAuth, sensorController.getSensorsByBuilding);

// Get all sensors for a site (across all buildings)
router.get('/site/:siteId', requireAuth, sensorController.getSensorsBySite);

// Get all sensors for a local room (must be before /:sensorId to avoid route conflicts)
router.get('/local-room/:localRoomId', requireAuth, sensorController.getSensorsByLocalRoom);

// Get a single sensor by ID
router.get('/:sensorId', requireAuth, sensorController.getSensorById);

// Bulk update threshold and peak values for multiple sensors
router.put('/bulk-update', requireAuth, sensorController.bulkUpdateThresholds);

module.exports = router;

