const mongoose = require('mongoose');

const buildingContactSchema = new mongoose.Schema({
  name: {
    type: String,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  phone: {
    type: String,
  },
}, {
  timestamps: true,
});

// Indexes
buildingContactSchema.index({ email: 1 });

module.exports = mongoose.model('BuildingContact', buildingContactSchema);
