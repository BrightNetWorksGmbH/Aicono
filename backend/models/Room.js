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
    unique: true,
    // Note: M1: Loxone mapping - UUID from LoxAPP3.json
  },
}, {
  timestamps: true,
});

// Indexes
roomSchema.index({ building_id: 1 });
roomSchema.index({ loxone_room_uuid: 1 });

module.exports = mongoose.model('Room', roomSchema);

