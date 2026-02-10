const Site = require('../models/Site');
const BryteSwitchSettings = require('../models/BryteSwitchSettings');
const UserRole = require('../models/UserRole');
const { NotFoundError, AuthorizationError, ConflictError, ValidationError } = require('../utils/errors');
const Building = require('../models/Building');
class SiteService {
  /**
   * Create a site for a BryteSwitch
   * @param {String} bryteswitchId - BryteSwitch ID
   * @param {Object} siteData - Site data
   * @param {String} siteData.name - Site name
   * @param {String} siteData.address - Site address (optional)
   * @param {String} siteData.resource_type - Resource type (optional)
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} Created site
   */
  async createSite(bryteswitchId, siteData, userId) {
    const { name, address, resource_type } = siteData;

    // Verify BryteSwitch exists
    const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId);
    if (!bryteSwitch) {
      throw new NotFoundError('BryteSwitch');
    }

    // Check if user has access to this BryteSwitch
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: bryteswitchId
    });

    if (!userRole) {
      // Check if user is superadmin
      const User = require('../models/User');
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        throw new AuthorizationError('You do not have access to this BryteSwitch');
      }
    }

    // Check if site with same name already exists for this BryteSwitch
    const existingSite = await Site.findOne({
      bryteswitch_id: bryteswitchId,
      name: { $regex: new RegExp(`^${name}$`, 'i') }
    });

    if (existingSite) {
      throw new ConflictError(`A site with the name "${name}" already exists in this BryteSwitch`);
    }

    // Create site
    const site = new Site({
      bryteswitch_id: bryteswitchId,
      name: name.trim(),
      address: address || null,
      resource_type: resource_type || null,
    });

    await site.save();

    return site;
  }

  /**
   * Get all sites for a BryteSwitch
   * @param {String} bryteswitchId - BryteSwitch ID
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Array>} Sites
   */
  async getSitesByBryteSwitch(bryteswitchId, userId) {
    // Verify BryteSwitch exists
    const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId);
    if (!bryteSwitch) {
      throw new NotFoundError('BryteSwitch');
    }

    // Check if user has access
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: bryteswitchId
    });

    if (!userRole) {
      const User = require('../models/User');
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        throw new AuthorizationError('You do not have access to this BryteSwitch');
      }
    }

    // Get sites
    const sites = await Site.find({ bryteswitch_id: bryteswitchId }).sort({ name: 1 });

    return sites;
  }

  /**
   * Get site by ID
   * @param {String} siteId - Site ID
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} Site
   */
  async getSiteById(siteId, userId) {
    const site = await Site.findById(siteId).populate('bryteswitch_id', 'organization_name');
    
    if (!site) {
      throw new NotFoundError('Site');
    }

    // Check if user has access to the BryteSwitch
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: site.bryteswitch_id._id
    });

    if (!userRole) {
      const User = require('../models/User');
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        throw new AuthorizationError('You do not have access to this site');
      }
    }

    return site;
  }

  /**
   * Update site
   * @param {String} siteId - Site ID
   * @param {Object} updateData - Update data
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated site
   */
  async updateSite(siteId, updateData, userId) {
    const site = await Site.findById(siteId);
    if (!site) {
      throw new NotFoundError('Site');
    }

    // Check permissions
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: site.bryteswitch_id
    }).populate('role_id');

    if (!userRole || !userRole.role_id) {
      throw new AuthorizationError('You do not have access to this site');
    }

    const role = userRole.role_id;
    
    // Check if user has Read-Only role - they cannot edit sites
    if (role.name === 'Read-Only') {
      throw new AuthorizationError('Read-Only users cannot edit sites');
    }

    if (!role.permissions.manage_sites) {
      throw new AuthorizationError('You do not have permission to update sites');
    }

    // Prevent updating bryteswitch_id
    if (updateData.bryteswitch_id !== undefined) {
      throw new ValidationError('Cannot update bryteswitch_id');
    }

    // Only allow updating name, address, and resource_type
    const allowedFields = ['name', 'address', 'resource_type'];
    const updateFields = Object.keys(updateData);
    const invalidFields = updateFields.filter(field => !allowedFields.includes(field));
    
    if (invalidFields.length > 0) {
      throw new ValidationError(`Cannot update fields: ${invalidFields.join(', ')}. Only name, address, and resource_type can be updated.`);
    }

    // Update allowed fields
    if (updateData.name !== undefined) {
      // Check for duplicate name
      const existingSite = await Site.findOne({
        bryteswitch_id: site.bryteswitch_id,
        name: { $regex: new RegExp(`^${updateData.name}$`, 'i') },
        _id: { $ne: siteId }
      });
      if (existingSite) {
        throw new ConflictError(`A site with the name "${updateData.name}" already exists`);
      }
      site.name = updateData.name.trim();
    }
    if (updateData.address !== undefined) {
      site.address = updateData.address;
    }
    if (updateData.resource_type !== undefined) {
      site.resource_type = updateData.resource_type;
    }

    await site.save();
    return site;
  }

  /**
   * Delete site
   * @param {String} siteId - Site ID
   * @param {String} userId - User ID
   * @returns {Promise<void>}
   */
  async deleteSite(siteId, userId) {
    const site = await Site.findById(siteId);
    if (!site) {
      throw new NotFoundError('Site');
    }

    // Check permissions
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: site.bryteswitch_id
    }).populate('role_id');

    if (!userRole || !userRole.role_id) {
      throw new AuthorizationError('You do not have access to this site');
    }

    const role = userRole.role_id;
    
    // Check if user has Read-Only role - they cannot delete sites
    if (role.name === 'Read-Only') {
      throw new AuthorizationError('Read-Only users cannot delete sites');
    }

    if (!role.permissions.manage_sites) {
      throw new AuthorizationError('You do not have permission to delete sites');
    }

    // Check if site has buildings - must delete all buildings first
  
    const buildingCount = await Building.countDocuments({ site_id: siteId });
    if (buildingCount > 0) {
      throw new ConflictError(`Cannot delete site with ${buildingCount} building(s). Please delete all buildings first.`);
    }

    await Site.findByIdAndDelete(siteId);
  }
}

module.exports = new SiteService();

