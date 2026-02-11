const User = require('../models/User');
const UserRole = require('../models/UserRole');
const { AuthorizationError } = require('../utils/errors');

/**
 * Check if user has permission to manage buildings for a BryteSwitch
 * @param {String} userId - User ID
 * @param {String} bryteswitchId - BryteSwitch ID
 * @param {Boolean} allowReadOnly - Whether to allow Read-Only users (default: false)
 * @returns {Promise<Object>} { hasAccess: Boolean, role: Object|null, isSuperadmin: Boolean }
 * @throws {AuthorizationError} If user doesn't have access
 */
async function checkBuildingPermission(userId, bryteswitchId, allowReadOnly = false) {
  const userRole = await UserRole.findOne({
    user_id: userId,
    bryteswitch_id: bryteswitchId
  }).populate('role_id');

  if (!userRole || !userRole.role_id) {
    // Check if user is superadmin
    const user = await User.findById(userId);
    if (user && user.is_superadmin) {
      return {
        hasAccess: true,
        role: null,
        isSuperadmin: true
      };
    }
    throw new AuthorizationError('You do not have access to manage buildings');
  }

  const role = userRole.role_id;

  // Check if user has Read-Only role
  if (role.name === 'Read-Only' && !allowReadOnly) {
    throw new AuthorizationError('Read-Only users cannot perform this action');
  }

  // Check manage_buildings permission
  if (!role.permissions.manage_buildings) {
    throw new AuthorizationError('You do not have permission to manage buildings');
  }

  return {
    hasAccess: true,
    role: role,
    isSuperadmin: false
  };
}

/**
 * Check if user has permission to manage BryteSwitch settings
 * @param {String} userId - User ID
 * @param {String} bryteswitchId - BryteSwitch ID
 * @returns {Promise<Object>} { hasAccess: Boolean, role: Object|null, isSuperadmin: Boolean }
 * @throws {AuthorizationError} If user doesn't have access
 */
async function checkBryteSwitchPermission(userId, bryteswitchId) {
  const userRole = await UserRole.findOne({
    user_id: userId,
    bryteswitch_id: bryteswitchId
  }).populate('role_id');

  if (!userRole || !userRole.role_id) {
    // Check if user is superadmin
    const user = await User.findById(userId);
    if (user && user.is_superadmin) {
      return {
        hasAccess: true,
        role: null,
        isSuperadmin: true
      };
    }
    throw new AuthorizationError('You do not have access to this BryteSwitch');
  }

  const role = userRole.role_id;

  // Check manage_bryteswitch permission
  if (!role.permissions.manage_bryteswitch) {
    throw new AuthorizationError('You do not have permission to manage BryteSwitch settings');
  }

  return {
    hasAccess: true,
    role: role,
    isSuperadmin: false
  };
}

module.exports = {
  checkBuildingPermission,
  checkBryteSwitchPermission
};
