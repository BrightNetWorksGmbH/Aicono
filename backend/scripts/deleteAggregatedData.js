require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');

/**
 * Script to delete all aggregated data from measurements collection
 * 
 * This script safely deletes only aggregated documents (source: 'aggregated')
 * while preserving raw data (resolution_minutes: 0 or source: 'websocket')
 * 
 * After running this, the aggregation scheduler will automatically recreate
 * the aggregates with the correct resolution_minutes field.
 * 
 * Usage: node backend/scripts/deleteAggregatedData.js
 * 
 * WARNING: This will delete all aggregated data. Make sure you understand
 * the implications before running this script.
 */

async function deleteAggregatedData() {
    try {
        // Connect to database
        await connectToDatabase();
        console.log('✅ Connected to database');
        
        const db = mongoose.connection.db;
        const collection = db.collection('measurements');
        
        // Check if this is a Time Series collection
        const collections = await db.listCollections({ name: 'measurements' }).toArray();
        const isTimeSeries = collections.length > 0 && collections[0].options?.timeseries;
        
        if (isTimeSeries) {
            console.log('📊 Detected Time Series collection\n');
        }
        
        // Count aggregated documents before deletion
        console.log('🔍 Counting aggregated documents...');
        const aggregatedCount = await collection.aggregate([
            {
                $match: {
                    source: 'aggregated'
                }
            },
            {
                $count: 'total'
            }
        ]).toArray();
        
        const count = aggregatedCount.length > 0 ? aggregatedCount[0].total : 0;
        
        if (count === 0) {
            console.log('✅ No aggregated documents found. Nothing to delete.');
            return;
        }
        
        console.log(`   Found ${count} aggregated documents to delete\n`);
        
        // Count raw data to confirm we're not deleting it
        const rawCount = await collection.aggregate([
            {
                $match: {
                    $or: [
                        { resolution_minutes: 0 },
                        { source: 'websocket' }
                    ]
                }
            },
            {
                $count: 'total'
            }
        ]).toArray();
        
        const rawDataCount = rawCount.length > 0 ? rawCount[0].total : 0;
        console.log(`📊 Current data status:`);
        console.log(`   Aggregated documents: ${count}`);
        console.log(`   Raw data documents: ${rawDataCount}`);
        console.log(`   Total documents: ${count + rawDataCount}\n`);
        
        // Confirm deletion
        console.log('⚠️  WARNING: This will delete ALL aggregated data!');
        console.log('   - All 15-minute, hourly, daily, weekly, and monthly aggregates will be deleted');
        console.log('   - Raw data will be preserved');
        console.log('   - Aggregates will be automatically recreated by the aggregation scheduler\n');
        
        // For Time Series collections, we need to delete using deleteMany with proper query
        // We can query on meta fields and timestamp, but we need to be careful
        // Since we can't query on 'source' directly, we'll use a different approach
        
        if (isTimeSeries) {
            console.log('🔄 Deleting aggregated documents from Time Series collection...');
            console.log('   Using deleteMany with meta field queries...\n');
            
            let deletedCount = 0;
            
            // Strategy for Time Series collections:
            // 1. Delete documents with resolution_minutes > 0 (definitely aggregates)
            // 2. Delete documents without resolution_minutes that have aggregation indicators
            //    (like avgValue, minValue, maxValue, count > 1, or source='aggregated')
            
            // Step 1: Delete documents with resolution_minutes set (these are aggregates)
            console.log('   Step 1: Deleting documents with resolution_minutes > 0...');
            const deleteWithResolution = await collection.deleteMany({
                resolution_minutes: { $exists: true, $ne: 0 }
            });
            deletedCount += deleteWithResolution.deletedCount;
            console.log(`   ✅ Deleted ${deleteWithResolution.deletedCount} documents with resolution_minutes set`);
            
            // Step 2: Delete documents without resolution_minutes but with aggregation indicators
            // We can identify them by having avgValue, minValue, maxValue (aggregation fields)
            // OR by having count > 1 (aggregated from multiple raw points)
            console.log('   Step 2: Finding aggregated documents without resolution_minutes...');
            
            // Use aggregation to find documents that look like aggregates
            const docsToDelete = await collection.aggregate([
                {
                    $match: {
                        resolution_minutes: { $exists: false },
                        $or: [
                            { avgValue: { $exists: true } },
                            { minValue: { $exists: true } },
                            { maxValue: { $exists: true } },
                            { count: { $gt: 1 } },
                            { source: 'aggregated' }
                        ]
                    }
                },
                {
                    $project: {
                        _id: 1,
                        timestamp: 1,
                        'meta.sensorId': 1,
                        'meta.buildingId': 1,
                        'meta.measurementType': 1,
                        'meta.stateType': 1
                    }
                }
            ]).toArray();
            
            console.log(`   Found ${docsToDelete.length} documents without resolution_minutes that appear to be aggregates`);
            
            if (docsToDelete.length > 0) {
                // Delete in batches using deleteMany with meta field + timestamp queries
                let batchDeleted = 0;
                const batchSize = 50; // Smaller batches for Time Series
                
                console.log(`   Deleting in batches of ${batchSize}...`);
                
                for (let i = 0; i < docsToDelete.length; i += batchSize) {
                    const batch = docsToDelete.slice(i, i + batchSize);
                    
                    // Delete each document using meta fields + timestamp (allowed for Time Series)
                    for (const doc of batch) {
                        try {
                            const result = await collection.deleteMany({
                                timestamp: doc.timestamp,
                                'meta.sensorId': doc.meta.sensorId,
                                'meta.buildingId': doc.meta.buildingId,
                                'meta.measurementType': doc.meta.measurementType,
                                'meta.stateType': doc.meta.stateType
                            });
                            batchDeleted += result.deletedCount;
                        } catch (error) {
                            // Some documents might already be deleted or have issues
                            // Continue with next document
                        }
                    }
                    
                    // Progress indicator
                    const processed = Math.min(i + batchSize, docsToDelete.length);
                    if (processed % 500 === 0 || processed === docsToDelete.length) {
                        console.log(`   Progress: ${processed}/${docsToDelete.length} processed (${batchDeleted} deleted so far)...`);
                    }
                }
                
                deletedCount += batchDeleted;
                console.log(`   ✅ Deleted ${batchDeleted} documents without resolution_minutes`);
            }
            
            console.log(`\n✅ Total deleted: ${deletedCount} aggregated documents`);
            
        } else {
            // Regular collection - can use simple deleteMany
            console.log('🔄 Deleting aggregated documents...');
            const result = await collection.deleteMany({
                source: 'aggregated'
            });
            
            console.log(`✅ Deleted ${result.deletedCount} aggregated documents`);
        }
        
        // Verify deletion
        console.log('\n📊 Verification:');
        const remainingAggregated = await collection.aggregate([
            {
                $match: {
                    source: 'aggregated'
                }
            },
            {
                $count: 'total'
            }
        ]).toArray();
        
        const remainingCount = remainingAggregated.length > 0 ? remainingAggregated[0].total : 0;
        console.log(`   Remaining aggregated documents: ${remainingCount}`);
        
        const remainingRaw = await collection.aggregate([
            {
                $match: {
                    $or: [
                        { resolution_minutes: 0 },
                        { source: 'websocket' }
                    ]
                }
            },
            {
                $count: 'total'
            }
        ]).toArray();
        
        const remainingRawCount = remainingRaw.length > 0 ? remainingRaw[0].total : 0;
        console.log(`   Raw data documents: ${remainingRawCount} (preserved)`);
        
        console.log('\n========================================');
        console.log('✅ Deletion complete!');
        console.log('   The aggregation scheduler will automatically');
        console.log('   recreate aggregates with correct resolution_minutes.');
        console.log('========================================\n');
        
    } catch (error) {
        console.error('❌ Deletion failed:', error);
        throw error;
    } finally {
        await mongoose.connection.close();
        console.log('✅ Database connection closed');
    }
}

// Run if called directly
if (require.main === module) {
    deleteAggregatedData()
        .then(() => {
            console.log('✅ Script completed successfully');
            process.exit(0);
        })
        .catch((error) => {
            console.error('❌ Script failed:', error);
            process.exit(1);
        });
}

module.exports = { deleteAggregatedData };

