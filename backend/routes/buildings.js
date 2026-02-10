const express = require('express');
const router = express.Router();
const buildingController = require('../controllers/buildingController');
const { requireAuth } = require('../middleware/auth');

// Create multiple buildings for a site
router.post('/site/:siteId', requireAuth, buildingController.createBuildings);

// Get all buildings for a site
router.get('/site/:siteId', requireAuth, buildingController.getBuildingsBySite);

// Get all building contacts (with optional filtering)
// Must be before /:buildingId to avoid route conflicts
router.get('/contacts', requireAuth, buildingController.getContacts);

// Update Loxone configuration (must be before generic /:buildingId routes to avoid conflicts)
router.patch('/:buildingId/loxone-config', requireAuth, buildingController.updateLoxoneConfig);

// Get a building by ID
router.get('/:buildingId', requireAuth, buildingController.getBuildingById);

// Update building details
router.patch('/:buildingId', requireAuth, buildingController.updateBuilding);

// Delete building
router.delete('/:buildingId', requireAuth, buildingController.deleteBuilding);

module.exports = router;

