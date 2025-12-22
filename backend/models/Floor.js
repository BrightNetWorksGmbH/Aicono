const mongoose = require('mongoose');

const floorSchema = new mongoose.Schema({
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  floor_plan_link: {
    type: String,
  },
}, {
  timestamps: true,
});

// Indexes
floorSchema.index({ building_id: 1 });

module.exports = mongoose.model('Floor', floorSchema);

