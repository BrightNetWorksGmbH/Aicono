require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');
const measurementCollectionService = require('../services/measurementCollectionService');

/**
 * Migration Script: Separate Measurements Collections
 * 
 * Migrates data from single 'measurements' collection to:
 * - measurements_raw: Raw data (resolution_minutes: 0)
 * - measurements_aggregated: All aggregated data (15, 60, 1440, 10080, 43200)
 * 
 * Usage:
 *   node scripts/migrateToSeparateCollections.js [--dry-run] [--batch-size=10000]
 * 
 * Options:
 *   --dry-run: Show what would be migrated without actually migrating
 *   --batch-size: Number of documents to process at a time (default: 10000)
 */

const BATCH_SIZE = parseInt(process.argv.find(arg => arg.startsWith('--batch-size='))?.split('=')[1] || '10000', 10);
const DRY_RUN = process.argv.includes('--dry-run');

async function migrateData() {
    try {
        console.log('[MIGRATION] Connecting to MongoDB...');
        await connectToDatabase();
        console.log('[MIGRATION] ✓ Connected to MongoDB');

        const db = mongoose.connection.db;
        
        // Ensure new collections exist
        console.log('[MIGRATION] Ensuring new collections exist...');
        await measurementCollectionService.ensureCollectionsExist();
        console.log('[MIGRATION] ✓ Collections initialized');

        // Check if old measurements collection exists
        const oldCollection = db.collection('measurements');
        const oldCollectionExists = await db.listCollections({ name: 'measurements' }).hasNext();
        
        if (!oldCollectionExists) {
            console.log('[MIGRATION] ⚠️  Old measurements collection does not exist. Nothing to migrate.');
            return;
        }

        // Count documents in old collection
        const totalCount = await oldCollection.countDocuments();
        console.log(`[MIGRATION] Found ${totalCount} documents in old measurements collection`);

        if (totalCount === 0) {
            console.log('[MIGRATION] ✓ No documents to migrate');
            return;
        }

        // Count by resolution
        const rawCount = await oldCollection.countDocuments({ resolution_minutes: 0 });
        const aggregatedCount = await oldCollection.countDocuments({ resolution_minutes: { $ne: 0 } });
        console.log(`[MIGRATION] Breakdown:`);
        console.log(`  - Raw data (resolution_minutes: 0): ${rawCount}`);
        console.log(`  - Aggregated data (resolution_minutes > 0): ${aggregatedCount}`);

        if (DRY_RUN) {
            console.log('\n[MIGRATION] 🔍 DRY RUN MODE - No data will be migrated');
            console.log(`[MIGRATION] Would migrate:`);
            console.log(`  - ${rawCount} documents → measurements_raw`);
            console.log(`  - ${aggregatedCount} documents → measurements_aggregated`);
            return;
        }

        // Migrate raw data
        console.log('\n[MIGRATION] Starting migration of raw data to measurements_raw...');
        let rawMigrated = 0;
        let rawSkipped = 0;
        
        const rawCursor = oldCollection.find({ resolution_minutes: 0 }).batchSize(BATCH_SIZE);
        let rawBatch = [];
        
        for await (const doc of rawCursor) {
            rawBatch.push(doc);
            
            if (rawBatch.length >= BATCH_SIZE) {
                try {
                    await db.collection('measurements_raw').insertMany(rawBatch, { ordered: false });
                    rawMigrated += rawBatch.length;
                    console.log(`[MIGRATION] Migrated ${rawMigrated}/${rawCount} raw documents...`);
                } catch (error) {
                    if (error.writeErrors) {
                        rawMigrated += error.insertedCount || 0;
                        rawSkipped += error.writeErrors.length;
                        console.warn(`[MIGRATION] ⚠️  Some raw documents skipped (duplicates): ${error.writeErrors.length}`);
                    } else {
                        throw error;
                    }
                }
                rawBatch = [];
            }
        }
        
        // Insert remaining batch
        if (rawBatch.length > 0) {
            try {
                await db.collection('measurements_raw').insertMany(rawBatch, { ordered: false });
                rawMigrated += rawBatch.length;
            } catch (error) {
                if (error.writeErrors) {
                    rawMigrated += error.insertedCount || 0;
                    rawSkipped += error.writeErrors.length;
                } else {
                    throw error;
                }
            }
        }
        
        console.log(`[MIGRATION] ✓ Raw data migration complete: ${rawMigrated} migrated, ${rawSkipped} skipped`);

        // Migrate aggregated data
        console.log('\n[MIGRATION] Starting migration of aggregated data to measurements_aggregated...');
        let aggregatedMigrated = 0;
        let aggregatedSkipped = 0;
        
        const aggregatedCursor = oldCollection.find({ resolution_minutes: { $ne: 0 } }).batchSize(BATCH_SIZE);
        let aggregatedBatch = [];
        
        for await (const doc of aggregatedCursor) {
            aggregatedBatch.push(doc);
            
            if (aggregatedBatch.length >= BATCH_SIZE) {
                try {
                    await db.collection('measurements_aggregated').insertMany(aggregatedBatch, { ordered: false });
                    aggregatedMigrated += aggregatedBatch.length;
                    console.log(`[MIGRATION] Migrated ${aggregatedMigrated}/${aggregatedCount} aggregated documents...`);
                } catch (error) {
                    if (error.writeErrors) {
                        aggregatedMigrated += error.insertedCount || 0;
                        aggregatedSkipped += error.writeErrors.length;
                        console.warn(`[MIGRATION] ⚠️  Some aggregated documents skipped (duplicates): ${error.writeErrors.length}`);
                    } else {
                        throw error;
                    }
                }
                aggregatedBatch = [];
            }
        }
        
        // Insert remaining batch
        if (aggregatedBatch.length > 0) {
            try {
                await db.collection('measurements_aggregated').insertMany(aggregatedBatch, { ordered: false });
                aggregatedMigrated += aggregatedBatch.length;
            } catch (error) {
                if (error.writeErrors) {
                    aggregatedMigrated += error.insertedCount || 0;
                    aggregatedSkipped += error.writeErrors.length;
                } else {
                    throw error;
                }
            }
        }
        
        console.log(`[MIGRATION] ✓ Aggregated data migration complete: ${aggregatedMigrated} migrated, ${aggregatedSkipped} skipped`);

        // Verify migration
        console.log('\n[MIGRATION] Verifying migration...');
        const rawCountNew = await db.collection('measurements_raw').countDocuments();
        const aggregatedCountNew = await db.collection('measurements_aggregated').countDocuments();
        
        console.log(`[MIGRATION] Verification:`);
        console.log(`  - measurements_raw: ${rawCountNew} documents (expected: ${rawCount})`);
        console.log(`  - measurements_aggregated: ${aggregatedCountNew} documents (expected: ${aggregatedCount})`);
        
        if (rawCountNew >= rawCount && aggregatedCountNew >= aggregatedCount) {
            console.log('[MIGRATION] ✅ Migration verification passed!');
            console.log('\n[MIGRATION] ⚠️  IMPORTANT: Old measurements collection still exists.');
            console.log('[MIGRATION] After verifying everything works correctly, you can drop it with:');
            console.log('[MIGRATION]   db.measurements.drop()');
        } else {
            console.warn('[MIGRATION] ⚠️  Migration verification shows discrepancies. Please review.');
        }

        console.log('\n[MIGRATION] ✅ Migration complete!');
        
    } catch (error) {
        console.error('[MIGRATION] ❌ Migration failed:', error.message);
        console.error('[MIGRATION] Stack:', error.stack);
        process.exit(1);
    } finally {
        await mongoose.connection.close();
        console.log('[MIGRATION] Database connection closed');
    }
}

// Run migration
if (require.main === module) {
    migrateData().catch(error => {
        console.error('[MIGRATION] Fatal error:', error);
        process.exit(1);
    });
}

module.exports = { migrateData };
