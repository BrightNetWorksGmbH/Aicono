const mongoose = require('mongoose');

const renovationProjectSchema = new mongoose.Schema({
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  estimated_cost: {
    type: mongoose.Schema.Types.Decimal128,
  },
  actual_energy_savings: {
    type: mongoose.Schema.Types.Decimal128,
    // Note: M2: Used for ROI Calculation
  },
  created_by_user_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
}, {
  timestamps: true,
});

// Indexes
renovationProjectSchema.index({ building_id: 1 });
renovationProjectSchema.index({ created_by_user_id: 1 });

module.exports = mongoose.model('RenovationProject', renovationProjectSchema);

