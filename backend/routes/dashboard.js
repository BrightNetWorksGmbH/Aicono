const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const dashboardReportsController = require('../controllers/dashboardReportsController');
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
// Note: This endpoint has a longer timeout (60s) for building analytics generation
router.get('/buildings/:buildingId', requireAuth, (req, res, next) => {
  // Set longer timeout for building analytics (60 seconds)
  req.setTimeout(60000, () => {
    if (!res.headersSent) {
      res.status(504).json({
        success: false,
        message: 'Request timeout - building analytics took too long',
        code: 'REQUEST_TIMEOUT',
        timeout: 60000
      });
    }
  });
  next();
}, dashboardController.getBuildingDetails);

// Get floor details with nested data
router.get('/floors/:floorId', requireAuth, dashboardController.getFloorDetails);

// Get room details with nested data
router.get('/rooms/:roomId', requireAuth, dashboardController.getRoomDetails);

// Get sensor details with measurement data
router.get('/sensors/:sensorId', requireAuth, dashboardController.getSensorDetails);

/**
 * Dashboard Reports API Routes
 * 
 * Provides hierarchical data retrieval for the "Your Reports" section:
 * Sites → Buildings → Reports
 */

// Get sites with reports
router.get('/reports/sites', requireAuth, dashboardReportsController.getSites);

// Get buildings in a site
router.get('/reports/sites/:siteId/buildings', requireAuth, dashboardReportsController.getBuildings);

// Get reports for a building
router.get('/reports/buildings/:buildingId/reports', requireAuth, dashboardReportsController.getReports);

// Get report content (current period) - requires building_id query param
// Note: This endpoint has a longer timeout (60s) set in the controller via req.setTimeout
router.get('/reports/view/:reportId', requireAuth, (req, res, next) => {
  // Set longer timeout for report generation (60 seconds)
  req.setTimeout(60000, () => {
    if (!res.headersSent) {
      res.status(504).json({
        success: false,
        message: 'Request timeout - report generation took too long',
        code: 'REQUEST_TIMEOUT',
        timeout: 60000
      });
    }
  });
  next();
}, dashboardReportsController.getReportContent);

module.exports = router;

