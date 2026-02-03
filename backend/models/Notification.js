const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  // Who receives this notification
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  
  // Context - which switch this notification belongs to
  bryteswitch_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BryteSwitchSettings',
    required: true,
    index: true
  },
  
  // Notification type
  type: {
    type: String,
    required: true,
    enum: [
      // Invitation-related notifications
      'invitation_pending',
      'invitation_received',
      'invitation_accepted',
      'invitation_expired',
      
      // User/Switch-related notifications
      'user_joined_switch',
      
      // System notifications
      'system_notification'
    ],
    index: true
  },
  
  // Priority level
  priority: {
    type: String,
    enum: ['low', 'medium', 'high', 'urgent'],
    default: 'medium',
    index: true
  },
  
  // Notification content
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  
  message: {
    type: String,
    required: true,
    trim: true,
    maxlength: 500
  },
  
  // Status tracking
  status: {
    type: String,
    enum: ['unread', 'read', 'dismissed'],
    default: 'unread',
    index: true
  },
  
  read_at: {
    type: Date,
    default: null
  },
  
  // Action/navigation
  action_url: {
    type: String,
    trim: true,
    default: null
  },
  
  action_required: {
    type: Boolean,
    default: false
  },
  
  // Related resource tracking
  related_resource_type: {
    type: String,
    enum: ['invitation', 'user', 'switch', null],
    default: null
  },
  
  related_resource_id: {
    type: mongoose.Schema.Types.ObjectId,
    default: null,
    index: true
  },
  
  // Who triggered this notification (optional)
  created_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  
  // Auto-expire notifications after certain time
  expires_at: {
    type: Date,
    default: function() {
      // Default: expire after 90 days
      const date = new Date();
      date.setDate(date.getDate() + 90);
      return date;
    },
    index: true
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

// Compound indexes for efficient queries
notificationSchema.index({ user_id: 1, status: 1, created_at: -1 });
notificationSchema.index({ bryteswitch_id: 1, type: 1, created_at: -1 });
notificationSchema.index({ user_id: 1, bryteswitch_id: 1, status: 1 });
notificationSchema.index({ related_resource_type: 1, related_resource_id: 1 });
notificationSchema.index({ expires_at: 1, status: 1 }); // For cleanup job

// Virtual for checking if notification is expired
notificationSchema.virtual('is_expired').get(function() {
  return this.expires_at && this.expires_at < new Date();
});

// Method to mark as read
notificationSchema.methods.markAsRead = async function() {
  if (this.status === 'unread') {
    this.status = 'read';
    this.read_at = new Date();
    return await this.save();
  }
  return this;
};

// Method to mark as dismissed
notificationSchema.methods.markAsDismissed = async function() {
  this.status = 'dismissed';
  return await this.save();
};

// Static method to get unread count for a user
notificationSchema.statics.getUnreadCount = async function(userId, bryteswitchId = null) {
  const query = {
    user_id: userId,
    status: 'unread',
    expires_at: { $gt: new Date() } // Only count non-expired notifications
  };
  
  if (bryteswitchId) {
    query.bryteswitch_id = bryteswitchId;
  }
  
  return await this.countDocuments(query);
};

// Static method to mark all as read for a user
notificationSchema.statics.markAllAsRead = async function(userId, bryteswitchId = null) {
  const query = {
    user_id: userId,
    status: 'unread'
  };
  
  if (bryteswitchId) {
    query.bryteswitch_id = bryteswitchId;
  }
  
  return await this.updateMany(
    query,
    { 
      $set: { 
        status: 'read',
        read_at: new Date()
      }
    }
  );
};

// Static method to cleanup expired notifications
notificationSchema.statics.cleanupExpired = async function() {
  const result = await this.deleteMany({
    expires_at: { $lt: new Date() },
    status: { $in: ['read', 'dismissed'] } // Only delete read/dismissed expired ones
  });
  
  console.log(`Cleaned up ${result.deletedCount} expired notifications`);
  return result;
};

// Ensure virtuals are included when converting to JSON
notificationSchema.set('toJSON', { virtuals: true });
notificationSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Notification', notificationSchema);
