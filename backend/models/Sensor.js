const mongoose = require('mongoose');

const sensorSchema = new mongoose.Schema({
  room_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room', // Reference to Loxone Room (not LocalRoom)
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  unit: {
    type: String,
    required: true,
  },
  loxone_control_uuid: {
    type: String,
    required: true,
    unique: true,
    // Note: M1: Loxone mapping - Control UUID from LoxAPP3.json
  },
  // Category information from Loxone for measurement type inference
  loxone_category_uuid: {
    type: String,
  },
  loxone_category_name: {
    type: String,
  },
  loxone_category_type: {
    type: String, // e.g., 'indoortemperature', 'lights', 'shading', 'media'
  },
  // User-defined thresholds for plausibility checks
  threshold_min: {
    type: Number,
    // Minimum threshold value for plausibility checks
  },
  threshold_max: {
    type: Number,
    // Maximum threshold (peak) value for plausibility checks
  },
}, {
  timestamps: true,
});

// Indexes
sensorSchema.index({ room_id: 1 });
sensorSchema.index({ loxone_control_uuid: 1 });

module.exports = mongoose.model('Sensor', sensorSchema);

