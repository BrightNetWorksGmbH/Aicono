const mongoose = require('mongoose');

/**
 * Measurement Aggregation Service
 * 
 * Handles aggregation of real-time measurements into different time resolutions:
 * - 15-minute aggregates (from raw data)
 * - Hourly aggregates (from 15-minute data)
 * - Daily aggregates (from hourly data)
 * 
 * This service reduces storage requirements by ~96% while maintaining
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
                    // For energy meters: consumption = last - first
                    // For other types: use average
                    value: {
                        $cond: {
                            if: { $eq: ['$_id.measurementType', 'Energy'] },
                            then: { $subtract: ['$lastValue', '$firstValue'] },
                            else: '$avgValue'
                        }
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
            const dataCount = await db.collection('measurements').countDocuments(matchStage);
            console.log(`[AGGREGATION] [15-min] Found ${dataCount} raw data points to aggregate (${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()})`);
            
            if (dataCount === 0) {
                // Check if there's any raw data at all (even if too recent)
                const allRawDataCount = await db.collection('measurements').countDocuments({
                    resolution_minutes: 0,
                    ...(buildingId ? {
                        'meta.buildingId': { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        }
                    } : {})
                });
                
                // Check for data in the current incomplete window
                const currentWindowStart = safeAggregationEnd;
                const currentWindowEnd = new Date(safeAggregationEnd.getTime() + 15 * 60 * 1000);
                const currentWindowCount = await db.collection('measurements').countDocuments({
                    resolution_minutes: 0,
                    timestamp: { $gte: currentWindowStart, $lt: currentWindowEnd },
                    ...(buildingId ? {
                        'meta.buildingId': { 
                            $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
                        }
                    } : {})
                });
                
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
                
                if (aggregatedDocs.length === 0) {
                    console.log(`[AGGREGATION] [15-min] No aggregates to insert`);
                } else {
                    // Show sample
                    console.log(`[AGGREGATION] [15-min] Sample aggregate:`, JSON.stringify(aggregatedDocs[0], null, 2).substring(0, 200));
                    
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
                    
                    // Insert new aggregates using insertMany
                    try {
                        const insertResult = await db.collection('measurements').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                        console.log(`[AGGREGATION] [15-min] Inserted ${count} aggregates into Time Series collection`);
                    } catch (error) {
                        // Handle partial inserts
                        if (error.insertedCount) {
                            count = error.insertedCount;
                            console.log(`[AGGREGATION] [15-min] Inserted ${count} aggregates (some duplicates may have been skipped)`);
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
                    // For energy: sum consumption, for others: average
                    value: {
                        $sum: {
                            $cond: [
                                { $eq: ['$meta.measurementType', 'Energy'] },
                                '$value',
                                0
                            ]
                        }
                    },
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
                    value: {
                        $cond: {
                            if: { $eq: ['$_id.measurementType', 'Energy'] },
                            then: '$value',
                            else: '$avgValue'
                        }
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
            
            return { success: true, count, buildingId };
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
                    value: {
                        $sum: {
                            $cond: [
                                { $eq: ['$meta.measurementType', 'Energy'] },
                                '$value',
                                0
                            ]
                        }
                    },
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
                    value: {
                        $cond: {
                            if: { $eq: ['$_id.measurementType', 'Energy'] },
                            then: '$value',
                            else: '$avgValue'
                        }
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
            
            return { success: true, count, buildingId };
        } catch (error) {
            console.error(`[AGGREGATION] [Daily] Error:`, error.message);
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
}

module.exports = new MeasurementAggregationService();

