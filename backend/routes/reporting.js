const express = require('express');
const router = express.Router();
const reportingController = require('../controllers/reportingController');
const { requireAuth } = require('../middleware/auth');

// Setup reporting for multiple buildings
router.post('/setup', requireAuth, reportingController.handleReportSetup);

// Manual trigger for testing (admin only - consider adding admin check)
router.post('/trigger/:interval', requireAuth, reportingController.triggerReportGeneration);

// Get scheduler status
router.get('/scheduler/status', requireAuth, reportingController.getSchedulerStatus);

// Get all reporting recipients (with optional filtering)
router.get('/recipients', requireAuth, reportingController.getRecipients);

module.exports = router;
