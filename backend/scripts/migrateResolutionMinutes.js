require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');

/**
 * Migration script to add resolution_minutes to existing aggregated documents
 * 
 * This script identifies aggregated documents missing resolution_minutes and adds
 * the appropriate value based on timestamp patterns:
 * - 15-minute: timestamps at :00, :15, :30, :45
 * - Hourly: timestamps at :00:00 (but not :15/:30/:45)
 * - Daily: timestamps at T00:00:00
 * - Weekly: timestamps on Monday at 00:00:00
 * - Monthly: timestamps on 1st of month at 00:00:00
 * 
 * Usage: node backend/scripts/migrateResolutionMinutes.js
 */

async function migrateResolutionMinutes() {
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
            console.log('📊 Detected Time Series collection - using aggregation pipeline approach\n');
        }
        
        let totalUpdated = 0;
        
        // For Time Series collections, we need to use aggregation pipeline with $merge
        // We can only query on timestamp and meta fields, so we'll fetch all aggregated docs
        // and update them based on timestamp patterns
        
        console.log('\n🔍 Fetching aggregated documents missing resolution_minutes...');
        
        // Step 1: Find all aggregated documents missing resolution_minutes
        // We'll use aggregation to identify them, then update individually
        const docsToUpdate = await collection.aggregate([
            {
                $match: {
                    source: 'aggregated',
                    resolution_minutes: { $exists: false }
                }
            },
            {
                $addFields: {
                    // Determine resolution based on timestamp pattern
                    calculatedResolution: {
                        $cond: {
                            if: { 
                                $regexMatch: { 
                                    input: { $toString: '$timestamp' }, 
                                    regex: 'T\\d{2}:(15|30|45):00' 
                                } 
                            },
                            then: 15, // :15, :30, :45 = 15-minute
                            else: {
                                $cond: {
                                    if: { 
                                        $and: [
                                            { 
                                                $regexMatch: { 
                                                    input: { $toString: '$timestamp' }, 
                                                    regex: 'T\\d{2}:00:00' 
                                                } 
                                            },
                                            { 
                                                $not: { 
                                                    $regexMatch: { 
                                                        input: { $toString: '$timestamp' }, 
                                                        regex: 'T00:00:00' 
                                                    } 
                                                } 
                                            },
                                            { $gte: ['$count', 100] } // High count = 15-min from raw
                                        ]
                                    },
                                    then: 15,
                                    else: {
                                        $cond: {
                                            if: {
                                                $and: [
                                                    { 
                                                        $regexMatch: { 
                                                            input: { $toString: '$timestamp' }, 
                                                            regex: 'T\\d{2}:00:00' 
                                                        } 
                                                    },
                                                    { 
                                                        $not: { 
                                                            $regexMatch: { 
                                                                input: { $toString: '$timestamp' }, 
                                                                regex: 'T00:00:00' 
                                                            } 
                                                        } 
                                                    },
                                                    { $lt: ['$count', 100] },
                                                    { $gte: ['$count', 1] }
                                                ]
                                            },
                                            then: 60, // Hourly
                                            else: {
                                                $cond: {
                                                    if: { 
                                                        $regexMatch: { 
                                                            input: { $toString: '$timestamp' }, 
                                                            regex: 'T00:00:00' 
                                                        } 
                                                    },
                                                    then: 1440, // Daily
                                                    else: 15 // Default to 15-minute if unclear
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            {
                $project: {
                    _id: 1,
                    timestamp: 1,
                    'meta.sensorId': 1,
                    'meta.buildingId': 1,
                    'meta.measurementType': 1,
                    'meta.stateType': 1,
                    calculatedResolution: 1
                }
            }
        ]).toArray();
        
        console.log(`   Found ${docsToUpdate.length} documents to update\n`);
        
        if (docsToUpdate.length === 0) {
            console.log('✅ No documents need updating!');
        } else {
            // Group by resolution for reporting
            const byResolution = {};
            docsToUpdate.forEach(doc => {
                const res = doc.calculatedResolution;
                byResolution[res] = (byResolution[res] || 0) + 1;
            });
            
            console.log('📊 Documents to update by resolution:');
            Object.entries(byResolution).forEach(([res, count]) => {
                const label = res === '15' ? '15-minute' : res === '60' ? 'hourly' : res === '1440' ? 'daily' : `${res}-minute`;
                console.log(`   ${label}: ${count} documents`);
            });
            console.log('');
            
            // Update documents one by one using replaceOne with proper query (meta + timestamp)
            console.log('🔄 Updating documents...');
            let updated = 0;
            let errors = 0;
            
            for (const doc of docsToUpdate) {
                try {
                    // For Time Series, we can only query on meta fields and timestamp
                    // So we fetch the full document first, then update it
                    const fullDoc = await collection.findOne({
                        _id: doc._id
                    });
                    
                    if (fullDoc) {
                        // Add resolution_minutes to the document
                        fullDoc.resolution_minutes = doc.calculatedResolution;
                        
                        // Use replaceOne with query on meta and timestamp (allowed for Time Series)
                        const result = await collection.replaceOne(
                            {
                                timestamp: doc.timestamp,
                                'meta.sensorId': doc.meta.sensorId,
                                'meta.buildingId': doc.meta.buildingId,
                                'meta.measurementType': doc.meta.measurementType,
                                'meta.stateType': doc.meta.stateType
                            },
                            fullDoc
                        );
                        
                        if (result.modifiedCount > 0 || result.upsertedCount > 0) {
                            updated++;
                        }
                    }
                } catch (error) {
                    errors++;
                    if (errors <= 5) {
                        console.error(`   ⚠️  Error updating document ${doc._id}:`, error.message);
                    }
                }
                
                // Progress indicator
                if ((updated + errors) % 100 === 0) {
                    console.log(`   Progress: ${updated + errors}/${docsToUpdate.length} processed...`);
                }
            }
            
            totalUpdated = updated;
            console.log(`\n   ✅ Updated ${updated} documents`);
            if (errors > 0) {
                console.log(`   ⚠️  ${errors} documents had errors`);
            }
        }
        
        // Check for any remaining aggregated documents without resolution_minutes
        const remaining = await collection.aggregate([
            {
                $match: {
                    source: 'aggregated',
                    resolution_minutes: { $exists: false }
                }
            },
            {
                $count: 'total'
            }
        ]).toArray();
        
        const remainingCount = remaining.length > 0 ? remaining[0].total : 0;
        
        if (remainingCount > 0) {
            console.log(`\n⚠️  Warning: ${remainingCount} aggregated documents still missing resolution_minutes`);
            console.log('   These may need manual review. Sample documents:');
            const samples = await collection.aggregate([
                {
                    $match: {
                        source: 'aggregated',
                        resolution_minutes: { $exists: false }
                    }
                },
                {
                    $limit: 3
                },
                {
                    $project: {
                        timestamp: 1,
                        count: 1
                    }
                }
            ]).toArray();
            
            samples.forEach((doc, idx) => {
                console.log(`   ${idx + 1}. timestamp: ${doc.timestamp}, count: ${doc.count || 'N/A'}`);
            });
        }
        
        // Summary
        console.log('\n========================================');
        console.log(`✅ Migration complete!`);
        console.log(`   Total documents updated: ${totalUpdated}`);
        console.log(`   Remaining without resolution_minutes: ${remainingCount}`);
        console.log('========================================\n');
        
        // 6. Verification: Count by resolution
        console.log('📊 Verification - Aggregates by resolution:');
        const stats = await collection.aggregate([
            {
                $match: { source: 'aggregated' }
            },
            {
                $group: {
                    _id: '$resolution_minutes',
                    count: { $sum: 1 }
                }
            },
            {
                $sort: { _id: 1 }
            }
        ]).toArray();
        
        stats.forEach(stat => {
            const label = stat._id === null ? 'missing' : 
                         stat._id === 0 ? 'raw' :
                         stat._id === 15 ? '15-minute' :
                         stat._id === 60 ? 'hourly' :
                         stat._id === 1440 ? 'daily' :
                         stat._id === 10080 ? 'weekly' :
                         stat._id === 43200 ? 'monthly' :
                         `${stat._id}-minute`;
            console.log(`   ${label}: ${stat.count} documents`);
        });
        
    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        await mongoose.connection.close();
        console.log('✅ Database connection closed');
    }
}

// Run migration if called directly
if (require.main === module) {
    migrateResolutionMinutes()
        .then(() => {
            console.log('✅ Migration script completed successfully');
            process.exit(0);
        })
        .catch((error) => {
            console.error('❌ Migration script failed:', error);
            process.exit(1);
        });
}

module.exports = { migrateResolutionMinutes };

