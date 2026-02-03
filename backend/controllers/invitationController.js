const invitationService = require('../services/invitationService');
const ActivityLog = require('../models/ActivityLog');
const User = require('../models/User');
const UserRole = require('../models/UserRole');
const NotificationService = require('../services/notificationService');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * @desc    Create invitation
 * @route   POST /api/v1/invitations
 * @access  Private (Superadmin, Owner, Admin with invite_users permission)
 */
const createInvitation = asyncHandler(async (req, res) => {
  const {
    bryteswitch_id,
    role_id,
    recipient_email,
    first_name,
    last_name,
    position,
    expires_in_days = 7,
  } = req.body;

  const inviterId = req.user._id;

  // Validate required fields
  if (!bryteswitch_id || !role_id || !recipient_email) {
    return res.status(400).json({
      success: false,
      message: 'bryteswitch_id, role_id, and recipient_email are required',
    });
  }

  // Check if user has permission to invite
  const hasPermission = await invitationService.hasInvitePermission(inviterId, bryteswitch_id);
  if (!hasPermission) {
    return res.status(403).json({
      success: false,
      message: 'You do not have permission to invite users to this BryteSwitch',
    });
  }

  // Check if user is already a member (for notification purposes)
  const membershipStatus = await invitationService.checkUserMembership(recipient_email, bryteswitch_id);
  
  if (membershipStatus.exists && membershipStatus.isMember) {
    return res.status(400).json({
      success: false,
      message: 'User is already a member of this BryteSwitch',
      details: {
        email: recipient_email.toLowerCase(),
        user_id: membershipStatus.user_id,
        bryteswitch_id: bryteswitch_id,
        has_active_role: membershipStatus.hasActiveRole,
        role_id: membershipStatus.role_id
      }
    });
  }

  // Create invitation with proper error handling
  let invitation;
  try {
    invitation = await invitationService.createInvitation({
      bryteswitch_id,
      role_id,
      recipient_email,
      first_name,
      last_name,
      position,
      invited_by_user_id: inviterId,
      expires_in_days,
    });
  } catch (error) {
    // Handle specific error cases
    if (error.message === 'User is already a member of this BryteSwitch') {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }
    
    if (error.message === 'There is already a pending invitation for this email to this BryteSwitch') {
      return res.status(409).json({
        success: false,
        message: error.message,
      });
    }
    
    if (error.message === 'BryteSwitch not found') {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    if (error.message === 'Invalid role for the specified BryteSwitch') {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }
    
    // For any other errors, return 500
    console.error('Error creating invitation:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error creating invitation',
      error: error.message,
    });
  }

  // Populate invitation for notifications (need role_id populated)
  const populatedInvitation = await invitationService.getInvitationById(invitation._id);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: invitation.bryteswitch_id,
      user_id: inviterId,
      action: 'create',
      resource_type: 'invitation',
      resource_id: invitation._id.toString(),
      timestamp: new Date(),
      details: {
        recipient_email: invitation.recipient_email,
        role_id: invitation.role_id.toString(),
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log invitation creation:', logError);
    // Don't fail if logging fails
  }

  // Create notifications
  try {
    const existingUser = membershipStatus.exists ? membershipStatus.user_id : null;
    await NotificationService.notifyInvitationSent(populatedInvitation, inviterId, existingUser);
  } catch (notifError) {
    console.error('Error creating invitation notifications:', notifError);
    // Don't fail the request if notification fails
  }

  res.status(201).json({
    success: true,
    message: 'Invitation created successfully',
    data: {
      invitation: {
        _id: invitation._id,
        bryteswitch_id: invitation.bryteswitch_id,
        recipient_email: invitation.recipient_email,
        role_id: invitation.role_id,
        token: invitation.token,
        invited_by_user_id: invitation.invited_by_user_id,
        status: invitation.status,
        first_name: invitation.first_name,
        last_name: invitation.last_name,
        position: invitation.position,
        expires_at: invitation.expires_at,
        created_at: invitation.createdAt,
      },
    },
  });
});

/**
 * @desc    Get invitation by token
 * @route   GET /api/v1/invitations/token/:token
 * @access  Public
 */
const getInvitationByToken = asyncHandler(async (req, res) => {
  const { token } = req.params;

  const invitation = await invitationService.getInvitationByToken(token);

  res.json({
    success: true,
    data: {
      invitation: {
        _id: invitation._id,
        bryteswitch_id: invitation.bryteswitch_id,
        recipient_email: invitation.recipient_email,
        role: invitation.role_id ? {
          _id: invitation.role_id._id,
          name: invitation.role_id.name,
          description: invitation.role_id.description,
        } : null,
        bryteswitch: invitation.bryteswitch_id ? {
          _id: invitation.bryteswitch_id._id,
          organization_name: invitation.bryteswitch_id.organization_name,
          sub_domain: invitation.bryteswitch_id.sub_domain,
          is_setup_complete: invitation.bryteswitch_id.is_setup_complete,
        } : null,
        invited_by: invitation.invited_by_user_id ? {
          _id: invitation.invited_by_user_id._id,
          name: `${invitation.invited_by_user_id.first_name} ${invitation.invited_by_user_id.last_name}`,
          email: invitation.invited_by_user_id.email,
        } : null,
        status: invitation.status,
        first_name: invitation.first_name,
        last_name: invitation.last_name,
        position: invitation.position,
        expires_at: invitation.expires_at,
        created_at: invitation.createdAt,
      },
    },
  });
});

/**
 * @desc    Get invitation by ID
 * @route   GET /api/v1/invitations/:id
 * @access  Private (Inviter, Superadmin, or member of the BryteSwitch)
 */
const getInvitationById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user._id;

  const invitation = await invitationService.getInvitationById(id);

  // Check if user has access (inviter, superadmin, or member of the BryteSwitch)
  const user = await User.findById(userId);
  const isSuperadmin = user && user.is_superadmin;
  const isInviter = invitation.invited_by_user_id._id.toString() === userId.toString();
  
  // Check if user is a member of this BryteSwitch
  const isMember = await UserRole.findOne({
    user_id: userId,
    bryteswitch_id: invitation.bryteswitch_id._id,
  });

  if (!isSuperadmin && !isInviter && !isMember) {
    return res.status(403).json({
      success: false,
      message: 'You do not have access to this invitation',
    });
  }

  res.json({
    success: true,
    data: {
      invitation: {
        _id: invitation._id,
        bryteswitch_id: invitation.bryteswitch_id,
        recipient_email: invitation.recipient_email,
        role: invitation.role_id ? {
          _id: invitation.role_id._id,
          name: invitation.role_id.name,
          description: invitation.role_id.description,
        } : null,
        bryteswitch: invitation.bryteswitch_id ? {
          _id: invitation.bryteswitch_id._id,
          organization_name: invitation.bryteswitch_id.organization_name,
          sub_domain: invitation.bryteswitch_id.sub_domain,
        } : null,
        invited_by: invitation.invited_by_user_id ? {
          _id: invitation.invited_by_user_id._id,
          name: `${invitation.invited_by_user_id.first_name} ${invitation.invited_by_user_id.last_name}`,
          email: invitation.invited_by_user_id.email,
        } : null,
        status: invitation.status,
        first_name: invitation.first_name,
        last_name: invitation.last_name,
        position: invitation.position,
        expires_at: invitation.expires_at,
        created_at: invitation.createdAt,
      },
    },
  });
});

/**
 * @desc    Update invitation
 * @route   PUT /api/v1/invitations/:id
 * @access  Private (Inviter or Superadmin)
 */
const updateInvitation = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user._id;
  const updates = req.body;

  const invitation = await invitationService.updateInvitation(id, userId, updates);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: invitation.bryteswitch_id,
      user_id: userId,
      action: 'update',
      resource_type: 'invitation',
      resource_id: invitation._id.toString(),
      timestamp: new Date(),
      details: {
        updated_fields: Object.keys(updates),
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log invitation update:', logError);
  }

  res.json({
    success: true,
    message: 'Invitation updated successfully',
    data: {
      invitation: {
        _id: invitation._id,
        bryteswitch_id: invitation.bryteswitch_id,
        recipient_email: invitation.recipient_email,
        role_id: invitation.role_id,
        status: invitation.status,
        first_name: invitation.first_name,
        last_name: invitation.last_name,
        position: invitation.position,
        expires_at: invitation.expires_at,
      },
    },
  });
});

/**
 * @desc    Delete invitation
 * @route   DELETE /api/v1/invitations/:id
 * @access  Private (Inviter or Superadmin)
 */
const deleteInvitation = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user._id;

  // Get invitation before deletion for logging
  const invitation = await invitationService.getInvitationById(id);
  
  await invitationService.deleteInvitation(id, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: invitation.bryteswitch_id._id,
      user_id: userId,
      action: 'delete',
      resource_type: 'invitation',
      resource_id: id,
      timestamp: new Date(),
      details: {
        recipient_email: invitation.recipient_email,
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log invitation deletion:', logError);
  }

  res.json({
    success: true,
    message: 'Invitation deleted successfully',
  });
});

/**
 * @desc    Get pending invitations for a BryteSwitch
 * @route   GET /api/v1/invitations/bryteswitch/:bryteswitchId
 * @access  Private (Superadmin, Owner, Admin with invite_users or manage_users permission)
 */
const getPendingInvitations = asyncHandler(async (req, res) => {
  const { bryteswitchId } = req.params;
  const userId = req.user._id;

  // Check if user has permission to view invitations
  const hasPermission = await invitationService.hasInvitePermission(userId, bryteswitchId);
  if (!hasPermission) {
    return res.status(403).json({
      success: false,
      message: 'You do not have permission to view invitations for this BryteSwitch',
    });
  }

  const result = await invitationService.getPendingInvitations(bryteswitchId);

  res.json({
    success: true,
    message: 'Invitations retrieved successfully',
    data: result,
  });
});

module.exports = {
  createInvitation,
  getInvitationByToken,
  getInvitationById,
  updateInvitation,
  deleteInvitation,
  getPendingInvitations,
};
