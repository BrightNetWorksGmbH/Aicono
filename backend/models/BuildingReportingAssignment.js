const mongoose = require('mongoose');

const buildingReportingAssignmentSchema = new mongoose.Schema({
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true,
  },
  recipient_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ReportingRecipient',
    required: true,
  },
  reporting_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Reporting',
    required: true,
  },
}, {
  timestamps: true,
});

// Indexes
buildingReportingAssignmentSchema.index({ building_id: 1 });
buildingReportingAssignmentSchema.index({ recipient_id: 1 });
buildingReportingAssignmentSchema.index({ reporting_id: 1 });
// Unique constraint: one assignment per building+recipient+reporting combination
buildingReportingAssignmentSchema.index(
  { building_id: 1, recipient_id: 1, reporting_id: 1 },
  { unique: true }
);

module.exports = mongoose.model('BuildingReportingAssignment', buildingReportingAssignmentSchema);
