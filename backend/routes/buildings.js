const express = require('express');
const router = express.Router();
const buildingController = require('../controllers/buildingController');
const { requireAuth } = require('../middleware/auth');

// Create multiple buildings for a site
router.post('/site/:siteId', requireAuth, buildingController.createBuildings);

// Get all buildings for a site
router.get('/site/:siteId', requireAuth, buildingController.getBuildingsBySite);

// Get a building by ID
router.get('/:buildingId', requireAuth, buildingController.getBuildingById);

// Update building details
router.patch('/:buildingId', requireAuth, buildingController.updateBuilding);

module.exports = router;

