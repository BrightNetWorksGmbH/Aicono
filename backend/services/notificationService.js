const Notification = require('../models/Notification');
const UserRole = require('../models/UserRole');
const User = require('../models/User');

/**
 * NotificationService - Centralized service for creating and managing notifications
 * 
 * This service handles:
 * - Creating notifications with role-based routing
 * - Finding recipients based on permissions
 * - Building notification content
 * - Batch notification creation
 */
class NotificationService {
  
  /**
   * Create a single notification
   * @param {Object} data - Notification data
   * @returns {Promise<Notification>}
   */
  static async create(data) {
    const notification = new Notification(data);
    await notification.save();
    return notification;
  }

  /**
   * Create multiple notifications (batch)
   * @param {Array} notificationDataArray - Array of notification data objects
   * @returns {Promise<Array>}
   */
  static async createBatch(notificationDataArray) {
    return await Notification.insertMany(notificationDataArray);
  }

  /**
   * Get users with specific permission in a switch
   * @param {ObjectId} bryteswitchId 
   * @param {String} permission - Permission name (e.g., 'invite_users')
   * @returns {Promise<Array>} Array of user IDs
   */
  static async getUsersWithPermission(bryteswitchId, permission) {
    // Find all active user roles in this switch
    const userRoles = await UserRole.find({
      bryteswitch_id: bryteswitchId
    }).populate('role_id');

    const userIds = [];
    
    for (const userRole of userRoles) {
      if (userRole.role_id && userRole.role_id.permissions) {
        // Check if this role has the required permission
        if (userRole.role_id.permissions[permission] === true) {
          userIds.push(userRole.user_id);
        }
      }
    }

    // Also check for superadmins
    const superAdmins = await User.find({
      is_superadmin: true,
      is_active: true,
      joined_switch: bryteswitchId
    }).select('_id');

    superAdmins.forEach(admin => {
      if (!userIds.some(id => id.equals(admin._id))) {
        userIds.push(admin._id);
      }
    });

    return userIds;
  }

  /**
   * Get all admin users in a switch (Owner and Admin roles)
   * @param {ObjectId} bryteswitchId 
   * @returns {Promise<Array>} Array of user IDs
   */
  static async getAdminUsers(bryteswitchId) {
    const userRoles = await UserRole.find({
      bryteswitch_id: bryteswitchId
    }).populate('role_id');

    const adminUserIds = [];
    
    for (const userRole of userRoles) {
      if (userRole.role_id && (userRole.role_id.name === 'Owner' || userRole.role_id.name === 'Admin')) {
        adminUserIds.push(userRole.user_id);
      }
    }

    // Also include superadmins
    const superAdmins = await User.find({
      is_superadmin: true,
      is_active: true,
      joined_switch: bryteswitchId
    }).select('_id');

    superAdmins.forEach(admin => {
      if (!adminUserIds.some(id => id.equals(admin._id))) {
        adminUserIds.push(admin._id);
      }
    });

    return adminUserIds;
  }

  /**
   * Create notification when invitation is sent
   * @param {Object} invitation - Invitation document
   * @param {ObjectId} invitedBy - User who sent the invitation
   * @param {ObjectId} invitedUserId - User ID (if user already exists)
   */
  static async notifyInvitationSent(invitation, invitedBy, invitedUserId = null) {
    const notifications = [];

    // Get bryteswitch_id (handle both ObjectId and populated object)
    const bryteswitchId = invitation.bryteswitch_id?._id || invitation.bryteswitch_id;
    const roleName = invitation.role_id?.name || 'member';

    // 1. Notify admins about pending invitation (for tracking)
    const adminIds = await this.getAdminUsers(bryteswitchId);
    
    adminIds.forEach(adminId => {
      notifications.push({
        user_id: adminId,
        bryteswitch_id: bryteswitchId,
        type: 'invitation_pending',
        priority: 'low',
        title: 'Invitation Sent',
        message: `Invitation sent to ${invitation.recipient_email} for role ${roleName}.`,
        action_url: `/switches/${bryteswitchId}/invitations`,
        action_required: false,
        related_resource_type: 'invitation',
        related_resource_id: invitation._id,
        created_by: invitedBy
      });
    });

    // 2. If invited user already exists, notify them directly
    if (invitedUserId) {
      notifications.push({
        user_id: invitedUserId,
        bryteswitch_id: bryteswitchId,
        type: 'invitation_received',
        priority: 'high',
        title: 'You\'ve Been Invited',
        message: `You've been invited to join a switch. Please check your invitation.`,
        action_url: `/invitation/${invitation.token}`,
        action_required: true,
        related_resource_type: 'invitation',
        related_resource_id: invitation._id,
        created_by: invitedBy
      });
    }

    if (notifications.length > 0) {
      return await this.createBatch(notifications);
    }
  }

  /**
   * Create notification when user accepts invitation (during registration)
   * @param {Object} invitation - Invitation document
   * @param {ObjectId} newUserId - Newly registered user ID
   */
  static async notifyInvitationReceived(invitation, newUserId) {
    return await this.create({
      user_id: newUserId,
      bryteswitch_id: invitation.bryteswitch_id,
      type: 'invitation_received',
      priority: 'high',
      title: 'Welcome! Complete Your Setup',
      message: `You've accepted the invitation. Complete your switch setup to get started.`,
      action_url: `/switches/${invitation.bryteswitch_id}/join`,
      action_required: true,
      related_resource_type: 'invitation',
      related_resource_id: invitation._id,
      created_by: invitation.invited_by_user_id
    });
  }

  /**
   * Create notification when user joins switch (after accepting invitation)
   * @param {ObjectId} bryteswitchId 
   * @param {ObjectId} userId - User who joined
   * @param {String} userName - User's full name
   */
  static async notifyUserJoinedSwitch(bryteswitchId, userId, userName) {
    // Notify all admins that a new user has joined
    const adminIds = await this.getAdminUsers(bryteswitchId);

    if (adminIds.length === 0) {
      console.warn('No admins found for switch:', bryteswitchId);
      return;
    }

    const notifications = adminIds.map(adminId => ({
      user_id: adminId,
      bryteswitch_id: bryteswitchId,
      type: 'user_joined_switch',
      priority: 'medium',
      title: 'New User Joined',
      message: `${userName} has joined the switch.`,
      action_url: `/switches/${bryteswitchId}/users`,
      action_required: false,
      related_resource_type: 'user',
      related_resource_id: userId,
      created_by: userId
    }));

    return await this.createBatch(notifications);
  }

  /**
   * Create notification when invitation expires
   * @param {Object} invitation - Invitation document
   * @param {ObjectId} invitedUserId - User ID (if user exists)
   */
  static async notifyInvitationExpired(invitation, invitedUserId) {
    if (!invitedUserId) {
      return; // Can't notify if user doesn't exist
    }

    return await this.create({
      user_id: invitedUserId,
      bryteswitch_id: invitation.bryteswitch_id,
      type: 'invitation_expired',
      priority: 'low',
      title: 'Invitation Expired',
      message: `Your invitation to join the switch has expired. Please request a new invitation.`,
      action_url: null,
      action_required: false,
      related_resource_type: 'invitation',
      related_resource_id: invitation._id,
      created_by: null
    });
  }

  /**
   * Batch dismiss multiple notifications
   * @param {ObjectId} userId - User ID (for security validation)
   * @param {Array} notificationIds - Array of notification IDs to dismiss
   * @returns {Promise<Object>} Result with count of dismissed notifications
   */
  static async batchDismissNotifications(userId, notificationIds) {
    if (!Array.isArray(notificationIds) || notificationIds.length === 0) {
      throw new Error('notificationIds must be a non-empty array');
    }

    // Update all notifications that belong to this user and are in the ID list
    const result = await Notification.updateMany(
      {
        _id: { $in: notificationIds },
        user_id: userId // Security: only dismiss user's own notifications
      },
      {
        $set: { status: 'dismissed' }
      }
    );

    return {
      success: true,
      dismissedCount: result.modifiedCount,
      requestedCount: notificationIds.length
    };
  }

  /**
   * Get notifications for a user with filtering
   * @param {ObjectId} userId 
   * @param {Object} filters - Filter options (bryteswitch_id, status, type, priority, include_dismissed, limit, skip)
   * @returns {Promise<Object>} Notifications and metadata
   */
  static async getUserNotifications(userId, filters = {}) {
    const {
      bryteswitch_id,
      status,
      type,
      priority,
      include_dismissed = false, // By default, exclude dismissed notifications
      limit = 20,
      skip = 0
    } = filters;

    // Build query
    const query = {
      user_id: userId,
      expires_at: { $gt: new Date() } // Only non-expired notifications
    };

    if (bryteswitch_id) query.bryteswitch_id = bryteswitch_id;
    
    // Handle status filtering
    if (status) {
      // If explicit status is provided, use it
      query.status = status;
    } else if (!include_dismissed) {
      // By default, exclude dismissed notifications
      query.status = { $in: ['unread', 'read'] };
    }
    // If include_dismissed is true and no status specified, show all statuses
    
    if (type) query.type = type;
    if (priority) query.priority = priority;

    // Get notifications
    const notifications = await Notification.find(query)
      .populate('created_by', 'first_name last_name email')
      .populate('bryteswitch_id', 'organization_name sub_domain')
      .sort({ created_at: -1 })
      .skip(skip)
      .limit(limit);

    // Get total count
    const total = await Notification.countDocuments(query);

    // Get unread count
    const unreadCount = await Notification.getUnreadCount(userId, bryteswitch_id);

    return {
      notifications,
      pagination: {
        total,
        limit,
        skip,
        hasMore: skip + limit < total
      },
      unreadCount
    };
  }
}

module.exports = NotificationService;
