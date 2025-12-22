const mongoose = require('mongoose');

const invitationSchema = new mongoose.Schema({
  bryteswitch_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BryteSwitchSettings',
    required: true,
  },
  role_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Role',
    required: true,
  },
  invited_by_user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  recipient_email: {
    type: String,
    required: true,
    lowercase: true,
  },
  token: {
    type: String,
    required: true,
    unique: true,
  },
  status: {
    type: String,
    required: true,
    enum: ['pending', 'accepted', 'expired'],
    default: 'pending',
  },
  expires_at: {
    type: Date,
  },
  // User details from invitation (populated by superadmin)
  first_name: {
    type: String,
    default: '',
  },
  last_name: {
    type: String,
    default: '',
  },
  position: {
    type: String,
    default: '',
  },
}, {
  timestamps: true,
});

// Indexes
invitationSchema.index({ token: 1 });
invitationSchema.index({ recipient_email: 1 });
invitationSchema.index({ bryteswitch_id: 1, status: 1 });
invitationSchema.index({ expires_at: 1 });

module.exports = mongoose.model('Invitation', invitationSchema);

