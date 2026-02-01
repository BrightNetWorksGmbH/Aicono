const mongoose = require('mongoose');

/**
 * Measurement Collection Service
 * 
 * Manages initialization and setup of measurement collections:
 * - measurements_raw: Raw data (resolution_minutes: 0)
 * - measurements_aggregated: All aggregated data (15, 60, 1440, 10080, 43200)
 * 
 * Both collections are MongoDB Time Series collections for optimal performance.
 */
class MeasurementCollectionService {
    constructor() {
        // Track if collections have been initialized to avoid redundant checks
        this._initialized = false;
        this._initializationPromise = null;
    }

    /**
     * Initialize measurements_raw Time Series collection
     * @returns {Promise<void>}
     */
    async initializeRawCollection() {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        const collectionName = 'measurements_raw';
        const collections = await db.listCollections({ name: collectionName }).toArray();
        const collectionExists = collections.length > 0;

        let isTimeSeries = false;
        let hasCorrectMetaField = false;

        if (collectionExists) {
            const collectionInfo = collections[0];
            const options = collectionInfo.options || {};
            const timeseries = options.timeseries || {};
            isTimeSeries = !!(timeseries && timeseries.timeField);
            hasCorrectMetaField = timeseries.metaField === 'meta';
        }

        if (collectionExists && (!isTimeSeries || !hasCorrectMetaField)) {
            console.warn(`[MEASUREMENT-COLLECTIONS] Collection ${collectionName} exists but is not valid Time Series, dropping...`);
            try {
                await db.collection(collectionName).drop();
                await db.collection(`system.buckets.${collectionName}`).drop().catch(() => {});
                await new Promise(resolve => setTimeout(resolve, 100));
            } catch (error) {
                if (!error.message.includes('ns not found')) {
                    throw error;
                }
            }
        }

        if (!collectionExists || !isTimeSeries || !hasCorrectMetaField) {
            try {
                await db.createCollection(collectionName, {
                    timeseries: {
                        timeField: 'timestamp',
                        metaField: 'meta',
                        granularity: 'seconds'
                    }
                });
                console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created Time Series collection: ${collectionName}`);

                // Create indexes for optimal query performance
                await this.createRawCollectionIndexes(collectionName);
            } catch (error) {
                if (error.message.includes('already exists')) {
                    console.log(`[MEASUREMENT-COLLECTIONS] Collection ${collectionName} already exists`);
                } else {
                    throw error;
                }
            }
        } else {
            console.log(`[MEASUREMENT-COLLECTIONS] Collection ${collectionName} already exists and is valid`);
        }
    }

    /**
     * Initialize measurements_aggregated Time Series collection
     * @returns {Promise<void>}
     */
    async initializeAggregatedCollection() {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        const collectionName = 'measurements_aggregated';
        const collections = await db.listCollections({ name: collectionName }).toArray();
        const collectionExists = collections.length > 0;

        let isTimeSeries = false;
        let hasCorrectMetaField = false;

        if (collectionExists) {
            const collectionInfo = collections[0];
            const options = collectionInfo.options || {};
            const timeseries = options.timeseries || {};
            isTimeSeries = !!(timeseries && timeseries.timeField);
            hasCorrectMetaField = timeseries.metaField === 'meta';
        }

        if (collectionExists && (!isTimeSeries || !hasCorrectMetaField)) {
            console.warn(`[MEASUREMENT-COLLECTIONS] Collection ${collectionName} exists but is not valid Time Series, dropping...`);
            try {
                await db.collection(collectionName).drop();
                await db.collection(`system.buckets.${collectionName}`).drop().catch(() => {});
                await new Promise(resolve => setTimeout(resolve, 100));
            } catch (error) {
                if (!error.message.includes('ns not found')) {
                    throw error;
                }
            }
        }

        if (!collectionExists || !isTimeSeries || !hasCorrectMetaField) {
            try {
                await db.createCollection(collectionName, {
                    timeseries: {
                        timeField: 'timestamp',
                        metaField: 'meta',
                        granularity: 'seconds'
                    }
                });
                console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created Time Series collection: ${collectionName}`);

                // Create indexes for optimal query performance
                await this.createAggregatedCollectionIndexes(collectionName);
            } catch (error) {
                if (error.message.includes('already exists')) {
                    console.log(`[MEASUREMENT-COLLECTIONS] Collection ${collectionName} already exists`);
                } else {
                    throw error;
                }
            }
        } else {
            console.log(`[MEASUREMENT-COLLECTIONS] Collection ${collectionName} already exists and is valid`);
        }
    }

    /**
     * Create indexes for measurements_raw collection
     * @param {string} collectionName - Collection name
     * @returns {Promise<void>}
     */
    async createRawCollectionIndexes(collectionName) {
        const db = mongoose.connection.db;
        const collection = db.collection(collectionName);

        try {
            // Index for building queries
            await collection.createIndex({ 'meta.buildingId': 1, timestamp: -1 }, { background: true });
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created index on ${collectionName}: meta.buildingId + timestamp`);

            // Index for sensor queries
            await collection.createIndex({ 'meta.sensorId': 1, timestamp: -1 }, { background: true });
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created index on ${collectionName}: meta.sensorId + timestamp`);

            // Index for resolution queries (always 0, but useful for consistency)
            await collection.createIndex({ resolution_minutes: 1, timestamp: -1 }, { background: true });
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created index on ${collectionName}: resolution_minutes + timestamp`);
            
            // Optimized compound index for deletion queries (timestamp range + buildingId)
            // This is critical for efficient deletion operations
            // Order: timestamp first (for range queries), then buildingId (for filtering)
            await collection.createIndex({ timestamp: 1, 'meta.buildingId': 1 }, { background: true });
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created optimized deletion index on ${collectionName}: timestamp + meta.buildingId`);
        } catch (error) {
            // Index might already exist, which is fine
            if (!error.message.includes('already exists') && !error.message.includes('duplicate key')) {
                console.warn(`[MEASUREMENT-COLLECTIONS] Warning creating indexes on ${collectionName}:`, error.message);
            }
        }
    }

    /**
     * Create indexes for measurements_aggregated collection
     * @param {string} collectionName - Collection name
     * @returns {Promise<void>}
     */
    async createAggregatedCollectionIndexes(collectionName) {
        const db = mongoose.connection.db;
        const collection = db.collection(collectionName);

        try {
            // Compound index for building queries with resolution
            await collection.createIndex(
                { 'meta.buildingId': 1, resolution_minutes: 1, timestamp: -1 },
                { background: true }
            );
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created compound index on ${collectionName}: meta.buildingId + resolution_minutes + timestamp`);

            // Compound index for sensor queries with resolution
            await collection.createIndex(
                { 'meta.sensorId': 1, resolution_minutes: 1, timestamp: -1 },
                { background: true }
            );
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created compound index on ${collectionName}: meta.sensorId + resolution_minutes + timestamp`);

            // Index for resolution queries
            await collection.createIndex({ resolution_minutes: 1, timestamp: -1 }, { background: true });
            console.log(`[MEASUREMENT-COLLECTIONS] ✓ Created index on ${collectionName}: resolution_minutes + timestamp`);
        } catch (error) {
            // Index might already exist, which is fine
            if (!error.message.includes('already exists') && !error.message.includes('duplicate key')) {
                console.warn(`[MEASUREMENT-COLLECTIONS] Warning creating indexes on ${collectionName}:`, error.message);
            }
        }
    }

    /**
     * Ensure both collections exist with correct structure
     * @returns {Promise<void>}
     */
    async ensureCollectionsExist() {
        // If already initialized, return immediately (avoid redundant checks)
        if (this._initialized) {
            return;
        }
        
        // If initialization is in progress, wait for it
        if (this._initializationPromise) {
            return this._initializationPromise;
        }
        
        // Start initialization and cache the promise
        this._initializationPromise = (async () => {
            try {
                await this.initializeRawCollection();
                await this.initializeAggregatedCollection();
                console.log('[MEASUREMENT-COLLECTIONS] ✓ Both measurement collections initialized');
                this._initialized = true;
            } catch (error) {
                // Reset promise on error so it can be retried
                this._initializationPromise = null;
                throw error;
            }
        })();
        
        return this._initializationPromise;
    }

    /**
     * Get collection name based on resolution
     * @param {number} resolution_minutes - Resolution in minutes
     * @returns {string} Collection name
     */
    static getCollectionName(resolution_minutes) {
        return resolution_minutes === 0 ? 'measurements_raw' : 'measurements_aggregated';
    }
}

module.exports = new MeasurementCollectionService();
