const mongoose = require('mongoose');

// Loxone Room Schema - Rooms imported from Loxone structure file
const roomSchema = new mongoose.Schema({
  miniserver_serial: {
    type: String,
    required: true,
    // Note: Server serial number - rooms are scoped to server, not building
    // Multiple buildings can use the same server and share rooms
  },
  name: {
    type: String,
    required: true,
  },
  loxone_room_uuid: {
    type: String,
    required: true,
    // Note: M1: Loxone mapping - UUID from LoxAPP3.json
  },
}, {
  timestamps: true,
});

// Indexes
roomSchema.index({ miniserver_serial: 1 });
roomSchema.index({ loxone_room_uuid: 1 });
// Compound unique index: same room UUID can exist for different servers
roomSchema.index({ miniserver_serial: 1, loxone_room_uuid: 1 }, { unique: true });

module.exports = mongoose.model('Room', roomSchema);

