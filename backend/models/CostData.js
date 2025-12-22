const mongoose = require('mongoose');

const costDataSchema = new mongoose.Schema({
  sensor_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Sensor',
    required: true,
  },
  tariff_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tariff',
    required: true,
  },
  timestamp_period: {
    type: Date,
  },
  cost_value: {
    type: mongoose.Schema.Types.Decimal128,
    required: true,
  },
}, {
  timestamps: true,
});

// Indexes
costDataSchema.index({ sensor_id: 1, timestamp_period: -1 });
costDataSchema.index({ tariff_id: 1 });

module.exports = mongoose.model('CostData', costDataSchema);

