const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { requireAuth } = require('../middleware/auth');

/**
 * Dashboard Discovery API Routes
 * 
 * Provides hierarchical data retrieval for the dashboard with nested structures:
 * Site → Building → Floor → Room → Sensor
 * 
 * Each endpoint supports:
 * - Time range filtering (startDate, endDate, days)
 * - Resolution selection (raw, 15-min, hourly, daily, weekly, monthly)
 * - Measurement type filtering
 * - KPI calculations (Total Consumption, Peak, Base, Average Quality)
 */

// Get all sites for the authenticated user
router.get('/sites', requireAuth, dashboardController.getSites);

// Get site details with full hierarchy
router.get('/sites/:siteId', requireAuth, dashboardController.getSiteDetails);

// Get building details with nested data
router.get('/buildings/:buildingId', requireAuth, dashboardController.getBuildingDetails);

// Get floor details with nested data
router.get('/floors/:floorId', requireAuth, dashboardController.getFloorDetails);

// Get room details with nested data
router.get('/rooms/:roomId', requireAuth, dashboardController.getRoomDetails);

// Get sensor details with measurement data
router.get('/sensors/:sensorId', requireAuth, dashboardController.getSensorDetails);

module.exports = router;

