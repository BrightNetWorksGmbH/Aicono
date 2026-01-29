/**
 * Migration Script: Add Aggregation Index
 * 
 * This script adds the missing index for aggregation queries:
 * { resolution_minutes: 1, timestamp: -1 }
 * 
 * This index significantly speeds up countDocuments queries in the aggregation service
 * and prevents connection timeouts on large collections.
 * 
 * Run this script once to add the index to existing databases.
 * 
 * Usage: node scripts/addAggregationIndex.js
 */

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');

async function addAggregationIndex() {
  try {
    console.log('🔄 Starting aggregation index migration...\n');
    
    // Connect to database
    await connectToDatabase();
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    console.log('📋 Checking existing indexes...\n');
    
    // Get current indexes
    const existingIndexes = await collection.indexes();
    console.log('Current indexes on measurements collection:');
    existingIndexes.forEach(idx => {
      console.log(`  - ${idx.name}: ${JSON.stringify(idx.key)}`);
    });
    console.log('');
    
    // Check if the index already exists
    const indexExists = existingIndexes.some(
      idx => idx.name === 'resolution_timestamp_idx'
    );
    
    if (indexExists) {
      console.log('✅ Index "resolution_timestamp_idx" already exists. No action needed.\n');
      return;
    }
    
    console.log('📊 Creating index: { resolution_minutes: 1, timestamp: -1 }...\n');
    console.log('⚠️  This may take a while on large collections. Please be patient...\n');
    
    // Create the index in the background
    await collection.createIndex(
      { resolution_minutes: 1, timestamp: -1 },
      { 
        background: true, 
        name: 'resolution_timestamp_idx' 
      }
    );
    
    console.log('✅ Successfully created index "resolution_timestamp_idx"\n');
    
    // Verify the index was created
    const updatedIndexes = await collection.indexes();
    const newIndex = updatedIndexes.find(idx => idx.name === 'resolution_timestamp_idx');
    
    if (newIndex) {
      console.log('✅ Index verified:');
      console.log(`   Name: ${newIndex.name}`);
      console.log(`   Key: ${JSON.stringify(newIndex.key)}`);
      console.log(`   Background: ${newIndex.background || false}\n`);
    }
    
    console.log('🎉 Migration completed successfully!\n');
    
  } catch (error) {
    console.error('❌ Error during migration:', error.message);
    if (error.message.includes('already exists')) {
      console.log('\n✅ Index already exists. No action needed.');
    } else {
      throw error;
    }
  } finally {
    await mongoose.connection.close();
    console.log('📴 Database connection closed.');
    process.exit(0);
  }
}

// Run the migration
addAggregationIndex().catch(error => {
  console.error('💥 Fatal error:', error);
  process.exit(1);
});
