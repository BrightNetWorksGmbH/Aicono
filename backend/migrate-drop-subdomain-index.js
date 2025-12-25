require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('./db/connection');

/**
 * Migration script to drop the unique index on sub_domain
 * This allows multiple BryteSwitch instances to share the same subdomain
 * Run this script once: node migrate-drop-subdomain-index.js
 */
async function dropSubdomainUniqueIndex() {
  try {
    console.log('Connecting to database...');
    await connectToDatabase();
    
    const db = mongoose.connection.db;
    const collection = db.collection('bryteswitchsettings');
    
    // List all indexes
    const indexes = await collection.indexes();
    console.log('Current indexes:', indexes.map(idx => idx.name));
    
    // Check if the unique sub_domain index exists
    const subdomainIndex = indexes.find(idx => 
      idx.name === 'sub_domain_1' || 
      (idx.key && idx.key.sub_domain === 1 && idx.unique === true)
    );
    
    if (subdomainIndex) {
      console.log('Found unique index on sub_domain, dropping it...');
      await collection.dropIndex(subdomainIndex.name);
      console.log(`✓ Successfully dropped index: ${subdomainIndex.name}`);
    } else {
      console.log('No unique index found on sub_domain. Index may have already been dropped.');
    }
    
    // Verify the index was dropped
    const updatedIndexes = await collection.indexes();
    console.log('\nUpdated indexes:', updatedIndexes.map(idx => idx.name));
    
    console.log('\n✓ Migration completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('✗ Migration failed:', error);
    process.exit(1);
  }
}

// Run the migration
dropSubdomainUniqueIndex();

