/**
 * Migration Script: Fix Room and Sensor Indexes
 * 
 * This script drops the old global unique indexes on loxone_room_uuid and loxone_control_uuid
 * and creates new compound unique indexes that allow the same UUIDs for different buildings.
 * 
 * Run this script once before restarting the server after schema changes.
 * 
 * Usage: node scripts/fixRoomSensorIndexes.js
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');

async function fixIndexes() {
  try {
    console.log('🔄 Starting index migration...\n');
    
    // Connect to database
    await connectToDatabase();
    const db = mongoose.connection.db;
    
    console.log('📋 Checking existing indexes...\n');
    
    // Check and drop old unique indexes on rooms
    try {
      const roomIndexes = await db.collection('rooms').indexes();
      console.log('Current room indexes:');
      roomIndexes.forEach(idx => {
        console.log(`  - ${idx.name}: ${JSON.stringify(idx.key)}`);
      });
      
      // Drop the old unique index on loxone_room_uuid if it exists
      const oldRoomIndex = roomIndexes.find(idx => 
        idx.name === 'loxone_room_uuid_1' || 
        (idx.key.loxone_room_uuid === 1 && idx.unique && !idx.key.building_id)
      );
      
      if (oldRoomIndex) {
        console.log(`\n🗑️  Dropping old unique index: ${oldRoomIndex.name}`);
        await db.collection('rooms').dropIndex(oldRoomIndex.name);
        console.log(`✅ Dropped ${oldRoomIndex.name}\n`);
      } else {
        console.log('✅ No old room unique index found\n');
      }
      
      // Create new compound unique index
      console.log('📝 Creating compound unique index: { building_id: 1, loxone_room_uuid: 1 }');
      try {
        await db.collection('rooms').createIndex(
          { building_id: 1, loxone_room_uuid: 1 },
          { unique: true, name: 'building_id_1_loxone_room_uuid_1' }
        );
        console.log('✅ Created compound unique index for rooms\n');
      } catch (error) {
        if (error.code === 85 || error.codeName === 'IndexOptionsConflict') {
          console.log('⚠️  Compound index already exists or conflict, checking...');
          const existingCompound = roomIndexes.find(idx => 
            idx.key.building_id === 1 && idx.key.loxone_room_uuid === 1 && idx.unique
          );
          if (existingCompound) {
            console.log('✅ Compound index already exists\n');
          } else {
            throw error;
          }
        } else {
          throw error;
        }
      }
    } catch (error) {
      if (error.message.includes('index not found')) {
        console.log('ℹ️  Old index already dropped\n');
      } else {
        throw error;
      }
    }
    
    // Check and drop old unique indexes on sensors
    try {
      const sensorIndexes = await db.collection('sensors').indexes();
      console.log('Current sensor indexes:');
      sensorIndexes.forEach(idx => {
        console.log(`  - ${idx.name}: ${JSON.stringify(idx.key)}`);
      });
      
      // Drop the old unique index on loxone_control_uuid if it exists
      const oldSensorIndex = sensorIndexes.find(idx => 
        idx.name === 'loxone_control_uuid_1' || 
        (idx.key.loxone_control_uuid === 1 && idx.unique)
      );
      
      if (oldSensorIndex) {
        console.log(`\n🗑️  Dropping old unique index: ${oldSensorIndex.name}`);
        await db.collection('sensors').dropIndex(oldSensorIndex.name);
        console.log(`✅ Dropped ${oldSensorIndex.name}\n`);
      } else {
        console.log('✅ No old sensor unique index found\n');
      }
      
      // Note: Sensors don't need a compound unique index because they reference rooms,
      // and rooms are already unique per building. The same control UUID can exist
      // for different buildings through different rooms.
      console.log('✅ Sensors can now have duplicate control UUIDs (through different rooms)\n');
      
    } catch (error) {
      if (error.message.includes('index not found')) {
        console.log('ℹ️  Old index already dropped\n');
      } else {
        throw error;
      }
    }
    
    console.log('✅ Index migration completed successfully!\n');
    console.log('📝 Summary:');
    console.log('  - Rooms: Can now have duplicate loxone_room_uuid per building');
    console.log('  - Sensors: Can now have duplicate loxone_control_uuid (via different rooms)');
    console.log('  - Compound unique index ensures uniqueness per building for rooms\n');
    console.log('🔄 You can now restart your server. The structure import should work for all buildings.\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error(error);
    process.exit(1);
  }
}

// Run migration
fixIndexes();

