const express = require('express');
const router = express.Router();
const bryteswitchController = require('../controllers/bryteswitchController');
const { requireAuth } = require('../middleware/auth');

// Create initial BryteSwitch (superadmin only)
router.post('/create-initial', requireAuth, bryteswitchController.createInitialSwitch);

// Complete BryteSwitch setup (owner only)
router.post('/:bryteswitchId/complete-setup', requireAuth, bryteswitchController.completeSwitchSetup);

// Get BryteSwitch by ID
router.get('/:bryteswitchId', requireAuth, bryteswitchController.getBryteSwitch);

// Update BryteSwitch
router.put('/:bryteswitchId', requireAuth, bryteswitchController.updateBryteSwitch);

module.exports = router;

