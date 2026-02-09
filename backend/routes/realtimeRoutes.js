const express = require('express');
const router = express.Router();
const realtimeController = require('../controllers/realtimeController');

/**
 * Real-time Sensor Data API Routes
 * 
 * Provides REST endpoints for WebSocket connection information
 * and subscription statistics.
 */

// Get WebSocket connection information
router.get('/test', realtimeController.getConnectionInfo);

// Get subscription statistics (requires authentication)
router.get('/subscriptions', realtimeController.getSubscriptions);

module.exports = router;
