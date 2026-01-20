const mongoose = require('mongoose');

const buildingSchema = new mongoose.Schema({
  site_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Site',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  // Building Details (optional, can be updated later)
  heated_building_area: {
    type: mongoose.Schema.Types.Decimal128,
    // Note: M1: Denominator for EUI
  },
  building_size: {
    type: Number, // Square meters
  },
  num_floors: {
    type: Number,
  },
  year_of_construction: {
    type: Number,
  },
  type_of_use: {
    type: String,
    // Note: M1: Links to Benchmark table (M6)
  },
  num_students_employees: {
    type: Number,
    // Note: M1: Denominator for Per Capita KPI
  },
  // Loxone Connection Configuration
  miniserver_ip: {
    type: String,
  },
  miniserver_port: {
    type: String,
  },
  miniserver_protocol: {
    type: String,
    default: 'wss',
  },
  miniserver_user: {
    type: String,
  },
  miniserver_pass: {
    type: String, // Should be encrypted in production
  },
  miniserver_external_address: {
    type: String, // For cloud connections (e.g., dns.loxonecloud.com)
  },
  miniserver_serial: {
    type: String, // Serial number for cloud connection
  },
  miniserver_connected: {
    type: Boolean,
    default: false,
  },
  miniserver_last_connected: {
    type: Date,
  },
  miniserver_auth_token: {
    type: String, // JWT token after authentication
  },
  // Building Contact - Operational contact for immediate alert reports
  buildingContact_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'BuildingContact',
  },
}, {
  timestamps: true,
});

// Indexes
buildingSchema.index({ site_id: 1 });
buildingSchema.index({ type_of_use: 1 });
buildingSchema.index({ name: 1, site_id: 1 }, { unique: true }); // Ensure unique building names per site
buildingSchema.index({ buildingContact_id: 1 });

module.exports = mongoose.model('Building', buildingSchema);

