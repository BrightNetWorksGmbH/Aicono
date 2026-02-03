const express = require('express');
const router = express.Router();
const {
  listRolesBySwitch,
} = require('../controllers/roleController');
const { requireAuth } = require('../middleware/auth');

/**
 * @route   GET /api/v1/roles/bryteswitch/:bryteswitchId
 * @desc    List roles by BryteSwitch ID (excluding Owner role)
 * @access  Private
 */
router.get(
  '/bryteswitch/:bryteswitchId',
  requireAuth,
  listRolesBySwitch
);

module.exports = router;
