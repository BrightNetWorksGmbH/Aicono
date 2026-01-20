const mongoose = require('mongoose');

const reportingSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  interval: {
    type: String,
    required: true,
    enum: ['Daily', 'Weekly', 'Monthly', 'Yearly'],
  },
  reportContents: [{
    type: String,
    enum: ['TotalConsumption', 'ConsumptionByRoom', 'PeakLoads', 'Anomalies', 'InefficientUsage'],
  }],
}, {
  timestamps: true,
});

// Indexes
reportingSchema.index({ name: 1 });
reportingSchema.index({ interval: 1 });

module.exports = mongoose.model('Reporting', reportingSchema);
