require('dotenv').config();
const mongoose = require('mongoose');

/**
 * Script to copy all collections from 'aicono' database to 'aicono-test' database
 * 
 * This script:
 * - Connects to MongoDB using MONGODB_URI from .env
 * - Lists all collections in the source database (aicono)
 * - Copies all documents and indexes from each collection to target database (aicono-test)
 * - Handles large collections efficiently using batches
 * 
 * Usage:
 *   node scripts/copyDatabaseToTest.js [--batch-size=10000] [--skip-indexes]
 * 
 * Options:
 *   --batch-size: Number of documents to copy at a time (default: 10000)
 *   --skip-indexes: Skip copying indexes (faster but you'll need to recreate them)
 * 
 * Prerequisites:
 *   - MONGODB_URI must be set in .env file
 *   - Target database (aicono-test) must exist (can be empty)
 */

const BATCH_SIZE = parseInt(
    process.argv.find(arg => arg.startsWith('--batch-size='))?.split('=')[1] || '10000',
    10
);
const SKIP_INDEXES = process.argv.includes('--skip-indexes');

const SOURCE_DB_NAME = 'aicono';
const TARGET_DB_NAME = 'aicono-test';

// Collections to skip (system collections, timeseries buckets, and measurement collections)
const SKIP_COLLECTIONS = [
    'system.views',
    'system.buckets.measurements_aggregated',
    'system.buckets.measurements_raw',
    'measurements_aggregated',
    'measurements_raw',
];

// Check if a collection should be skipped
function shouldSkipCollection(collectionName) {
    // Skip system collections (starting with 'system.')
    if (collectionName.startsWith('system.')) {
        return true;
    }
    // Skip specific collections
    if (SKIP_COLLECTIONS.includes(collectionName)) {
        return true;
    }
    return false;
}

async function copyDatabase() {
    
    try {
        console.log('========================================');
        console.log('[COPY DB] Starting database copy operation...');
        console.log(`[COPY DB] Source: ${SOURCE_DB_NAME}`);
        console.log(`[COPY DB] Target: ${TARGET_DB_NAME}`);
        console.log('========================================\n');

        // Get connection string from environment
        const mongoUri = process.env.MONGODB_URI;
        if (!mongoUri) {
            throw new Error('MONGODB_URI is not set in environment variables');
        }

        // Replace database name in connection string to connect to admin database first
        // This allows us to access both source and target databases
        const adminUri = mongoUri.replace(/\/([^/?]+)(\?|$)/, '/admin$2');
        
        console.log('[COPY DB] Connecting to MongoDB...');
        await mongoose.connect(adminUri, {
            maxPoolSize: 10,
            serverSelectionTimeoutMS: 60000,
            socketTimeoutMS: 120000,
        });
        console.log('[COPY DB] ✓ Connected to MongoDB\n');

        // Get the native MongoDB client from mongoose
        const client = mongoose.connection.getClient();
        
        // Access source and target databases
        const sourceDb = client.db(SOURCE_DB_NAME);
        const targetDb = client.db(TARGET_DB_NAME);

        // Verify source database exists
        const adminDb = client.db('admin');
        const databases = await adminDb.admin().listDatabases();
        const sourceDbExists = databases.databases.some(db => db.name === SOURCE_DB_NAME);
        
        if (!sourceDbExists) {
            throw new Error(`Source database '${SOURCE_DB_NAME}' does not exist`);
        }

        console.log(`[COPY DB] ✓ Source database '${SOURCE_DB_NAME}' found`);
        console.log(`[COPY DB] ✓ Target database '${TARGET_DB_NAME}' ready\n`);

        // List all collections in source database
        const allCollections = await sourceDb.listCollections().toArray();
        
        if (allCollections.length === 0) {
            console.log('[COPY DB] ⚠️  Source database has no collections. Nothing to copy.');
            return;
        }

        // Filter out collections to skip
        const collections = allCollections.filter(col => !shouldSkipCollection(col.name));
        const skippedCollections = allCollections.filter(col => shouldSkipCollection(col.name));

        if (skippedCollections.length > 0) {
            console.log(`[COPY DB] Skipping ${skippedCollections.length} collection(s):\n`);
            skippedCollections.forEach((col, index) => {
                console.log(`  ${index + 1}. ${col.name} (skipped)`);
            });
            console.log('');
        }

        if (collections.length === 0) {
            console.log('[COPY DB] ⚠️  No collections to copy after filtering.');
            return;
        }

        console.log(`[COPY DB] Found ${collections.length} collection(s) to copy:\n`);
        collections.forEach((col, index) => {
            console.log(`  ${index + 1}. ${col.name}`);
        });
        console.log('');

        const startTime = Date.now();
        let totalDocumentsCopied = 0;
        let totalCollectionsCopied = 0;
        const results = [];

        // Copy each collection
        for (const collectionInfo of collections) {
            const collectionName = collectionInfo.name;
            console.log(`[COPY DB] Processing collection: ${collectionName}`);
            
            try {
                const sourceCollection = sourceDb.collection(collectionName);
                const targetCollection = targetDb.collection(collectionName);

                // Count documents in source collection
                const documentCount = await sourceCollection.countDocuments();
                console.log(`  [COPY DB]   Found ${documentCount} document(s)`);

                if (documentCount === 0) {
                    console.log(`  [COPY DB]   ⚠️  Collection is empty, skipping data copy`);
                } else {
                    // Copy documents in batches
                    let copiedCount = 0;
                    let batchNumber = 0;
                    const cursor = sourceCollection.find({}).batchSize(BATCH_SIZE);

                    // Clear target collection first (optional - comment out if you want to append)
                    const existingCount = await targetCollection.countDocuments();
                    if (existingCount > 0) {
                        console.log(`  [COPY DB]   ⚠️  Target collection has ${existingCount} existing documents`);
                        console.log(`  [COPY DB]   Clearing target collection...`);
                        await targetCollection.deleteMany({});
                        console.log(`  [COPY DB]   ✓ Target collection cleared`);
                    }

                    let batch = [];
                    for await (const doc of cursor) {
                        batch.push(doc);
                        
                        if (batch.length >= BATCH_SIZE) {
                            batchNumber++;
                            try {
                                await targetCollection.insertMany(batch, { ordered: false });
                                copiedCount += batch.length;
                                console.log(`  [COPY DB]   Batch ${batchNumber}: Copied ${copiedCount}/${documentCount} documents...`);
                            } catch (error) {
                                if (error.writeErrors) {
                                    // Some documents might be duplicates, count inserted ones
                                    copiedCount += error.insertedCount || 0;
                                    console.warn(`  [COPY DB]   ⚠️  Batch ${batchNumber}: Some documents skipped (${error.writeErrors.length} errors, ${error.insertedCount || 0} inserted)`);
                                } else {
                                    throw error;
                                }
                            }
                            batch = [];
                        }
                    }

                    // Insert remaining batch
                    if (batch.length > 0) {
                        batchNumber++;
                        try {
                            await targetCollection.insertMany(batch, { ordered: false });
                            copiedCount += batch.length;
                        } catch (error) {
                            if (error.writeErrors) {
                                copiedCount += error.insertedCount || 0;
                            } else {
                                throw error;
                            }
                        }
                    }

                    console.log(`  [COPY DB]   ✓ Copied ${copiedCount} document(s)`);
                    totalDocumentsCopied += copiedCount;
                }

                // Copy indexes
                if (!SKIP_INDEXES) {
                    console.log(`  [COPY DB]   Copying indexes...`);
                    const indexes = await sourceCollection.indexes();
                    
                    // Skip the default _id index as it's automatically created
                    const customIndexes = indexes.filter(idx => idx.name !== '_id_');
                    
                    if (customIndexes.length > 0) {
                        for (const index of customIndexes) {
                            try {
                                // Remove name and v fields as they're auto-generated
                                const indexSpec = { ...index };
                                delete indexSpec.name;
                                delete indexSpec.v;
                                delete indexSpec.ns;
                                
                                await targetCollection.createIndex(indexSpec.key, {
                                    name: index.name,
                                    unique: index.unique || false,
                                    sparse: index.sparse || false,
                                    background: true, // Create in background to avoid blocking
                                    ...(index.expireAfterSeconds !== undefined && { expireAfterSeconds: index.expireAfterSeconds }),
                                    ...(index.partialFilterExpression && { partialFilterExpression: index.partialFilterExpression }),
                                });
                            } catch (error) {
                                // Index might already exist or have a conflict
                                if (error.code === 85 || error.code === 86) {
                                    console.warn(`  [COPY DB]   ⚠️  Index '${index.name}' already exists or has conflict, skipping`);
                                } else {
                                    throw error;
                                }
                            }
                        }
                        console.log(`  [COPY DB]   ✓ Copied ${customIndexes.length} index(es)`);
                    } else {
                        console.log(`  [COPY DB]   ℹ️  No custom indexes to copy`);
                    }
                } else {
                    console.log(`  [COPY DB]   ⏭️  Skipping indexes (--skip-indexes flag)`);
                }

                // Verify copy
                const targetCount = await targetCollection.countDocuments();
                const sourceCount = await sourceCollection.countDocuments();
                
                if (targetCount === sourceCount) {
                    console.log(`  [COPY DB]   ✅ Verification passed: ${targetCount} documents in target`);
                } else {
                    console.warn(`  [COPY DB]   ⚠️  Verification warning: Source has ${sourceCount}, target has ${targetCount}`);
                }

                results.push({
                    collection: collectionName,
                    sourceCount,
                    targetCount,
                    success: targetCount === sourceCount,
                });

                totalCollectionsCopied++;
                console.log(`  [COPY DB]   ✓ Collection '${collectionName}' copied successfully\n`);

            } catch (error) {
                console.error(`  [COPY DB]   ❌ Error copying collection '${collectionName}':`, error.message);
                results.push({
                    collection: collectionName,
                    error: error.message,
                    success: false,
                });
            }
        }

        const endTime = Date.now();
        const duration = ((endTime - startTime) / 1000).toFixed(2);

        // Print summary
        console.log('========================================');
        console.log('[COPY DB] Copy operation complete!');
        console.log('========================================');
        console.log(`Collections processed: ${totalCollectionsCopied}/${collections.length}`);
        if (skippedCollections.length > 0) {
            console.log(`Collections skipped: ${skippedCollections.length}`);
        }
        console.log(`Total documents copied: ${totalDocumentsCopied.toLocaleString()}`);
        console.log(`Total time: ${duration}s`);
        console.log('\nCollection Summary:');
        console.log('----------------------------------------');
        
        results.forEach(result => {
            if (result.success) {
                console.log(`✅ ${result.collection}: ${result.targetCount} documents`);
            } else if (result.error) {
                console.log(`❌ ${result.collection}: Error - ${result.error}`);
            } else {
                console.log(`⚠️  ${result.collection}: ${result.sourceCount} → ${result.targetCount} documents`);
            }
        });
        
        if (skippedCollections.length > 0) {
            console.log('\nSkipped Collections:');
            console.log('----------------------------------------');
            skippedCollections.forEach(col => {
                console.log(`⏭️  ${col.name} (skipped)`);
            });
        }
        
        console.log('========================================\n');

        const allSuccessful = results.every(r => r.success);
        if (allSuccessful) {
            console.log('[COPY DB] ✅ All collections copied successfully!');
            console.log(`[COPY DB] You can now use '${TARGET_DB_NAME}' database in your .env file`);
            console.log(`[COPY DB] Update MONGODB_URI to use '${TARGET_DB_NAME}' instead of '${SOURCE_DB_NAME}'`);
        } else {
            console.warn('[COPY DB] ⚠️  Some collections had issues. Please review the summary above.');
        }

    } catch (error) {
        console.error('[COPY DB] ❌ Fatal error:', error.message);
        console.error('[COPY DB] Stack:', error.stack);
        process.exit(1);
    } finally {
        if (mongoose.connection.readyState === 1) {
            await mongoose.connection.close();
            console.log('[COPY DB] Database connection closed');
        }
    }
}

// Run the copy operation
if (require.main === module) {
    copyDatabase().catch(error => {
        console.error('[COPY DB] Fatal error:', error);
        process.exit(1);
    });
}

module.exports = { copyDatabase };
