const mongoose = require('mongoose');

const userRoleSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  role_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Role',
    required: true,
  },
  bryteswitch_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BryteSwitchSettings',
    required: true,
  },
  assigned_by_user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  assigned_at: {
    type: Date,
    required: true,
    default: Date.now,
  },
}, {
  timestamps: true,
});

// Indexes
userRoleSchema.index({ user_id: 1, bryteswitch_id: 1 });
userRoleSchema.index({ role_id: 1 });
userRoleSchema.index({ bryteswitch_id: 1 });

module.exports = mongoose.model('UserRole', userRoleSchema);

