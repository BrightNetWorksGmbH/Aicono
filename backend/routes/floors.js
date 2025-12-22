const express = require('express');
const router = express.Router();
const floorController = require('../controllers/floorController');
const { requireAuth } = require('../middleware/auth');

// Create a floor with rooms for a building
router.post('/building/:buildingId', requireAuth, floorController.createFloorWithRooms);

// Get all floors for a building
router.get('/building/:buildingId', requireAuth, floorController.getFloorsByBuilding);

// Get a floor by ID
router.get('/:floorId', requireAuth, floorController.getFloorById);

// Update a floor
router.patch('/:floorId', requireAuth, floorController.updateFloor);

// Add a room to a floor
router.post('/:floorId/rooms', requireAuth, floorController.addRoomToFloor);

// Update a local room
router.patch('/rooms/:roomId', requireAuth, floorController.updateLocalRoom);

// Delete a local room
router.delete('/rooms/:roomId', requireAuth, floorController.deleteLocalRoom);

module.exports = router;

