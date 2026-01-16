const mongoose = require('mongoose');

// Loxone Room Schema - Rooms imported from Loxone structure file
const roomSchema = new mongoose.Schema({
  building_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Building',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  loxone_room_uuid: {
    type: String,
    required: true,
    // Note: Not unique globally - same UUID can exist for different buildings
    // Note: M1: Loxone mapping - UUID from LoxAPP3.json
  },
}, {
  timestamps: true,
});

// Indexes
roomSchema.index({ building_id: 1 });
roomSchema.index({ loxone_room_uuid: 1 });
// Compound unique index: same room UUID can exist for different buildings
roomSchema.index({ building_id: 1, loxone_room_uuid: 1 }, { unique: true });

module.exports = mongoose.model('Room', roomSchema);

