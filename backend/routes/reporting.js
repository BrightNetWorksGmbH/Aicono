const express = require('express');
const router = express.Router();
const reportingController = require('../controllers/reportingController');
const { requireAuth } = require('../middleware/auth');

// Setup reporting for multiple buildings
router.post('/setup', requireAuth, reportingController.handleReportSetup);

module.exports = router;
