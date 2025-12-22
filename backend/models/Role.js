const mongoose = require('mongoose');

// Define the permissions schema for structured permissions
const permissionsSchema = new mongoose.Schema({
  manage_users: { type: Boolean, default: false },
  invite_users: { type: Boolean, default: false },
  manage_roles: { type: Boolean, default: false },
  manage_buildings: { type: Boolean, default: false },
  manage_sites: { type: Boolean, default: false },
  manage_bryteswitch: { type: Boolean, default: false },
  view_reports: { type: Boolean, default: false },
  manage_alarms: { type: Boolean, default: false },
  manage_loxone: { type: Boolean, default: false },
}, { _id: false });

const roleSchema = new mongoose.Schema({
  bryteswitch_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BryteSwitchSettings',
    required: true,
    index: true
  },
  name: {
    type: String,
    required: true,
    enum: ['Owner', 'Admin', 'Expert', 'Read-Only'],
    trim: true
  },
  permissions: {
    type: permissionsSchema,
    default: {
      manage_users: false,
      invite_users: false,
      manage_roles: false,
      manage_buildings: false,
      manage_sites: false,
      manage_bryteswitch: false,
      view_reports: false,
      manage_alarms: false,
      manage_loxone: false,
    }
  },
  permissions_json: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
    // Legacy field for backward compatibility
  },
  description: {
    type: String,
    default: '',
    maxlength: 500
  },
  is_system_role: {
    type: Boolean,
    default: false
  },
}, {
  timestamps: true,
});

// Compound unique index to prevent duplicate role names per bryteswitch
roleSchema.index({ bryteswitch_id: 1, name: 1 }, { unique: true });

// Static method to get default permissions for system roles
roleSchema.statics.getDefaultPermissions = function(roleName) {
  const defaultPermissions = {
    Owner: {
      manage_users: true,
      invite_users: true,
      manage_roles: true,
      manage_buildings: true,
      manage_sites: true,
      manage_bryteswitch: true,
      view_reports: true,
      manage_alarms: true,
      manage_loxone: true,
    },
    Admin: {
      manage_users: true,
      invite_users: true,
      manage_roles: false,
      manage_buildings: true,
      manage_sites: true,
      manage_bryteswitch: false,
      view_reports: true,
      manage_alarms: true,
      manage_loxone: true,
    },
    Expert: {
      manage_users: false,
      invite_users: false,
      manage_roles: false,
      manage_buildings: false,
      manage_sites: false,
      manage_bryteswitch: false,
      view_reports: true,
      manage_alarms: false,
      manage_loxone: false,
    },
    'Read-Only': {
      manage_users: false,
      invite_users: false,
      manage_roles: false,
      manage_buildings: false,
      manage_sites: false,
      manage_bryteswitch: false,
      view_reports: true,
      manage_alarms: false,
      manage_loxone: false,
    }
  };
  
  return defaultPermissions[roleName] || defaultPermissions.Expert;
};

module.exports = mongoose.model('Role', roleSchema);

