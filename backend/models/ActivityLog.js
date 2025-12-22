const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema({
  bryteswitch_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BryteSwitchSettings',
    required: true,
  },
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  action: {
    type: String,
    required: true,
    // e.g., 'login', 'create', 'update', 'delete', 'report_export'
  },
  resource_type: {
    type: String,
    required: true,
    // e.g., 'building', 'user', 'alarm', 'login'
  },
  resource_id: {
    type: mongoose.Schema.Types.Mixed,
    // ID of the affected entity (Polymorphic - can be ObjectId, Number, or String)
  },
  timestamp: {
    type: Date,
    required: true,
    default: Date.now,
  },
  details: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
    // Stores specific context or payload of the action
  },
  ip_address: {
    type: String,
  },
  severity: {
    type: String,
    enum: ['low', 'medium', 'critical'],
  },
}, {
  timestamps: true,
});

// Indexes for efficient querying
activityLogSchema.index({ bryteswitch_id: 1, timestamp: -1 });
activityLogSchema.index({ user_id: 1, timestamp: -1 });
activityLogSchema.index({ resource_type: 1, resource_id: 1 });
activityLogSchema.index({ action: 1 });
activityLogSchema.index({ severity: 1 });

module.exports = mongoose.model('ActivityLog', activityLogSchema);

