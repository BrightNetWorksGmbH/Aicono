const bryteswitchService = require('../services/bryteswitchService');
const ActivityLog = require('../models/ActivityLog');
const { sendInvitationEmail } = require('../services/emailService');
const { asyncHandler } = require('../middleware/errorHandler');
const { validationResult } = require('express-validator');

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

