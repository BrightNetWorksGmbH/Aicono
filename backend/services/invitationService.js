const Invitation = require('../models/Invitation');
const Role = require('../models/Role');
const User = require('../models/User');
const UserRole = require('../models/UserRole');
const BryteSwitchSettings = require('../models/BryteSwitchSettings');
const { sendInvitationEmail } = require('./emailService');
const crypto = require('crypto');

/**
 * Check if a user is already a member of a BryteSwitch
 * @param {string} email - User email
 * @param {ObjectId} bryteswitchId - BryteSwitch ID
 * @returns {Promise<Object>} Membership status
 */
async function checkUserMembership(email, bryteswitchId) {
  const user = await User.findOne({ email: email.toLowerCase() });
  
  if (!user) {
    return { exists: false, isMember: false };
  }

  // Check UserRole for active roles
  const activeUserRole = await UserRole.findOne({
    user_id: user._id,
    bryteswitch_id: bryteswitchId,
  });

  return {
    exists: true,
    user_id: user._id,
    isMember: !!activeUserRole,
    hasActiveRole: !!activeUserRole,
    role_id: activeUserRole?.role_id,
  };
}

/**
 * Check if user has permission to invite users to a BryteSwitch
 * @param {ObjectId} userId - User ID
 * @param {ObjectId} bryteswitchId - BryteSwitch ID
 * @returns {Promise<boolean>} True if user has permission
 */
async function hasInvitePermission(userId, bryteswitchId) {
  const user = await User.findById(userId);
  
  // Superadmins can always invite
  if (user && user.is_superadmin) {
    return true;
  }

  // Check if user has a role in this BryteSwitch with invite_users permission
  const userRole = await UserRole.findOne({
    user_id: userId,
    bryteswitch_id: bryteswitchId,
  }).populate('role_id');

  if (!userRole || !userRole.role_id) {
    return false;
  }

  const role = userRole.role_id;
  // Check permissions field first, fallback to permissions_json for backward compatibility
  const permissions = role.permissions || role.permissions_json || {};
  
  // Owner and Admin roles should have invite_users or manage_users permission
  return permissions.invite_users === true || permissions.manage_users === true;
}

/**
 * Create a new invitation
 * @param {Object} data - Invitation data
 * @param {ObjectId} data.bryteswitch_id - BryteSwitch ID
 * @param {ObjectId} data.role_id - Role ID
 * @param {string} data.recipient_email - Recipient email
 * @param {string} data.first_name - First name (optional)
 * @param {string} data.last_name - Last name (optional)
 * @param {string} data.position - Position (optional)
 * @param {ObjectId} data.invited_by_user_id - User ID of inviter
 * @param {number} data.expires_in_days - Expiration in days (default: 7)
 * @returns {Promise<Object>} Created invitation
 */
async function createInvitation(data) {
  const {
    bryteswitch_id,
    role_id,
    recipient_email,
    first_name,
    last_name,
    position,
    invited_by_user_id,
    expires_in_days = 7,
  } = data;

  // Validate BryteSwitch exists
  const bryteSwitch = await BryteSwitchSettings.findById(bryteswitch_id);
  if (!bryteSwitch) {
    throw new Error('BryteSwitch not found');
  }

  // Validate role exists and belongs to the same BryteSwitch
  const role = await Role.findOne({ _id: role_id, bryteswitch_id });
  if (!role) {
    throw new Error('Invalid role for the specified BryteSwitch');
  }

  // Check if user already exists and is part of this BryteSwitch
  const membershipStatus = await checkUserMembership(recipient_email, bryteswitch_id);
  
  if (membershipStatus.exists && membershipStatus.isMember) {
    throw new Error('User is already a member of this BryteSwitch');
  }

  // Check if there's already a pending invitation for this email and BryteSwitch
  const existingInvitation = await Invitation.findOne({
    recipient_email: recipient_email.toLowerCase(),
    bryteswitch_id: bryteswitch_id,
    status: 'pending',
    expires_at: { $gt: new Date() }, // Not expired
  });

  if (existingInvitation) {
    throw new Error('There is already a pending invitation for this email to this BryteSwitch');
  }

  // Generate unique token
  const token = crypto.randomUUID();
  const now = new Date();
  const expires_at = new Date(now.getTime() + expires_in_days * 24 * 60 * 60 * 1000);

  // Create invitation
  const invitation = new Invitation({
    bryteswitch_id,
    role_id,
    recipient_email: recipient_email.toLowerCase(),
    token,
    invited_by_user_id,
    status: 'pending',
    expires_at,
    first_name: first_name || '',
    last_name: last_name || '',
    position: position || '',
  });

  await invitation.save();

  // Send invitation email (non-blocking)
  try {
    await sendInvitationEmail({
      to: invitation.recipient_email,
      organizationName: bryteSwitch.organization_name,
      roleName: role.name,
      token: invitation.token,
      subdomain: bryteSwitch.sub_domain,
      firstName: first_name,
      lastName: last_name,
    });
  } catch (emailError) {
    console.error('Failed to send invitation email:', emailError);
    // Don't fail the request if email fails
  }

  return invitation;
}

/**
 * Get invitation by token
 * @param {string} token - Invitation token
 * @returns {Promise<Object>} Invitation object
 */
async function getInvitationByToken(token) {
  const invitation = await Invitation.findOne({ token })
    .populate('role_id', 'name description permissions permissions_json')
    .populate('bryteswitch_id', 'organization_name sub_domain is_setup_complete')
    .populate('invited_by_user_id', 'first_name last_name email');

  if (!invitation) {
    throw new Error('Invitation not found');
  }

  return invitation;
}

/**
 * Get invitation by ID
 * @param {ObjectId} invitationId - Invitation ID
 * @returns {Promise<Object>} Invitation object
 */
async function getInvitationById(invitationId) {
  const invitation = await Invitation.findById(invitationId)
    .populate('role_id', 'name description permissions permissions_json')
    .populate('bryteswitch_id', 'organization_name sub_domain is_setup_complete')
    .populate('invited_by_user_id', 'first_name last_name email');

  if (!invitation) {
    throw new Error('Invitation not found');
  }

  return invitation;
}

/**
 * Update invitation (only inviter can update)
 * @param {ObjectId} invitationId - Invitation ID
 * @param {ObjectId} userId - User ID requesting update
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} Updated invitation
 */
async function updateInvitation(invitationId, userId, updates) {
  const invitation = await Invitation.findById(invitationId);
  
  if (!invitation) {
    throw new Error('Invitation not found');
  }

  // Check if user is the inviter or superadmin
  const user = await User.findById(userId);
  const isSuperadmin = user && user.is_superadmin;
  const isInviter = invitation.invited_by_user_id.toString() === userId.toString();

  if (!isSuperadmin && !isInviter) {
    throw new Error('Only the inviter can update this invitation');
  }

  if (invitation.status === 'accepted') {
    throw new Error('Cannot update an already accepted invitation');
  }

  const ALLOWED = ['recipient_email', 'first_name', 'last_name', 'position', 'expires_at', 'role_id'];

  // If role_id is being changed, ensure it belongs to the same BryteSwitch
  if (updates.role_id && updates.role_id.toString() !== invitation.role_id.toString()) {
    const role = await Role.findOne({ 
      _id: updates.role_id, 
      bryteswitch_id: invitation.bryteswitch_id 
    });
    if (!role) {
      throw new Error('Invalid role for the specified BryteSwitch');
    }
  }

  // Apply allowed updates
  ALLOWED.forEach((key) => {
    if (updates[key] !== undefined) {
      if (key === 'recipient_email') {
        invitation[key] = String(updates[key]).toLowerCase();
      } else {
        invitation[key] = updates[key];
      }
    }
  });

  await invitation.save();
  return invitation;
}

/**
 * Delete invitation (only inviter can delete)
 * @param {ObjectId} invitationId - Invitation ID
 * @param {ObjectId} userId - User ID requesting deletion
 * @returns {Promise<void>}
 */
async function deleteInvitation(invitationId, userId) {
  const invitation = await Invitation.findById(invitationId);
  
  if (!invitation) {
    throw new Error('Invitation not found');
  }

  // Check if user is the inviter or superadmin
  const user = await User.findById(userId);
  const isSuperadmin = user && user.is_superadmin;
  const isInviter = invitation.invited_by_user_id.toString() === userId.toString();

  if (!isSuperadmin && !isInviter) {
    throw new Error('Only the inviter can delete this invitation');
  }

  if (invitation.status === 'accepted') {
    throw new Error('Cannot delete an already accepted invitation');
  }

  await invitation.deleteOne();
}

/**
 * Get pending invitations for a BryteSwitch
 * @param {ObjectId} bryteswitchId - BryteSwitch ID
 * @returns {Promise<Object>} Pending and accepted invitations
 */
async function getPendingInvitations(bryteswitchId) {
  const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId);
  if (!bryteSwitch) {
    throw new Error('BryteSwitch not found');
  }

  // Get all invitations for this BryteSwitch
  const invitations = await Invitation.find({ bryteswitch_id: bryteswitchId })
    .populate('role_id', 'name description permissions permissions_json')
    .populate('invited_by_user_id', 'first_name last_name email')
    .sort({ createdAt: -1 });

  // Separate pending and accepted invitations
  const pendingInvitations = [];
  const acceptedInvitations = [];

  for (const invitation of invitations) {
    // Check if user has joined the BryteSwitch
    const membershipStatus = await checkUserMembership(invitation.recipient_email, bryteswitchId);
    
    const invitationData = {
      _id: invitation._id,
      recipient_email: invitation.recipient_email,
      first_name: invitation.first_name,
      last_name: invitation.last_name,
      full_name: `${invitation.first_name || ''} ${invitation.last_name || ''}`.trim() || invitation.recipient_email,
      position: invitation.position,
      role: {
        _id: invitation.role_id._id,
        name: invitation.role_id.name,
        description: invitation.role_id.description,
      },
      invited_by: invitation.invited_by_user_id ? {
        _id: invitation.invited_by_user_id._id,
        name: `${invitation.invited_by_user_id.first_name} ${invitation.invited_by_user_id.last_name}`,
        email: invitation.invited_by_user_id.email,
      } : null,
      created_at: invitation.createdAt,
      expires_at: invitation.expires_at,
      status: invitation.status,
      user_exists: membershipStatus.exists,
      user_joined_switch: membershipStatus.isMember,
    };

    if (membershipStatus.isMember) {
      acceptedInvitations.push(invitationData);
    } else {
      pendingInvitations.push(invitationData);
    }
  }

  return {
    bryteSwitch: {
      _id: bryteSwitch._id,
      organization_name: bryteSwitch.organization_name,
      sub_domain: bryteSwitch.sub_domain,
    },
    pending_invitations: pendingInvitations,
    accepted_invitations: acceptedInvitations,
    summary: {
      total_invitations: invitations.length,
      pending_count: pendingInvitations.length,
      accepted_count: acceptedInvitations.length,
    },
  };
}

module.exports = {
  createInvitation,
  getInvitationByToken,
  getInvitationById,
  updateInvitation,
  deleteInvitation,
  getPendingInvitations,
  checkUserMembership,
  hasInvitePermission,
};

