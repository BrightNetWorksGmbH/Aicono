const userService = require('../services/userService');
const ActivityLog = require('../models/ActivityLog');
const User = require('../models/User');
const UserRole = require('../models/UserRole');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * Get current user profile
 * GET /api/v1/users/me
 * @access Private
 */
exports.getMyProfile = asyncHandler(async (req, res) => {
  const userId = req.user._id;

  const user = await userService.getUserProfile(userId);

  // Get user's roles
  const userRoles = await UserRole.find({
    user_id: user._id,
  })
    .populate("role_id", "name permissions_json")
    .populate("bryteswitch_id", "organization_name sub_domain is_setup_complete");

  // Build user roles response
  const roles = userRoles.map((ur) => ({
    role_id: ur.role_id?._id,
    role_name: ur.role_id?.name,
    permissions: ur.role_id?.permissions_json,
    bryteswitch_id: ur.bryteswitch_id?._id,
    organization_name: ur.bryteswitch_id?.organization_name,
    sub_domain: ur.bryteswitch_id?.sub_domain,
  }));

  res.json({
    success: true,
    data: {
      user: {
        _id: user._id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        phone_number: user.phone_number,
        position: user.position,
        profile_picture_url: user.profile_picture_url,
        is_superadmin: user.is_superadmin || false,
        is_active: user.is_active,
        joined_switch: user.joined_switch,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      },
      roles
    }
  });
});

/**
 * Update current user profile
 * PUT /api/v1/users/me
 * @access Private
 */
exports.updateMyProfile = asyncHandler(async (req, res) => {
  const userId = req.user._id;
  const updateData = req.body;

  // Get user to access joined_switch for activity logging
  const userBeforeUpdate = await User.findById(userId).select('joined_switch profile_picture_url');
  if (!userBeforeUpdate) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }

  // Track old profile picture URL for deletion
  const oldProfilePictureUrl = userBeforeUpdate.profile_picture_url;

  // Update user profile
  const { user, changes } = await userService.updateUserProfile(userId, updateData);

  // Delete old profile picture if it was changed
  if (changes && changes.profile_picture_url && oldProfilePictureUrl) {
    // Delete old picture asynchronously (don't wait for it)
    // This handles both: replacing with a new picture or removing the picture
    userService.deleteOldProfilePicture(oldProfilePictureUrl).catch(err => {
      console.error('Error deleting old profile picture:', err);
    });
  }

  // Log activity for each BryteSwitch the user has joined
  if (changes && userBeforeUpdate.joined_switch && userBeforeUpdate.joined_switch.length > 0) {
    try {
      const activityLogPromises = userBeforeUpdate.joined_switch.map(bryteswitchId =>
        ActivityLog.create({
          bryteswitch_id: bryteswitchId,
          user_id: userId,
          action: 'update',
          resource_type: 'user',
          resource_id: userId,
          timestamp: new Date(),
          details: {
            changes,
            updated_fields: Object.keys(changes),
            context: 'profile_update',
            user_email: user.email,
            user_name: `${user.first_name} ${user.last_name}`.trim()
          },
          ip_address: req.ip || req.connection.remoteAddress,
          severity: 'low',
        }).catch(err => {
          console.error(`Failed to log activity for bryteswitch ${bryteswitchId}:`, err.message);
          return null;
        })
      );

      await Promise.all(activityLogPromises);
    } catch (logError) {
      console.error('Failed to log profile update activity:', logError);
      // Don't fail the request if logging fails
    }
  }

  res.json({
    success: true,
    message: 'Profile updated successfully',
    data: {
      _id: user._id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: user.phone_number,
      position: user.position,
      profile_picture_url: user.profile_picture_url,
      is_superadmin: user.is_superadmin,
      is_active: user.is_active,
      updatedAt: user.updatedAt
    }
  });
});

/**
 * Change current user password
 * PUT /api/v1/users/me/password
 * @access Private
 */
exports.changeMyPassword = asyncHandler(async (req, res) => {
  const userId = req.user._id;
  const { current_password, new_password, confirm_password } = req.body;

  // Validate request
  if (!current_password || !new_password || !confirm_password) {
    return res.status(400).json({
      success: false,
      message: 'Please provide current password, new password, and confirmation'
    });
  }

  // Check if new password and confirmation match
  if (new_password !== confirm_password) {
    return res.status(400).json({
      success: false,
      message: 'New password and confirmation do not match'
    });
  }

  // Validate new password strength
  if (new_password.length < 8) {
    return res.status(400).json({
      success: false,
      message: 'New password must be at least 8 characters long'
    });
  }

  // Find user
  const user = await User.findById(userId);
  if (!user) {
    return res.status(404).json({
      success: false,
      message: 'User not found'
    });
  }

  // Verify current password
  const isCurrentPasswordValid = await user.matchPassword(current_password);
  if (!isCurrentPasswordValid) {
    return res.status(401).json({
      success: false,
      message: 'Current password is incorrect'
    });
  }

  // Set new password (will be hashed by the model method)
  await user.setPassword(new_password);
  await user.save();

  // Log activity - Create activity log for EACH BryteSwitch the user belongs to
  try {
    const userRoles = await UserRole.find({ user_id: userId });
    
    if (userRoles && userRoles.length > 0) {
      const activityLogPromises = userRoles.map(ur =>
        ActivityLog.create({
          bryteswitch_id: ur.bryteswitch_id,
          user_id: userId,
          resource_type: 'user',
          resource_id: userId,
          action: 'update',
          timestamp: new Date(),
          details: {
            context: 'password_change',
            message: 'User changed their password',
            user_email: user.email,
            user_name: `${user.first_name} ${user.last_name}`.trim()
          },
          ip_address: req.ip || req.connection.remoteAddress,
          severity: 'low',
        }).catch(err => {
          console.error(`Failed to log password change for bryteswitch ${ur.bryteswitch_id}:`, err.message);
          // Don't fail if logging fails for a specific bryteswitch
          return null;
        })
      );
      
      await Promise.all(activityLogPromises);
    }
  } catch (logError) {
    console.error('Failed to log password change activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Password changed successfully'
  });
});
