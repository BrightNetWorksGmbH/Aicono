const mongoose = require('mongoose');

const reportingRecipientSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  name: {
    type: String,
  },
  buildings: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
  }],
  is_active: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

// Indexes
reportingRecipientSchema.index({ email: 1 });
reportingRecipientSchema.index({ buildings: 1 });
reportingRecipientSchema.index({ is_active: 1 });

module.exports = mongoose.model('ReportingRecipient', reportingRecipientSchema);

