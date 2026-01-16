const mongoose = require('mongoose');

const alarmLogSchema = new mongoose.Schema({
  sensor_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sensor',
    required: true,
  },
  alarm_rule_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'AlarmRule',
    required: true,
  },
  timestamp_start: {
    type: Date,
    required: true,
  },
  status: {
    type: String,
    required: true,
    enum: ['Open', 'Acknowledged', 'Resolved', 'Closed'],
    default: 'Open',
  },
  violatedRule: {
    type: String,
    // Describes the violated rule, e.g., "Negative Reading Detected", "Min Threshold Exceeded"
  },
  severity: {
    type: String,
    required: true,
    enum: ['High', 'Medium', 'Low'],
  },
  value: {
    type: Number,
    // The measurement value that triggered the alarm
  },
  threshold_min: {
    type: Number,
    // Minimum threshold if applicable
  },
  threshold_max: {
    type: Number,
    // Maximum threshold if applicable
  },
}, {
  timestamps: true,
});

// Indexes
alarmLogSchema.index({ sensor_id: 1, timestamp_start: -1 });
alarmLogSchema.index({ alarm_rule_id: 1 });
alarmLogSchema.index({ status: 1 });
alarmLogSchema.index({ severity: 1 });
alarmLogSchema.index({ severity: 1, status: 1 });

module.exports = mongoose.model('AlarmLog', alarmLogSchema);

