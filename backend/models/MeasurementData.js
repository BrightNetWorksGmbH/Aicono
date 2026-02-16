const mongoose = require('mongoose');

// Measurement Data Schema - MongoDB Time Series Collection
// This matches the structure from mongodbStorage.js
const measurementDataSchema = new mongoose.Schema({
  // Time Series Fields (must be first for MongoDB Time Series)
  timestamp: {
    type: Date,
    required: true,
  },
  // Meta Field (for Time Series - must be an object/document)
  meta: {
    sensorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Sensor',
      required: true,
    },
    buildingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Building',
      required: false, // Optional - measurements are server-scoped, buildingId can be derived via sensor->room->building
    },
    measurementType: String, // e.g., 'Energy', 'Temperature', 'Water', 'Power'
    stateType: String, // e.g., 'actual', 'total', 'totalDay'
    controlType: String, // NEW: 'Meter', 'EFM', or undefined - distinguishes Meter vs EFM power readings
  },
  // Measurement Data
  value: {
    type: Number, // Changed from Decimal128 to Number for Time Series compatibility
    required: true,
  },
  unit: String,
  quality: {
    type: Number,
    default: 100,
  },
  source: {
    type: String,
    default: 'websocket',
  },
  resolution_minutes: {
    type: Number,
    default: 0, // 0 for real-time, 15 for aggregated
  },
}, {
  timestamps: false, // We use timestamp field instead
  collection: 'measurements',
});

// Indexes for efficient querying
// Note: buildingId index removed - measurements are now server-scoped and queried by sensorId
// To get building-specific data, traverse: Building -> Floor -> LocalRoom -> Room -> Sensor
measurementDataSchema.index({ 'meta.sensorId': 1, timestamp: -1 });
measurementDataSchema.index({ 'meta.sensorId': 1, resolution_minutes: 1, timestamp: -1 });
measurementDataSchema.index({ timestamp: -1 });
// Index for controlType queries (used for filtering Meter vs EFM power)
measurementDataSchema.index({ 'meta.controlType': 1, 'meta.measurementType': 1 });

// Static helper method to get collection name based on resolution
measurementDataSchema.statics.getCollectionName = function(resolution_minutes) {
  return resolution_minutes === 0 ? 'measurements_raw' : 'measurements_aggregated';
};

module.exports = mongoose.model('MeasurementData', measurementDataSchema);

