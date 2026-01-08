/**
 * Script to fix the measurements Time Series collection structure
 * 
 * This script checks if the measurements collection has the correct
 * metaField structure and recreates it if needed.
 * 
 * WARNING: This will DROP the existing collection and all its data!
 * Only run this if you're okay with losing existing measurement data.
 */

require('dotenv').config();
const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
    console.error('[ERROR] MONGODB_URI not set in .env file');
    process.exit(1);
}

async function fixMeasurementsCollection() {
    try {
        console.log('[FIX] Connecting to MongoDB...');
        await mongoose.connect(MONGODB_URI, {
            serverSelectionTimeoutMS: 15000,
            socketTimeoutMS: 45000,
        });

        await mongoose.connection.db.admin().ping();
        console.log('[FIX] ✓ Connected to MongoDB');

        const db = mongoose.connection.db;
        
        // Check if collection exists
        const collections = await db.listCollections({ name: 'measurements' }).toArray();
        
        if (collections.length === 0) {
            console.log('[FIX] Collection does not exist, creating with correct structure...');
            await db.createCollection('measurements', {
                timeseries: {
                    timeField: 'timestamp',
                    metaField: 'meta', // Must be an object
                    granularity: 'seconds'
                }
            });
            console.log('[FIX] ✓ Created Time Series collection with correct structure');
        } else {
            // Check current structure
            const collectionInfo = await db.listCollections({ name: 'measurements' }).toArray();
            const options = collectionInfo[0]?.options || {};
            const timeseries = options.timeseries || {};
            const currentMetaField = timeseries.metaField;
            
            console.log(`[FIX] Current metaField: ${currentMetaField || 'none'}`);
            
            if (currentMetaField !== 'meta') {
                console.warn('[FIX] ⚠️  Collection has incorrect metaField structure!');
                console.warn('[FIX] ⚠️  Current:', currentMetaField, 'Expected: meta');
                console.warn('[FIX] ⚠️  This will cause measurements to not be stored correctly.');
                console.log('');
                console.log('[FIX] To fix this, you need to:');
                console.log('[FIX] 1. Drop the existing collection (this will DELETE all data!)');
                console.log('[FIX] 2. Recreate it with the correct structure');
                console.log('');
                
                // Ask for confirmation (in a real script, you'd use readline)
                console.log('[FIX] Run this command in MongoDB shell or Compass:');
                console.log('[FIX]   db.measurements.drop()');
                console.log('[FIX]   db.createCollection("measurements", {');
                console.log('[FIX]     timeseries: {');
                console.log('[FIX]       timeField: "timestamp",');
                console.log('[FIX]       metaField: "meta",');
                console.log('[FIX]       granularity: "seconds"');
                console.log('[FIX]     }');
                console.log('[FIX]   })');
                console.log('');
                console.log('[FIX] Or use MongoDB Compass to drop and recreate the collection.');
            } else {
                console.log('[FIX] ✓ Collection has correct structure');
            }
        }

        // Create indexes
        const collection = db.collection('measurements');
        try {
            await collection.createIndex({ 'meta.sensorId': 1, timestamp: -1 });
            await collection.createIndex({ 'meta.buildingId': 1, timestamp: -1 });
            await collection.createIndex({ timestamp: -1 });
            console.log('[FIX] ✓ Indexes created');
        } catch (indexError) {
            if (!indexError.message.includes('already exists')) {
                console.warn('[FIX] Index creation warning:', indexError.message);
            }
        }

        // Check document count
        const count = await collection.countDocuments();
        console.log(`[FIX] Current document count: ${count}`);
        
        if (count > 0) {
            // Show sample document
            const sample = await collection.findOne();
            console.log('[FIX] Sample document structure:');
            console.log(JSON.stringify(sample, null, 2));
        }

        await mongoose.disconnect();
        console.log('[FIX] ✓ Done');
    } catch (error) {
        console.error('[FIX] Error:', error.message);
        console.error(error);
        process.exit(1);
    }
}

fixMeasurementsCollection();

