const Role = require('../models/Role');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * @desc    List roles by BryteSwitch ID
 * @route   GET /api/v1/roles/bryteswitch/:bryteswitchId
 * @access  Private
 */
const listRolesBySwitch = asyncHandler(async (req, res) => {
  const { bryteswitchId } = req.params;

  // Find all roles for this switch, excluding Owner role
  const roles = await Role.find({ 
    bryteswitch_id: bryteswitchId,
    name: { $ne: 'Owner' } // Exclude Owner role
  })
    .select('_id name description permissions') // Select only needed fields
    .sort({ name: 1 }); // Sort alphabetically by name

  res.json({
    success: true,
    data: {
      roles,
      count: roles.length,
      bryteswitch_id: bryteswitchId
    }
  });
});

module.exports = {
  listRolesBySwitch,
};
