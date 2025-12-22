const mongoose = require('mongoose');

const benchmarkSchema = new mongoose.Schema({
  type_of_use: {
    type: String,
    required: true,
    unique: true,
  },
  target_eui_kwh_m2_year: {
    type: mongoose.Schema.Types.Decimal128,
    required: true,
  },
  source: {
    type: String,
  },
}, {
  timestamps: true,
});

// Indexes
benchmarkSchema.index({ type_of_use: 1 });

module.exports = mongoose.model('Benchmark', benchmarkSchema);

