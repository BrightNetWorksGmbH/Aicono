const mongoose = require('mongoose');

const alarmRuleSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  sensor_type: {
    type: String,
  },
  rule_type: {
    type: String,
    required: true,
  },
}, {
  timestamps: true,
});

// Indexes
alarmRuleSchema.index({ sensor_type: 1 });
alarmRuleSchema.index({ rule_type: 1 });

module.exports = mongoose.model('AlarmRule', alarmRuleSchema);

