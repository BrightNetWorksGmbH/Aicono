const mongoose = require('mongoose');

// Branding schema (similar to Verse branding)
const brandingSchema = new mongoose.Schema({
  logo_url: { type: String, default: null },
  primary_color: { type: String, default: '#3B82F6' },
  color_name: { type: String, default: 'Primary Blue' },
}, { _id: false });

const bryteSwitchSettingsSchema = new mongoose.Schema({
  organization_name: {
    type: String,
    required: true,
    unique: true,
    trim: true,
  },
  sub_domain: {
    type: String,
    required: false, // Made optional since it's not unique anymore
    sparse: true, // Allows null for incomplete setup
    lowercase: true,
    match: [
      /^[a-z0-9.-]+$/,
      'Subdomain can only contain lowercase letters, numbers, dots, and hyphens',
    ],
  },
  branding: {
    type: brandingSchema,
    default: () => ({}),
  },
  dark_mode: {
    type: Boolean,
    default: true, // Default to dark mode
  },
  is_setup_complete: {
    type: Boolean,
    default: false,
  },
  setup_completed_at: {
    type: Date,
    default: null,
  },
  setup_completed_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  owner_email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
  },
  created_by: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: false,
  },
  is_active: {
    type: Boolean,
    default: true,
    index: true,
  },
}, {
  timestamps: true,
});

// Indexes
bryteSwitchSettingsSchema.index({ organization_name: 1 }, { unique: true });
bryteSwitchSettingsSchema.index({ sub_domain: 1 }); // Non-unique index
bryteSwitchSettingsSchema.index({ owner_email: 1 });
bryteSwitchSettingsSchema.index({ is_setup_complete: 1 });
bryteSwitchSettingsSchema.index({ created_by: 1 });

module.exports = mongoose.model('BryteSwitchSettings', bryteSwitchSettingsSchema);

