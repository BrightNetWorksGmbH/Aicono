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

module.exports = router;

