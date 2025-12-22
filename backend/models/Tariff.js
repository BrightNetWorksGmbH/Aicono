const mongoose = require('mongoose');

const tariffSchema = new mongoose.Schema({
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  energy_carrier: {
    type: String,
    required: true,
  },
  rate_table_json: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
}, {
  timestamps: true,
});

// Indexes
tariffSchema.index({ building_id: 1 });
tariffSchema.index({ energy_carrier: 1 });

module.exports = mongoose.model('Tariff', tariffSchema);

