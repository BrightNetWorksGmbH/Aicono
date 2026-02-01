const loxoneStorageService = require('./loxoneStorageService');
const { getPoolStatistics, PRIORITY } = require('../db/connection');

/**
 * Measurement Queue Service
 * 
 * Processes measurement storage operations in the background to prevent
 * blocking WebSocket handlers and REST API requests.
 * 
 * Uses a simple in-memory queue with batching to optimize database operations.
 */
class MeasurementQueueService {
    constructor() {
        // Queue: Map<buildingId, Array<measurements>>
        this.queue = new Map();
        // Processing flags: Map<buildingId, boolean>
        this.processing = new Map();
        // Batch size for processing
        this.batchSize = parseInt(process.env.MEASUREMENT_QUEUE_BATCH_SIZE || '200', 10); // Increased default from 50 to 200
        // Processing interval (milliseconds)
        this.processingInterval = parseInt(process.env.MEASUREMENT_QUEUE_INTERVAL || '1000', 10);
        // Max queue size per building (prevent memory issues)
        this.maxQueueSize = parseInt(process.env.MEASUREMENT_QUEUE_MAX_SIZE || '20000', 10); // Increased from 10000 to 20000
        
        // Priority system: Track active API requests
        this.activeApiRequests = 0;
        this.apiRequestThreshold = parseInt(process.env.API_REQUEST_THRESHOLD || '5', 10);
        // Throttle factor: reduce processing when API load is high
        this.throttleFactor = parseFloat(process.env.MEASUREMENT_QUEUE_THROTTLE_FACTOR || '0.5', 10);
        
        // Track last warning time per building to reduce log spam
        this.lastWarningTime = new Map(); // buildingId -> timestamp
        this.warningCooldown = 60000; // Only warn once per minute per building
        
        // Start processing loop
        this.startProcessing();
        
        console.log(`[MEASUREMENT-QUEUE] Initialized with batchSize=${this.batchSize}, interval=${this.processingInterval}ms, maxQueueSize=${this.maxQueueSize}`);
        console.log(`[MEASUREMENT-QUEUE] Priority system enabled: throttleFactor=${this.throttleFactor}, apiRequestThreshold=${this.apiRequestThreshold}`);
    }

    /**
     * Add measurements to queue for a building
     * @param {string} buildingId - Building ID
     * @param {Array} measurements - Array of measurement objects
     * @returns {Promise<void>}
     */
    async enqueue(buildingId, measurements) {
        if (!buildingId || !measurements || measurements.length === 0) {
            return;
        }

        // Initialize queue for building if needed
        if (!this.queue.has(buildingId)) {
            this.queue.set(buildingId, []);
        }

        const buildingQueue = this.queue.get(buildingId);
        
        // Check queue size limit
        if (buildingQueue.length >= this.maxQueueSize) {
            // Only log warning once per minute per building to reduce log spam
            const now = Date.now();
            const lastWarning = this.lastWarningTime.get(buildingId) || 0;
            
            if (now - lastWarning > this.warningCooldown) {
                console.warn(`[MEASUREMENT-QUEUE] [${buildingId}] Queue full (${buildingQueue.length}), dropping measurements. Processing may be too slow.`);
                this.lastWarningTime.set(buildingId, now);
            }
            return;
        }

        // Add measurements to queue
        buildingQueue.push(...measurements);
    }

    /**
     * Start the processing loop
     */
    startProcessing() {
        // Process queue periodically with adaptive interval
        let lastProcessingTime = Date.now();
        let isProcessing = false;
        
        const processWithAdaptiveInterval = async () => {
            if (isProcessing) {
                // If still processing, schedule next check sooner
                setTimeout(processWithAdaptiveInterval, 50);
                return;
            }
            
            const now = Date.now();
            const timeSinceLastProcess = now - lastProcessingTime;
            
            // Check if any queues are getting full
            let hasFullQueues = false;
            let hasCriticalQueues = false; // >90% full
            let totalQueued = 0;
            for (const [buildingId, measurements] of this.queue.entries()) {
                totalQueued += measurements.length;
                const queuePercent = measurements.length / this.maxQueueSize;
                if (queuePercent > 0.9) {
                    hasCriticalQueues = true;
                    hasFullQueues = true;
                } else if (queuePercent > 0.7) {
                    hasFullQueues = true;
                }
            }
            
            // Adaptive interval: process more frequently when queues are full
            // Normal: every processingInterval (default 1000ms)
            // When full (>70%): every processingInterval / 2 (default 500ms)
            // When critical (>90%): every 50ms (continuous processing)
            let currentInterval;
            if (hasCriticalQueues) {
                currentInterval = 50; // Continuous processing when critical
            } else if (hasFullQueues) {
                currentInterval = Math.max(this.processingInterval / 2, 100); // Min 100ms
            } else {
                currentInterval = this.processingInterval;
            }
            
            // Process the queue
            isProcessing = true;
            try {
                await this.processQueue();
            } finally {
                isProcessing = false;
            }
            
            lastProcessingTime = Date.now();
            
            // Schedule next processing with adaptive interval
            setTimeout(processWithAdaptiveInterval, currentInterval);
        };
        
        // Start processing
        processWithAdaptiveInterval();
    }

    /**
     * Process queued measurements for all buildings
     */
    async processQueue() {
        // Check if we should throttle processing due to high API load
        const shouldThrottle = this.activeApiRequests >= this.apiRequestThreshold;
        
        if (shouldThrottle) {
            // Skip this processing cycle to give priority to API requests
            return;
        }
        
        // Check connection pool usage - throttle if too high
        try {
            const poolStats = await getPoolStatistics(PRIORITY.HIGH);
            if (poolStats.available && poolStats.usagePercent > 85) {
                // Pool usage is high - skip this cycle to avoid overwhelming the pool
                // Real-time storage will handle throttling internally, but we can help here too
                return;
            }
        } catch (error) {
            // If pool check fails, proceed anyway (don't block real-time storage)
            // console.warn('[MEASUREMENT-QUEUE] Error checking pool stats:', error.message);
        }

        // Process buildings in parallel for better throughput
        const processingPromises = [];
        
        for (const [buildingId, measurements] of this.queue.entries()) {
            // Skip if already processing this building
            if (this.processing.get(buildingId)) {
                continue;
            }

            // Skip if queue is empty
            if (measurements.length === 0) {
                continue;
            }

            // Process this building's queue asynchronously (in parallel with others)
            processingPromises.push(
                this.processBuildingQueue(buildingId).catch(err => {
                    console.error(`[MEASUREMENT-QUEUE] [${buildingId}] Error processing queue:`, err.message);
                })
            );
        }
        
        // Wait for all buildings to finish processing (but don't block the next interval)
        // This allows parallel processing while still respecting the interval
        if (processingPromises.length > 0) {
            Promise.all(processingPromises).catch(() => {
                // Errors already logged in individual catch blocks
            });
        }
    }

    /**
     * Process queued measurements for a specific building
     * @param {string} buildingId - Building ID
     */
    async processBuildingQueue(buildingId) {
        const buildingQueue = this.queue.get(buildingId);
        if (!buildingQueue || buildingQueue.length === 0) {
            return;
        }

        // Mark as processing
        this.processing.set(buildingId, true);

        try {
            // Adaptive batch processing: use larger batches when queue is full
            const queueSize = buildingQueue.length;
            const queuePercent = queueSize / this.maxQueueSize;
            const isQueueCritical = queuePercent > 0.9; // >90% full
            const isQueueFull = queuePercent > 0.7; // >70% full
            
            // Aggressive batching when queue is critical
            let adaptiveBatchSize;
            let maxBatchesPerCycle;
            
            if (isQueueCritical) {
                // Critical: process as much as possible
                adaptiveBatchSize = this.batchSize * 4; // 4x batch size (800 measurements)
                maxBatchesPerCycle = 10; // Process up to 10 batches per cycle
            } else if (isQueueFull) {
                // Full: process more aggressively
                adaptiveBatchSize = this.batchSize * 2; // 2x batch size (400 measurements)
                maxBatchesPerCycle = 5; // Process up to 5 batches per cycle
            } else {
                // Normal: standard processing
                adaptiveBatchSize = this.batchSize;
                maxBatchesPerCycle = 1;
            }
            
            let batchesProcessed = 0;
            
            // Process in batches
            while (buildingQueue.length > 0 && batchesProcessed < maxBatchesPerCycle) {
                // Take a batch
                const batch = buildingQueue.splice(0, adaptiveBatchSize);
                
                if (batch.length === 0) {
                    break;
                }
                
                // Store measurements with skipPlausibilityCheck option when critical
                try {
                    await loxoneStorageService.storeMeasurements(
                        buildingId, 
                        batch,
                        { skipPlausibilityCheck: isQueueCritical } // Skip plausibility checks when critical
                    );
                    batchesProcessed++;
                } catch (error) {
                    console.error(`[MEASUREMENT-QUEUE] [${buildingId}] Error storing batch:`, error.message);
                    // Continue with next batch even if this one fails
                    batchesProcessed++;
                }

                // Yield to event loop between batches (but less frequently when queue is critical)
                if (!isQueueCritical && (!isQueueFull || batchesProcessed % 2 === 0)) {
                    await new Promise(resolve => setImmediate(resolve));
                }
            }
        } finally {
            // Mark as not processing
            this.processing.set(buildingId, false);
        }
    }

    /**
     * Increment active API request counter (call when API request starts)
     */
    incrementApiRequests() {
        this.activeApiRequests++;
    }

    /**
     * Decrement active API request counter (call when API request ends)
     */
    decrementApiRequests() {
        if (this.activeApiRequests > 0) {
            this.activeApiRequests--;
        }
    }

    /**
     * Get queue statistics
     * @returns {Object} Queue statistics
     */
    getStats() {
        const stats = {
            totalBuildings: this.queue.size,
            totalMeasurements: 0,
            processing: 0,
            activeApiRequests: this.activeApiRequests,
            throttled: this.activeApiRequests >= this.apiRequestThreshold,
            buildings: {}
        };

        for (const [buildingId, measurements] of this.queue.entries()) {
            const count = measurements.length;
            stats.totalMeasurements += count;
            stats.buildings[buildingId] = {
                queued: count,
                processing: this.processing.get(buildingId) || false
            };
            if (stats.buildings[buildingId].processing) {
                stats.processing++;
            }
        }

        return stats;
    }

    /**
     * Clear queue for a building (useful for testing or cleanup)
     * @param {string} buildingId - Building ID
     */
    clearQueue(buildingId) {
        if (buildingId) {
            this.queue.delete(buildingId);
            this.processing.delete(buildingId);
        } else {
            this.queue.clear();
            this.processing.clear();
        }
    }
}

module.exports = new MeasurementQueueService();
