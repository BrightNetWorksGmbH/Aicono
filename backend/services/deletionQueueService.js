const mongoose = require('mongoose');
const { getPoolStatistics, isConnectionHealthy } = require('../db/connection');

/**
 * Deletion Queue Service
 * 
 * Processes measurement deletions in the background to prevent blocking
 * aggregation operations and API requests. Uses rate limiting and connection
 * pool awareness to avoid overwhelming the database.
 */
class DeletionQueueService {
    constructor() {
        this.queue = [];
        this.processing = false;
        this.stats = {
            totalQueued: 0,
            totalProcessed: 0,
            totalDeleted: 0,
            totalErrors: 0,
            lastProcessed: null
        };
        
        // Configuration from environment variables
        this.config = {
            batchSize: parseInt(process.env.DELETION_QUEUE_BATCH_SIZE || '50000', 10),
            intervalMs: parseInt(process.env.DELETION_QUEUE_INTERVAL_MS || '2000', 10),
            maxPoolUsage: parseInt(process.env.DELETION_QUEUE_MAX_POOL_USAGE || '85', 10),
            minPoolUsage: 70, // Resume processing when pool usage drops below this
            maxRetries: 3
        };
        
        console.log(`[DELETION-QUEUE] Initialized with batchSize=${this.config.batchSize}, interval=${this.config.intervalMs}ms, maxPoolUsage=${this.config.maxPoolUsage}%`);
        
        // Start processing loop
        this.startProcessing();
    }

    /**
     * Add a deletion task to the queue
     * @param {Object} task - Deletion task
     * @param {string} task.collectionName - Collection name (e.g., 'measurements_raw')
     * @param {Object} task.matchStage - MongoDB match query
     * @param {string} task.description - Optional description for logging
     * @returns {Promise<void>}
     */
    async enqueue(collectionName, matchStage, description = null) {
        if (!collectionName || !matchStage) {
            console.warn('[DELETION-QUEUE] Invalid deletion task: missing collectionName or matchStage');
            return;
        }

        const task = {
            id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            collectionName,
            matchStage,
            description: description || `Delete from ${collectionName}`,
            queuedAt: new Date(),
            retries: 0
        };

        this.queue.push(task);
        this.stats.totalQueued++;
        
        console.log(`[DELETION-QUEUE] Queued deletion task: ${task.description} (queue size: ${this.queue.length})`);
    }

    /**
     * Start the processing loop
     */
    startProcessing() {
        if (this.processing) {
            return;
        }

        this.processing = true;
        this.processLoop();
    }

    /**
     * Main processing loop
     */
    async processLoop() {
        while (this.processing) {
            try {
                // Check connection health
                if (!isConnectionHealthy()) {
                    console.warn('[DELETION-QUEUE] Database not healthy, pausing deletion processing...');
                    await new Promise(resolve => setTimeout(resolve, 5000));
                    continue;
                }

                // Check connection pool usage
                const poolStats = await getPoolStatistics();
                if (poolStats.available && poolStats.usagePercent >= this.config.maxPoolUsage) {
                    // Pool usage is high, wait before processing
                    const waitTime = 5000; // Wait 5 seconds
                    console.log(`[DELETION-QUEUE] Pool usage high (${poolStats.usagePercent}%), waiting ${waitTime}ms before processing...`);
                    await new Promise(resolve => setTimeout(resolve, waitTime));
                    continue;
                }

                // Process queue if there are tasks
                if (this.queue.length > 0) {
                    await this.processNextTask();
                } else {
                    // No tasks, wait before checking again
                    await new Promise(resolve => setTimeout(resolve, this.config.intervalMs));
                }
            } catch (error) {
                console.error('[DELETION-QUEUE] Error in processing loop:', error.message);
                this.stats.totalErrors++;
                await new Promise(resolve => setTimeout(resolve, 5000));
            }
        }
    }

    /**
     * Process the next task in the queue
     */
    async processNextTask() {
        if (this.queue.length === 0) {
            return;
        }

        const task = this.queue.shift();
        const startTime = Date.now();

        try {
            console.log(`[DELETION-QUEUE] Processing: ${task.description} (task ID: ${task.id})`);

            // Check pool usage before starting
            const poolStats = await getPoolStatistics();
            if (poolStats.available && poolStats.usagePercent >= this.config.maxPoolUsage) {
                // Pool is too high, re-queue the task
                console.log(`[DELETION-QUEUE] Pool usage too high (${poolStats.usagePercent}%), re-queuing task...`);
                this.queue.unshift(task);
                await new Promise(resolve => setTimeout(resolve, this.config.intervalMs));
                return;
            }

            // Execute deletion using optimized direct deleteMany
            const deletedCount = await this.executeDeletion(
                task.collectionName,
                task.matchStage,
                this.config.batchSize,
                this.config.maxRetries
            );

            const duration = Date.now() - startTime;
            this.stats.totalProcessed++;
            this.stats.totalDeleted += deletedCount;
            this.stats.lastProcessed = new Date();

            console.log(`[DELETION-QUEUE] ✅ Completed: ${task.description} - deleted ${deletedCount} documents in ${duration}ms`);

            // Wait before processing next task to avoid overwhelming the pool
            await new Promise(resolve => setTimeout(resolve, this.config.intervalMs));

        } catch (error) {
            const duration = Date.now() - startTime;
            task.retries++;
            this.stats.totalErrors++;

            if (task.retries < this.config.maxRetries) {
                console.warn(`[DELETION-QUEUE] Task failed (attempt ${task.retries}/${this.config.maxRetries}), retrying: ${error.message}`);
                // Re-queue with exponential backoff
                const backoffMs = Math.pow(2, task.retries) * 1000;
                setTimeout(() => {
                    this.queue.unshift(task);
                }, backoffMs);
            } else {
                console.error(`[DELETION-QUEUE] ❌ Task failed after ${this.config.maxRetries} attempts: ${task.description} - ${error.message}`);
            }
        }
    }

    /**
     * Optimized direct deletion using deleteMany with match query
     * This is much faster than the old deleteInBatches approach
     * 
     * @param {string} collectionName - Collection name
     * @param {Object} matchStage - MongoDB match query
     * @param {number} maxBatchSize - Maximum documents to delete in one operation
     * @param {number} maxRetries - Maximum retry attempts
     * @returns {Promise<number>} Number of documents deleted
     */
    async executeDeletion(collectionName, matchStage, maxBatchSize = 50000, maxRetries = 3) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        const collection = db.collection(collectionName);
        let totalDeleted = 0;
        let attempts = 0;

        // For very large deletions, we may need to delete in chunks
        // But first, try a single deleteMany operation (MongoDB handles this efficiently)
        while (attempts < maxRetries) {
            try {
                attempts++;
                const deleteStartTime = Date.now();

                // Direct deleteMany - MongoDB handles large deletions efficiently
                // For Time Series collections, this is optimized by MongoDB
                const deleteResult = await collection.deleteMany(matchStage);
                const deletedCount = deleteResult.deletedCount || 0;
                const duration = Date.now() - deleteStartTime;

                totalDeleted += deletedCount;

                console.log(`[DELETION-QUEUE] [DELETE-DIRECT] Deleted ${deletedCount} documents from ${collectionName} in ${duration}ms`);

                // If we got fewer documents than expected, we're done
                // For very large datasets, MongoDB might limit the deletion
                // In that case, we'd need to delete in chunks, but this is rare
                if (deletedCount === 0 || deletedCount < maxBatchSize) {
                    break;
                }

                // If we deleted exactly maxBatchSize, there might be more
                // Yield to event loop and check again
                await new Promise(resolve => setImmediate(resolve));

            } catch (error) {
                if (attempts < maxRetries) {
                    const waitTime = Math.pow(2, attempts) * 1000; // Exponential backoff
                    console.warn(`[DELETION-QUEUE] [DELETE-DIRECT] Deletion failed, retrying in ${waitTime}ms (attempt ${attempts}/${maxRetries}): ${error.message}`);
                    await new Promise(resolve => setTimeout(resolve, waitTime));
                } else {
                    throw error;
                }
            }
        }

        return totalDeleted;
    }

    /**
     * Get queue statistics
     * @returns {Object} Queue statistics
     */
    getStats() {
        return {
            queueSize: this.queue.length,
            processing: this.processing,
            stats: { ...this.stats },
            config: { ...this.config }
        };
    }

    /**
     * Stop processing (for graceful shutdown)
     */
    stop() {
        this.processing = false;
        console.log('[DELETION-QUEUE] Processing stopped');
    }
}

module.exports = new DeletionQueueService();
