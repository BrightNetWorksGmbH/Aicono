const mongoose = require('mongoose');

const reportHistorySchema = new mongoose.Schema({
  assignment_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BuildingReportingAssignment',
    required: true,
  },
  recipient_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ReportingRecipient',
    required: true,
  },
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true,
  },
  reporting_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Reporting',
    required: true,
  },
  time_range: {
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
  },
  interval: {
    type: String,
    required: true,
    enum: ['Daily', 'Weekly', 'Monthly', 'Yearly'],
  },
  generated_at: {
    type: Date,
    default: Date.now,
  },
  sent_at: {
    type: Date,
  },
  token: {
    type: String,
    // JWT token used in email link
  },
}, {
  timestamps: true,
});

// Indexes
reportHistorySchema.index({ assignment_id: 1 });
reportHistorySchema.index({ recipient_id: 1 });
reportHistorySchema.index({ building_id: 1 });
reportHistorySchema.index({ reporting_id: 1 });
reportHistorySchema.index({ generated_at: -1 });
reportHistorySchema.index({ recipient_id: 1, generated_at: -1 });
reportHistorySchema.index({ building_id: 1, generated_at: -1 });

module.exports = mongoose.model('ReportHistory', reportHistorySchema);
