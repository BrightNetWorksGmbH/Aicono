const mongoose = require('mongoose');
const { isConnectionHealthy } = require('../db/connection');

/**
 * Measurement Aggregation Service
 * 
 * Handles aggregation of real-time measurements into different time resolutions:
 * - 15-minute aggregates (from raw data) - resolution_minutes: 15
 * - Hourly aggregates (from 15-minute data) - resolution_minutes: 60
 * - Daily aggregates (from hourly data) - resolution_minutes: 1440
 * - Weekly aggregates (from daily data) - resolution_minutes: 10080
 * - Monthly aggregates (from weekly/daily data) - resolution_minutes: 43200
 * 
 * Data Retention Strategy:
 * - Raw data (0): Deleted immediately after 15-min aggregation (with buffer)
 * - 15-minute (15): Deleted when hourly aggregation runs (older than 1 hour)
 * - Hourly (60): Deleted when weekly aggregation runs (older than 1 week)
 * - Daily (1440): Kept for long-term storage
 * - Weekly (10080): Kept for long-term storage
 * - Monthly (43200): Kept indefinitely
 * 
 * This service reduces storage requirements by ~99% while maintaining
 * data integrity for reporting purposes.
 */
class MeasurementAggregationService {
    /**
     * Get the actual database name from connection string or connection
     */
    getDatabaseName() {
        // Try to get from connection string first
        const uri = process.env.MONGODB_URI || mongoose.connection.client?.s?.url;
        if (uri) {
            // Parse database name from connection string
            // Format: mongodb://host/dbname or mongodb+srv://host/dbname
            const match = uri.match(/\/([^/?]+)(\?|$)/);
            if (match && match[1] && match[1] !== 'admin') {
                return match[1];
            }
        }
        
        // Fallback: try to get from mongoose connection
        const dbName = mongoose.connection.name;
        if (dbName && dbName !== 'admin') {
            return dbName;
        }
        
        // Last resort: get from db object
        const db = mongoose.connection.db;
        if (db) {
            const dbNameFromDb = db.databaseName;
            if (dbNameFromDb && dbNameFromDb !== 'admin') {
                return dbNameFromDb;
            }
        }
        
        // If all else fails, return null - we'll omit database in $merge
        return null;
    }

    /**
     * Check if a collection is a Time Series collection
     */
    async isTimeSeriesCollection(db, collectionName) {
        try {
            const collections = await db.listCollections({ name: collectionName }).toArray();
            if (collections.length === 0) {
                return false;
            }
            const collectionInfo = collections[0];
            const options = collectionInfo.options || {};
            const timeseries = options.timeseries || {};
            return !!(timeseries && timeseries.timeField);
        } catch (error) {
            console.warn(`[AGGREGATION] Error checking if collection is Time Series:`, error.message);
            return false;
        }
    }
    /**
     * Aggregate raw measurements into 15-minute buckets
     * 
     * @param {string|null} buildingId - Optional building ID to filter aggregation
     * @param {boolean} deleteAfterAggregation - Whether to delete raw data after aggregation (default: true)
     * @param {number} bufferMinutes - Safety buffer to keep raw data (default: 30 minutes)
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregate15Minutes(buildingId = null, deleteAfterAggregation = true, bufferMinutes = 30) {
        // Helper function for retrying database queries with timeout handling
        const queryWithRetry = async (queryFn, retries = 3) => {
            while (retries > 0) {
                try {
                    return await queryFn();
                } catch (error) {
                    if ((error.message.includes('timeout') || error.message.includes('timed out')) && retries > 1) {
                        const remaining = retries - 1;
                        console.warn(`[AGGREGATION] [15-min] Query timeout, retrying... (${remaining} attempts left)`);
                        await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds before retry
                        retries--;
                    } else {
                        throw error;
                    }
                }
            }
        };
        
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new Error('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        // Get the database name - check if it's 'admin' (which MongoDB doesn't allow $merge to)
        const dbName = this.getDatabaseName();
        const currentDbName = mongoose.connection.name || db.databaseName;
        const isAdminDb = currentDbName === 'admin';
        
        if (isAdminDb) {
            console.warn(
                '[AGGREGATION] WARNING: Using "admin" database. MongoDB restricts $merge operations. ' +
                'Using workaround with temporary collection. ' +
                'RECOMMENDED: Update MONGODB_URI to use a different database name. ' +
                'Example: mongodb+srv://...@host/your_database_name?authSource=admin&...'
            );
        }
        
        console.log(`[AGGREGATION] Database name: ${dbName || currentDbName || 'using current database context'}`);

        // Check if measurements collection is a Time Series collection
        const isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements');
        if (isTimeSeries) {
            console.log(`[AGGREGATION] [15-min] Detected Time Series collection - will use direct inserts instead of $merge`);
        }

        const now = new Date();
        
        // The end of aggregation window is the start of the CURRENT 15-minute bucket
        // This ensures we only aggregate COMPLETE 15-minute windows
        const safeAggregationEnd = this.roundTo15Minutes(now);
        
        // Look back 24 hours for any un-aggregated raw data
        // The $merge with 'replace' will handle re-running on same data safely
        const lookbackHours = 24;
        const bucketStart = new Date(safeAggregationEnd.getTime() - lookbackHours * 60 * 60 * 1000);
        
        console.log(`[AGGREGATION] [15-min] Time window: ${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()}`);
        
        // Skip if we're at the very start of a 15-minute window (no complete window yet)
        if (safeAggregationEnd.getTime() === this.roundTo15Minutes(new Date(now.getTime() - 1000)).getTime()) {
            // We just started a new window, check if we have any data to aggregate at all
            console.log(`[AGGREGATION] [15-min] At start of new 15-minute window, checking for data...`);
        }
        
        const matchStage = {
            resolution_minutes: 0, // Only aggregate raw data (field is at root level, not in meta)
            timestamp: { $gte: bucketStart, $lt: safeAggregationEnd }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            // Match both string and ObjectId for backwards compatibility
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        buildingId: '$meta.buildingId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        bucket: {
                            $dateTrunc: {
                                date: '$timestamp',
                                unit: 'minute',
                                binSize: 15
                            }
                        }
                    },
                    // Statistics
                    avgValue: { $avg: '$value' },
                    minValue: { $min: '$value' },
                    maxValue: { $max: '$value' },
                    firstValue: { $first: '$value' },
                    lastValue: { $last: '$value' },
                    count: { $sum: 1 },
                    // Metadata
                    unit: { $first: '$unit' },
                    quality: { $avg: '$quality' }
                }
            },
            {
                $project: {
                    _id: 0,
                    timestamp: '$_id.bucket',
                    meta: {
                        sensorId: '$_id.sensorId',
                        buildingId: '$_id.buildingId',
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType'
                    },
                    // Aggregation strategy based on measurementType AND stateType:
                    // - Power (actual* states): use average (instantaneous values)
                    // - Energy (total* states): use last - first (cumulative counter consumption)
                    // - All others: use average
                    value: {
                        $cond: [
                            // Case 1: Energy (total* states) → consumption = last - first
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                            { $eq: ['$_id.stateType', 'totalYear'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] },
                                            { $eq: ['$_id.stateType', 'totalNegDay'] },
                                            { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                            { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                            { $eq: ['$_id.stateType', 'totalNegYear'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Energy consumption calculation with reset detection
                                $let: {
                                    vars: {
                                        consumption: { $subtract: ['$lastValue', '$firstValue'] },
                                        resetThreshold: 100 // Threshold to detect significant resets
                                    },
                                    in: {
                                        $cond: {
                                            // If consumption < 0 AND firstValue > threshold: reset detected
                                            if: {
                                                $and: [
                                                    { $lt: ['$$consumption', 0] },
                                                    { $gt: ['$firstValue', '$$resetThreshold'] }
                                                ]
                                            },
                                            then: '$lastValue', // Reset detected: consumption = lastValue (new period started at 0)
                                            else: {
                                                // Normal case: consumption = last - first (ensure non-negative)
                                                $max: [
                                                    0,
                                                    '$$consumption'
                                                ]
                                            }
                                        }
                                    }
                                }
                            },
                            // Case 2: Power (actual* states) → average
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Power'] },
                                            {
                                                $regexMatch: {
                                                    input: '$_id.stateType',
                                                    regex: '^actual'
                                                }
                                            }
                                        ]
                                    },
                                    '$avgValue',
                                    // Case 3: Water/Gas (if cumulative total* states) → consumption = last - first
                                    {
                                        $cond: [
                                            {
                                                $and: [
                                                    {
                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                    },
                                                    {
                                                        $or: [
                                                            { $eq: ['$_id.stateType', 'total'] },
                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                // Water/Gas consumption with reset detection
                                                $let: {
                                                    vars: {
                                                        consumption: { $subtract: ['$lastValue', '$firstValue'] },
                                                        resetThreshold: 10 // Lower threshold for water/gas
                                                    },
                                                    in: {
                                                        $cond: {
                                                            if: {
                                                                $and: [
                                                                    { $lt: ['$$consumption', 0] },
                                                                    { $gt: ['$firstValue', '$$resetThreshold'] }
                                                                ]
                                                            },
                                                            then: '$lastValue',
                                                            else: {
                                                                $max: [0, '$$consumption']
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            // Case 4: All others (Temperature, Humidity, etc.) → average
                                            '$avgValue'
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    // Add hasReset flag for debugging (Energy and Water/Gas only)
                    hasReset: {
                        $cond: [
                            {
                                $and: [
                                    {
                                        $in: ['$_id.measurementType', ['Energy', 'Water', 'Heating']]
                                    },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                            { $eq: ['$_id.stateType', 'totalYear'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] },
                                            { $eq: ['$_id.stateType', 'totalNegDay'] },
                                            { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                            { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                            { $eq: ['$_id.stateType', 'totalNegYear'] }
                                        ]
                                    },
                                    {
                                        $and: [
                                            { $lt: [{ $subtract: ['$lastValue', '$firstValue'] }, 0] },
                                            {
                                                $gt: [
                                                    '$firstValue',
                                                    {
                                                        $cond: {
                                                            if: { $eq: ['$_id.measurementType', 'Energy'] },
                                                            then: 100,
                                                            else: 10
                                                        }
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                ]
                            },
                            true,
                            false
                        ]
                    },
                    avgValue: 1,
                    minValue: 1,
                    maxValue: 1,
                    unit: 1,
                    quality: 1,
                    count: 1,
                    source: 'aggregated',
                    resolution_minutes: 15
                }
            },
            // Use $out for admin database (workaround), $merge for others
            ...(isAdminDb ? [
                {
                    $out: 'measurements_aggregated_temp_15min'
                }
            ] : [
            {
                $merge: {
                        // Only specify database if we have a valid database name (not 'admin')
                        into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            }
            ])
        ];
        
        try {
            // First, check if there's any data to aggregate
            const dataCount = await queryWithRetry(() => 
                db.collection('measurements').countDocuments(matchStage)
            );
            console.log(`[AGGREGATION] [15-min] Found ${dataCount} raw data points to aggregate (${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()})`);
            
            if (dataCount === 0) {
                // Check if there's any raw data at all (even if too recent)
                const allRawDataCount = await queryWithRetry(() =>
                    db.collection('measurements').countDocuments({
                        resolution_minutes: 0,
                        ...(buildingId ? {
                            'meta.buildingId': { 
                                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                            }
                        } : {})
                    })
                );
                
                // Check for data in the current incomplete window
                const currentWindowStart = safeAggregationEnd;
                const currentWindowEnd = new Date(safeAggregationEnd.getTime() + 15 * 60 * 1000);
                const currentWindowCount = await queryWithRetry(() =>
                    db.collection('measurements').countDocuments({
                        resolution_minutes: 0,
                        timestamp: { $gte: currentWindowStart, $lt: currentWindowEnd },
                        ...(buildingId ? {
                            'meta.buildingId': { 
                                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                            }
                        } : {})
                    })
                );
                
                if (allRawDataCount > 0) {
                    console.log(`[AGGREGATION] [15-min] No raw data in aggregation window, but found:`);
                    console.log(`   - Total raw data: ${allRawDataCount} documents`);
                    console.log(`   - Data in current incomplete window (${currentWindowStart.toISOString()} to ${currentWindowEnd.toISOString()}): ${currentWindowCount} documents`);
                    console.log(`   - NOTE: Data in current window will be aggregated after ${currentWindowEnd.toISOString()}`);
                    console.log(`   - Aggregation only processes COMPLETE 15-minute windows (data older than ${safeAggregationEnd.toISOString()})`);
                } else {
                    console.log(`[AGGREGATION] [15-min] No raw data found in database`);
                }
                
                return { success: true, count: 0, deleted: 0, buildingId, skipped: true, reason: 'No data in time range' };
            }
            
            // Execute aggregation
            let count = 0;
            if (isAdminDb) {
                // For admin database: use $out to temp collection, then manually upsert
                await db.collection('measurements').aggregate(pipeline).toArray();
                
                // Read from temp collection and upsert to main collection
                const tempCollection = db.collection('measurements_aggregated_temp_15min');
                const aggregatedDocs = await tempCollection.find({}).toArray();
                
                // Ensure resolution_minutes is set (safeguard - always set explicitly)
                aggregatedDocs.forEach(doc => {
                    doc.resolution_minutes = 15;
                });
                
                // Upsert each document
                for (const doc of aggregatedDocs) {
                    const result = await db.collection('measurements').replaceOne(
                        {
                            timestamp: doc.timestamp,
                            'meta.sensorId': doc.meta.sensorId,
                            'meta.buildingId': doc.meta.buildingId,
                            'meta.measurementType': doc.meta.measurementType,
                            'meta.stateType': doc.meta.stateType,
                            resolution_minutes: 15
                        },
                        doc,
                        { upsert: true }
                    );
                    if (result.upsertedCount > 0 || result.modifiedCount > 0) {
                        count++;
                    }
                }
                
                // Clean up temp collection
                await tempCollection.drop().catch(() => {});
                
                console.log(`[AGGREGATION] [15-min] Created ${count} aggregates using workaround (admin database)`);
            } else if (isTimeSeries) {
                // Time Series collection: use direct inserts (can't use $merge on views)
                // Get aggregated results without $merge
                const aggregationPipeline = pipeline.slice(0, -1); // Remove the $merge stage
                console.log(`[AGGREGATION] [15-min] Executing aggregation pipeline for Time Series collection...`);
                const aggregatedDocs = await db.collection('measurements').aggregate(aggregationPipeline).toArray();
                console.log(`[AGGREGATION] [15-min] Pipeline produced ${aggregatedDocs.length} aggregates`);
                
                // Check if pipeline output includes resolution_minutes
                if (aggregatedDocs.length > 0) {
                    const sampleFromPipeline = aggregatedDocs[0];
                    const hasResolutionInPipeline = sampleFromPipeline.hasOwnProperty('resolution_minutes');
                    const resolutionValue = sampleFromPipeline.resolution_minutes;
                    console.log(`[AGGREGATION] [15-min] Pipeline output check: has resolution_minutes=${hasResolutionInPipeline}, value=${resolutionValue}`);
                    if (!hasResolutionInPipeline || resolutionValue !== 15) {
                        console.log(`[AGGREGATION] [15-min] ⚠️  WARNING: Pipeline output missing or incorrect resolution_minutes! Expected: 15, Got: ${resolutionValue}`);
                        console.log(`[AGGREGATION] [15-min] Sample document keys:`, Object.keys(sampleFromPipeline).join(', '));
                    }
                }
                
                if (aggregatedDocs.length === 0) {
                    console.log(`[AGGREGATION] [15-min] No aggregates to insert`);
                } else {
                    // Show sample (full document to verify resolution_minutes is included)
                    const sampleDoc = aggregatedDocs[0];
                    console.log(`[AGGREGATION] [15-min] Sample aggregate:`, JSON.stringify(sampleDoc, null, 2).substring(0, 300));
                    if (!sampleDoc.resolution_minutes) {
                        console.log(`[AGGREGATION] [15-min] ⚠️  WARNING: Sample document is missing resolution_minutes!`);
                    }
                    
                    // Delete existing aggregates in this time window first (to avoid duplicates)
                    const deleteMatchStage = {
                        resolution_minutes: 15,
                        timestamp: { $gte: bucketStart, $lt: safeAggregationEnd }
                    };
                    
                    if (buildingId) {
                        deleteMatchStage['meta.buildingId'] = { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        };
                    }
                    
                    const deleteResult = await db.collection('measurements').deleteMany(deleteMatchStage);
                    console.log(`[AGGREGATION] [15-min] Deleted ${deleteResult.deletedCount} existing aggregates in time window`);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    let missingCount = 0;
                    aggregatedDocs.forEach(doc => {
                        if (!doc.resolution_minutes) {
                            missingCount++;
                        }
                        // Always set explicitly to ensure it's present
                        doc.resolution_minutes = 15;
                    });
                    
                    if (missingCount > 0) {
                        console.log(`[AGGREGATION] [15-min] ⚠️  ${missingCount} documents were missing resolution_minutes (fixed by safeguard)`);
                    }
                    
                    // Verify all documents have resolution_minutes before insertion
                    const allHaveResolution = aggregatedDocs.every(doc => doc.resolution_minutes === 15);
                    if (!allHaveResolution) {
                        console.error(`[AGGREGATION] [15-min] ❌ ERROR: Some documents still missing resolution_minutes after safeguard!`);
                        aggregatedDocs.forEach((doc, idx) => {
                            if (doc.resolution_minutes !== 15) {
                                console.error(`[AGGREGATION] [15-min] Document ${idx} missing resolution_minutes:`, JSON.stringify(doc).substring(0, 200));
                            }
                        });
                    }
                    
                    // Final verification: ensure ALL documents have resolution_minutes before insertion
                    const docsMissingField = aggregatedDocs.filter(doc => doc.resolution_minutes !== 15);
                    if (docsMissingField.length > 0) {
                        console.error(`[AGGREGATION] [15-min] ❌ CRITICAL: ${docsMissingField.length} documents still missing resolution_minutes! Fixing now...`);
                        docsMissingField.forEach((doc, idx) => {
                            doc.resolution_minutes = 15;
                            console.log(`[AGGREGATION] [15-min] Fixed document ${idx}:`, JSON.stringify(doc).substring(0, 150));
                        });
                    }
                    
                    // Double-check: verify all documents now have the field
                    const allHaveField = aggregatedDocs.every(doc => doc.resolution_minutes === 15);
                    if (!allHaveField) {
                        throw new Error(`[AGGREGATION] [15-min] FATAL: Some documents still missing resolution_minutes after all safeguards!`);
                    }
                    
                    // Insert new aggregates using insertMany
                    try {
                        const insertResult = await db.collection('measurements').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                        console.log(`[AGGREGATION] [15-min] Inserted ${count} aggregates into Time Series collection`);
                        console.log(`[AGGREGATION] [15-min] ✅ Verified: All ${count} inserted documents have resolution_minutes: 15`);
                    } catch (error) {
                        // Handle partial inserts
                        if (error.insertedCount) {
                            count = error.insertedCount;
                            console.log(`[AGGREGATION] [15-min] ⚠️  Partial insert: ${count} aggregates inserted (some duplicates may have been skipped)`);
                            console.log(`[AGGREGATION] [15-min] ⚠️  Note: Inserted documents should have resolution_minutes: 15`);
                            // Note: We can't verify which specific documents were inserted in partial failure cases
                        } else {
                            console.error(`[AGGREGATION] [15-min] Error inserting aggregates:`, error.message);
                            throw error;
                        }
                    }
                }
            } else {
                // Normal flow: use $merge (for regular collections)
                // First, test the aggregation pipeline without $merge to see if it produces results
                const testPipeline = pipeline.slice(0, -1); // Remove the $merge stage
                console.log(`[AGGREGATION] [15-min] Testing aggregation pipeline (without $merge)...`);
                const testResults = await db.collection('measurements').aggregate(testPipeline).toArray();
                console.log(`[AGGREGATION] [15-min] Pipeline would produce ${testResults.length} aggregates`);
                
                if (testResults.length === 0) {
                    console.log(`[AGGREGATION] [15-min] WARNING: Aggregation pipeline produces no results!`);
                    console.log(`[AGGREGATION] [15-min] This might indicate an issue with the grouping or data structure.`);
                } else {
                    // Show sample of what would be created
                    console.log(`[AGGREGATION] [15-min] Sample aggregate:`, JSON.stringify(testResults[0], null, 2).substring(0, 200));
                }
                
                // Now execute the full pipeline with $merge
                console.log(`[AGGREGATION] [15-min] Executing aggregation pipeline with $merge...`);
                const cursor = db.collection('measurements').aggregate(pipeline);
                await cursor.toArray(); // This will execute the pipeline even though it returns empty
                
                // Count aggregates in the time window (this includes both new and existing)
                const aggregateMatchStage = {
                    resolution_minutes: 15,
                    timestamp: { $gte: bucketStart, $lt: safeAggregationEnd }
                };
                
                if (buildingId) {
                    aggregateMatchStage['meta.buildingId'] = { 
                        $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                    };
                }
                
                const totalAggregates = await db.collection('measurements').countDocuments(aggregateMatchStage);
                count = testResults.length; // Use the count from the test pipeline
                console.log(`[AGGREGATION] [15-min] Created/updated ${count} aggregates (total in window: ${totalAggregates})`);
            }
            
            // Success logging - visible in terminal
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [15-min] SUCCESS!`);
            console.log(`   Created ${count} aggregates`);
            console.log(`   Building: ${buildingId || 'all buildings'}`);
            console.log(`   Window: ${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()}`);
            console.log(`   Raw data points processed: ${dataCount}`);
            console.log(`   Note: Meter resets (negative consumption) are automatically set to 0`);
            console.log(`========================================\n`);
            
            let deletedCount = 0;
            
            // Delete raw data that was just aggregated (only if deleteAfterAggregation is true)
            if (deleteAfterAggregation && count > 0) {
                // Calculate the cutoff: only delete data older than bufferMinutes
                const bufferCutoff = new Date(now.getTime() - bufferMinutes * 60 * 1000);
                
                // Only delete data that:
                // 1. Was in the aggregated time range (bucketStart to safeAggregationEnd)
                // 2. Is older than the buffer cutoff (safety check)
                const deleteCutoff = new Date(Math.min(safeAggregationEnd.getTime(), bufferCutoff.getTime()));
                
                if (deleteCutoff > bucketStart) {
                    const deleteMatchStage = {
                        resolution_minutes: 0, // Field is at root level, not in meta
                        timestamp: { 
                            $gte: bucketStart, 
                            $lt: deleteCutoff  // Only delete up to the cutoff
                        }
                    };
                    
                    if (buildingId) {
                        // Match both string and ObjectId for backwards compatibility
                        deleteMatchStage['meta.buildingId'] = { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        };
                    }
                    
                    try {
                        const deleteResult = await db.collection('measurements').deleteMany(deleteMatchStage);
                        deletedCount = deleteResult.deletedCount;
                        console.log(`[AGGREGATION] [15-min] Deleted ${deletedCount} raw data points (${bucketStart.toISOString()} to ${deleteCutoff.toISOString()})`);
                    } catch (deleteError) {
                        console.error(`[AGGREGATION] [15-min] Error deleting raw data:`, deleteError.message);
                        // Don't throw - aggregation succeeded, deletion is secondary
                    }
                } else {
                    console.log(`[AGGREGATION] [15-min] Skipping deletion: Data is within ${bufferMinutes}-minute safety buffer`);
                }
            }
            
            return { 
                success: true, 
                count, 
                deleted: deletedCount,
                aggregationWindow: {
                    start: bucketStart.toISOString(),
                    end: safeAggregationEnd.toISOString()
                },
                buildingId 
            };
        } catch (error) {
            console.error(`[AGGREGATION] [15-min] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate 15-minute data into hourly buckets
     * 
     * @param {string|null} buildingId - Optional building ID to filter aggregation
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateHourly(buildingId = null) {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new Error('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        // Get the database name - if null, we'll omit it from $merge (uses current database)
        const dbName = this.getDatabaseName();
        
        // Check if measurements collection is a Time Series collection
        const isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements');

        const now = new Date();
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
        
        const bucketStart = this.roundToHour(oneHourAgo);
        const bucketEnd = this.roundToHour(now);
        
        const matchStage = {
            resolution_minutes: 15, // Field is at root level, not in meta
            timestamp: { $gte: bucketStart, $lt: bucketEnd }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            // Match both string and ObjectId for backwards compatibility
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        buildingId: '$meta.buildingId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        bucket: {
                            $dateTrunc: {
                                date: '$timestamp',
                                unit: 'hour'
                            }
                        }
                    },
                    // Aggregate from 15-minute aggregates:
                    // - Energy (total* states): sum consumption values
                    // - Power (actual* states): average power values
                    // - Others: average
                    firstValue: { $first: '$value' },
                    lastValue: { $last: '$value' },
                    sumValue: { $sum: '$value' },
                    avgValue: { $avg: '$avgValue' },
                    minValue: { $min: '$minValue' },
                    maxValue: { $max: '$maxValue' },
                    count: { $sum: '$count' },
                    unit: { $first: '$unit' },
                    quality: { $avg: '$quality' }
                }
            },
            {
                $project: {
                    _id: 0,
                    timestamp: '$_id.bucket',
                    meta: {
                        sensorId: '$_id.sensorId',
                        buildingId: '$_id.buildingId',
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType'
                    },
                    // Aggregation strategy for hourly from 15-minute aggregates:
                    // - Energy (total* states): sum consumption from 15-min aggregates
                    // - Power (actual* states): average power from 15-min aggregates
                    // - Others: average
                    value: {
                        $cond: [
                            // Case 1: Energy (total* states) → sum consumption
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                            { $eq: ['$_id.stateType', 'totalYear'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] },
                                            { $eq: ['$_id.stateType', 'totalNegDay'] },
                                            { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                            { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                            { $eq: ['$_id.stateType', 'totalNegYear'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Sum consumption from 15-minute aggregates (ensure non-negative)
                                $max: [0, '$sumValue']
                            },
                            // Case 2: Power (actual* states) → average
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Power'] },
                                            {
                                                $regexMatch: {
                                                    input: '$_id.stateType',
                                                    regex: '^actual'
                                                }
                                            }
                                        ]
                                    },
                                    '$avgValue',
                                    // Case 3: Water/Gas (total* states) → sum consumption
                                    {
                                        $cond: [
                                            {
                                                $and: [
                                                    {
                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                    },
                                                    {
                                                        $or: [
                                                            { $eq: ['$_id.stateType', 'total'] },
                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                $max: [0, '$sumValue']
                                            },
                                            // Case 4: All others → average
                                            '$avgValue'
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    avgValue: 1,
                    minValue: 1,
                    maxValue: 1,
                    unit: 1,
                    quality: 1,
                    count: 1,
                    source: 'aggregated',
                    resolution_minutes: 60
                }
            },
            {
                $merge: {
                    // Only specify database if we have a valid database name (not 'admin')
                    // Otherwise, MongoDB will use the current database context
                    into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            }
        ];
        
        try {
            let count = 0;
            
            if (isTimeSeries) {
                // Time Series collection: use direct inserts
                const aggregationPipeline = pipeline.slice(0, -1); // Remove the $merge stage
                const aggregatedDocs = await db.collection('measurements').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing hourly aggregates in this time window
                    const deleteMatchStage = {
                        resolution_minutes: 60,
                        timestamp: { $gte: bucketStart, $lt: bucketEnd }
                    };
                    
                    if (buildingId) {
                        deleteMatchStage['meta.buildingId'] = { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        };
                    }
                    
                    await db.collection('measurements').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 60;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Hourly] Created ${count} aggregates for ${buildingId || 'all buildings'} (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Hourly] Created ${count} aggregates for ${buildingId || 'all buildings'}`);
            }
            
            // Delete 15-minute aggregates older than 1 hour (now that we have hourly aggregates)
            // This prevents database bloat from accumulating 15-minute data
            // We only need 15-minute data for the current hour to create hourly aggregates
            let deleted15MinCount = 0;
            if (count > 0) {
                const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
                deleted15MinCount = await this.deleteOldAggregates(15, oneHourAgo, buildingId);
                if (deleted15MinCount > 0) {
                    console.log(`[AGGREGATION] [Hourly] Deleted ${deleted15MinCount} old 15-minute aggregates (older than 1 hour)`);
                }
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Hourly] SUCCESS!`);
            console.log(`   Created ${count} hourly aggregates`);
            if (deleted15MinCount > 0) {
                console.log(`   Deleted ${deleted15MinCount} old 15-minute aggregates (older than 1 hour)`);
            }
            console.log(`   Building: ${buildingId || 'all buildings'}`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count, 
                deleted: deleted15MinCount,
                buildingId 
            };
        } catch (error) {
            console.error(`[AGGREGATION] [Hourly] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate hourly data into daily buckets
     * 
     * @param {string|null} buildingId - Optional building ID to filter aggregation
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateDaily(buildingId = null) {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new Error('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        // Get the database name - if null, we'll omit it from $merge (uses current database)
        const dbName = this.getDatabaseName();
        
        // Check if measurements collection is a Time Series collection
        const isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements');

        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        yesterday.setHours(0, 0, 0, 0);
        
        const today = new Date(yesterday);
        today.setDate(today.getDate() + 1);
        
        const matchStage = {
            resolution_minutes: 60, // Field is at root level, not in meta
            timestamp: { $gte: yesterday, $lt: today }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            // Match both string and ObjectId for backwards compatibility
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        buildingId: '$meta.buildingId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        bucket: {
                            $dateTrunc: {
                                date: '$timestamp',
                                unit: 'day'
                            }
                        }
                    },
                    // Aggregate from hourly aggregates:
                    // - Energy (total* states): sum consumption values
                    // - Power (actual* states): average power values
                    // - Others: average
                    sumValue: { $sum: '$value' },
                    avgValue: { $avg: '$avgValue' },
                    minValue: { $min: '$minValue' },
                    maxValue: { $max: '$maxValue' },
                    count: { $sum: '$count' },
                    unit: { $first: '$unit' },
                    quality: { $avg: '$quality' }
                }
            },
            {
                $project: {
                    _id: 0,
                    timestamp: '$_id.bucket',
                    meta: {
                        sensorId: '$_id.sensorId',
                        buildingId: '$_id.buildingId',
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType'
                    },
                    // Aggregation strategy for daily from hourly aggregates:
                    // - Energy (total* states): sum consumption from hourly aggregates
                    // - Power (actual* states): average power from hourly aggregates
                    // - Others: average
                    value: {
                        $cond: [
                            // Case 1: Energy (total* states) → sum consumption
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                            { $eq: ['$_id.stateType', 'totalYear'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] },
                                            { $eq: ['$_id.stateType', 'totalNegDay'] },
                                            { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                            { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                            { $eq: ['$_id.stateType', 'totalNegYear'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Sum consumption from hourly aggregates (ensure non-negative)
                                $max: [0, '$sumValue']
                            },
                            // Case 2: Power (actual* states) → average
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Power'] },
                                            {
                                                $regexMatch: {
                                                    input: '$_id.stateType',
                                                    regex: '^actual'
                                                }
                                            }
                                        ]
                                    },
                                    '$avgValue',
                                    // Case 3: Water/Gas (total* states) → sum consumption
                                    {
                                        $cond: [
                                            {
                                                $and: [
                                                    {
                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                    },
                                                    {
                                                        $or: [
                                                            { $eq: ['$_id.stateType', 'total'] },
                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                $max: [0, '$sumValue']
                                            },
                                            // Case 4: All others → average
                                            '$avgValue'
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    avgValue: 1,
                    minValue: 1,
                    maxValue: 1,
                    unit: 1,
                    quality: 1,
                    count: 1,
                    source: 'aggregated',
                    resolution_minutes: 1440
                }
            },
            {
                $merge: {
                    // Only specify database if we have a valid database name (not 'admin')
                    // Otherwise, MongoDB will use the current database context
                    into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            }
        ];
        
        try {
            let count = 0;
            
            if (isTimeSeries) {
                // Time Series collection: use direct inserts
                const aggregationPipeline = pipeline.slice(0, -1); // Remove the $merge stage
                const aggregatedDocs = await db.collection('measurements').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing daily aggregates for yesterday
                    const deleteMatchStage = {
                        resolution_minutes: 1440,
                        timestamp: { $gte: yesterday, $lt: today }
                    };
                    
                    if (buildingId) {
                        deleteMatchStage['meta.buildingId'] = { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        };
                    }
                    
                    await db.collection('measurements').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 1440;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Daily] Created ${count} aggregates for ${buildingId || 'all buildings'} (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Daily] Created ${count} aggregates for ${buildingId || 'all buildings'}`);
            }
            
            // Delete 15-minute aggregates older than 1 day (now that we have daily aggregates)
            let deleted15MinCount = 0;
            if (count > 0) {
                // Delete 15-minute aggregates older than yesterday (1 day ago)
                const oneDayAgo = this.roundToDay(new Date(yesterday.getTime() - 24 * 60 * 60 * 1000));
                deleted15MinCount = await this.deleteOldAggregates(15, oneDayAgo, buildingId);
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Daily] SUCCESS!`);
            console.log(`   Created ${count} daily aggregates`);
            console.log(`   Deleted ${deleted15MinCount} old 15-minute aggregates (older than 1 day)`);
            console.log(`   Building: ${buildingId || 'all buildings'}`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count, 
                deleted: deleted15MinCount,
                buildingId 
            };
        } catch (error) {
            console.error(`[AGGREGATION] [Daily] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate daily data into weekly buckets
     * Also deletes hourly aggregates older than 1 week
     * 
     * @param {string|null} buildingId - Optional building ID to filter aggregation
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateWeekly(buildingId = null) {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new Error('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        // Get the database name
        const dbName = this.getDatabaseName();
        
        // Check if measurements collection is a Time Series collection
        const isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements');

        const now = new Date();
        const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        
        const weekStart = this.roundToWeek(oneWeekAgo);
        const currentWeekStart = this.roundToWeek(now);
        
        const matchStage = {
            resolution_minutes: 1440, // Aggregate from daily data
            timestamp: { $gte: weekStart, $lt: currentWeekStart }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $addFields: {
                    // Calculate week start (Monday)
                    // dayOfWeek: 1=Sunday, 2=Monday, ..., 7=Saturday
                    // We want to go back to Monday (day 2)
                    daysToMonday: {
                        $cond: {
                            if: { $eq: [{ $dayOfWeek: '$timestamp' }, 1] }, // Sunday
                            then: 6, // Go back 6 days to Monday
                            else: { $subtract: [{ $dayOfWeek: '$timestamp' }, 2] } // Otherwise subtract to get to Monday
                        }
                    }
                }
            },
            {
                $addFields: {
                    weekStart: {
                        $dateSubtract: {
                            startDate: {
                                $dateFromParts: {
                                    year: { $year: '$timestamp' },
                                    month: { $month: '$timestamp' },
                                    day: { $dayOfMonth: '$timestamp' },
                                    hour: 0,
                                    minute: 0,
                                    second: 0
                                }
                            },
                            unit: 'day',
                            amount: '$daysToMonday'
                        }
                    }
                }
            },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        buildingId: '$meta.buildingId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        bucket: '$weekStart'
                    },
                    // Aggregate from daily aggregates:
                    // - Energy (total* states): sum consumption values
                    // - Power (actual* states): average power values
                    // - Others: average
                    sumValue: { $sum: '$value' },
                    avgValue: { $avg: '$avgValue' },
                    minValue: { $min: '$minValue' },
                    maxValue: { $max: '$maxValue' },
                    count: { $sum: '$count' },
                    unit: { $first: '$unit' },
                    quality: { $avg: '$quality' }
                }
            },
            {
                $project: {
                    _id: 0,
                    timestamp: '$_id.bucket',
                    meta: {
                        sensorId: '$_id.sensorId',
                        buildingId: '$_id.buildingId',
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType'
                    },
                    // Aggregation strategy for weekly from daily aggregates:
                    // - Energy (total* states): sum consumption from daily aggregates
                    // - Power (actual* states): average power from daily aggregates
                    // - Others: average
                    value: {
                        $cond: [
                            // Case 1: Energy (total* states) → sum consumption
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                            { $eq: ['$_id.stateType', 'totalYear'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] },
                                            { $eq: ['$_id.stateType', 'totalNegDay'] },
                                            { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                            { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                            { $eq: ['$_id.stateType', 'totalNegYear'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Sum consumption from daily aggregates (ensure non-negative)
                                $max: [0, '$sumValue']
                            },
                            // Case 2: Power (actual* states) → average
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Power'] },
                                            {
                                                $regexMatch: {
                                                    input: '$_id.stateType',
                                                    regex: '^actual'
                                                }
                                            }
                                        ]
                                    },
                                    '$avgValue',
                                    // Case 3: Water/Gas (total* states) → sum consumption
                                    {
                                        $cond: [
                                            {
                                                $and: [
                                                    {
                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                    },
                                                    {
                                                        $or: [
                                                            { $eq: ['$_id.stateType', 'total'] },
                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                $max: [0, '$sumValue']
                                            },
                                            // Case 4: All others → average
                                            '$avgValue'
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    avgValue: 1,
                    minValue: 1,
                    maxValue: 1,
                    unit: 1,
                    quality: 1,
                    count: 1,
                    source: 'aggregated',
                    resolution_minutes: 10080 // 7 days * 24 hours * 60 minutes = 10080
                }
            },
            {
                $merge: {
                    into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            }
        ];
        
        try {
            let count = 0;
            
            if (isTimeSeries) {
                // Time Series collection: use direct inserts
                const aggregationPipeline = pipeline.slice(0, -1);
                const aggregatedDocs = await db.collection('measurements').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing weekly aggregates in this time window
                    const deleteMatchStage = {
                        resolution_minutes: 10080,
                        timestamp: { $gte: weekStart, $lt: currentWeekStart }
                    };
                    
                    if (buildingId) {
                        deleteMatchStage['meta.buildingId'] = { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        };
                    }
                    
                    await db.collection('measurements').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 10080;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Weekly] Created ${count} aggregates for ${buildingId || 'all buildings'} (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Weekly] Created ${count} aggregates for ${buildingId || 'all buildings'}`);
            }
            
            // Delete hourly aggregates older than 1 week (now that we have weekly aggregates)
            let deletedHourlyCount = 0;
            if (count > 0) {
                const oneWeekAgoCutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                deletedHourlyCount = await this.deleteOldAggregates(60, oneWeekAgoCutoff, buildingId);
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Weekly] SUCCESS!`);
            console.log(`   Created ${count} weekly aggregates`);
            console.log(`   Deleted ${deletedHourlyCount} old hourly aggregates (older than 1 week)`);
            console.log(`   Building: ${buildingId || 'all buildings'}`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count, 
                deleted: deletedHourlyCount,
                buildingId 
            };
        } catch (error) {
            console.error(`[AGGREGATION] [Weekly] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate daily/weekly data into monthly buckets
     * 
     * @param {string|null} buildingId - Optional building ID to filter aggregation
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateMonthly(buildingId = null) {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new Error('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        // Get the database name
        const dbName = this.getDatabaseName();
        
        // Check if measurements collection is a Time Series collection
        const isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements');

        const now = new Date();
        const oneMonthAgo = new Date(now);
        oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);
        
        const monthStart = this.roundToMonth(oneMonthAgo);
        const currentMonthStart = this.roundToMonth(now);
        
        // Try to aggregate from weekly data first, fallback to daily
        const matchStage = {
            $or: [
                { resolution_minutes: 10080 }, // Weekly
                { resolution_minutes: 1440 }   // Daily (fallback)
            ],
            timestamp: { $gte: monthStart, $lt: currentMonthStart }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $addFields: {
                    // Calculate month start
                    monthStart: {
                        $dateFromParts: {
                            year: { $year: '$timestamp' },
                            month: { $month: '$timestamp' },
                            day: 1,
                            hour: 0,
                            minute: 0,
                            second: 0
                        }
                    }
                }
            },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        buildingId: '$meta.buildingId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        bucket: '$monthStart'
                    },
                    // Aggregate from weekly/daily aggregates:
                    // - Energy (total* states): sum consumption values
                    // - Power (actual* states): average power values
                    // - Others: average
                    sumValue: { $sum: '$value' },
                    avgValue: { $avg: '$avgValue' },
                    minValue: { $min: '$minValue' },
                    maxValue: { $max: '$maxValue' },
                    count: { $sum: '$count' },
                    unit: { $first: '$unit' },
                    quality: { $avg: '$quality' }
                }
            },
            {
                $project: {
                    _id: 0,
                    timestamp: '$_id.bucket',
                    meta: {
                        sensorId: '$_id.sensorId',
                        buildingId: '$_id.buildingId',
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType'
                    },
                    // Aggregation strategy for monthly from weekly/daily aggregates:
                    // - Energy (total* states): sum consumption from weekly/daily aggregates
                    // - Power (actual* states): average power from weekly/daily aggregates
                    // - Others: average
                    value: {
                        $cond: [
                            // Case 1: Energy (total* states) → sum consumption
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                            { $eq: ['$_id.stateType', 'totalYear'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] },
                                            { $eq: ['$_id.stateType', 'totalNegDay'] },
                                            { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                            { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                            { $eq: ['$_id.stateType', 'totalNegYear'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Sum consumption from weekly/daily aggregates (ensure non-negative)
                                $max: [0, '$sumValue']
                            },
                            // Case 2: Power (actual* states) → average
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Power'] },
                                            {
                                                $regexMatch: {
                                                    input: '$_id.stateType',
                                                    regex: '^actual'
                                                }
                                            }
                                        ]
                                    },
                                    '$avgValue',
                                    // Case 3: Water/Gas (total* states) → sum consumption
                                    {
                                        $cond: [
                                            {
                                                $and: [
                                                    {
                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                    },
                                                    {
                                                        $or: [
                                                            { $eq: ['$_id.stateType', 'total'] },
                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                        ]
                                                    }
                                                ]
                                            },
                                            {
                                                $max: [0, '$sumValue']
                                            },
                                            // Case 4: All others → average
                                            '$avgValue'
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
                    avgValue: 1,
                    minValue: 1,
                    maxValue: 1,
                    unit: 1,
                    quality: 1,
                    count: 1,
                    source: 'aggregated',
                    resolution_minutes: 43200 // ~30 days * 24 hours * 60 minutes = 43200
                }
            },
            {
                $merge: {
                    into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            }
        ];
        
        try {
            let count = 0;
            
            if (isTimeSeries) {
                // Time Series collection: use direct inserts
                const aggregationPipeline = pipeline.slice(0, -1);
                const aggregatedDocs = await db.collection('measurements').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing monthly aggregates in this time window
                    const deleteMatchStage = {
                        resolution_minutes: 43200,
                        timestamp: { $gte: monthStart, $lt: currentMonthStart }
                    };
                    
                    if (buildingId) {
                        deleteMatchStage['meta.buildingId'] = { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        };
                    }
                    
                    await db.collection('measurements').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 43200;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Monthly] Created ${count} aggregates for ${buildingId || 'all buildings'} (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Monthly] Created ${count} aggregates for ${buildingId || 'all buildings'}`);
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Monthly] SUCCESS!`);
            console.log(`   Created ${count} monthly aggregates`);
            console.log(`   Building: ${buildingId || 'all buildings'}`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count,
                buildingId 
            };
        } catch (error) {
            console.error(`[AGGREGATION] [Monthly] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Clean up old raw data (keep only last N days)
     * 
     * @param {number} retentionDays - Number of days to keep raw data (default: 30)
     * @param {string|null} buildingId - Optional building ID to filter cleanup
     * @returns {Promise<number>} Number of deleted documents
     */
    async cleanupRawData(retentionDays = 30, buildingId = null) {
        // Check connection health before starting operations
        if (!isConnectionHealthy()) {
            throw new Error('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
        
        const matchStage = {
            resolution_minutes: 0, // Field is at root level, not in meta
            timestamp: { $lt: cutoffDate }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            // Match both string and ObjectId for backwards compatibility
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        try {
            const result = await db.collection('measurements').deleteMany(matchStage);
            console.log(`[AGGREGATION] [Cleanup] Deleted ${result.deletedCount} raw data points older than ${retentionDays} days`);
            return result.deletedCount;
        } catch (error) {
            console.error(`[AGGREGATION] [Cleanup] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Helper: Round date to 15-minute boundary
     * 
     * @param {Date} date - Date to round
     * @returns {Date} Rounded date
     */
    roundTo15Minutes(date) {
        const rounded = new Date(date);
        const minutes = rounded.getMinutes();
        const roundedMinutes = Math.floor(minutes / 15) * 15;
        rounded.setMinutes(roundedMinutes, 0, 0);
        return rounded;
    }
    
    /**
     * Helper: Round date to hour boundary
     * 
     * @param {Date} date - Date to round
     * @returns {Date} Rounded date
     */
    roundToHour(date) {
        const rounded = new Date(date);
        rounded.setMinutes(0, 0, 0);
        return rounded;
    }
    
    /**
     * Helper: Round date to day boundary (start of day)
     * 
     * @param {Date} date - Date to round
     * @returns {Date} Rounded date
     */
    roundToDay(date) {
        const rounded = new Date(date);
        rounded.setUTCHours(0, 0, 0, 0);
        return rounded;
    }
    
    /**
     * Helper: Round date to week boundary (start of week, Monday)
     * 
     * @param {Date} date - Date to round
     * @returns {Date} Rounded date
     */
    roundToWeek(date) {
        const rounded = new Date(date);
        rounded.setUTCHours(0, 0, 0, 0);
        // Get day of week (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
        const dayOfWeek = rounded.getUTCDay();
        // Calculate days to subtract to get to Monday (or Sunday if week starts on Sunday)
        // Using ISO week (Monday = start of week)
        const daysToSubtract = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
        rounded.setUTCDate(rounded.getUTCDate() - daysToSubtract);
        return rounded;
    }
    
    /**
     * Helper: Round date to month boundary (start of month)
     * 
     * @param {Date} date - Date to round
     * @returns {Date} Rounded date
     */
    roundToMonth(date) {
        const rounded = new Date(date);
        rounded.setUTCDate(1);
        rounded.setUTCHours(0, 0, 0, 0);
        return rounded;
    }
    
    /**
     * Modular helper: Delete old aggregates by resolution
     * 
     * @param {number} resolutionMinutes - Resolution to delete (15, 60, etc.)
     * @param {Date} cutoffDate - Delete aggregates older than this date
     * @param {string|null} buildingId - Optional building ID to filter
     * @returns {Promise<number>} Number of deleted documents
     */
    async deleteOldAggregates(resolutionMinutes, cutoffDate, buildingId = null) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        const matchStage = {
            resolution_minutes: resolutionMinutes,
            timestamp: { $lt: cutoffDate }
        };
        
        if (buildingId) {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid buildingId: ${buildingId}`);
            }
            matchStage['meta.buildingId'] = { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            };
        }
        
        try {
            const result = await db.collection('measurements').deleteMany(matchStage);
            const resolutionLabel = this.getResolutionLabel(resolutionMinutes);
            console.log(`[AGGREGATION] [Cleanup] Deleted ${result.deletedCount} ${resolutionLabel} aggregates older than ${cutoffDate.toISOString()}`);
            return result.deletedCount;
        } catch (error) {
            console.error(`[AGGREGATION] [Cleanup] Error deleting ${this.getResolutionLabel(resolutionMinutes)} aggregates:`, error.message);
            throw error;
        }
    }
    
    /**
     * Helper: Get human-readable resolution label
     * 
     * @param {number} resolutionMinutes - Resolution in minutes
     * @returns {string} Human-readable label
     */
    getResolutionLabel(resolutionMinutes) {
        const labels = {
            0: 'raw',
            15: '15-minute',
            60: 'hourly',
            1440: 'daily',
            10080: 'weekly',
            43200: 'monthly'
        };
        return labels[resolutionMinutes] || `${resolutionMinutes}-minute`;
    }
}

module.exports = new MeasurementAggregationService();

