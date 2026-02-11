const BryteSwitchSettings = require('../models/BryteSwitchSettings');
const Role = require('../models/Role');
const UserRole = require('../models/UserRole');
const Invitation = require('../models/Invitation');
const User = require('../models/User');
const { AuthorizationError } = require('../utils/errors');

class BryteSwitchService {
  /**
   * Create initial BryteSwitch (superadmin only)
   * @param {Object} data - Switch creation data
   * @param {String} data.organization_name - Organization name
   * @param {String} data.owner_email - Owner email
   * @param {String} data.first_name - Owner first name
   * @param {String} data.last_name - Owner last name
   * @param {String} data.position - Owner position
   * @param {String} data.sub_domain - Subdomain (optional)
   * @param {String} superadminId - Superadmin user ID
   * @returns {Promise<Object>} Created switch and invitation
   */
  async createInitialSwitch(data, superadminId) {
    const { organization_name, owner_email, first_name, last_name, position, sub_domain } = data;

    // Check if superadmin
    const superadmin = await User.findById(superadminId);
    if (!superadmin || !superadmin.is_superadmin) {
      throw new Error('Only superadmins can create initial BryteSwitch');
    }

    // Check if organization name already exists
    const existingSwitch = await BryteSwitchSettings.findOne({ 
      organization_name: organization_name.trim() 
    });
    if (existingSwitch) {
      throw new Error('Organization name already exists. Please choose a different name.');
    }

    // Check if owner email already exists as a user (optional)
    const ownerUser = await User.findOne({ email: owner_email.toLowerCase() });

    // Create BryteSwitch
    const bryteSwitch = new BryteSwitchSettings({
      organization_name: organization_name.trim(),
      owner_email: owner_email.toLowerCase(),
      sub_domain: sub_domain ? sub_domain.trim().toLowerCase() : undefined,
      created_by: ownerUser ? ownerUser._id : null,
      is_setup_complete: false,
    });

    await bryteSwitch.save();

    // Ensure Owner role exists for this switch (idempotent)
    const ownerRole = await Role.findOneAndUpdate(
      { bryteswitch_id: bryteSwitch._id, name: 'Owner' },
      {
        $setOnInsert: {
          permissions: Role.getDefaultPermissions('Owner'),
          description: 'Full administrative access to the BryteSwitch',
          is_system_role: true
        }
      },
      { new: true, upsert: true }
    );

    // Ensure Admin role exists for this switch (idempotent)
    await Role.findOneAndUpdate(
      { bryteswitch_id: bryteSwitch._id, name: 'Admin' },
      {
        $setOnInsert: {
          permissions: Role.getDefaultPermissions('Admin'),
          description: 'Administrative access with limited permissions',
          is_system_role: true
        }
      },
      { new: true, upsert: true }
    );

    // Ensure Expert role exists for this switch (idempotent)
    await Role.findOneAndUpdate(
      { bryteswitch_id: bryteSwitch._id, name: 'Expert' },
      {
        $setOnInsert: {
          permissions: Role.getDefaultPermissions('Expert'),
          description: 'Subject matter expert with specialized access',
          is_system_role: true
        }
      },
      { new: true, upsert: true }
    );

    // Ensure Read-Only role exists for this switch (idempotent)
    await Role.findOneAndUpdate(
      { bryteswitch_id: bryteSwitch._id, name: 'Read-Only' },
      {
        $setOnInsert: {
          permissions: Role.getDefaultPermissions('Read-Only'),
          description: 'Read-only access to view reports and data',
          is_system_role: true
        }
      },
      { new: true, upsert: true }
    );

    // Generate invitation token
    // Try crypto.randomUUID first (Node 14.17+), fallback to crypto.randomBytes
    const crypto = require('crypto');
    const token = crypto.randomUUID ? crypto.randomUUID() : crypto.randomBytes(16).toString('hex');
    const now = new Date();
    const expires_at = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // 7 days

    // Create invitation for owner
    const invitation = new Invitation({
      bryteswitch_id: bryteSwitch._id,
      role_id: ownerRole._id,
      invited_by_user_id: superadminId,
      recipient_email: owner_email.toLowerCase(),
      token,
      status: 'pending',
      expires_at,
      first_name: first_name || '',
      last_name: last_name || '',
      position: position || '',
    });

    await invitation.save();

    return {
      bryteSwitch: {
        _id: bryteSwitch._id,
        organization_name: bryteSwitch.organization_name,
        owner_email: bryteSwitch.owner_email,
        sub_domain: bryteSwitch.sub_domain,
        is_setup_complete: bryteSwitch.is_setup_complete,
        created_at: bryteSwitch.createdAt,
      },
      invitation: {
        _id: invitation._id,
        token: invitation.token,
        recipient_email: invitation.recipient_email,
        expires_at: invitation.expires_at,
        role_id: ownerRole._id,
      }
    };
  }

  /**
   * Complete BryteSwitch setup (owner only)
   * @param {String} bryteswitchId - BryteSwitch ID
   * @param {Object} data - Setup completion data
   * @param {String} data.organization_name - Organization name
   * @param {String} data.sub_domain - Subdomain
   * @param {Object} data.branding - Branding settings
   * @param {Boolean} data.dark_mode - Dark mode preference
   * @param {String} ownerId - Owner user ID
   * @returns {Promise<Object>} Updated switch
   */
  async completeSwitchSetup(bryteswitchId, data, ownerId) {
    const { organization_name, sub_domain, branding, dark_mode } = data;

    // Find the switch
    const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId);
    if (!bryteSwitch) {
      throw new Error('BryteSwitch not found');
    }

    // Check if user has an invitation for this switch with Owner role
    const invitation = await Invitation.findOne({
      recipient_email: (await User.findById(ownerId)).email,
      bryteswitch_id: bryteswitchId
    }).populate('role_id');

    if (!invitation || !invitation.role_id) {
      throw new Error('No valid invitation found for this BryteSwitch');
    }

    // Check if user has Owner role
    const role = invitation.role_id;
    if (role.name !== 'Owner') {
      throw new Error('Only users with Owner role can complete BryteSwitch setup');
    }

    // Mark invitation as accepted
    if (invitation.status !== 'accepted') {
      invitation.status = 'accepted';
      await invitation.save();
    }

    // Check if setup is already complete
    if (bryteSwitch.is_setup_complete) {
      throw new Error('BryteSwitch setup is already complete');
    }

    // Check if organization name already exists (excluding current switch)
    if (organization_name) {
      const existingSwitch = await BryteSwitchSettings.findOne({
        organization_name: organization_name.trim(),
        _id: { $ne: bryteswitchId }
      });
      if (existingSwitch) {
        throw new Error('Organization name already exists. Please choose a different name.');
      }
    }

    // Update switch with provided data
    if (organization_name) {
      bryteSwitch.organization_name = organization_name.trim();
    }
    if (typeof sub_domain === 'string' && sub_domain.trim().length > 0) {
      bryteSwitch.sub_domain = sub_domain.trim().toLowerCase();
    }
    if (branding) {
      bryteSwitch.branding = {
        logo_url: branding.logo_url || bryteSwitch.branding?.logo_url || null,
        primary_color: branding.primary_color || bryteSwitch.branding?.primary_color || '#3B82F6',
        color_name: branding.color_name || bryteSwitch.branding?.color_name || 'Primary Blue'
      };
    }
    if (typeof dark_mode === 'boolean') {
      bryteSwitch.dark_mode = dark_mode;
    }

    // Mark setup as complete
    bryteSwitch.is_setup_complete = true;
    bryteSwitch.setup_completed_at = new Date();
    bryteSwitch.setup_completed_by = ownerId;

    await bryteSwitch.save();

    // Create UserRole for the owner (if not already exists)
    let userRole = await UserRole.findOne({
      user_id: ownerId,
      bryteswitch_id: bryteswitchId
    });

    if (!userRole) {
      userRole = await UserRole.create({
        user_id: ownerId,
        bryteswitch_id: bryteswitchId,
        role_id: invitation.role_id._id,
        assigned_at: new Date(),
        assigned_by_user_id: invitation.invited_by_user_id
      });
    }

    return {
      _id: bryteSwitch._id,
      organization_name: bryteSwitch.organization_name,
      sub_domain: bryteSwitch.sub_domain,
      branding: bryteSwitch.branding,
      dark_mode: bryteSwitch.dark_mode,
      is_setup_complete: bryteSwitch.is_setup_complete,
      setup_completed_at: bryteSwitch.setup_completed_at
    };
  }

  /**
   * Get BryteSwitch by ID
   * @param {String} bryteswitchId - BryteSwitch ID
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} BryteSwitch
   */
  async getBryteSwitchById(bryteswitchId, userId) {
    const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId)
      .populate('created_by', 'first_name last_name email')
      .populate('setup_completed_by', 'first_name last_name');

    if (!bryteSwitch) {
      throw new Error('BryteSwitch not found');
    }

    // Check if user has access (has UserRole for this switch)
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: bryteswitchId
    });

    if (!userRole) {
      // Check if user is superadmin
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        throw new Error('You do not have access to this BryteSwitch');
      }
    }

    return bryteSwitch;
  }

  /**
   * Update BryteSwitch
   * @param {String} bryteswitchId - BryteSwitch ID
   * @param {Object} updates - Update data
   * @param {String} userId - User ID
   * @returns {Promise<Object>} Updated switch
   */
  async updateBryteSwitch(bryteswitchId, updates, userId) {
    const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId);
    if (!bryteSwitch) {
      throw new Error('BryteSwitch not found');
    }

    // Check permissions (user must have manage_bryteswitch permission)
    // Note: Permission check is also done in controller, but we keep it here for service-level safety
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: bryteswitchId
    }).populate('role_id');

    if (!userRole || !userRole.role_id) {
      throw new AuthorizationError('You do not have access to this BryteSwitch');
    }

    const role = userRole.role_id;
    if (!role.permissions.manage_bryteswitch) {
      throw new AuthorizationError('You do not have permission to update this BryteSwitch');
    }

    // Check if organization name already exists (excluding current switch)
    if (updates.organization_name && updates.organization_name.trim() !== bryteSwitch.organization_name) {
      const existingSwitch = await BryteSwitchSettings.findOne({
        organization_name: updates.organization_name.trim(),
        _id: { $ne: bryteswitchId }
      });
      if (existingSwitch) {
        throw new Error('Organization name already exists. Please choose a different name.');
      }
    }

    // Update allowed fields
    if (updates.organization_name !== undefined) {
      bryteSwitch.organization_name = updates.organization_name.trim();
    }
    if (updates.sub_domain !== undefined) {
      bryteSwitch.sub_domain = updates.sub_domain ? updates.sub_domain.trim().toLowerCase() : undefined;
    }
    if (updates.branding !== undefined) {
      bryteSwitch.branding = {
        logo_url: updates.branding.logo_url !== undefined ? updates.branding.logo_url : bryteSwitch.branding?.logo_url || null,
        primary_color: updates.branding.primary_color || bryteSwitch.branding?.primary_color || '#3B82F6',
        color_name: updates.branding.color_name || bryteSwitch.branding?.color_name || 'Primary Blue'
      };
    }
    if (updates.dark_mode !== undefined) {
      bryteSwitch.dark_mode = updates.dark_mode;
    }

    await bryteSwitch.save();

    return bryteSwitch;
  }
}

module.exports = new BryteSwitchService();

