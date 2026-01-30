require('dotenv').config();
const mongoose = require('mongoose');
const { connectToDatabase } = require('../db/connection');
const measurementAggregationService = require('../services/measurementAggregationService');

/**
 * Migration script to aggregate existing unaggregated data in measurements collection
 * 
 * This script processes:
 * 1. Raw data (resolution_minutes: 0) → 15-minute aggregates
 * 2. 15-minute data older than 1 hour → hourly aggregates
 * 3. Hourly data older than 1 week → daily aggregates
 * 
 * Usage: node backend/scripts/aggregateExistingData.js
 */

// Statistics tracking
const stats = {
    phase1: { rawProcessed: 0, aggregatesCreated: 0, rawDeleted: 0 },
    phase2: { processed: 0, aggregatesCreated: 0, deleted: 0 },
    phase3: { processed: 0, aggregatesCreated: 0, deleted: 0 },
    startTime: null,
    endTime: null
};

/**
 * Helper: Add days to a date
 */
function addDays(date, days) {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
}

/**
 * Helper: Add hours to a date
 */
function addHours(date, hours) {
    const result = new Date(date);
    result.setTime(result.getTime() + hours * 60 * 60 * 1000);
    return result;
}

/**
 * Helper: Round date to 15-minute boundary
 */
function roundTo15Minutes(date) {
    const rounded = new Date(date);
    const minutes = rounded.getMinutes();
    const roundedMinutes = Math.floor(minutes / 15) * 15;
    rounded.setMinutes(roundedMinutes, 0, 0);
    return rounded;
}

/**
 * Helper: Round date to hour boundary
 */
function roundToHour(date) {
    const rounded = new Date(date);
    rounded.setMinutes(0, 0, 0);
    return rounded;
}

/**
 * Helper: Round date to day boundary (start of day)
 */
function roundToDay(date) {
    const rounded = new Date(date);
    rounded.setHours(0, 0, 0, 0);
    return rounded;
}

/**
 * Check and suggest indexes for better performance
 */
async function checkIndexes() {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    try {
        const indexes = await collection.indexes();
        const hasResolutionTimestampIndex = indexes.some(idx => 
            idx.key && idx.key.resolution_minutes === 1 && idx.key.timestamp === 1
        );
        
        if (!hasResolutionTimestampIndex) {
            console.log('  ⚠️  Performance tip: Consider creating an index for faster queries:');
            console.log('     db.measurements.createIndex({ resolution_minutes: 1, timestamp: 1 })');
            console.log('     This will significantly speed up the migration.\n');
        } else {
            console.log('  ✓ Found index on resolution_minutes and timestamp\n');
        }
    } catch (error) {
        console.log('  ⚠️  Could not check indexes:', error.message);
    }
}

/**
 * Helper: Retry query with exponential backoff
 */
async function retryQuery(queryFn, maxRetries = 3, delayMs = 2000) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
            return await queryFn();
        } catch (error) {
            if (attempt === maxRetries) {
                throw error;
            }
            if (error.message.includes('timeout') || error.message.includes('timed out')) {
                console.log(`  ⚠️  Query timeout (attempt ${attempt}/${maxRetries}), retrying in ${delayMs}ms...`);
                await new Promise(resolve => setTimeout(resolve, delayMs));
                delayMs *= 2; // Exponential backoff
            } else {
                throw error;
            }
        }
    }
}

/**
 * Find oldest raw data timestamp using aggregation (more efficient)
 */
async function findOldestRawData() {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    return await retryQuery(async () => {
        // Use aggregation pipeline with limit for better performance
        const result = await collection.aggregate([
            { $match: { resolution_minutes: 0 } },
            { $sort: { timestamp: 1 } },
            { $limit: 1 },
            { $project: { timestamp: 1 } }
        ]).toArray();
        
        return result.length > 0 ? result[0].timestamp : null;
    });
}

/**
 * Find oldest 15-minute data timestamp using aggregation
 */
async function findOldest15MinData() {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    return await retryQuery(async () => {
        const result = await collection.aggregate([
            { $match: { resolution_minutes: 15 } },
            { $sort: { timestamp: 1 } },
            { $limit: 1 },
            { $project: { timestamp: 1 } }
        ]).toArray();
        
        return result.length > 0 ? result[0].timestamp : null;
    });
}

/**
 * Find oldest hourly data timestamp using aggregation
 */
async function findOldestHourlyData() {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    return await retryQuery(async () => {
        const result = await collection.aggregate([
            { $match: { resolution_minutes: 60 } },
            { $sort: { timestamp: 1 } },
            { $limit: 1 },
            { $project: { timestamp: 1 } }
        ]).toArray();
        
        return result.length > 0 ? result[0].timestamp : null;
    });
}

/**
 * Count documents in a time range with retry logic
 */
async function countDocuments(resolution, startDate, endDate, buildingId = null) {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    return await retryQuery(async () => {
        const matchStage = {
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (buildingId) {
            matchStage['meta.buildingId'] = {
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId]
            };
        }
        
        return await collection.countDocuments(matchStage);
    });
}

/**
 * Process raw data in a time window (aggregate to 15-minute)
 */
async function processRawDataWindow(windowStart, windowEnd, buildingId = null) {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    // Round to 15-minute boundaries
    const bucketStart = roundTo15Minutes(windowStart);
    const safeEnd = roundTo15Minutes(windowEnd);
    
    // Count raw data in this window
    const rawCount = await countDocuments(0, bucketStart, safeEnd, buildingId);
    
    if (rawCount === 0) {
        return { created: 0, deleted: 0 };
    }
    
    console.log(`  Processing ${rawCount} raw data points from ${bucketStart.toISOString()} to ${safeEnd.toISOString()}`);
    
    const matchStage = {
        resolution_minutes: 0,
        timestamp: { $gte: bucketStart, $lt: safeEnd }
    };
    
    if (buildingId) {
        matchStage['meta.buildingId'] = {
            $in: [new mongoose.Types.ObjectId(buildingId), buildingId]
        };
    }
    
    // Check if Time Series collection
    const isTimeSeries = await measurementAggregationService.isTimeSeriesCollection(db, 'measurements');
    
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
                    buildingId: '$_id.buildingId',
                    measurementType: '$_id.measurementType',
                    stateType: '$_id.stateType'
                },
                value: '$avgValue',
                avgValue: '$avgValue',
                minValue: '$minValue',
                maxValue: '$maxValue',
                firstValue: '$firstValue',
                lastValue: '$lastValue',
                count: '$count',
                unit: '$unit',
                quality: '$quality',
                resolution_minutes: 15,
                source: 'aggregated'
            }
        }
    ];
    
    let created = 0;
    let deleted = 0;
    
    if (isTimeSeries) {
        // Time Series: use insertMany
        const aggregatedDocs = await collection.aggregate(pipeline).toArray();
        
        if (aggregatedDocs.length > 0) {
            // Ensure all documents have resolution_minutes
            aggregatedDocs.forEach(doc => {
                if (!doc.resolution_minutes) {
                    doc.resolution_minutes = 15;
                }
            });
            
            await collection.insertMany(aggregatedDocs, { ordered: false });
            created = aggregatedDocs.length;
            
            // Delete raw data after successful aggregation
            const deleteResult = await collection.deleteMany(matchStage);
            deleted = deleteResult.deletedCount;
        }
    } else {
        // Regular collection: use $merge
        const dbName = measurementAggregationService.getDatabaseName();
        const mergeStage = {
            into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
            whenMatched: 'replace',
            whenNotMatched: 'insert'
        };
        
        pipeline.push({ $merge: mergeStage });
        
        await collection.aggregate(pipeline).toArray();
        
        // Count created aggregates
        created = await countDocuments(15, bucketStart, safeEnd, buildingId);
        
        // Delete raw data after successful aggregation
        const deleteResult = await collection.deleteMany(matchStage);
        deleted = deleteResult.deletedCount;
    }
    
    return { created, deleted };
}

/**
 * Process 15-minute data in a time window (aggregate to hourly)
 * Only processes data older than 1 hour
 */
async function process15MinDataWindow(windowStart, windowEnd, buildingId = null) {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    // Only process data older than 1 hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const effectiveStart = windowStart < oneHourAgo ? windowStart : oneHourAgo;
    const effectiveEnd = windowEnd < oneHourAgo ? windowEnd : oneHourAgo;
    
    if (effectiveStart >= effectiveEnd) {
        return { created: 0, deleted: 0 };
    }
    
    // Round to hour boundaries
    const bucketStart = roundToHour(effectiveStart);
    const bucketEnd = roundToHour(effectiveEnd);
    
    // Count 15-minute data in this window
    const count15Min = await countDocuments(15, bucketStart, bucketEnd, buildingId);
    
    if (count15Min === 0) {
        return { created: 0, deleted: 0 };
    }
    
    console.log(`  Processing ${count15Min} 15-minute data points from ${bucketStart.toISOString()} to ${bucketEnd.toISOString()}`);
    
    const matchStage = {
        resolution_minutes: 15,
        timestamp: { $gte: bucketStart, $lt: bucketEnd }
    };
    
    if (buildingId) {
        matchStage['meta.buildingId'] = {
            $in: [new mongoose.Types.ObjectId(buildingId), buildingId]
        };
    }
    
    const isTimeSeries = await measurementAggregationService.isTimeSeriesCollection(db, 'measurements');
    
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
                value: '$avgValue',
                avgValue: '$avgValue',
                minValue: '$minValue',
                maxValue: '$maxValue',
                count: '$count',
                unit: '$unit',
                quality: '$quality',
                resolution_minutes: 60,
                source: 'aggregated'
            }
        }
    ];
    
    let created = 0;
    let deleted = 0;
    
    if (isTimeSeries) {
        const aggregatedDocs = await collection.aggregate(pipeline).toArray();
        
        if (aggregatedDocs.length > 0) {
            aggregatedDocs.forEach(doc => {
                if (!doc.resolution_minutes) {
                    doc.resolution_minutes = 60;
                }
            });
            
            await collection.insertMany(aggregatedDocs, { ordered: false });
            created = aggregatedDocs.length;
            
            const deleteResult = await collection.deleteMany(matchStage);
            deleted = deleteResult.deletedCount;
        }
    } else {
        const dbName = measurementAggregationService.getDatabaseName();
        const mergeStage = {
            into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
            whenMatched: 'replace',
            whenNotMatched: 'insert'
        };
        
        pipeline.push({ $merge: mergeStage });
        await collection.aggregate(pipeline).toArray();
        
        created = await countDocuments(60, bucketStart, bucketEnd, buildingId);
        
        const deleteResult = await collection.deleteMany(matchStage);
        deleted = deleteResult.deletedCount;
    }
    
    return { created, deleted };
}

/**
 * Process hourly data in a time window (aggregate to daily)
 * Only processes data older than 1 week
 */
async function processHourlyDataWindow(windowStart, windowEnd, buildingId = null) {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    // Only process data older than 1 week
    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const effectiveStart = windowStart < oneWeekAgo ? windowStart : oneWeekAgo;
    const effectiveEnd = windowEnd < oneWeekAgo ? windowEnd : oneWeekAgo;
    
    if (effectiveStart >= effectiveEnd) {
        return { created: 0, deleted: 0 };
    }
    
    // Round to day boundaries
    const bucketStart = roundToDay(effectiveStart);
    const bucketEnd = roundToDay(effectiveEnd);
    
    // Count hourly data in this window
    const countHourly = await countDocuments(60, bucketStart, bucketEnd, buildingId);
    
    if (countHourly === 0) {
        return { created: 0, deleted: 0 };
    }
    
    console.log(`  Processing ${countHourly} hourly data points from ${bucketStart.toISOString()} to ${bucketEnd.toISOString()}`);
    
    const matchStage = {
        resolution_minutes: 60,
        timestamp: { $gte: bucketStart, $lt: bucketEnd }
    };
    
    if (buildingId) {
        matchStage['meta.buildingId'] = {
            $in: [new mongoose.Types.ObjectId(buildingId), buildingId]
        };
    }
    
    const isTimeSeries = await measurementAggregationService.isTimeSeriesCollection(db, 'measurements');
    
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
                value: '$avgValue',
                avgValue: '$avgValue',
                minValue: '$minValue',
                maxValue: '$maxValue',
                count: '$count',
                unit: '$unit',
                quality: '$quality',
                resolution_minutes: 1440,
                source: 'aggregated'
            }
        }
    ];
    
    let created = 0;
    let deleted = 0;
    
    if (isTimeSeries) {
        const aggregatedDocs = await collection.aggregate(pipeline).toArray();
        
        if (aggregatedDocs.length > 0) {
            aggregatedDocs.forEach(doc => {
                if (!doc.resolution_minutes) {
                    doc.resolution_minutes = 1440;
                }
            });
            
            await collection.insertMany(aggregatedDocs, { ordered: false });
            created = aggregatedDocs.length;
            
            const deleteResult = await collection.deleteMany(matchStage);
            deleted = deleteResult.deletedCount;
        }
    } else {
        const dbName = measurementAggregationService.getDatabaseName();
        const mergeStage = {
            into: dbName ? { db: dbName, coll: 'measurements' } : 'measurements',
            whenMatched: 'replace',
            whenNotMatched: 'insert'
        };
        
        pipeline.push({ $merge: mergeStage });
        await collection.aggregate(pipeline).toArray();
        
        created = await countDocuments(1440, bucketStart, bucketEnd, buildingId);
        
        const deleteResult = await collection.deleteMany(matchStage);
        deleted = deleteResult.deletedCount;
    }
    
    return { created, deleted };
}

/**
 * Phase 1: Aggregate raw data to 15-minute
 */
async function phase1AggregateRawData() {
    console.log('\n[MIGRATION] Phase 1: Aggregating raw data to 15-minute...');
    console.log('  Finding oldest raw data...');
    
    let oldestRaw;
    try {
        oldestRaw = await findOldestRawData();
    } catch (error) {
        console.error('  ✗ Error finding oldest raw data:', error.message);
        console.log('  ⚠️  Skipping Phase 1 due to query timeout. This may indicate a very large collection.');
        console.log('  💡 Consider creating indexes: db.measurements.createIndex({ resolution_minutes: 1, timestamp: 1 })');
        return;
    }
    
    if (!oldestRaw) {
        console.log('  No raw data found. Skipping Phase 1.');
        return;
    }
    
    const now = new Date();
    const windowDays = 1; // Process 1 day at a time
    
    console.log(`  Found raw data from ${oldestRaw.toISOString()} to ${now.toISOString()}`);
    
    let windowStart = new Date(oldestRaw);
    windowStart = roundTo15Minutes(windowStart);
    
    let totalCreated = 0;
    let totalDeleted = 0;
    let windowCount = 0;
    
    while (windowStart < now) {
        const windowEnd = Math.min(addDays(windowStart, windowDays), now);
        
        try {
            const result = await processRawDataWindow(windowStart, windowEnd);
            totalCreated += result.created;
            totalDeleted += result.deleted;
            windowCount++;
            
            stats.phase1.rawProcessed += result.deleted;
            stats.phase1.aggregatesCreated += result.created;
            stats.phase1.rawDeleted += result.deleted;
            
            if (result.created > 0 || result.deleted > 0) {
                console.log(`  ✓ Window ${windowCount}: Created ${result.created} aggregates, deleted ${result.deleted} raw data points`);
            }
        } catch (error) {
            console.error(`  ✗ Error processing window ${windowStart.toISOString()} to ${windowEnd.toISOString()}:`, error.message);
            // Continue with next window
        }
        
        windowStart = windowEnd;
    }
    
    console.log(`\n[MIGRATION] Phase 1 complete: ${totalDeleted} raw → ${totalCreated} 15-minute aggregates`);
}

/**
 * Phase 2: Aggregate 15-minute data (older than 1 hour) to hourly
 */
async function phase2Aggregate15MinData() {
    console.log('\n[MIGRATION] Phase 2: Aggregating 15-minute data (older than 1 hour) to hourly...');
    console.log('  Finding oldest 15-minute data...');
    
    let oldest15Min;
    try {
        oldest15Min = await findOldest15MinData();
    } catch (error) {
        console.error('  ✗ Error finding oldest 15-minute data:', error.message);
        console.log('  ⚠️  Skipping Phase 2 due to query timeout.');
        return;
    }
    
    if (!oldest15Min) {
        console.log('  No 15-minute data found. Skipping Phase 2.');
        return;
    }
    
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    const effectiveStart = oldest15Min < oneHourAgo ? oldest15Min : oneHourAgo;
    
    if (effectiveStart >= oneHourAgo) {
        console.log('  No 15-minute data older than 1 hour. Skipping Phase 2.');
        return;
    }
    
    const windowHours = 24; // Process 24 hours at a time
    
    console.log(`  Found 15-minute data from ${effectiveStart.toISOString()} to ${oneHourAgo.toISOString()}`);
    
    let windowStart = new Date(effectiveStart);
    windowStart = roundToHour(windowStart);
    
    let totalCreated = 0;
    let totalDeleted = 0;
    let windowCount = 0;
    
    while (windowStart < oneHourAgo) {
        const windowEnd = Math.min(addHours(windowStart, windowHours), oneHourAgo);
        
        try {
            const result = await process15MinDataWindow(windowStart, windowEnd);
            totalCreated += result.created;
            totalDeleted += result.deleted;
            windowCount++;
            
            stats.phase2.processed += result.deleted;
            stats.phase2.aggregatesCreated += result.created;
            stats.phase2.deleted += result.deleted;
            
            if (result.created > 0 || result.deleted > 0) {
                console.log(`  ✓ Window ${windowCount}: Created ${result.created} aggregates, deleted ${result.deleted} 15-minute data points`);
            }
        } catch (error) {
            console.error(`  ✗ Error processing window ${windowStart.toISOString()} to ${windowEnd.toISOString()}:`, error.message);
            // Continue with next window
        }
        
        windowStart = windowEnd;
    }
    
    console.log(`\n[MIGRATION] Phase 2 complete: ${totalDeleted} 15-minute → ${totalCreated} hourly aggregates`);
}

/**
 * Phase 3: Aggregate hourly data (older than 1 week) to daily
 */
async function phase3AggregateHourlyData() {
    console.log('\n[MIGRATION] Phase 3: Aggregating hourly data (older than 1 week) to daily...');
    console.log('  Finding oldest hourly data...');
    
    let oldestHourly;
    try {
        oldestHourly = await findOldestHourlyData();
    } catch (error) {
        console.error('  ✗ Error finding oldest hourly data:', error.message);
        console.log('  ⚠️  Skipping Phase 3 due to query timeout.');
        return;
    }
    
    if (!oldestHourly) {
        console.log('  No hourly data found. Skipping Phase 3.');
        return;
    }
    
    const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const effectiveStart = oldestHourly < oneWeekAgo ? oldestHourly : oneWeekAgo;
    
    if (effectiveStart >= oneWeekAgo) {
        console.log('  No hourly data older than 1 week. Skipping Phase 3.');
        return;
    }
    
    const windowDays = 7; // Process 7 days at a time
    
    console.log(`  Found hourly data from ${effectiveStart.toISOString()} to ${oneWeekAgo.toISOString()}`);
    
    let windowStart = new Date(effectiveStart);
    windowStart = roundToDay(windowStart);
    
    let totalCreated = 0;
    let totalDeleted = 0;
    let windowCount = 0;
    
    while (windowStart < oneWeekAgo) {
        const windowEnd = Math.min(addDays(windowStart, windowDays), oneWeekAgo);
        
        try {
            const result = await processHourlyDataWindow(windowStart, windowEnd);
            totalCreated += result.created;
            totalDeleted += result.deleted;
            windowCount++;
            
            stats.phase3.processed += result.deleted;
            stats.phase3.aggregatesCreated += result.created;
            stats.phase3.deleted += result.deleted;
            
            if (result.created > 0 || result.deleted > 0) {
                console.log(`  ✓ Window ${windowCount}: Created ${result.created} aggregates, deleted ${result.deleted} hourly data points`);
            }
        } catch (error) {
            console.error(`  ✗ Error processing window ${windowStart.toISOString()} to ${windowEnd.toISOString()}:`, error.message);
            // Continue with next window
        }
        
        windowStart = windowEnd;
    }
    
    console.log(`\n[MIGRATION] Phase 3 complete: ${totalDeleted} hourly → ${totalCreated} daily aggregates`);
}
/**
 * Get total document counts by resolution
 */
async function getDocumentCounts() {
    const db = mongoose.connection.db;
    const collection = db.collection('measurements');
    
    console.log('\n📊 Current Document Counts:');
    
    try {
        const counts = await Promise.all([
            collection.countDocuments({}),
            collection.countDocuments({ resolution_minutes: 0 }),
            collection.countDocuments({ resolution_minutes: 15 }),
            collection.countDocuments({ resolution_minutes: 60 }),
            collection.countDocuments({ resolution_minutes: 1440 }),
        ]);
        
        console.log(`  Total: ${counts[0].toLocaleString()}`);
        console.log(`  Raw (0): ${counts[1].toLocaleString()}`);
        console.log(`  15-minute (15): ${counts[2].toLocaleString()}`);
        console.log(`  Hourly (60): ${counts[3].toLocaleString()}`);
        console.log(`  Daily (1440): ${counts[4].toLocaleString()}`);
    } catch (error) {
        console.error('  Error getting counts:', error.message);
    }
}

/**
 * Main function
 */
async function main() {
    stats.startTime = Date.now();
    
    console.log('========================================');
    console.log('[MIGRATION] Starting data aggregation migration...');
    console.log('========================================\n');
    
    try {
        // Connect to database with increased timeouts for large queries
        await connectToDatabase();
        
        // Increase socket timeout for long-running queries
        mongoose.connection.setMaxListeners(0);
        mongoose.connection.db.client.options.socketTimeoutMS = 300000; // 5 minutes
        mongoose.connection.db.client.options.serverSelectionTimeoutMS = 60000; // 1 minute
        
        console.log('✅ Connected to MongoDB');
        console.log('  Socket timeout: 5 minutes');
        console.log('  Server selection timeout: 1 minute\n');
        
        // Check indexes for performance
        await checkIndexes();
        await getDocumentCounts();
        // Run all phases
        await phase1AggregateRawData();
        await phase2Aggregate15MinData();
        await phase3AggregateHourlyData();
        
        stats.endTime = Date.now();
        const totalTime = Math.round((stats.endTime - stats.startTime) / 1000);
        const minutes = Math.floor(totalTime / 60);
        const seconds = totalTime % 60;
        
        console.log('\n========================================');
        console.log('[MIGRATION] Migration complete! Summary:');
        console.log('========================================');
        console.log(`Phase 1 (Raw → 15-minute):`);
        console.log(`  - Raw data processed: ${stats.phase1.rawProcessed.toLocaleString()}`);
        console.log(`  - 15-minute aggregates created: ${stats.phase1.aggregatesCreated.toLocaleString()}`);
        console.log(`  - Raw data deleted: ${stats.phase1.rawDeleted.toLocaleString()}`);
        console.log(`\nPhase 2 (15-minute → Hourly):`);
        console.log(`  - 15-minute data processed: ${stats.phase2.processed.toLocaleString()}`);
        console.log(`  - Hourly aggregates created: ${stats.phase2.aggregatesCreated.toLocaleString()}`);
        console.log(`  - 15-minute data deleted: ${stats.phase2.deleted.toLocaleString()}`);
        console.log(`\nPhase 3 (Hourly → Daily):`);
        console.log(`  - Hourly data processed: ${stats.phase3.processed.toLocaleString()}`);
        console.log(`  - Daily aggregates created: ${stats.phase3.aggregatesCreated.toLocaleString()}`);
        console.log(`  - Hourly data deleted: ${stats.phase3.deleted.toLocaleString()}`);
        console.log(`\nTotal time: ${minutes}m ${seconds}s`);
        console.log('========================================\n');
        
    } catch (error) {
        console.error('\n[MIGRATION] Fatal error:', error.message);
        console.error(error.stack);
        process.exit(1);
    } finally {
        // Close database connection
        await mongoose.connection.close();
        console.log('✅ Database connection closed');
    }
}

// Run the script
if (require.main === module) {
    main().catch(error => {
        console.error('Unhandled error:', error);
        process.exit(1);
    });
}

module.exports = { main };
