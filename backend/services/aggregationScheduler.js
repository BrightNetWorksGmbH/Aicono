const cron = require('node-cron');
const measurementAggregationService = require('./measurementAggregationService');

/**
 * Aggregation Scheduler
 * 
 * Manages cron jobs for automatic measurement aggregation:
 * - Every 15 minutes: Aggregate raw data to 15-minute buckets
 * - Every hour: Aggregate 15-minute data to hourly buckets
 * - Daily at 1 AM: Aggregate hourly data to daily buckets
 * - Daily at 2 AM: Cleanup old raw data (keep 30 days)
 * 
 * Cron schedule format: minute hour day month weekday
 * Examples:
 * - Every 15 minutes: '*\/15 * * * *'
 * - Every hour at minute 0: '0 * * * *'
 * - Daily at 1:00 AM: '0 1 * * *'
 */
class AggregationScheduler {
    constructor() {
        this.jobs = [];
        this.isRunning = false;
        
        // Configuration from environment variables
        this.config = {
            // Delete raw data immediately after aggregation (default: true)
            deleteAfterAggregation: process.env.DELETE_RAW_AFTER_AGGREGATION !== 'false',
            // Safety buffer: keep raw data for at least N minutes (default: 30 minutes)
            rawDataBufferMinutes: parseInt(process.env.RAW_DATA_BUFFER_MINUTES || '30', 10),
            // Old cleanup job retention (for backward compatibility, but less aggressive)
            oldDataRetentionDays: parseInt(process.env.OLD_DATA_RETENTION_DAYS || '1', 10)
        };
        
        console.log(`[SCHEDULER] Configuration:`, {
            deleteAfterAggregation: this.config.deleteAfterAggregation,
            rawDataBufferMinutes: this.config.rawDataBufferMinutes,
            oldDataRetentionDays: this.config.oldDataRetentionDays
        });
    }

    /**
     * Start all aggregation cron jobs
     * Should be called after database connection is established
     */
    start() {
        if (this.isRunning) {
            console.log('[SCHEDULER] Scheduler is already running');
            return;
        }

        // Job 1: Aggregate raw data to 15-minute buckets (every 15 minutes)
        const job15Min = cron.schedule('*/15 * * * *', async () => {
            const timestamp = new Date().toISOString();
            console.log(`[SCHEDULER] [${timestamp}] Running 15-minute aggregation...`);
            try {
                const result = await measurementAggregationService.aggregate15Minutes(
                    null, // buildingId (null = all buildings)
                    this.config.deleteAfterAggregation,
                    this.config.rawDataBufferMinutes
                );
                
                if (result.skipped) {
                    console.log(`[SCHEDULER] [${timestamp}] 15-minute aggregation skipped: Not enough data`);
                } else {
                    console.log(`[SCHEDULER] [${timestamp}] 15-minute aggregation completed: ${result.count} aggregates created, ${result.deleted || 0} raw data points deleted`);
                }
            } catch (error) {
                console.error(`[SCHEDULER] [${timestamp}] 15-minute aggregation failed:`, error.message);
            }
        }, {
            scheduled: false, // Don't start immediately
            timezone: 'UTC'
        });

        // Job 2: Aggregate 15-minute data to hourly buckets (every hour at minute 0)
        const jobHourly = cron.schedule('0 * * * *', async () => {
            const timestamp = new Date().toISOString();
            console.log(`[SCHEDULER] [${timestamp}] Running hourly aggregation...`);
            try {
                const result = await measurementAggregationService.aggregateHourly();
                console.log(`[SCHEDULER] [${timestamp}] Hourly aggregation completed: ${result.count} aggregates created`);
            } catch (error) {
                console.error(`[SCHEDULER] [${timestamp}] Hourly aggregation failed:`, error.message);
            }
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Job 3: Aggregate hourly data to daily buckets (daily at 1:00 AM)
        const jobDaily = cron.schedule('0 1 * * *', async () => {
            const timestamp = new Date().toISOString();
            console.log(`[SCHEDULER] [${timestamp}] Running daily aggregation...`);
            try {
                const result = await measurementAggregationService.aggregateDaily();
                console.log(`[SCHEDULER] [${timestamp}] Daily aggregation completed: ${result.count} aggregates created`);
            } catch (error) {
                console.error(`[SCHEDULER] [${timestamp}] Daily aggregation failed:`, error.message);
            }
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Job 4: Cleanup old raw data (safety net - runs daily at 2:00 AM)
        // This is a safety net in case immediate deletion fails or is disabled
        // It only deletes data older than the configured retention period
        const jobCleanup = cron.schedule('0 2 * * *', async () => {
            const timestamp = new Date().toISOString();
            console.log(`[SCHEDULER] [${timestamp}] Running safety cleanup (retention: ${this.config.oldDataRetentionDays} days)...`);
            try {
                // Only delete data older than retention period (default: 1 day)
                // This acts as a safety net, but most data should already be deleted by immediate cleanup
                const deletedCount = await measurementAggregationService.cleanupRawData(
                    this.config.oldDataRetentionDays
                );
                console.log(`[SCHEDULER] [${timestamp}] Safety cleanup completed: ${deletedCount} documents deleted`);
            } catch (error) {
                console.error(`[SCHEDULER] [${timestamp}] Safety cleanup failed:`, error.message);
            }
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Store job references
        this.jobs = [
            { name: '15-minute', job: job15Min },
            { name: 'hourly', job: jobHourly },
            { name: 'daily', job: jobDaily },
            { name: 'cleanup', job: jobCleanup }
        ];

        // Start all jobs
        this.jobs.forEach(({ name, job }) => {
            job.start();
            console.log(`[SCHEDULER] Started ${name} aggregation job`);
        });

        this.isRunning = true;
        console.log('[SCHEDULER] ✓ Aggregation scheduler started successfully');
        console.log('[SCHEDULER] Jobs: 15-min (every 15m), Hourly (every hour), Daily (1 AM), Safety Cleanup (2 AM)');
        if (this.config.deleteAfterAggregation) {
            console.log(`[SCHEDULER] Raw data will be deleted immediately after aggregation (buffer: ${this.config.rawDataBufferMinutes} minutes)`);
        } else {
            console.log('[SCHEDULER] Raw data deletion after aggregation is DISABLED');
        }
    }

    /**
     * Stop all aggregation cron jobs
     */
    stop() {
        if (!this.isRunning) {
            console.log('[SCHEDULER] Scheduler is not running');
            return;
        }

        this.jobs.forEach(({ name, job }) => {
            job.stop();
            console.log(`[SCHEDULER] Stopped ${name} aggregation job`);
        });

        this.jobs = [];
        this.isRunning = false;
        console.log('[SCHEDULER] Aggregation scheduler stopped');
    }

    /**
     * Get status of all jobs
     * 
     * @returns {Object} Status of all scheduled jobs
     */
    getStatus() {
        return {
            isRunning: this.isRunning,
            jobs: this.jobs.map(({ name, job }) => ({
                name,
                running: job.running || false
            }))
        };
    }

    /**
     * Manually trigger 15-minute aggregation (for testing)
     * 
     * @param {string|null} buildingId - Optional building ID
     * @param {boolean} deleteAfterAggregation - Whether to delete raw data after aggregation
     * @returns {Promise<Object>} Aggregation result
     */
    async trigger15MinuteAggregation(buildingId = null, deleteAfterAggregation = null) {
        console.log('[SCHEDULER] Manually triggering 15-minute aggregation...');
        const shouldDelete = deleteAfterAggregation !== null 
            ? deleteAfterAggregation 
            : this.config.deleteAfterAggregation;
        return await measurementAggregationService.aggregate15Minutes(
            buildingId, 
            shouldDelete,
            this.config.rawDataBufferMinutes
        );
    }

    /**
     * Manually trigger hourly aggregation (for testing)
     * 
     * @param {string|null} buildingId - Optional building ID
     * @returns {Promise<Object>} Aggregation result
     */
    async triggerHourlyAggregation(buildingId = null) {
        console.log('[SCHEDULER] Manually triggering hourly aggregation...');
        return await measurementAggregationService.aggregateHourly(buildingId);
    }

    /**
     * Manually trigger daily aggregation (for testing)
     * 
     * @param {string|null} buildingId - Optional building ID
     * @returns {Promise<Object>} Aggregation result
     */
    async triggerDailyAggregation(buildingId = null) {
        console.log('[SCHEDULER] Manually triggering daily aggregation...');
        return await measurementAggregationService.aggregateDaily(buildingId);
    }
}

module.exports = new AggregationScheduler();

