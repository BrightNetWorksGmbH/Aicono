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
  },
}, {
  timestamps: true,
});

// Indexes
alarmLogSchema.index({ sensor_id: 1, timestamp_start: -1 });
alarmLogSchema.index({ alarm_rule_id: 1 });
alarmLogSchema.index({ status: 1 });

module.exports = mongoose.model('AlarmLog', alarmLogSchema);

