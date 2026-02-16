const mongoose = require('mongoose');
const { isConnectionHealthy } = require('../db/connection');
const deletionQueueService = require('./deletionQueueService');
const measurementCollectionService = require('./measurementCollectionService');
const { ServiceUnavailableError, InternalServerError } = require('../utils/errors');

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
     * Ensure measurements_aggregated collection exists as a Time Series collection
     * If it doesn't exist or is not a Time Series, initializes it properly
     * This prevents MongoDB from auto-creating a regular collection on insert
     * @param {Object} db - MongoDB database instance
     * @param {string} logPrefix - Log prefix for aggregation type (e.g., '[15-min]', '[hourly]')
     * @returns {Promise<boolean>} True if collection is now a Time Series collection
     */
    async ensureTimeSeriesCollection(db, logPrefix = '') {
        let isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements_aggregated');
        
        if (!isTimeSeries) {
            console.log(`[AGGREGATION] ${logPrefix} Collection is not a Time Series - initializing as Time Series collection...`);
            try {
                await measurementCollectionService.initializeAggregatedCollection();
                isTimeSeries = true;
                console.log(`[AGGREGATION] ${logPrefix} ✓ Time Series collection initialized`);
            } catch (error) {
                console.warn(`[AGGREGATION] ${logPrefix} Warning: Failed to initialize Time Series collection:`, error.message);
            }
        }
        
        return isTimeSeries;
    }

    /**
     * Delete documents in batches to avoid connection timeouts and pool exhaustion
     * @param {Object} db - MongoDB database instance
     * @param {string} collectionName - Collection name
     * @param {Object} matchStage - MongoDB match query
     * @param {number} batchSize - Number of documents to delete per batch (default: 10000)
     * @param {number} maxRetries - Maximum retry attempts for failed batches (default: 3)
     * @returns {Promise<number>} Total number of documents deleted
     */
    /**
     * Optimized direct deletion using deleteMany with match query
     * This is much faster than the old deleteInBatches approach (10-50x faster)
     * 
     * @param {Object} db - Database instance
     * @param {string} collectionName - Collection name
     * @param {Object} matchStage - MongoDB match query
     * @param {number} maxBatchSize - Maximum documents per operation (default: 50000)
     * @param {number} maxRetries - Maximum retry attempts (default: 3)
     * @returns {Promise<number>} Number of documents deleted
     */
    async deleteDirect(db, collectionName, matchStage, maxBatchSize = 50000, maxRetries = 3) {
        const collection = db.collection(collectionName);
        let totalDeleted = 0;
        let attempts = 0;
        const deleteStartTime = Date.now();

        try {
            console.log(`[AGGREGATION] [DELETE-DIRECT] Starting optimized deletion from ${collectionName}`);

            // For very large deletions, MongoDB handles them efficiently with deleteMany
            // We use a single operation which is much faster than the old two-step approach
            while (attempts < maxRetries) {
                try {
                    attempts++;
                    const operationStartTime = Date.now();

                    // Direct deleteMany - MongoDB handles large deletions efficiently
                    // For Time Series collections, this is optimized by MongoDB
                    const deleteResult = await collection.deleteMany(matchStage);
                    const deletedCount = deleteResult.deletedCount || 0;
                    const duration = Date.now() - operationStartTime;

                    totalDeleted += deletedCount;

                    console.log(`[AGGREGATION] [DELETE-DIRECT] Deleted ${deletedCount} documents from ${collectionName} in ${duration}ms`);

                    // If we got 0 documents, we're done
                    if (deletedCount === 0) {
                        break;
                    }

                    // For very large datasets, MongoDB might limit the deletion in a single operation
                    // If we got exactly maxBatchSize, there might be more, but this is rare
                    // In practice, deleteMany handles millions of documents efficiently
                    break;

                } catch (error) {
                    if (attempts < maxRetries) {
                        const waitTime = Math.pow(2, attempts) * 1000; // Exponential backoff
                        console.warn(`[AGGREGATION] [DELETE-DIRECT] Deletion failed, retrying in ${waitTime}ms (attempt ${attempts}/${maxRetries}): ${error.message}`);
                        await new Promise(resolve => setTimeout(resolve, waitTime));
                    } else {
                        throw error;
                    }
                }
            }

            const totalDuration = Date.now() - deleteStartTime;
            console.log(`[AGGREGATION] [DELETE-DIRECT] ✅ Completed deletion: ${totalDeleted} documents deleted in ${totalDuration}ms`);
            return totalDeleted;

        } catch (error) {
            const totalDuration = Date.now() - deleteStartTime;
            console.error(`[AGGREGATION] [DELETE-DIRECT] ❌ Deletion failed after ${totalDuration}ms:`, error.message);
            console.error(`[AGGREGATION] [DELETE-DIRECT] Deleted ${totalDeleted} documents before failure`);
            throw error;
        }
    }

    /**
     * @deprecated Use deleteDirect() or deletionQueueService.enqueue() instead
     * Kept for backward compatibility but should not be used
     */
    async deleteInBatches(db, collectionName, matchStage, batchSize = 10000, maxRetries = 3) {
        console.warn('[AGGREGATION] [DELETE-BATCH] deleteInBatches is deprecated. Use deleteDirect() or deletionQueueService.enqueue() instead.');
        return this.deleteDirect(db, collectionName, matchStage, batchSize, maxRetries);
    }
    /**
     * Aggregate raw measurements into 15-minute buckets
     * 
     * Note: buildingId is no longer used - measurements are now server-scoped and aggregated by sensorId only.
     * To get building-specific data, use the sensorLookup utility to get sensor IDs for a building.
     * 
     * @param {boolean} deleteAfterAggregation - Whether to delete raw data after aggregation (default: true)
     * @param {number} bufferMinutes - Safety buffer to keep raw data (default: 30 minutes)
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregate15Minutes(deleteAfterAggregation = true, bufferMinutes = 30) {
        const functionStartTime = Date.now();
        console.log(`[AGGREGATION] [15-min] [TIMING] Starting aggregate15Minutes for all sensors`);
        
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
            throw new ServiceUnavailableError('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
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

        // Check and ensure measurements_aggregated collection is a Time Series collection
        // This prevents MongoDB from auto-creating a regular collection if someone dropped it
        const collectionCheckStartTime = Date.now();
        const isTimeSeries = await this.ensureTimeSeriesCollection(db, '[15-min]');
        const collectionCheckDuration = Date.now() - collectionCheckStartTime;
        console.log(`[AGGREGATION] [15-min] [TIMING] Collection type check/init took ${collectionCheckDuration}ms`);
        if (isTimeSeries) {
            console.log(`[AGGREGATION] [15-min] Using Time Series collection - will use direct inserts instead of $merge`);
        }

        const now = new Date();
        
        // The end of aggregation window is the start of the CURRENT 15-minute bucket
        // This ensures we only aggregate COMPLETE 15-minute windows
        const safeAggregationEnd = this.roundTo15Minutes(now);
        
        // Optimized lookback strategy:
        // - Regular runs: Only process recent data (30 minutes) to avoid timeouts and reduce load
        // - Catch-up: Use longer window (7 days) only if no recent data found
        const regularLookbackHours = parseFloat(process.env.AGGREGATION_REGULAR_LOOKBACK_HOURS || '0.5', 10); // 30 minutes default
        const catchupLookbackDays = parseInt(process.env.AGGREGATION_LOOKBACK_DAYS || '7', 10);
        
        // First, check for recent data (last 2 hours)
        // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
        const recentDataStart = new Date(safeAggregationEnd.getTime() - regularLookbackHours * 60 * 60 * 1000);
        const recentDataCountStartTime = Date.now();
        const recentDataCount = await queryWithRetry(() => 
            db.collection('measurements_raw').countDocuments({
                timestamp: { 
                    $gte: recentDataStart,
                    $lt: safeAggregationEnd 
                }
            })
        );
        const recentDataCountDuration = Date.now() - recentDataCountStartTime;
        console.log(`[AGGREGATION] [15-min] [TIMING] Recent data count query took ${recentDataCountDuration}ms (found ${recentDataCount} documents)`);
        
        // Determine lookback window based on data availability
        let lookbackHours;
        let isCatchup = false;
        
        if (recentDataCount > 0) {
            // Regular run: only process recent data (faster, avoids timeouts)
            lookbackHours = regularLookbackHours;
            console.log(`[AGGREGATION] [15-min] Regular aggregation: processing last ${regularLookbackHours} hours (${recentDataCount} documents)`);
        } else {
            // No recent data: check for older unaggregated data (catch-up scenario)
            // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
            const oldDataStart = new Date(safeAggregationEnd.getTime() - catchupLookbackDays * 24 * 60 * 60 * 1000);
            const oldDataCountStartTime = Date.now();
            const oldDataCount = await queryWithRetry(() => 
                db.collection('measurements_raw').countDocuments({
                    timestamp: { 
                        $gte: oldDataStart,
                        $lt: recentDataStart
                    }
                })
            );
            const oldDataCountDuration = Date.now() - oldDataCountStartTime;
            console.log(`[AGGREGATION] [15-min] [TIMING] Old data count query took ${oldDataCountDuration}ms (found ${oldDataCount} documents)`);
            
            if (oldDataCount > 0) {
                // Use catch-up window (but will process in chunks)
                lookbackHours = catchupLookbackDays * 24;
                isCatchup = true;
                console.log(`[AGGREGATION] [15-min] Catch-up aggregation: processing last ${catchupLookbackDays} days (found ${oldDataCount} old unaggregated documents, will process in chunks)`);
            } else {
                // No data at all, use regular window
                lookbackHours = regularLookbackHours;
                console.log(`[AGGREGATION] [15-min] No data found, using regular window: ${regularLookbackHours} hours`);
            }
        }
        
        const bucketStart = new Date(safeAggregationEnd.getTime() - lookbackHours * 60 * 60 * 1000);
        
        console.log(`[AGGREGATION] [15-min] Time window: ${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()} (lookback: ${lookbackHours} hours)`);
        
        // Skip if we're at the very start of a 15-minute window (no complete window yet)
        if (safeAggregationEnd.getTime() === this.roundTo15Minutes(new Date(now.getTime() - 1000)).getTime()) {
            // We just started a new window, check if we have any data to aggregate at all
            console.log(`[AGGREGATION] [15-min] At start of new 15-minute window, checking for data...`);
        }
        
        const matchStage = {
            // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
            timestamp: { $gte: bucketStart, $lt: safeAggregationEnd }
        };
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
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
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType'
                    },
                    // Aggregation strategy based on measurementType AND stateType:
                    // - Power (actual* states): use average (instantaneous values)
                    // - Energy (total state): use last - first (cumulative counter consumption)
                    // - Energy (totalDay/Week/Month/Year): use last (period totals, not cumulative)
                    // - All others: use average
                    value: {
                        $cond: [
                            // Case 1: Energy (total state) → consumption = last - first (cumulative counter)
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Energy consumption calculation with reset detection for cumulative counter
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
                            // Case 1b: Energy (totalDay/Week/Month/Year) → use last value (period totals)
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Energy'] },
                                            {
                                                $or: [
                                                    { $eq: ['$_id.stateType', 'totalDay'] },
                                                    { $eq: ['$_id.stateType', 'totalWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalYear'] },
                                                    { $eq: ['$_id.stateType', 'totalNegDay'] },
                                                    { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalNegYear'] }
                                                ]
                                            }
                                        ]
                                    },
                                    // Period totals: use last value (represents the period's total consumption)
                                    '$lastValue',
                                    // Case 2: Power (all states: Meter actual* and EFM states like selfConsumption, Gpwr) → average
                                    // Remove stateType regex filter - include all Power states (both Meter actual* and EFM states)
                                    {
                                        $cond: [
                                            {
                                                $eq: ['$_id.measurementType', 'Power']
                                            },
                                            '$avgValue',
                                            // Case 3: Water/Gas (total state) → consumption = last - first (cumulative counter)
                                            {
                                                $cond: [
                                                    {
                                                        $and: [
                                                            {
                                                                $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                            },
                                                            {
                                                                $or: [
                                                                    { $eq: ['$_id.stateType', 'total'] }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    {
                                                        // Water/Gas consumption with reset detection for cumulative counter
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
                                                    // Case 3b: Water/Gas (totalDay/Week/Month/Year) → use last value (period totals)
                                                    {
                                                        $cond: [
                                                            {
                                                                $and: [
                                                                    {
                                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                                    },
                                                                    {
                                                                        $or: [
                                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            // Period totals: use last value
                                                            '$lastValue',
                                                            // Case 4: All others (Temperature, Humidity, etc.) → average
                                                            '$avgValue'
                                                        ]
                                                    }
                                                ]
                                            }
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
                        // Write to measurements_aggregated collection
                        into: dbName ? { db: dbName, coll: 'measurements_aggregated' } : 'measurements_aggregated',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            }
            ])
        ];
        
        try {
            // Log the match stage for debugging
            console.log(`[AGGREGATION] [15-min] Query match stage:`, JSON.stringify(matchStage, null, 2));
            
            // First, check if there's any data to aggregate (read from measurements_raw)
            const dataCountStartTime = Date.now();
            const dataCount = await queryWithRetry(() => 
                db.collection('measurements_raw').countDocuments(matchStage)
            );
            const dataCountDuration = Date.now() - dataCountStartTime;
            console.log(`[AGGREGATION] [15-min] [TIMING] Main data count query took ${dataCountDuration}ms (found ${dataCount} documents)`);
            console.log(`[AGGREGATION] [15-min] Found ${dataCount} raw data points to aggregate (${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()})`);
            
            if (dataCount === 0) {
                // Check if there's any raw data at all (even if too recent)
                // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                const allRawDataQuery = {};
                const allRawDataCountStartTime = Date.now();
                const allRawDataCount = await queryWithRetry(() =>
                    db.collection('measurements_raw').countDocuments(allRawDataQuery)
                );
                const allRawDataCountDuration = Date.now() - allRawDataCountStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] All raw data count query took ${allRawDataCountDuration}ms (found ${allRawDataCount} documents)`);
                
                // Get sample raw data to verify structure
                let sampleRawData = null;
                if (allRawDataCount > 0) {
                    try {
                        sampleRawData = await db.collection('measurements_raw')
                            .findOne(allRawDataQuery, { 
                                projection: { 
                                    timestamp: 1, 
                                    resolution_minutes: 1, 
                                    'meta.sensorId': 1,
                                    'meta.measurementType': 1,
                                    source: 1,
                                    _id: 0
                                } 
                            });
                    } catch (err) {
                        console.warn(`[AGGREGATION] [15-min] Could not fetch sample data:`, err.message);
                    }
                }
                
                // Check for data in the current incomplete window
                // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                const currentWindowStart = safeAggregationEnd;
                const currentWindowEnd = new Date(safeAggregationEnd.getTime() + 15 * 60 * 1000);
                const currentWindowCountStartTime = Date.now();
                const currentWindowCount = await queryWithRetry(() =>
                    db.collection('measurements_raw').countDocuments({
                        timestamp: { $gte: currentWindowStart, $lt: currentWindowEnd }
                    })
                );
                const currentWindowCountDuration = Date.now() - currentWindowCountStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] Current window count query took ${currentWindowCountDuration}ms (found ${currentWindowCount} documents)`);
                
                // Check for data outside the lookback window (older than 7 days)
                // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                const oldDataOutsideWindowStartTime = Date.now();
                const oldDataCount = await queryWithRetry(() =>
                    db.collection('measurements_raw').countDocuments({
                        timestamp: { $lt: bucketStart }
                    })
                );
                const oldDataOutsideWindowDuration = Date.now() - oldDataOutsideWindowStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] Old data outside window count query took ${oldDataOutsideWindowDuration}ms (found ${oldDataCount} documents)`);
                
                if (allRawDataCount > 0) {
                    console.log(`[AGGREGATION] [15-min] No raw data in aggregation window, but found:`);
                    console.log(`   - Total raw data: ${allRawDataCount} documents`);
                    console.log(`   - Data in current incomplete window (${currentWindowStart.toISOString()} to ${currentWindowEnd.toISOString()}): ${currentWindowCount} documents`);
                    console.log(`   - Data older than lookback window: ${oldDataCount} documents`);
                    if (sampleRawData) {
                        console.log(`   - Sample raw data structure:`, JSON.stringify(sampleRawData, null, 2));
                    }
                    console.log(`   - NOTE: Data in current window will be aggregated after ${currentWindowEnd.toISOString()}`);
                    console.log(`   - Aggregation only processes COMPLETE 15-minute windows (data older than ${safeAggregationEnd.toISOString()})`);
                    if (oldDataCount > 0) {
                        console.log(`   - WARNING: ${oldDataCount} raw data points are older than ${lookbackDays} days and won't be aggregated automatically. Use manual date range aggregation.`);
                    }
                } else {
                    console.log(`[AGGREGATION] [15-min] No raw data found in database`);
                }
                
                return { success: true, count: 0, deleted: 0, skipped: true, reason: 'No data in time range' };
            }
            
            // Execute aggregation
            let count = 0;
            if (isAdminDb) {
                // For admin database: use $out to temp collection, then manually upsert
                // Read from measurements_raw
                const adminPipelineStartTime = Date.now();
                await db.collection('measurements_raw').aggregate(pipeline, {
                    allowDiskUse: true,
                    maxTimeMS: 300000 // 5 minute timeout
                }).toArray();
                const adminPipelineDuration = Date.now() - adminPipelineStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] Admin DB $out pipeline took ${adminPipelineDuration}ms`);
                
                // Read from temp collection and upsert to main collection
                const tempCollection = db.collection('measurements_aggregated_temp_15min');
                const readTempStartTime = Date.now();
                const aggregatedDocs = await tempCollection.find({}).toArray();
                const readTempDuration = Date.now() - readTempStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] Read from temp collection took ${readTempDuration}ms (found ${aggregatedDocs.length} documents)`);
                
                // Ensure resolution_minutes is set (safeguard - always set explicitly)
                aggregatedDocs.forEach(doc => {
                    doc.resolution_minutes = 15;
                });
                
                // Upsert each document to measurements_aggregated
                const upsertStartTime = Date.now();
                for (const doc of aggregatedDocs) {
                    const result = await db.collection('measurements_aggregated').replaceOne(
                        {
                            timestamp: doc.timestamp,
                            'meta.sensorId': doc.meta.sensorId,
                            'meta.measurementType': doc.meta.measurementType,
                            'meta.stateType': doc.meta.stateType,
                            'meta.controlType': doc.meta.controlType || null, // NEW: Include controlType in upsert key
                            resolution_minutes: 15
                        },
                        doc,
                        { upsert: true }
                    );
                    if (result.upsertedCount > 0 || result.modifiedCount > 0) {
                        count++;
                    }
                }
                const upsertDuration = Date.now() - upsertStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] Upsert operations took ${upsertDuration}ms (processed ${aggregatedDocs.length} documents, ${count} upserted/modified)`);
                
                // Clean up temp collection
                await tempCollection.drop().catch(() => {});
                
                console.log(`[AGGREGATION] [15-min] Created ${count} aggregates using workaround (admin database)`);
            } else if (isTimeSeries) {
                // Time Series collection: use direct inserts (can't use $merge on views)
                // Get aggregated results without $merge
                // Read from measurements_raw, write to measurements_aggregated
                const aggregationPipeline = pipeline.slice(0, -1); // Remove the $merge stage
                
                // Verify pipeline structure (for debugging)
                const pipelineStages = aggregationPipeline.map(stage => Object.keys(stage)[0]);
                console.log(`[AGGREGATION] [15-min] Pipeline stages: ${pipelineStages.join(' -> ')}`);
                // Verify $project stage includes resolution_minutes
                const projectStage = aggregationPipeline.find(s => s.$project);
                if (projectStage && projectStage.$project) {
                    const hasResolution = projectStage.$project.hasOwnProperty('resolution_minutes') || 
                                         projectStage.$project.resolution_minutes !== undefined;
                    console.log(`[AGGREGATION] [15-min] Pipeline $project includes resolution_minutes: ${hasResolution}`);
                    if (hasResolution) {
                        console.log(`[AGGREGATION] [15-min] Pipeline $project.resolution_minutes value: ${JSON.stringify(projectStage.$project.resolution_minutes)}`);
                    }
                }
                
                // For large datasets, process in chunks to avoid timeouts
                // Chunk if dataset is large (> 50K documents) to prevent timeouts even on regular runs
                const chunkSizeHours = parseInt(process.env.AGGREGATION_CHUNK_SIZE_HOURS || '1', 10);
                const chunkSizeMs = chunkSizeHours * 60 * 60 * 1000;
                const shouldChunk = dataCount > 50000; // Chunk if > 50K documents (catch-up OR regular) - lowered threshold
                
                let allAggregatedDocs = [];
                
                if (shouldChunk) {
                    console.log(`[AGGREGATION] [15-min] Large dataset detected (${dataCount} documents), processing in ${chunkSizeHours}-hour chunks...`);
                    
                    let currentChunkStart = bucketStart;
                    let chunkNumber = 0;
                    
                    while (currentChunkStart < safeAggregationEnd) {
                        const currentChunkEnd = new Date(Math.min(
                            currentChunkStart.getTime() + chunkSizeMs,
                            safeAggregationEnd.getTime()
                        ));
                        
                        chunkNumber++;
                        console.log(`[AGGREGATION] [15-min] Processing chunk ${chunkNumber}: ${currentChunkStart.toISOString()} to ${currentChunkEnd.toISOString()}`);
                        
                        // Create chunk-specific match stage
                        // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                        const chunkMatchStage = {
                            timestamp: { 
                                $gte: currentChunkStart,
                                $lt: currentChunkEnd
                            }
                        };
                        
                        // Create chunk pipeline (replace match stage)
                        const chunkPipeline = [
                            { $match: chunkMatchStage },
                            ...aggregationPipeline.slice(1) // Use rest of pipeline (group, project stages)
                        ];
                        
                        try {
                            const chunkAggregationStartTime = Date.now();
                            const chunkDocs = await db.collection('measurements_raw')
                                .aggregate(chunkPipeline, { 
                                    allowDiskUse: true,
                                    maxTimeMS: 300000 // 5 minute timeout per chunk
                                })
                                .toArray();
                            const chunkAggregationDuration = Date.now() - chunkAggregationStartTime;
                            console.log(`[AGGREGATION] [15-min] [TIMING] Chunk ${chunkNumber} aggregation pipeline took ${chunkAggregationDuration}ms (produced ${chunkDocs.length} documents)`);
                            
                            if (chunkDocs.length > 0) {
                                // Ensure resolution_minutes is set
                                chunkDocs.forEach(doc => {
                                    doc.resolution_minutes = 15;
                                });
                                allAggregatedDocs.push(...chunkDocs);
                                console.log(`[AGGREGATION] [15-min] Chunk ${chunkNumber} produced ${chunkDocs.length} aggregates`);
                            }
                            
                            // Yield to event loop between chunks
                            await new Promise(resolve => setImmediate(resolve));
                        } catch (chunkError) {
                            console.error(`[AGGREGATION] [15-min] Error processing chunk ${chunkNumber}:`, chunkError.message);
                            // Continue with next chunk
                        }
                        
                        currentChunkStart = currentChunkEnd;
                    }
                    
                    console.log(`[AGGREGATION] [15-min] Chunked processing complete: ${allAggregatedDocs.length} total aggregates from ${chunkNumber} chunks`);
                } else {
                    // Regular processing: single aggregation for smaller datasets
                    console.log(`[AGGREGATION] [15-min] Executing aggregation pipeline for Time Series collection...`);
                    const aggregationStartTime = Date.now();
                    const aggregatedDocs = await db.collection('measurements_raw')
                        .aggregate(aggregationPipeline, { 
                            allowDiskUse: true,
                            maxTimeMS: 300000 // 5 minute timeout
                        })
                        .toArray();
                    const aggregationDuration = Date.now() - aggregationStartTime;
                    console.log(`[AGGREGATION] [15-min] [TIMING] Aggregation pipeline took ${aggregationDuration}ms (produced ${aggregatedDocs.length} documents)`);
                    allAggregatedDocs = aggregatedDocs;
                }
                
                console.log(`[AGGREGATION] [15-min] Pipeline produced ${allAggregatedDocs.length} aggregates`);
                
                // Check if pipeline output includes resolution_minutes
                if (allAggregatedDocs.length > 0) {
                    const sampleFromPipeline = allAggregatedDocs[0];
                    const hasResolutionInPipeline = sampleFromPipeline.hasOwnProperty('resolution_minutes');
                    const resolutionValue = sampleFromPipeline.resolution_minutes;
                    console.log(`[AGGREGATION] [15-min] Pipeline output check: has resolution_minutes=${hasResolutionInPipeline}, value=${resolutionValue}`);
                    if (!hasResolutionInPipeline || resolutionValue !== 15) {
                        console.log(`[AGGREGATION] [15-min] ⚠️  WARNING: Pipeline output missing or incorrect resolution_minutes! Expected: 15, Got: ${resolutionValue}`);
                        console.log(`[AGGREGATION] [15-min] Sample document keys:`, Object.keys(sampleFromPipeline).join(', '));
                    }
                }
                
                if (allAggregatedDocs.length === 0) {
                    console.log(`[AGGREGATION] [15-min] No aggregates to insert`);
                } else {
                    // Show sample (full document to verify resolution_minutes is included)
                    const sampleDoc = allAggregatedDocs[0];
                    console.log(`[AGGREGATION] [15-min] Sample aggregate:`, JSON.stringify(sampleDoc, null, 2).substring(0, 300));
                    if (!sampleDoc.resolution_minutes) {
                        console.log(`[AGGREGATION] [15-min] ⚠️  WARNING: Sample document is missing resolution_minutes!`);
                    }
                    
                    // Extract unique bucket timestamps from aggregated results
                    // Only delete aggregates for buckets that will be recreated (prevents data loss)
                    const bucketsToRecreate = new Set();
                    allAggregatedDocs.forEach(doc => {
                        if (doc.timestamp) {
                            // Normalize timestamp to Date object if it's not already
                            const bucketTimestamp = doc.timestamp instanceof Date 
                                ? doc.timestamp 
                                : new Date(doc.timestamp);
                            // Use ISO string for consistent comparison
                            bucketsToRecreate.add(bucketTimestamp.toISOString());
                        }
                    });
                    
                    const uniqueBuckets = Array.from(bucketsToRecreate).map(iso => new Date(iso));
                    console.log(`[AGGREGATION] [15-min] Will recreate aggregates for ${uniqueBuckets.length} unique bucket(s): ${uniqueBuckets.map(b => b.toISOString()).join(', ')}`);
                    
                    // Only delete existing aggregates for buckets that will be recreated
                    // This prevents data loss when raw data for some buckets was already deleted
                    let deletedCount = 0;
                    if (uniqueBuckets.length > 0) {
                        const deleteMatchStage = {
                            resolution_minutes: 15,
                            timestamp: { $in: uniqueBuckets }
                        };
                        
                        // Delete existing aggregates from measurements_aggregated
                        const deleteExistingStartTime = Date.now();
                        const deleteResult = await db.collection('measurements_aggregated').deleteMany(deleteMatchStage);
                        const deleteExistingDuration = Date.now() - deleteExistingStartTime;
                        deletedCount = deleteResult.deletedCount || 0;
                        console.log(`[AGGREGATION] [15-min] [TIMING] Delete existing aggregates took ${deleteExistingDuration}ms (deleted ${deletedCount} documents)`);
                        console.log(`[AGGREGATION] [15-min] Deleted ${deletedCount} existing aggregates for ${uniqueBuckets.length} bucket(s) that will be recreated`);
                    } else {
                        console.log(`[AGGREGATION] [15-min] No bucket timestamps found in aggregated results, skipping deletion`);
                    }
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    let missingCount = 0;
                    allAggregatedDocs.forEach(doc => {
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
                    const allHaveResolution = allAggregatedDocs.every(doc => doc.resolution_minutes === 15);
                    if (!allHaveResolution) {
                        console.error(`[AGGREGATION] [15-min] ❌ ERROR: Some documents still missing resolution_minutes after safeguard!`);
                        allAggregatedDocs.forEach((doc, idx) => {
                            if (doc.resolution_minutes !== 15) {
                                console.error(`[AGGREGATION] [15-min] Document ${idx} missing resolution_minutes:`, JSON.stringify(doc).substring(0, 200));
                            }
                        });
                    }
                    
                    // Final verification: ensure ALL documents have resolution_minutes before insertion
                    const docsMissingField = allAggregatedDocs.filter(doc => doc.resolution_minutes !== 15);
                    if (docsMissingField.length > 0) {
                        console.error(`[AGGREGATION] [15-min] ❌ CRITICAL: ${docsMissingField.length} documents still missing resolution_minutes! Fixing now...`);
                        docsMissingField.forEach((doc, idx) => {
                            doc.resolution_minutes = 15;
                            console.log(`[AGGREGATION] [15-min] Fixed document ${idx}:`, JSON.stringify(doc).substring(0, 150));
                        });
                    }
                    
                    // Double-check: verify all documents now have the field
                    const allHaveField = allAggregatedDocs.every(doc => doc.resolution_minutes === 15);
                    if (!allHaveField) {
                        throw new InternalServerError('[AGGREGATION] [15-min] FATAL: Some documents still missing resolution_minutes after all safeguards!');
                    }
                    
                    // Insert new aggregates into measurements_aggregated using insertMany
                    // For large datasets, insert in batches to avoid memory issues
                    const insertBatchSize = 5000;
                    let totalInserted = 0;
                    
                    try {
                        const insertStartTime = Date.now();
                        if (allAggregatedDocs.length <= insertBatchSize) {
                            // Small dataset: single insert
                            const insertResult = await db.collection('measurements_aggregated').insertMany(allAggregatedDocs, { ordered: false });
                            totalInserted = insertResult.insertedCount || allAggregatedDocs.length;
                            const insertDuration = Date.now() - insertStartTime;
                            console.log(`[AGGREGATION] [15-min] [TIMING] insertMany (single) took ${insertDuration}ms (inserted ${totalInserted} documents)`);
                        } else {
                            // Large dataset: batch inserts
                            console.log(`[AGGREGATION] [15-min] Large result set (${allAggregatedDocs.length} documents), inserting in batches of ${insertBatchSize}...`);
                            for (let i = 0; i < allAggregatedDocs.length; i += insertBatchSize) {
                                const batch = allAggregatedDocs.slice(i, i + insertBatchSize);
                                const batchInsertStartTime = Date.now();
                                try {
                                    const insertResult = await db.collection('measurements_aggregated').insertMany(batch, { ordered: false });
                                    totalInserted += insertResult.insertedCount || batch.length;
                                    const batchInsertDuration = Date.now() - batchInsertStartTime;
                                    console.log(`[AGGREGATION] [15-min] [TIMING] Batch ${Math.floor(i / insertBatchSize) + 1} insertMany took ${batchInsertDuration}ms (inserted ${insertResult.insertedCount || batch.length} documents, total: ${totalInserted}/${allAggregatedDocs.length})`);
                                } catch (batchError) {
                                    if (batchError.insertedCount) {
                                        totalInserted += batchError.insertedCount;
                                        console.warn(`[AGGREGATION] [15-min] ⚠️  Batch insert partial: ${batchError.insertedCount}/${batch.length} inserted`);
                                    } else {
                                        console.error(`[AGGREGATION] [15-min] Error inserting batch:`, batchError.message);
                                        // Continue with next batch
                                    }
                                }
                                // Yield to event loop between batches
                                await new Promise(resolve => setImmediate(resolve));
                            }
                            const totalInsertDuration = Date.now() - insertStartTime;
                            console.log(`[AGGREGATION] [15-min] [TIMING] Total insertMany (batched) took ${totalInsertDuration}ms (inserted ${totalInserted} documents)`);
                        }
                        
                        count = totalInserted;
                        console.log(`[AGGREGATION] [15-min] Inserted ${count} aggregates into measurements_aggregated collection`);
                        console.log(`[AGGREGATION] [15-min] ✅ Verified: All ${count} inserted documents have resolution_minutes: 15`);
                    } catch (error) {
                        // Handle partial inserts
                        if (error.insertedCount) {
                            count = error.insertedCount;
                            console.log(`[AGGREGATION] [15-min] ⚠️  Partial insert: ${count} aggregates inserted (some duplicates may have been skipped)`);
                            console.log(`[AGGREGATION] [15-min] ⚠️  Note: Inserted documents should have resolution_minutes: 15`);
                        } else {
                            console.error(`[AGGREGATION] [15-min] Error inserting aggregates:`, error.message);
                            throw error;
                        }
                    }
                }
            } else {
                // Normal flow: use $merge (for regular collections)
                // First, test the aggregation pipeline without $merge to see if it produces results
                // Read from measurements_raw
                const testPipeline = pipeline.slice(0, -1); // Remove the $merge stage
                console.log(`[AGGREGATION] [15-min] Testing aggregation pipeline (without $merge)...`);
                const testPipelineStartTime = Date.now();
                const testResults = await db.collection('measurements_raw').aggregate(testPipeline, {
                    allowDiskUse: true,
                    maxTimeMS: 300000 // 5 minute timeout
                }).toArray();
                const testPipelineDuration = Date.now() - testPipelineStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] Test pipeline took ${testPipelineDuration}ms (produced ${testResults.length} aggregates)`);
                console.log(`[AGGREGATION] [15-min] Pipeline would produce ${testResults.length} aggregates`);
                
                if (testResults.length === 0) {
                    console.log(`[AGGREGATION] [15-min] WARNING: Aggregation pipeline produces no results!`);
                    console.log(`[AGGREGATION] [15-min] This might indicate an issue with the grouping or data structure.`);
                } else {
                    // Show sample of what would be created
                    console.log(`[AGGREGATION] [15-min] Sample aggregate:`, JSON.stringify(testResults[0], null, 2).substring(0, 200));
                }
                
                // Now execute the full pipeline with $merge (reads from measurements_raw, writes to measurements_aggregated)
                console.log(`[AGGREGATION] [15-min] Executing aggregation pipeline with $merge...`);
                const mergePipelineStartTime = Date.now();
                const cursor = db.collection('measurements_raw').aggregate(pipeline, {
                    allowDiskUse: true,
                    maxTimeMS: 300000 // 5 minute timeout
                });
                await cursor.toArray(); // This will execute the pipeline even though it returns empty
                const mergePipelineDuration = Date.now() - mergePipelineStartTime;
                console.log(`[AGGREGATION] [15-min] [TIMING] $merge pipeline execution took ${mergePipelineDuration}ms`);
                
                // Count aggregates in the time window (this includes both new and existing)
                const aggregateMatchStage = {
                    resolution_minutes: 15,
                    timestamp: { $gte: bucketStart, $lt: safeAggregationEnd }
                };
                
                const totalAggregates = await db.collection('measurements_aggregated').countDocuments(aggregateMatchStage);
                count = testResults.length; // Use the count from the test pipeline
                console.log(`[AGGREGATION] [15-min] Created/updated ${count} aggregates (total in window: ${totalAggregates})`);
            }
            
            // Success logging - visible in terminal
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [15-min] SUCCESS!`);
            console.log(`   Created ${count} aggregates`);
            console.log(`   Window: ${bucketStart.toISOString()} to ${safeAggregationEnd.toISOString()}`);
            console.log(`   Raw data points processed: ${dataCount}`);
            console.log(`   Note: Meter resets (negative consumption) are automatically set to 0`);
            console.log(`========================================\n`);
            
            let deletedCount = 0;
            
            // Delete raw data that was aggregated (always attempt deletion if deleteAfterAggregation is true)
            // This ensures raw data is cleaned up even if aggregation partially fails or times out
            // safeAggregationEnd is already the start of the current incomplete window,
            // so all data before it represents complete windows that should be deleted
            if (deleteAfterAggregation) {
                const deleteCutoff = safeAggregationEnd;
                
                if (deleteCutoff > bucketStart) {
                    // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                    const deleteMatchStage = {
                        timestamp: { 
                            $gte: bucketStart, 
                            $lt: deleteCutoff  // Delete all complete windows that were aggregated (or attempted)
                        }
                    };
                    
                    try {
                        // Queue deletion for background processing instead of blocking
                        // This allows aggregation to complete immediately
                        const description = `15-min aggregation cleanup: ${bucketStart.toISOString()} to ${deleteCutoff.toISOString()}`;
                        
                        console.log(`[AGGREGATION] [15-min] Queuing deletion for background processing: ${description}`);
                        
                        await deletionQueueService.enqueue(
                            'measurements_raw',
                            deleteMatchStage,
                            description
                        );
                        
                        // Note: deletedCount is set to 0 because deletion happens asynchronously
                        // The deletion queue service will handle the actual deletion
                        console.log(`[AGGREGATION] [15-min] ✅ Deletion queued for background processing`);
                    } catch (deleteError) {
                        console.error(`[AGGREGATION] [15-min] ❌ Error queueing deletion:`, deleteError.message);
                        console.error(`[AGGREGATION] [15-min] Error stack:`, deleteError.stack);
                        // Don't throw - deletion failure is non-critical, aggregation may have succeeded
                        // deletedCount remains 0 on error
                    }
                } else {
                    console.log(`[AGGREGATION] [15-min] ⏭️  Skipping deletion: No complete windows to delete (deleteCutoff ${deleteCutoff.toISOString()} <= bucketStart ${bucketStart.toISOString()})`);
                }
            }
            
            const functionTotalDuration = Date.now() - functionStartTime;
            console.log(`[AGGREGATION] [15-min] [TIMING] Total aggregate15Minutes took ${functionTotalDuration}ms (created ${count} aggregates, deleted ${deletedCount} raw documents)`);
            
            return { 
                success: true, 
                count, 
                deleted: deletedCount,
                aggregationWindow: {
                    start: bucketStart.toISOString(),
                    end: safeAggregationEnd.toISOString()
                }
            };
        } catch (error) {
            const functionTotalDuration = Date.now() - functionStartTime;
            console.error(`[AGGREGATION] [15-min] [TIMING] aggregate15Minutes failed after ${functionTotalDuration}ms`);
            console.error(`[AGGREGATION] [15-min] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate raw data for a specific date range (manual/catch-up aggregation)
     * 
     * @param {Date} startDate - Start date (will be rounded to 15-minute boundary)
     * @param {Date} endDate - End date (will be rounded to 15-minute boundary)
     * @param {boolean} deleteAfterAggregation - Whether to delete raw data after aggregation (default: true)
     * @param {number} bufferMinutes - Safety buffer to keep raw data (default: 30 minutes)
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateDateRange(startDate, endDate, deleteAfterAggregation = true, bufferMinutes = 30) {
        console.log(`[AGGREGATION] [DateRange] Starting aggregation for date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
        
        // Round dates to 15-minute boundaries
        const roundedStart = this.roundTo15Minutes(startDate);
        const roundedEnd = this.roundTo15Minutes(endDate);
        
        // Process in chunks to avoid memory issues with large date ranges
        const chunkSizeHours = 24; // Process 24 hours at a time
        const chunkSizeMs = chunkSizeHours * 60 * 60 * 1000;
        
        let totalCount = 0;
        let totalDeleted = 0;
        const errors = [];
        
        let currentStart = roundedStart;
        
        while (currentStart < roundedEnd) {
            const currentEnd = new Date(Math.min(currentStart.getTime() + chunkSizeMs, roundedEnd.getTime()));
            
            console.log(`[AGGREGATION] [DateRange] Processing chunk: ${currentStart.toISOString()} to ${currentEnd.toISOString()}`);
            
            try {
                // Temporarily modify the aggregation window by creating a custom match stage
                // We'll call aggregate15Minutes but need to override the time window
                // Since aggregate15Minutes uses internal logic, we'll create a wrapper
                
                // Check connection health
                if (!isConnectionHealthy()) {
                    throw new ServiceUnavailableError('Database connection not healthy');
                }
                
                const db = mongoose.connection.db;
                if (!db) {
                    throw new ServiceUnavailableError('Database connection not available');
                }
                
                // Build match stage for this chunk
                // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                const matchStage = {
                    timestamp: { $gte: currentStart, $lt: currentEnd }
                };
                
                // Check if there's data in this chunk (read from measurements_raw)
                const dataCount = await db.collection('measurements_raw').countDocuments(matchStage);
                
                if (dataCount > 0) {
                    console.log(`[AGGREGATION] [DateRange] Found ${dataCount} raw data points in chunk`);
                    
                    // Use the same pipeline logic as aggregate15Minutes but with custom date range
                    // We'll reuse the pipeline construction logic
                    const isTimeSeries = await this.isTimeSeriesCollection(db, 'measurements_raw');
                    const dbName = this.getDatabaseName();
                    const isAdminDb = (mongoose.connection.name || db.databaseName) === 'admin';
                    
                    // Build the same pipeline as aggregate15Minutes but with our custom match stage
                    const pipeline = this.build15MinuteAggregationPipeline(matchStage, isAdminDb, dbName);
                    
                    let chunkCount = 0;
                    
                    if (isTimeSeries) {
                        const aggregationPipeline = pipeline.slice(0, -1);
                        // Read from measurements_raw
                        const aggregatedDocs = await db.collection('measurements_raw').aggregate(aggregationPipeline).toArray();
                        
                        if (aggregatedDocs.length > 0) {
                            // Extract unique bucket timestamps from aggregated results
                            // Only delete aggregates for buckets that will be recreated (prevents data loss)
                            const bucketsToRecreate = new Set();
                            aggregatedDocs.forEach(doc => {
                                if (doc.timestamp) {
                                    const bucketTimestamp = doc.timestamp instanceof Date 
                                        ? doc.timestamp 
                                        : new Date(doc.timestamp);
                                    bucketsToRecreate.add(bucketTimestamp.toISOString());
                                }
                            });
                            
                            const uniqueBuckets = Array.from(bucketsToRecreate).map(iso => new Date(iso));
                            
                            // Only delete existing aggregates for buckets that will be recreated
                            if (uniqueBuckets.length > 0) {
                                const deleteMatchStage = {
                                    resolution_minutes: 15,
                                    timestamp: { $in: uniqueBuckets }
                                };
                                // Delete existing aggregates from measurements_aggregated
                                await db.collection('measurements_aggregated').deleteMany(deleteMatchStage);
                                console.log(`[AGGREGATION] [DateRange] Deleted existing aggregates for ${uniqueBuckets.length} bucket(s) that will be recreated`);
                            }
                            
                            aggregatedDocs.forEach(doc => {
                                doc.resolution_minutes = 15;
                            });
                            
                            try {
                                // Write to measurements_aggregated
                                const insertResult = await db.collection('measurements_aggregated').insertMany(aggregatedDocs, { ordered: false });
                                chunkCount = insertResult.insertedCount || aggregatedDocs.length;
                            } catch (error) {
                                if (error.insertedCount) {
                                    chunkCount = error.insertedCount;
                                } else {
                                    throw error;
                                }
                            }
                        }
                    } else if (isAdminDb) {
                        // Read from measurements_raw
                        await db.collection('measurements_raw').aggregate(pipeline).toArray();
                        const tempCollection = db.collection('measurements_aggregated_temp_15min');
                        const aggregatedDocs = await tempCollection.find({}).toArray();
                        aggregatedDocs.forEach(doc => {
                            doc.resolution_minutes = 15;
                        });
                        
                        // Write to measurements_aggregated
                        for (const doc of aggregatedDocs) {
                            const result = await db.collection('measurements_aggregated').replaceOne(
                                {
                                    timestamp: doc.timestamp,
                                    'meta.sensorId': doc.meta.sensorId,
                                    'meta.measurementType': doc.meta.measurementType,
                                    'meta.stateType': doc.meta.stateType,
                                    'meta.controlType': doc.meta.controlType || null, // NEW: Include controlType in upsert key
                                    resolution_minutes: 15
                                },
                                doc,
                                { upsert: true }
                            );
                            if (result.upsertedCount > 0 || result.modifiedCount > 0) {
                                chunkCount++;
                            }
                        }
                        await tempCollection.drop().catch(() => {});
                    } else {
                        // Read from measurements_raw
                        await db.collection('measurements_raw').aggregate(pipeline).toArray();
                        const aggregateMatchStage = {
                            resolution_minutes: 15,
                            timestamp: { $gte: currentStart, $lt: currentEnd }
                        };
                        const testPipeline = pipeline.slice(0, -1);
                        // Read from measurements_raw for test
                        const testResults = await db.collection('measurements_raw').aggregate(testPipeline).toArray();
                        chunkCount = testResults.length;
                    }
                    
                    totalCount += chunkCount;
                    
                    // Delete raw data if requested
                    if (deleteAfterAggregation && chunkCount > 0) {
                        const now = new Date();
                        const bufferCutoff = new Date(now.getTime() - bufferMinutes * 60 * 1000);
                        const deleteCutoff = new Date(Math.min(currentEnd.getTime(), bufferCutoff.getTime()));
                        
                        if (deleteCutoff > currentStart) {
                            // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
                            const deleteMatchStage = {
                                timestamp: { 
                                    $gte: currentStart, 
                                    $lt: deleteCutoff
                                }
                            };
                            
                            try {
                                // Queue deletion for background processing instead of blocking
                                const description = `DateRange aggregation cleanup: ${currentStart.toISOString()} to ${deleteCutoff.toISOString()}`;
                                
                                console.log(`[AGGREGATION] [DateRange] Queuing deletion for background processing: ${description}`);
                                
                                await deletionQueueService.enqueue(
                                    'measurements_raw',
                                    deleteMatchStage,
                                    description
                                );
                                
                                // Note: We don't track deletedCount here since deletion is async
                                // The deletion queue service will handle the actual deletion
                                console.log(`[AGGREGATION] [DateRange] ✅ Deletion queued for background processing`);
                            } catch (deleteError) {
                                console.error(`[AGGREGATION] [DateRange] Error queueing deletion:`, deleteError.message);
                            }
                        }
                    }
                    
                    console.log(`[AGGREGATION] [DateRange] Chunk completed: ${chunkCount} aggregates created`);
                } else {
                    console.log(`[AGGREGATION] [DateRange] No data in chunk, skipping`);
                }
            } catch (error) {
                const errorMsg = `Error processing chunk ${currentStart.toISOString()} to ${currentEnd.toISOString()}: ${error.message}`;
                console.error(`[AGGREGATION] [DateRange] ${errorMsg}`);
                errors.push(errorMsg);
                // Continue with next chunk even if this one fails
            }
            
            // Move to next chunk
            currentStart = currentEnd;
        }
        
        console.log(`[AGGREGATION] [DateRange] Completed: ${totalCount} aggregates created, ${totalDeleted} raw data points deleted`);
        if (errors.length > 0) {
            console.warn(`[AGGREGATION] [DateRange] ${errors.length} errors occurred during processing`);
        }
        
        return {
            success: errors.length === 0,
            count: totalCount,
            deleted: totalDeleted,
            errors: errors.length > 0 ? errors : undefined,
            dateRange: {
                start: roundedStart.toISOString(),
                end: roundedEnd.toISOString()
            }
        };
    }
    
    /**
     * Build 15-minute aggregation pipeline (extracted for reuse)
     * @private
     */
    build15MinuteAggregationPipeline(matchStage, isAdminDb, dbName) {
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        controlType: '$meta.controlType', // NEW: Group by controlType to keep EFM and Meter separate
                        bucket: {
                            $dateTrunc: {
                                date: '$timestamp',
                                unit: 'minute',
                                binSize: 15
                            }
                        }
                    },
                    avgValue: { $avg: '$value' },
                    minValue: { $min: '$value' },
                    maxValue: { $max: '$value' },
                    firstValue: { $first: '$value' },
                    lastValue: { $last: '$value' },
                    count: { $sum: 1 },
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
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType',
                        controlType: '$_id.controlType' // NEW: Include controlType in aggregated documents
                    },
                    value: {
                        $cond: [
                            // Case 1: Energy (total state) → consumption = last - first (cumulative counter)
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Energy consumption calculation with reset detection for cumulative counter
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
                            // Case 1b: Energy (totalDay/Week/Month/Year) → use last value (period totals)
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Energy'] },
                                            {
                                                $or: [
                                                    { $eq: ['$_id.stateType', 'totalDay'] },
                                                    { $eq: ['$_id.stateType', 'totalWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalYear'] },
                                                    { $eq: ['$_id.stateType', 'totalNegDay'] },
                                                    { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalNegYear'] }
                                                ]
                                            }
                                        ]
                                    },
                                    // Period totals: use last value (represents the period's total consumption)
                                    '$lastValue',
                                    // Case 2: Power (all states: Meter actual* and EFM states like selfConsumption, Gpwr) → average
                                    // Remove stateType regex filter - include all Power states (both Meter actual* and EFM states)
                                    {
                                        $cond: [
                                            {
                                                $eq: ['$_id.measurementType', 'Power']
                                            },
                                            '$avgValue',
                                            // Case 3: Water/Gas (total state) → consumption = last - first (cumulative counter)
                                            {
                                                $cond: [
                                                    {
                                                        $and: [
                                                            {
                                                                $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                            },
                                                            {
                                                                $or: [
                                                                    { $eq: ['$_id.stateType', 'total'] }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    {
                                                        // Water/Gas consumption with reset detection for cumulative counter
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
                                                    // Case 3b: Water/Gas (totalDay/Week/Month/Year) → use last value (period totals)
                                                    {
                                                        $cond: [
                                                            {
                                                                $and: [
                                                                    {
                                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                                    },
                                                                    {
                                                                        $or: [
                                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            // Period totals: use last value
                                                            '$lastValue',
                                                            // Case 4: All others (Temperature, Humidity, etc.) → average
                                                            '$avgValue'
                                                        ]
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    },
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
            }
        ];
        
        // Add $merge or $out stage
        if (isAdminDb) {
            pipeline.push({
                $out: 'measurements_aggregated_temp_15min'
            });
        } else {
            pipeline.push({
                $merge: {
                    into: dbName ? { db: dbName, coll: 'measurements_aggregated' } : 'measurements_aggregated',
                    whenMatched: 'replace',
                    whenNotMatched: 'insert'
                }
            });
        }
        
        return pipeline;
    }
    
    /**
     * Aggregate 15-minute data into hourly buckets
     * 
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateHourly() {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new ServiceUnavailableError('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        // Get the database name - if null, we'll omit it from $merge (uses current database)
        const dbName = this.getDatabaseName();
        
        // Check and ensure measurements_aggregated collection is a Time Series collection
        const isTimeSeries = await this.ensureTimeSeriesCollection(db, '[hourly]');

        const now = new Date();
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
        
        const bucketStart = this.roundToHour(oneHourAgo);
        const bucketEnd = this.roundToHour(now);
        
        const matchStage = {
            resolution_minutes: 15, // Field is at root level, not in meta
            timestamp: { $gte: bucketStart, $lt: bucketEnd }
        };
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        controlType: '$meta.controlType', // NEW: Group by controlType to keep EFM and Meter separate
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
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType',
                        controlType: '$_id.controlType' // NEW: Include controlType in aggregated documents
                    },
                    // Aggregation strategy for hourly from 15-minute aggregates:
                    // - Energy (total state): sum consumption deltas from 15-min aggregates
                    // - Energy (totalDay/Week/Month/Year): use last value (period totals)
                    //   IMPORTANT: totalDay/Week/Month/Year are period totals from Loxone, not cumulative deltas.
                    //   Each value represents the total consumption for that period (day/week/month/year).
                    //   We use lastValue to preserve the period total, which is the correct value for the hour.
                    //   When querying multiple periods, these values should be summed (not max'd) in calculateKPIsFromResults.
                    // - Power (actual* states): average power from 15-min aggregates
                    // - Others: average
                    value: {
                        $cond: [
                            // Case 1: Energy (total state) → sum consumption deltas
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Sum consumption deltas from 15-minute aggregates (ensure non-negative)
                                $max: [0, '$sumValue']
                            },
                            // Case 1b: Energy (totalDay/Week/Month/Year) → use last value (period totals)
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Energy'] },
                                            {
                                                $or: [
                                                    { $eq: ['$_id.stateType', 'totalDay'] },
                                                    { $eq: ['$_id.stateType', 'totalWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalYear'] },
                                                    { $eq: ['$_id.stateType', 'totalNegDay'] },
                                                    { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalNegYear'] }
                                                ]
                                            }
                                        ]
                                    },
                                    // Period totals: use last value (represents the period's total consumption)
                                    '$lastValue',
                                    // Case 2: Power (all states: Meter actual* and EFM states like selfConsumption, Gpwr) → average
                                    // Remove stateType regex filter - include all Power states (both Meter actual* and EFM states)
                                    {
                                        $cond: [
                                            {
                                                $eq: ['$_id.measurementType', 'Power']
                                            },
                                            '$avgValue',
                                            // Case 3: Water/Gas (total state) → sum consumption deltas
                                            {
                                                $cond: [
                                                    {
                                                        $and: [
                                                            {
                                                                $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                            },
                                                            {
                                                                $or: [
                                                                    { $eq: ['$_id.stateType', 'total'] }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    {
                                                        $max: [0, '$sumValue']
                                                    },
                                                    // Case 3b: Water/Gas (totalDay/Week/Month/Year) → use last value (period totals)
                                                    {
                                                        $cond: [
                                                            {
                                                                $and: [
                                                                    {
                                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                                    },
                                                                    {
                                                                        $or: [
                                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            // Period totals: use last value
                                                            '$lastValue',
                                                            // Case 4: All others → average
                                                            '$avgValue'
                                                        ]
                                                    }
                                                ]
                                            }
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
                    into: dbName ? { db: dbName, coll: 'measurements_aggregated' } : 'measurements_aggregated',
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
                const aggregatedDocs = await db.collection('measurements_aggregated').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing hourly aggregates in this time window
                    const deleteMatchStage = {
                        resolution_minutes: 60,
                        timestamp: { $gte: bucketStart, $lt: bucketEnd }
                    };
                    
                    await db.collection('measurements_aggregated').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 60;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements_aggregated').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Hourly] Created ${count} aggregates (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Hourly] Created ${count} aggregates`);
            }
            
            // Delete 15-minute aggregates older than 1 hour (now that we have hourly aggregates)
            // This prevents database bloat from accumulating 15-minute data
            // We only need 15-minute data for the current hour to create hourly aggregates
            let deleted15MinCount = 0;
            if (count > 0) {
                const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
                deleted15MinCount = await this.deleteOldAggregates(15, oneHourAgo);
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
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count, 
                deleted: deleted15MinCount
            };
        } catch (error) {
            console.error(`[AGGREGATION] [Hourly] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate hourly data into daily buckets
     * 
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateDaily() {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new ServiceUnavailableError('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        // Get the database name - if null, we'll omit it from $merge (uses current database)
        const dbName = this.getDatabaseName();
        
        // Check and ensure measurements_aggregated collection is a Time Series collection
        const isTimeSeries = await this.ensureTimeSeriesCollection(db, '[daily]');

        const yesterday = new Date();
        yesterday.setDate(yesterday.getDate() - 1);
        yesterday.setHours(0, 0, 0, 0);
        
        const today = new Date(yesterday);
        today.setDate(today.getDate() + 1);
        
        const matchStage = {
            resolution_minutes: 60, // Field is at root level, not in meta
            timestamp: { $gte: yesterday, $lt: today }
        };
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        controlType: '$meta.controlType', // NEW: Group by controlType to keep EFM and Meter separate
                        bucket: {
                            $dateTrunc: {
                                date: '$timestamp',
                                unit: 'day'
                            }
                        }
                    },
                    // Aggregate from hourly aggregates:
                    // - Energy (total state): sum consumption deltas
                    // - Energy (totalDay/Week/Month/Year): use last value (period totals)
                    // - Power (actual* states): average power values
                    // - Others: average
                    sumValue: { $sum: '$value' },
                    lastValue: { $last: '$value' },
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
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType',
                        controlType: '$_id.controlType' // NEW: Include controlType in aggregated documents
                    },
                    // Aggregation strategy for daily from hourly aggregates:
                    // - Energy (total state): sum consumption deltas from hourly aggregates
                    // - Energy (totalDay/Week/Month/Year): use last value (period totals)
                    //   IMPORTANT: totalDay/Week/Month/Year are period totals from Loxone, not cumulative deltas.
                    //   Each value represents the total consumption for that period (day/week/month/year).
                    //   We use lastValue to preserve the period total, which is the correct value for the day.
                    //   When querying multiple days, totalDay values should be summed (not max'd) in calculateKPIsFromResults.
                    // - Power (actual* states): average power from hourly aggregates
                    // - Others: average
                    value: {
                        $cond: [
                            // Case 1: Energy (total state) → sum consumption deltas
                            {
                                $and: [
                                    { $eq: ['$_id.measurementType', 'Energy'] },
                                    {
                                        $or: [
                                            { $eq: ['$_id.stateType', 'total'] },
                                            { $eq: ['$_id.stateType', 'totalNeg'] }
                                        ]
                                    }
                                ]
                            },
                            {
                                // Sum consumption deltas from hourly aggregates (ensure non-negative)
                                $max: [0, '$sumValue']
                            },
                            // Case 1b: Energy (totalDay/Week/Month/Year) → use last value (period totals)
                            {
                                $cond: [
                                    {
                                        $and: [
                                            { $eq: ['$_id.measurementType', 'Energy'] },
                                            {
                                                $or: [
                                                    { $eq: ['$_id.stateType', 'totalDay'] },
                                                    { $eq: ['$_id.stateType', 'totalWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalYear'] },
                                                    { $eq: ['$_id.stateType', 'totalNegDay'] },
                                                    { $eq: ['$_id.stateType', 'totalNegWeek'] },
                                                    { $eq: ['$_id.stateType', 'totalNegMonth'] },
                                                    { $eq: ['$_id.stateType', 'totalNegYear'] }
                                                ]
                                            }
                                        ]
                                    },
                                    // Period totals: use last value (represents the period's total consumption)
                                    '$lastValue',
                                    // Case 2: Power (all states: Meter actual* and EFM states like selfConsumption, Gpwr) → average
                                    // Remove stateType regex filter - include all Power states (both Meter actual* and EFM states)
                                    {
                                        $cond: [
                                            {
                                                $eq: ['$_id.measurementType', 'Power']
                                            },
                                            '$avgValue',
                                            // Case 3: Water/Gas (total state) → sum consumption deltas
                                            {
                                                $cond: [
                                                    {
                                                        $and: [
                                                            {
                                                                $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                            },
                                                            {
                                                                $or: [
                                                                    { $eq: ['$_id.stateType', 'total'] }
                                                                ]
                                                            }
                                                        ]
                                                    },
                                                    {
                                                        $max: [0, '$sumValue']
                                                    },
                                                    // Case 3b: Water/Gas (totalDay/Week/Month/Year) → use last value (period totals)
                                                    {
                                                        $cond: [
                                                            {
                                                                $and: [
                                                                    {
                                                                        $in: ['$_id.measurementType', ['Water', 'Heating']]
                                                                    },
                                                                    {
                                                                        $or: [
                                                                            { $eq: ['$_id.stateType', 'totalDay'] },
                                                                            { $eq: ['$_id.stateType', 'totalWeek'] },
                                                                            { $eq: ['$_id.stateType', 'totalMonth'] },
                                                                            { $eq: ['$_id.stateType', 'totalYear'] }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            // Period totals: use last value
                                                            '$lastValue',
                                                            // Case 4: All others → average
                                                            '$avgValue'
                                                        ]
                                                    }
                                                ]
                                            }
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
                    into: dbName ? { db: dbName, coll: 'measurements_aggregated' } : 'measurements_aggregated',
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
                const aggregatedDocs = await db.collection('measurements_aggregated').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing daily aggregates for yesterday
                    const deleteMatchStage = {
                        resolution_minutes: 1440,
                        timestamp: { $gte: yesterday, $lt: today }
                    };
                    
                    await db.collection('measurements_aggregated').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 1440;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements_aggregated').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Daily] Created ${count} aggregates (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Daily] Created ${count} aggregates`);
            }
            
            // Delete 15-minute aggregates older than 1 day (now that we have daily aggregates)
            let deleted15MinCount = 0;
            if (count > 0) {
                // Delete 15-minute aggregates older than yesterday (1 day ago)
                const oneDayAgo = this.roundToDay(new Date(yesterday.getTime() - 24 * 60 * 60 * 1000));
                deleted15MinCount = await this.deleteOldAggregates(15, oneDayAgo);
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Daily] SUCCESS!`);
            console.log(`   Created ${count} daily aggregates`);
            console.log(`   Deleted ${deleted15MinCount} old 15-minute aggregates (older than 1 day)`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count, 
                deleted: deleted15MinCount
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
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateWeekly() {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new ServiceUnavailableError('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        // Get the database name
        const dbName = this.getDatabaseName();
        
        // Check and ensure measurements_aggregated collection is a Time Series collection
        const isTimeSeries = await this.ensureTimeSeriesCollection(db, '[weekly]');

        const now = new Date();
        const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        
        const weekStart = this.roundToWeek(oneWeekAgo);
        const currentWeekStart = this.roundToWeek(now);
        
        const matchStage = {
            resolution_minutes: 1440, // Aggregate from daily data
            timestamp: { $gte: weekStart, $lt: currentWeekStart }
        };
        
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
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        controlType: '$meta.controlType', // NEW: Group by controlType to keep EFM and Meter separate
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
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType',
                        controlType: '$_id.controlType' // NEW: Include controlType in aggregated documents
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
                    into: dbName ? { db: dbName, coll: 'measurements_aggregated' } : 'measurements_aggregated',
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
                const aggregatedDocs = await db.collection('measurements_aggregated').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing weekly aggregates in this time window
                    const deleteMatchStage = {
                        resolution_minutes: 10080,
                        timestamp: { $gte: weekStart, $lt: currentWeekStart }
                    };
                    
                    await db.collection('measurements_aggregated').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 10080;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements_aggregated').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Weekly] Created ${count} aggregates (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Weekly] Created ${count} aggregates`);
            }
            
            // Delete hourly aggregates older than 1 week (now that we have weekly aggregates)
            let deletedHourlyCount = 0;
            if (count > 0) {
                const oneWeekAgoCutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                deletedHourlyCount = await this.deleteOldAggregates(60, oneWeekAgoCutoff);
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Weekly] SUCCESS!`);
            console.log(`   Created ${count} weekly aggregates`);
            console.log(`   Deleted ${deletedHourlyCount} old hourly aggregates (older than 1 week)`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count, 
                deleted: deletedHourlyCount
            };
        } catch (error) {
            console.error(`[AGGREGATION] [Weekly] Error:`, error.message);
            throw error;
        }
    }
    
    /**
     * Aggregate daily/weekly data into monthly buckets
     * 
     * @returns {Promise<Object>} Aggregation result with count of created aggregates
     */
    async aggregateMonthly() {
        // Check connection health before starting heavy operations
        if (!isConnectionHealthy()) {
            throw new ServiceUnavailableError('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        // Get the database name
        const dbName = this.getDatabaseName();
        
        // Check and ensure measurements_aggregated collection is a Time Series collection
        const isTimeSeries = await this.ensureTimeSeriesCollection(db, '[monthly]');

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
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        controlType: '$meta.controlType', // NEW: Group by controlType to keep EFM and Meter separate
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
                        measurementType: '$_id.measurementType',
                        stateType: '$_id.stateType',
                        controlType: '$_id.controlType' // NEW: Include controlType in aggregated documents
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
                    into: dbName ? { db: dbName, coll: 'measurements_aggregated' } : 'measurements_aggregated',
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
                const aggregatedDocs = await db.collection('measurements_aggregated').aggregate(aggregationPipeline).toArray();
                
                if (aggregatedDocs.length > 0) {
                    // Delete existing monthly aggregates in this time window
                    const deleteMatchStage = {
                        resolution_minutes: 43200,
                        timestamp: { $gte: monthStart, $lt: currentMonthStart }
                    };
                    
                    await db.collection('measurements_aggregated').deleteMany(deleteMatchStage);
                    
                    // Ensure resolution_minutes is set (safeguard - always set explicitly)
                    aggregatedDocs.forEach(doc => {
                        doc.resolution_minutes = 43200;
                    });
                    
                    // Insert new aggregates
                    try {
                        const insertResult = await db.collection('measurements_aggregated').insertMany(aggregatedDocs, { ordered: false });
                        count = insertResult.insertedCount || aggregatedDocs.length;
                    } catch (error) {
                        if (error.insertedCount) {
                            count = error.insertedCount;
                        } else {
                            throw error;
                        }
                    }
                }
                console.log(`[AGGREGATION] [Monthly] Created ${count} aggregates (Time Series)`);
            } else {
                // Regular collection: use $merge
                const result = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
                count = result.length;
                console.log(`[AGGREGATION] [Monthly] Created ${count} aggregates`);
            }
            
            console.log(`\n========================================`);
            console.log(`✅ [AGGREGATION] [Monthly] SUCCESS!`);
            console.log(`   Created ${count} monthly aggregates`);
            console.log(`========================================\n`);
            
            return { 
                success: true, 
                count
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
     * @returns {Promise<number>} Number of deleted documents
     */
    async cleanupRawData(retentionDays = 30) {
        // Check connection health before starting operations
        if (!isConnectionHealthy()) {
            throw new ServiceUnavailableError('Database connection not healthy. Please check MongoDB connection.');
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }

        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
        
        // Note: measurements_raw only contains raw data, so no need to filter by resolution_minutes: 0
        const matchStage = {
            timestamp: { $lt: cutoffDate }
        };
        
        try {
            // Delete raw data from measurements_raw
            const result = await db.collection('measurements_raw').deleteMany(matchStage);
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
     * @returns {Promise<number>} Number of deleted documents
     */
    async deleteOldAggregates(resolutionMinutes, cutoffDate) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        const matchStage = {
            resolution_minutes: resolutionMinutes,
            timestamp: { $lt: cutoffDate }
        };
        
        try {
            // Count before deletion for better logging (delete from measurements_aggregated)
            const countBeforeDelete = await db.collection('measurements_aggregated').countDocuments(matchStage);
            const resolutionLabel = this.getResolutionLabel(resolutionMinutes);
            
            if (countBeforeDelete > 0) {
                console.log(`[AGGREGATION] [Cleanup] Preparing to delete ${countBeforeDelete} ${resolutionLabel} aggregates older than ${cutoffDate.toISOString()}`);
            }
            
            const result = await db.collection('measurements_aggregated').deleteMany(matchStage);
            
            if (result.deletedCount !== countBeforeDelete) {
                console.warn(`[AGGREGATION] [Cleanup] ⚠️  Deletion count mismatch: Expected ${countBeforeDelete}, deleted ${result.deletedCount}`);
            }
            
            if (result.deletedCount > 0) {
                console.log(`[AGGREGATION] [Cleanup] ✅ Deleted ${result.deletedCount} ${resolutionLabel} aggregates older than ${cutoffDate.toISOString()}`);
            }
            
            return result.deletedCount;
        } catch (error) {
            console.error(`[AGGREGATION] [Cleanup] ❌ Error deleting ${this.getResolutionLabel(resolutionMinutes)} aggregates:`, error.message);
            console.error(`[AGGREGATION] [Cleanup] Error stack:`, error.stack);
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

