const bryteswitchService = require('../services/bryteswitchService');
const ActivityLog = require('../models/ActivityLog');
const { sendInvitationEmail } = require('../services/emailService');
const { asyncHandler } = require('../middleware/errorHandler');
const { validationResult } = require('express-validator');
const BryteSwitchSettings = require('../models/BryteSwitchSettings');
const User = require('../models/User');
const Invitation = require('../models/Invitation');
const UserRole = require('../models/UserRole');
const Role = require('../models/Role');
const NotificationService = require('../services/notificationService');
const { checkBryteSwitchPermission } = require('../utils/buildingPermissions');

/**
 * Create initial BryteSwitch (superadmin only)
 * POST /api/v1/bryteswitch/create-initial
 */
exports.createInitialSwitch = asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ 
      success: false,
      errors: errors.array() 
    });
  }

  const { organization_name, owner_email, first_name, last_name, position, sub_domain } = req.body;
  const superadminId = req.user._id;

  // Create switch and invitation
  const result = await bryteswitchService.createInitialSwitch(
    { organization_name, owner_email, first_name, last_name, position, sub_domain },
    superadminId
  );

  // Send invitation email (non-blocking)
  try {
    const emailResult = await sendInvitationEmail({
      to: result.invitation.recipient_email,
      organizationName: result.bryteSwitch.organization_name,
      roleName: 'Owner',
      token: result.invitation.token,
      subdomain: result.bryteSwitch.sub_domain,
      firstName: first_name,
      lastName: last_name,
    });
    
    if (!emailResult.ok) {
      console.error('Failed to send invitation email:', emailResult.error, 'Status:', emailResult.statusCode);
      // Log email failure but don't fail the request
    } else {
      console.log('Invitation email sent successfully to:', result.invitation.recipient_email);
    }
  } catch (emailError) {
    console.error('Failed to send invitation email:', emailError.message || emailError);
    // Don't fail the request if email fails
  }

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: result.bryteSwitch._id,
      user_id: superadminId,
      action: 'create',
      resource_type: 'bryteswitch',
      resource_id: result.bryteSwitch._id,
      timestamp: new Date(),
      details: {
        organization_name: result.bryteSwitch.organization_name,
        owner_email: result.bryteSwitch.owner_email,
        action: 'bryteswitch_created_by_superadmin',
        invitation_token: result.invitation.token
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail if logging fails
  }

  res.status(201).json({
    success: true,
    message: 'BryteSwitch created successfully. Invitation created for owner.',
    data: {
      bryteSwitch: result.bryteSwitch,
      invitation: result.invitation
    }
  });
});

/**
 * Complete BryteSwitch setup (owner only)
 * POST /api/v1/bryteswitch/:bryteswitchId/complete-setup
 */
exports.completeSwitchSetup = asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ 
      success: false,
      errors: errors.array() 
    });
  }

  const { bryteswitchId } = req.params;
  const { organization_name, sub_domain, branding, dark_mode } = req.body;
  const ownerId = req.user._id;

  // Complete setup
  const bryteSwitch = await bryteswitchService.completeSwitchSetup(
    bryteswitchId,
    { organization_name, sub_domain, branding, dark_mode },
    ownerId
  );

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: bryteswitchId,
      user_id: ownerId,
      action: 'setup_complete',
      resource_type: 'bryteswitch',
      resource_id: bryteswitchId,
      timestamp: new Date(),
      details: {
        organization_name: bryteSwitch.organization_name,
        sub_domain: bryteSwitch.sub_domain,
        dark_mode: bryteSwitch.dark_mode,
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
  }

  res.status(200).json({
    success: true,
    message: 'BryteSwitch setup completed successfully',
    data: bryteSwitch
  });
});

/**
 * Get BryteSwitch by ID
 * GET /api/v1/bryteswitch/:bryteswitchId
 */
exports.getBryteSwitch = asyncHandler(async (req, res) => {
  const { bryteswitchId } = req.params;
  const userId = req.user._id;

  const bryteSwitch = await bryteswitchService.getBryteSwitchById(bryteswitchId, userId);

  res.json({
    success: true,
    data: {
      _id: bryteSwitch._id,
      organization_name: bryteSwitch.organization_name,
      sub_domain: bryteSwitch.sub_domain,
      branding: bryteSwitch.branding,
      dark_mode: bryteSwitch.dark_mode,
      is_setup_complete: bryteSwitch.is_setup_complete,
      created_by: bryteSwitch.created_by,
      setup_completed_by: bryteSwitch.setup_completed_by,
      created_at: bryteSwitch.createdAt,
      updated_at: bryteSwitch.updatedAt
    }
  });
});

/**
 * Update BryteSwitch
 * PUT /api/v1/bryteswitch/:bryteswitchId
 */
exports.updateBryteSwitch = asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ 
      success: false,
      errors: errors.array() 
    });
  }

  const { bryteswitchId } = req.params;
  const updates = req.body;
  const userId = req.user._id;

  // Check if user has permission to manage BryteSwitch (Admin or Owner roles)
  await checkBryteSwitchPermission(userId, bryteswitchId);

  const bryteSwitch = await bryteswitchService.updateBryteSwitch(bryteswitchId, updates, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: bryteswitchId,
      user_id: userId,
      action: 'update',
      resource_type: 'bryteswitch',
      resource_id: bryteswitchId,
      timestamp: new Date(),
      details: {
        updated_fields: Object.keys(updates),
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
  }

  res.json({
    success: true,
    message: 'BryteSwitch updated successfully',
    data: {
      _id: bryteSwitch._id,
      organization_name: bryteSwitch.organization_name,
      sub_domain: bryteSwitch.sub_domain,
      branding: bryteSwitch.branding,
      dark_mode: bryteSwitch.dark_mode,
      is_setup_complete: bryteSwitch.is_setup_complete,
    }
  });
});

/**
 * Join existing BryteSwitch (for users who registered via invitation but didn't join yet)
 * POST /api/v1/bryteswitch/:bryteswitchId/join
 */
exports.joinSwitch = asyncHandler(async (req, res) => {
  const { bryteswitchId } = req.params;
  const userId = req.user._id;

  // Check if bryteswitch exists and is complete
  const bryteSwitch = await BryteSwitchSettings.findById(bryteswitchId);
  if (!bryteSwitch) {
    return res.status(404).json({
      success: false,
      message: 'BryteSwitch not found'
    });
  }

  if (!bryteSwitch.is_setup_complete) {
    return res.status(400).json({
      success: false,
      message: 'Cannot join BryteSwitch that is not yet set up'
    });
  }

  // Check if user already joined this switch
  const user = await User.findById(userId);
  if (!user) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }

  const alreadyJoined = user.joined_switch
    .map(s => s.toString())
    .includes(bryteswitchId.toString());

  if (alreadyJoined) {
    return res.status(400).json({
      success: false,
      message: 'User has already joined this BryteSwitch'
    });
  }

  // Check if user has an invitation for this switch
  const invitation = await Invitation.findOne({
    recipient_email: user.email,
    bryteswitch_id: bryteswitchId,
    // Note: We don't check status here because existing users need to set it to 'accepted'
  });
  console.log("invitation console",invitation)

  if (!invitation) {
    return res.status(403).json({
      success: false,
      message: 'No valid invitation found for this BryteSwitch'
    });
  }

  // Check if invitation is expired
  if (invitation.expires_at && new Date() > invitation.expires_at) {
    return res.status(400).json({
      success: false,
      message: 'Invitation has expired'
    });
  }

  // Check if UserRole already exists (shouldn't happen but safety check)
  const existingUserRole = await UserRole.findOne({
    user_id: userId,
    bryteswitch_id: bryteswitchId
  });
  console.log("user_id",userId)

  if (existingUserRole) {
    return res.status(400).json({
      success: false,
      message: 'User role already exists for this BryteSwitch'
    });
  }

  // For existing users, mark the invitation as accepted when they join
  // (New users already have this set to 'accepted' during registration)
  if (invitation.status !== 'accepted') {
    invitation.status = 'accepted';
    await invitation.save();
  }

  // Create UserRole
  await UserRole.create({
    user_id: userId,
    bryteswitch_id: bryteswitchId,
    role_id: invitation.role_id,
    assigned_at: new Date(),
    assigned_by_user_id: invitation.invited_by_user_id
  });

  // Add switch to user's joined_switch
  user.joined_switch.push(bryteswitchId);
  await user.save();

  // Log the activity
  try {
    await ActivityLog.create({
      bryteswitch_id: bryteswitchId,
      user_id: userId,
      action: 'create',
      resource_type: 'user_role',
      resource_id: invitation.role_id,
      timestamp: new Date(),
      details: {
        action: 'user_joined_switch',
        organization_name: bryteSwitch.organization_name,
        role_assigned: invitation.role_id.toString(),
        invitation_id: invitation._id.toString()
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail if logging fails
  }

  // Create notification for admins that user has joined
  const userName = `${user.first_name} ${user.last_name}`.trim() || user.email;
  
  try {
    await NotificationService.notifyUserJoinedSwitch(bryteswitchId, userId, userName);
  } catch (notifError) {
    console.error('Error creating user joined notification:', notifError);
    // Don't fail the request if notification fails
  }

  // Get role details for response
  const role = await Role.findById(invitation.role_id);

  res.status(200).json({
    success: true,
    message: 'Successfully joined BryteSwitch',
    data: {
      bryteSwitch: {
        _id: bryteSwitch._id,
        organization_name: bryteSwitch.organization_name,
        sub_domain: bryteSwitch.sub_domain,
      },
      role: {
        _id: role._id,
        name: role.name,
        description: role.description,
        permissions: role.permissions
      },
      user: {
        _id: user._id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        joined_switch: user.joined_switch
      }
    }
  });
});
