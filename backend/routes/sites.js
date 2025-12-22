const express = require('express');
const router = express.Router();
const siteController = require('../controllers/siteController');
const { requireAuth } = require('../middleware/auth');

// Create a site for a BryteSwitch
router.post('/bryteswitch/:bryteswitchId', requireAuth, siteController.createSite);

// Get all sites for a BryteSwitch
router.get('/bryteswitch/:bryteswitchId', requireAuth, siteController.getSitesByBryteSwitch);

// Get site by ID
router.get('/:siteId', requireAuth, siteController.getSiteById);

// Update site
router.patch('/:siteId', requireAuth, siteController.updateSite);

// Delete site
router.delete('/:siteId', requireAuth, siteController.deleteSite);

module.exports = router;

