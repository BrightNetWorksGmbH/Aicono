const express = require('express');
const router = express.Router();
const dashboardReportsController = require('../controllers/dashboardReportsController');

/**
 * Public Reports API Routes
 * 
 * These endpoints are public (no auth required) and used for token-based report viewing
 */

/**
 * Timeout middleware for report endpoints (60 seconds)
 * Report generation can take longer than the default 30-second timeout
 */
const reportTimeout = 60000; // 60 seconds
router.use((req, res, next) => {
  req.setTimeout(reportTimeout, () => {
    if (!res.headersSent) {
      res.status(504).json({
        success: false,
        message: 'Request timeout - report generation took too long',
        code: 'REQUEST_TIMEOUT',
        timeout: reportTimeout
      });
    }
  });
  next();
});

// Token-based report viewing (public endpoint, no auth required)
// Used when users click "View now" from email
// GET /api/v1/reports/view?token=...
router.get('/view', dashboardReportsController.getReportContentByToken);

module.exports = router;
