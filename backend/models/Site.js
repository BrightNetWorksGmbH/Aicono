const mongoose = require('mongoose');

const siteSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  address: {
    type: String,
  },
  resource_type: {
    type: String,
  },
  bryteswitch_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BryteSwitchSettings',
    required: true,
  },
}, {
  timestamps: true,
});

// Indexes
siteSchema.index({ bryteswitch_id: 1 });
siteSchema.index({ name: 1 });

module.exports = mongoose.model('Site', siteSchema);

