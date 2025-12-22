const mongoose = require('mongoose');

// Local Room Schema - Rooms created from floor plan, linked to Loxone rooms
const localRoomSchema = new mongoose.Schema({
  floor_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Floor',
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  color: {
    type: String, // Hex color code or color name
  },
  loxone_room_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Room', // Reference to Loxone Room (not UUID, but the Room document _id)
  },
}, {
  timestamps: true,
});

// Indexes
localRoomSchema.index({ floor_id: 1 });
localRoomSchema.index({ loxone_room_id: 1 });

module.exports = mongoose.model('LocalRoom', localRoomSchema);

