const User = require('../models/User');
const UserRole = require('../models/UserRole');
const Building = require('../models/Building');
const Site = require('../models/Site');
const Reporting = require('../models/Reporting');
const ReportingRecipient = require('../models/ReportingRecipient');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
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

/**
 * Check if user has permission to manage reporting (Owner, Admin, or Expert - not Read-Only)
 * @param {String} userId - User ID
 * @param {String} bryteswitchId - BryteSwitch ID
 * @returns {Promise<Object>} { hasAccess: Boolean, role: Object|null, isSuperadmin: Boolean }
 * @throws {AuthorizationError} If user doesn't have access or is Read-Only
 */
async function checkReportingPermission(userId, bryteswitchId) {
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
    throw new AuthorizationError('You do not have access to manage reporting');
  }

  const role = userRole.role_id;

  // Check if user has Read-Only role (not allowed for reporting management)
  if (role.name === 'Read-Only') {
    throw new AuthorizationError('Read-Only users cannot manage reporting');
  }

  // Allow Owner, Admin, and Expert roles
  const allowedRoles = ['Owner', 'Admin', 'Expert'];
  if (!allowedRoles.includes(role.name)) {
    throw new AuthorizationError('You do not have permission to manage reporting');
  }

  return {
    hasAccess: true,
    role: role,
    isSuperadmin: false
  };
}

/**
 * Get bryteswitch_id from a building ID
 * @param {String} buildingId - Building ID
 * @returns {Promise<String>} BryteSwitch ID
 * @throws {Error} If building or site not found
 */
async function getBryteswitchIdFromBuilding(buildingId) {
  const building = await Building.findById(buildingId).populate('site_id');
  if (!building) {
    throw new Error('Building not found');
  }

  const site = await Site.findById(building.site_id._id || building.site_id);
  if (!site) {
    throw new Error('Site not found');
  }

  return site.bryteswitch_id;
}

/**
 * Get bryteswitch_id from a reporting ID (via building assignment)
 * Tries multiple assignments in case some buildings are deleted (orphaned assignments)
 * @param {String} reportingId - Reporting ID
 * @returns {Promise<String|null>} BryteSwitch ID or null if no valid assignments found
 * @throws {Error} If reporting not found
 */
async function getBryteswitchIdFromReporting(reportingId) {
  // Verify reporting exists
  const reporting = await Reporting.findById(reportingId);
  if (!reporting) {
    throw new Error('Reporting not found');
  }

  // Get all assignments for this reporting (try multiple in case some buildings are deleted)
  const assignments = await BuildingReportingAssignment.find({
    reporting_id: reportingId
  }).populate({
    path: 'building_id',
    populate: { path: 'site_id' }
  });

  if (!assignments || assignments.length === 0) {
    // No assignments found
    return null;
  }

  // Try each assignment until we find one with a valid building and site
  for (const assignment of assignments) {
    if (!assignment.building_id) {
      // Building was deleted (orphaned assignment)
      continue;
    }

    const building = assignment.building_id;
    
    // Handle both populated and non-populated site_id
    let site = null;
    if (building.site_id) {
      if (building.site_id._id) {
        // Already populated
        site = building.site_id;
      } else {
        // Need to fetch
        site = await Site.findById(building.site_id);
      }
    }

    if (site && site.bryteswitch_id) {
      return site.bryteswitch_id;
    }
  }

  // All assignments have orphaned buildings (buildings deleted)
  return null;
}

/**
 * Check reporting permission using building ID
 * @param {String} userId - User ID
 * @param {String} buildingId - Building ID
 * @returns {Promise<Object>} Permission check result
 */
async function checkReportingPermissionByBuilding(userId, buildingId) {
  const bryteswitchId = await getBryteswitchIdFromBuilding(buildingId);
  return await checkReportingPermission(userId, bryteswitchId);
}

/**
 * Check reporting permission using reporting ID
 * Handles cases where reporting has no assignments or all buildings are deleted
 * @param {String} userId - User ID
 * @param {String} reportingId - Reporting ID
 * @returns {Promise<Object>} Permission check result
 * @throws {AuthorizationError} If user doesn't have access
 */
async function checkReportingPermissionByReporting(userId, reportingId) {
  const bryteswitchId = await getBryteswitchIdFromReporting(reportingId);
  
  // If no valid assignments found (no assignments or all buildings deleted)
  if (!bryteswitchId) {
    // Check if user has reporting permission in any bryteswitch they have access to
    const userRoles = await UserRole.find({ user_id: userId }).populate('role_id');
    
    // Check if user is superadmin
    const user = await User.findById(userId);
    if (user && user.is_superadmin) {
      return {
        hasAccess: true,
        role: null,
        isSuperadmin: true
      };
    }
    
    // Check if user has reporting permission in any bryteswitch
    const hasReportingAccess = userRoles.some(userRole => {
      if (!userRole.role_id) return false;
      const role = userRole.role_id;
      // Allow Owner, Admin, and Expert roles (not Read-Only)
      return ['Owner', 'Admin', 'Expert'].includes(role.name);
    });
    
    if (!hasReportingAccess) {
      throw new AuthorizationError('You do not have permission to manage reporting. Reporting has no valid building assignments to verify access.');
    }
    
    return {
      hasAccess: true,
      role: null,
      isSuperadmin: false
    };
  }
  
  return await checkReportingPermission(userId, bryteswitchId);
}

/**
 * Get bryteswitch_id from a recipient ID (via building assignment)
 * Tries multiple assignments in case some buildings are deleted (orphaned assignments)
 * @param {String} recipientId - Recipient ID
 * @returns {Promise<String|null>} BryteSwitch ID or null if no valid assignments found
 */
async function getBryteswitchIdFromRecipient(recipientId) {
  // Verify recipient exists
  const recipient = await ReportingRecipient.findById(recipientId);
  if (!recipient) {
    throw new Error('Recipient not found');
  }

  // Get all assignments for this recipient (try multiple in case some buildings are deleted)
  const assignments = await BuildingReportingAssignment.find({
    recipient_id: recipientId
  }).populate({
    path: 'building_id',
    populate: { path: 'site_id' }
  });

  if (!assignments || assignments.length === 0) {
    // No assignments found
    return null;
  }

  // Try each assignment until we find one with a valid building and site
  for (const assignment of assignments) {
    if (!assignment.building_id) {
      // Building was deleted (orphaned assignment)
      continue;
    }

    const building = assignment.building_id;
    
    // Handle both populated and non-populated site_id
    let site = null;
    if (building.site_id) {
      if (building.site_id._id) {
        // Already populated
        site = building.site_id;
      } else {
        // Need to fetch
        site = await Site.findById(building.site_id);
      }
    }

    if (site && site.bryteswitch_id) {
      return site.bryteswitch_id;
    }
  }

  // All assignments have orphaned buildings (buildings deleted)
  return null;
}

/**
 * Check reporting permission using recipient ID
 * @param {String} userId - User ID
 * @param {String} recipientId - Recipient ID
 * @returns {Promise<Object>} Permission check result
 * @throws {AuthorizationError} If user doesn't have access or recipient has no assignments
 */
async function checkReportingPermissionByRecipient(userId, recipientId) {
  const bryteswitchId = await getBryteswitchIdFromRecipient(recipientId);
  
  // If recipient has no assignments, check if user has reporting permission in any bryteswitch
  if (!bryteswitchId) {
    // Check if user has any reporting permission in any bryteswitch they have access to
    const userRoles = await UserRole.find({ user_id: userId }).populate('role_id');
    
    // Check if user is superadmin
    const user = await User.findById(userId);
    if (user && user.is_superadmin) {
      return {
        hasAccess: true,
        role: null,
        isSuperadmin: true
      };
    }
    
    // Check if user has reporting permission in any bryteswitch
    const hasReportingAccess = userRoles.some(userRole => {
      if (!userRole.role_id) return false;
      const role = userRole.role_id;
      // Allow Owner, Admin, and Expert roles (not Read-Only)
      return ['Owner', 'Admin', 'Expert'].includes(role.name);
    });
    
    if (!hasReportingAccess) {
      throw new AuthorizationError('You do not have permission to manage reporting. Recipient has no assignments to verify access.');
    }
    
    return {
      hasAccess: true,
      role: null,
      isSuperadmin: false
    };
  }
  
  return await checkReportingPermission(userId, bryteswitchId);
}

module.exports = {
  checkBuildingPermission,
  checkBryteSwitchPermission,
  checkReportingPermission,
  checkReportingPermissionByBuilding,
  checkReportingPermissionByReporting,
  checkReportingPermissionByRecipient,
  getBryteswitchIdFromBuilding,
  getBryteswitchIdFromReporting,
  getBryteswitchIdFromRecipient
};
