const userService = require('../services/userService');
const ActivityLog = require('../models/ActivityLog');
const User = require('../models/User');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * Get current user profile
 * GET /api/v1/users/me
 * @access Private
 */
exports.getMyProfile = asyncHandler(async (req, res) => {
  const userId = req.user._id;

  const user = await userService.getUserProfile(userId);

  res.json({
    success: true,
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
      joined_switch: user.joined_switch,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
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
