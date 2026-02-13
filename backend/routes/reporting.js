const express = require('express');
const router = express.Router();
const reportingController = require('../controllers/reportingController');
const recipientController = require('../controllers/recipientController');
const { requireAuth } = require('../middleware/auth');

// Setup reporting for multiple buildings
router.post('/setup', requireAuth, reportingController.handleReportSetup);

// Manual trigger for testing (admin only - consider adding admin check)
router.post('/trigger/:interval', requireAuth, reportingController.triggerReportGeneration);

// Get scheduler status
router.get('/scheduler/status', requireAuth, reportingController.getSchedulerStatus);

// Get all reporting recipients (with optional filtering)
router.get('/recipients', requireAuth, reportingController.getRecipients);

// Get report information from token (no auth required - token provides authentication)
router.get('/token/info', reportingController.getReportInfoFromToken);

// Recipient management endpoints (must be before /:reportingId routes to avoid route conflicts)
router.delete('/recipients/:recipientId', requireAuth, recipientController.deleteRecipient);
router.patch('/recipients/:recipientId', requireAuth, recipientController.updateRecipient);

// Report management endpoints
router.delete('/:reportingId', requireAuth, reportingController.deleteReport);
router.patch('/:reportingId', requireAuth, reportingController.updateReport);
router.post('/:reportingId/recipients', requireAuth, reportingController.addRecipientToReport);
router.delete('/:reportingId/recipients/:recipientId', requireAuth, reportingController.removeRecipientFromReport);

module.exports = router;
