const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema({
  user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  timestamp: {
    type: Date,
    required: true,
    default: Date.now,
  },
  text: {
    type: String,
    required: true,
  },
  // Polymorphic FKs - only one should be set
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
  },
  sensor_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sensor',
  },
  alarm_log_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'AlarmLog',
  },
}, {
  timestamps: true,
});

// Indexes
commentSchema.index({ user_id: 1 });
commentSchema.index({ building_id: 1 });
commentSchema.index({ sensor_id: 1 });
commentSchema.index({ alarm_log_id: 1 });
commentSchema.index({ timestamp: -1 });

module.exports = mongoose.model('Comment', commentSchema);

