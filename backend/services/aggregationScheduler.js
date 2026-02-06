const cron = require('node-cron');
const measurementAggregationService = require('./measurementAggregationService');
const { isConnectionHealthy, getPoolStatistics } = require('../db/connection');

/**
 * Aggregation Scheduler
 * 
 * Manages cron jobs for automatic measurement aggregation:
 * - Every 15 minutes: Aggregate raw data to 15-minute buckets (deletes raw data)
 * - Every hour: Aggregate 15-minute data to hourly buckets (keeps both)
 * - Daily at 1 AM: Aggregate hourly data to daily buckets (deletes 15-min > 1 day old)
 * - Weekly on Monday at 2 AM: Aggregate daily data to weekly buckets (deletes hourly > 1 week old)
 * - Monthly on 1st at 3 AM: Aggregate weekly/daily data to monthly buckets
 * - Daily at 4 AM: Cleanup old raw data (safety net)
 * 
 * Cron schedule format: minute hour day month weekday
 * Examples:
 * - Every 15 minutes: '*\/15 * * * *'
 * - Every hour at minute 0: '0 * * * *'
 * - Daily at 1:00 AM: '0 1 * * *'
 * - Weekly on Monday at 2:00 AM: '0 2 * * 1'
 * - Monthly on 1st at 3:00 AM: '0 3 1 * *'
 */
class AggregationScheduler {
    constructor() {
        this.jobs = [];
        this.isRunning = false;
        this.startedAt = null;
        this.lastRun = {
            '15-minute': null,
            'hourly': null,
            'daily': null,
            'weekly': null,
            'monthly': null,
            'cleanup': null
        };
        
        // Aggregation job queue to prevent overlapping aggregations
        this.jobQueue = [];
        this.runningJobs = new Set(); // Track currently running aggregation types
        this.queueEnabled = process.env.AGGREGATION_QUEUE_ENABLED !== 'false';
        this.maxConcurrent = parseInt(process.env.AGGREGATION_QUEUE_MAX_CONCURRENT || '1', 10);
        
        // Job priority order (higher number = higher priority)
        this.jobPriority = {
            '15-minute': 5,
            'hourly': 4,
            'daily': 3,
            'weekly': 2,
            'monthly': 1,
            'cleanup': 0
        };
        
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
            oldDataRetentionDays: this.config.oldDataRetentionDays,
            queueEnabled: this.queueEnabled,
            maxConcurrent: this.maxConcurrent
        });
    }
    
    /**
     * Check if an aggregation job can run (not already running)
     * @param {string} jobType - Type of aggregation job
     * @returns {boolean} True if job can run
     */
    canRunJob(jobType) {
        if (!this.queueEnabled) {
            return true; // Queue disabled, allow all jobs
        }
        
        // Check if any job is currently running
        if (this.runningJobs.size >= this.maxConcurrent) {
            return false;
        }
        
        // Check if this specific job type is already running
        return !this.runningJobs.has(jobType);
    }
    
    /**
     * Mark a job as running
     * @param {string} jobType - Type of aggregation job
     */
    startJob(jobType) {
        if (this.queueEnabled) {
            this.runningJobs.add(jobType);
        }
    }
    
    /**
     * Mark a job as completed
     * @param {string} jobType - Type of aggregation job
     */
    completeJob(jobType) {
        if (this.queueEnabled) {
            this.runningJobs.delete(jobType);
            // Process queued jobs
            this.processQueue();
        }
    }
    
    /**
     * Queue an aggregation job
     * @param {string} jobType - Type of aggregation job
     * @param {Function} jobFn - Function to execute
     * @returns {Promise} Job execution promise
     */
    async queueJob(jobType, jobFn) {
        if (!this.queueEnabled) {
            // Queue disabled, execute immediately
            return jobFn();
        }
        
        return new Promise((resolve, reject) => {
            const job = {
                type: jobType,
                priority: this.jobPriority[jobType] || 0,
                execute: jobFn,
                resolve,
                reject,
                queuedAt: new Date()
            };
            
            // Insert job in priority order (higher priority first)
            const insertIndex = this.jobQueue.findIndex(qJob => qJob.priority < job.priority);
            if (insertIndex === -1) {
                this.jobQueue.push(job);
            } else {
                this.jobQueue.splice(insertIndex, 0, job);
            }
            
            console.log(`[SCHEDULER] [QUEUE] Queued ${jobType} aggregation (queue size: ${this.jobQueue.length}, running: ${this.runningJobs.size})`);
            
            // Try to process queue
            this.processQueue();
        });
    }
    
    /**
     * Process queued jobs
     */
    async processQueue() {
        if (!this.queueEnabled) {
            return;
        }
        
        // Process jobs while we have capacity
        while (this.jobQueue.length > 0 && this.runningJobs.size < this.maxConcurrent) {
            const job = this.jobQueue.shift();
            
            // Check if this job type can run
            if (this.runningJobs.has(job.type)) {
                // Job type already running, re-queue it
                this.jobQueue.unshift(job);
                break;
            }
            
            // Execute job
            this.startJob(job.type);
            console.log(`[SCHEDULER] [QUEUE] Starting ${job.type} aggregation (queue size: ${this.jobQueue.length})`);
            
            job.execute()
                .then(result => {
                    this.completeJob(job.type);
                    job.resolve(result);
                })
                .catch(error => {
                    this.completeJob(job.type);
                    job.reject(error);
                });
        }
    }

    /**
     * Start all aggregation cron jobs
     * Should be called after database connection is established
     */
    start() {
        if (this.isRunning) {
            console.log('[SCHEDULER] ⚠️  Scheduler is already running. Stopping existing jobs before restart...');
            this.stop();
        }
        
        console.log('[SCHEDULER] 🚀 Starting aggregation scheduler...');

        // Job 1: Aggregate raw data to 15-minute buckets (every 15 minutes)
        const job15Min = cron.schedule('*/15 * * * *', async () => {
            const timestamp = new Date().toISOString();
            this.lastRun['15-minute'] = timestamp;
            console.log(`[SCHEDULER] [${timestamp}] ⏰ Running 15-minute aggregation (cron triggered)...`);
            
            // Queue the job to prevent overlapping aggregations
            await this.queueJob('15-minute', async () => {
                // Check connection health and pool availability before starting
                if (!isConnectionHealthy()) {
                    console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Database connection not healthy`);
                    return;
                }
                
                try {
                    // Check pool statistics - only skip if pool is truly exhausted (95%+)
                    // Aggregation is critical for storage efficiency, so we should run it even if pool is high
                    const poolStats = await getPoolStatistics();
                    if (poolStats.available && poolStats.usagePercent >= 95) {
                        console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Connection pool usage is critical (${poolStats.usagePercent}%)`);
                        return;
                    }
                    
                    // If pool is high (80-95%), wait a bit for connections to free up, then proceed
                    if (poolStats.available && poolStats.usagePercent >= 80) {
                        console.log(`[SCHEDULER] [${timestamp}] ⚠️  Pool usage is high (${poolStats.usagePercent}%), waiting 2 seconds before aggregation...`);
                        await new Promise(resolve => setTimeout(resolve, 2000));
                        
                        // Re-check pool after wait
                        const recheckStats = await getPoolStatistics();
                        if (recheckStats.available && recheckStats.usagePercent >= 95) {
                            console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Pool still critical after wait (${recheckStats.usagePercent}%)`);
                            return;
                        }
                    }
                    
                    // Yield to event loop before starting heavy operation
                    await new Promise(resolve => setImmediate(resolve));
                    
                    // Simplified: Aggregate all sensors at once (no per-building iteration needed)
                    // Since measurements are now server-scoped, we aggregate by sensorId only
                        const result = await measurementAggregationService.aggregate15Minutes(
                            this.config.deleteAfterAggregation,
                            this.config.rawDataBufferMinutes
                        );
                        
                        if (result.skipped) {
                            console.log(`[SCHEDULER] [${timestamp}] ⏭️  15-minute aggregation skipped: ${result.reason || 'Not enough data'}`);
                        } else {
                            console.log(`[SCHEDULER] [${timestamp}] ✅ 15-minute aggregation completed: ${result.count} aggregates created, ${result.deleted || 0} raw data points queued for deletion`);
                    }
                } catch (error) {
                    console.error(`[SCHEDULER] [${timestamp}] ❌ 15-minute aggregation failed:`, error.message);
                    console.error(`[SCHEDULER] [${timestamp}] Error stack:`, error.stack);
                    throw error; // Re-throw to be caught by queueJob
                }
            });
        }, {
            scheduled: false, // Don't start immediately
            timezone: 'UTC'
        });

        // Job 2: Aggregate 15-minute data to hourly buckets (every hour at minute 0)
        const jobHourly = cron.schedule('0 * * * *', async () => {
            const timestamp = new Date().toISOString();
            this.lastRun['hourly'] = timestamp;
            console.log(`[SCHEDULER] [${timestamp}] ⏰ Running hourly aggregation (cron triggered)...`);
            
            // Queue the job to prevent overlapping aggregations
            await this.queueJob('hourly', async () => {
                // Check connection health before starting
                if (!isConnectionHealthy()) {
                    console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Database connection not healthy`);
                    return;
                }
                
                try {
                    // Yield to event loop before starting
                    await new Promise(resolve => setImmediate(resolve));
                    
                    const result = await measurementAggregationService.aggregateHourly();
                    console.log(`[SCHEDULER] [${timestamp}] ✅ Hourly aggregation completed: ${result.count} aggregates created, ${result.deleted || 0} old 15-minute aggregates deleted`);
                } catch (error) {
                    console.error(`[SCHEDULER] [${timestamp}] ❌ Hourly aggregation failed:`, error.message);
                    console.error(`[SCHEDULER] [${timestamp}] Error stack:`, error.stack);
                    throw error; // Re-throw to be caught by queueJob
                }
            });
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Job 3: Aggregate hourly data to daily buckets (daily at 1:00 AM)
        // This also deletes 15-minute aggregates older than 1 day
        const jobDaily = cron.schedule('0 1 * * *', async () => {
            const timestamp = new Date().toISOString();
            this.lastRun['daily'] = timestamp;
            console.log(`[SCHEDULER] [${timestamp}] ⏰ Running daily aggregation (cron triggered)...`);
            
            // Queue the job to prevent overlapping aggregations
            await this.queueJob('daily', async () => {
                // Check connection health before starting
                if (!isConnectionHealthy()) {
                    console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Database connection not healthy`);
                    return;
                }
                
                try {
                    // Yield to event loop before starting
                    await new Promise(resolve => setImmediate(resolve));
                    
                    const result = await measurementAggregationService.aggregateDaily();
                    console.log(`[SCHEDULER] [${timestamp}] ✅ Daily aggregation completed: ${result.count} aggregates created, ${result.deleted || 0} old 15-minute aggregates deleted`);
                } catch (error) {
                    console.error(`[SCHEDULER] [${timestamp}] ❌ Daily aggregation failed:`, error.message);
                    console.error(`[SCHEDULER] [${timestamp}] Error stack:`, error.stack);
                    throw error; // Re-throw to be caught by queueJob
                }
            });
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Job 4: Aggregate daily data to weekly buckets (weekly on Monday at 2:00 AM)
        // This also deletes hourly aggregates older than 1 week
        const jobWeekly = cron.schedule('0 2 * * 1', async () => {
            const timestamp = new Date().toISOString();
            this.lastRun['weekly'] = timestamp;
            console.log(`[SCHEDULER] [${timestamp}] ⏰ Running weekly aggregation (cron triggered)...`);
            
            // Queue the job to prevent overlapping aggregations
            await this.queueJob('weekly', async () => {
                // Check connection health before starting
                if (!isConnectionHealthy()) {
                    console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Database connection not healthy`);
                    return;
                }
                
                try {
                    // Yield to event loop before starting
                    await new Promise(resolve => setImmediate(resolve));
                    
                    const result = await measurementAggregationService.aggregateWeekly();
                    console.log(`[SCHEDULER] [${timestamp}] ✅ Weekly aggregation completed: ${result.count} aggregates created, ${result.deleted || 0} old hourly aggregates deleted`);
                } catch (error) {
                    console.error(`[SCHEDULER] [${timestamp}] ❌ Weekly aggregation failed:`, error.message);
                    console.error(`[SCHEDULER] [${timestamp}] Error stack:`, error.stack);
                    throw error; // Re-throw to be caught by queueJob
                }
            });
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Job 5: Aggregate weekly/daily data to monthly buckets (monthly on 1st at 3:00 AM)
        const jobMonthly = cron.schedule('0 3 1 * *', async () => {
            const timestamp = new Date().toISOString();
            this.lastRun['monthly'] = timestamp;
            console.log(`[SCHEDULER] [${timestamp}] ⏰ Running monthly aggregation (cron triggered)...`);
            
            // Queue the job to prevent overlapping aggregations
            await this.queueJob('monthly', async () => {
                // Check connection health before starting
                if (!isConnectionHealthy()) {
                    console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping aggregation: Database connection not healthy`);
                    return;
                }
                
                try {
                    // Yield to event loop before starting
                    await new Promise(resolve => setImmediate(resolve));
                    
                    const result = await measurementAggregationService.aggregateMonthly();
                    console.log(`[SCHEDULER] [${timestamp}] ✅ Monthly aggregation completed: ${result.count} aggregates created`);
                } catch (error) {
                    console.error(`[SCHEDULER] [${timestamp}] ❌ Monthly aggregation failed:`, error.message);
                    console.error(`[SCHEDULER] [${timestamp}] Error stack:`, error.stack);
                    throw error; // Re-throw to be caught by queueJob
                }
            });
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Job 6: Cleanup old raw data (safety net - runs daily at 4:00 AM)
        // This is a safety net in case immediate deletion fails or is disabled
        // It only deletes data older than the configured retention period
        const jobCleanup = cron.schedule('0 4 * * *', async () => {
            const timestamp = new Date().toISOString();
            this.lastRun['cleanup'] = timestamp;
            console.log(`[SCHEDULER] [${timestamp}] ⏰ Running safety cleanup (cron triggered, retention: ${this.config.oldDataRetentionDays} days)...`);
            
            // Queue the job to prevent overlapping aggregations
            await this.queueJob('cleanup', async () => {
                // Check connection health before starting
                if (!isConnectionHealthy()) {
                    console.warn(`[SCHEDULER] [${timestamp}] ⚠️  Skipping cleanup: Database connection not healthy`);
                    return;
                }
                
                try {
                    // Yield to event loop before starting
                    await new Promise(resolve => setImmediate(resolve));
                    
                    // Only delete data older than retention period (default: 1 day)
                    // This acts as a safety net, but most data should already be deleted by immediate cleanup
                    const deletedCount = await measurementAggregationService.cleanupRawData(
                        this.config.oldDataRetentionDays
                    );
                    console.log(`[SCHEDULER] [${timestamp}] ✅ Safety cleanup completed: ${deletedCount} documents deleted`);
                } catch (error) {
                    console.error(`[SCHEDULER] [${timestamp}] ❌ Safety cleanup failed:`, error.message);
                    console.error(`[SCHEDULER] [${timestamp}] Error stack:`, error.stack);
                    throw error; // Re-throw to be caught by queueJob
                }
            });
        }, {
            scheduled: false,
            timezone: 'UTC'
        });

        // Store job references
        this.jobs = [
            { name: '15-minute', job: job15Min },
            { name: 'hourly', job: jobHourly },
            { name: 'daily', job: jobDaily },
            { name: 'weekly', job: jobWeekly },
            { name: 'monthly', job: jobMonthly },
            { name: 'cleanup', job: jobCleanup }
        ];

        // Start all jobs
        this.jobs.forEach(({ name, job }) => {
            job.start();
            console.log(`[SCHEDULER] Started ${name} aggregation job`);
        });

        this.isRunning = true;
        this.startedAt = new Date().toISOString();
        console.log('[SCHEDULER] ✓ Aggregation scheduler started successfully');
        console.log(`[SCHEDULER] Started at: ${this.startedAt}`);
        console.log('[SCHEDULER] Jobs: 15-min (every 15m), Hourly (every hour at :00), Daily (1 AM UTC), Weekly (Mon 2 AM UTC), Monthly (1st 3 AM UTC), Safety Cleanup (4 AM UTC)');
        if (this.config.deleteAfterAggregation) {
            console.log(`[SCHEDULER] Raw data will be deleted immediately after aggregation (buffer: ${this.config.rawDataBufferMinutes} minutes)`);
        } else {
            console.log('[SCHEDULER] Raw data deletion after aggregation is DISABLED');
        }
        
        // Calculate and log next run times
        const now = new Date();
        const next15Min = new Date(now);
        next15Min.setMinutes(Math.ceil(now.getMinutes() / 15) * 15, 0, 0);
        if (next15Min <= now) {
            next15Min.setMinutes(next15Min.getMinutes() + 15);
        }
        const nextHour = new Date(now);
        nextHour.setHours(nextHour.getHours() + 1, 0, 0, 0);
        
        console.log(`[SCHEDULER] Next 15-min run: ${next15Min.toISOString()} (in ${Math.round((next15Min - now) / 1000 / 60)} minutes)`);
        console.log(`[SCHEDULER] Next hourly run: ${nextHour.toISOString()} (in ${Math.round((nextHour - now) / 1000 / 60)} minutes)`);
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
        const now = new Date();
        
        // Calculate next run times
        const next15Min = new Date(now);
        next15Min.setMinutes(Math.ceil(now.getMinutes() / 15) * 15, 0, 0);
        if (next15Min <= now) {
            next15Min.setMinutes(next15Min.getMinutes() + 15);
        }
        
        const nextHour = new Date(now);
        nextHour.setHours(nextHour.getHours() + 1, 0, 0, 0);
        
        // Calculate next daily run (1 AM UTC)
        const nextDaily = new Date(now);
        nextDaily.setUTCHours(1, 0, 0, 0);
        if (nextDaily <= now) {
            nextDaily.setUTCDate(nextDaily.getUTCDate() + 1);
        }
        
        // Calculate next weekly run (Monday 2 AM UTC)
        const nextWeekly = new Date(now);
        nextWeekly.setUTCHours(2, 0, 0, 0);
        const dayOfWeek = nextWeekly.getUTCDay(); // 0=Sunday, 1=Monday, ..., 6=Saturday
        const daysUntilMonday = dayOfWeek === 0 ? 1 : (dayOfWeek === 1 ? (nextWeekly <= now ? 7 : 0) : (8 - dayOfWeek));
        if (daysUntilMonday > 0) {
            nextWeekly.setUTCDate(nextWeekly.getUTCDate() + daysUntilMonday);
        }
        
        // Calculate next monthly run (1st 3 AM UTC)
        const nextMonthly = new Date(now);
        nextMonthly.setUTCDate(1);
        nextMonthly.setUTCHours(3, 0, 0, 0);
        if (nextMonthly <= now) {
            nextMonthly.setUTCMonth(nextMonthly.getUTCMonth() + 1);
        }
        
        // Calculate next cleanup run (4 AM UTC)
        const nextCleanup = new Date(now);
        nextCleanup.setUTCHours(4, 0, 0, 0);
        if (nextCleanup <= now) {
            nextCleanup.setUTCDate(nextCleanup.getUTCDate() + 1);
        }
        
        return {
            isRunning: this.isRunning,
            startedAt: this.startedAt,
            uptime: this.startedAt ? Math.round((now - new Date(this.startedAt)) / 1000) : 0, // seconds
            lastRun: this.lastRun,
            nextRun: {
                '15-minute': next15Min.toISOString(),
                'hourly': nextHour.toISOString(),
                'daily': nextDaily.toISOString(),
                'weekly': nextWeekly.toISOString(),
                'monthly': nextMonthly.toISOString(),
                'cleanup': nextCleanup.toISOString()
            },
            jobs: this.jobs.map(({ name, job }) => ({
                name,
                running: job.running || false,
                lastRun: this.lastRun[name] || null
            })),
            config: this.config
        };
    }

    /**
     * Manually trigger 15-minute aggregation (for testing)
     * 
     * @param {boolean} deleteAfterAggregation - Whether to delete raw data after aggregation
     * @returns {Promise<Object>} Aggregation result
     */
    async trigger15MinuteAggregation(deleteAfterAggregation = null) {
        const timestamp = new Date().toISOString();
        console.log(`[SCHEDULER] [${timestamp}] 🔧 Manually triggering 15-minute aggregation...`);
        const shouldDelete = deleteAfterAggregation !== null 
            ? deleteAfterAggregation 
            : this.config.deleteAfterAggregation;
        const result = await measurementAggregationService.aggregate15Minutes(
            shouldDelete,
            this.config.rawDataBufferMinutes
        );
        // Update last run time for manual triggers too
        if (result && !result.skipped) {
            this.lastRun['15-minute'] = timestamp;
        }
        return result;
    }

    /**
     * Manually trigger hourly aggregation (for testing)
     * 
     * @returns {Promise<Object>} Aggregation result
     */
    async triggerHourlyAggregation() {
        console.log('[SCHEDULER] Manually triggering hourly aggregation...');
        return await measurementAggregationService.aggregateHourly();
    }

    /**
     * Manually trigger daily aggregation (for testing)
     * 
     * @returns {Promise<Object>} Aggregation result
     */
    async triggerDailyAggregation() {
        console.log('[SCHEDULER] Manually triggering daily aggregation...');
        return await measurementAggregationService.aggregateDaily();
    }

    /**
     * Manually trigger weekly aggregation (for testing)
     * 
     * @returns {Promise<Object>} Aggregation result
     */
    async triggerWeeklyAggregation() {
        console.log('[SCHEDULER] Manually triggering weekly aggregation...');
        return await measurementAggregationService.aggregateWeekly();
    }

    /**
     * Manually trigger monthly aggregation (for testing)
     * 
     * @returns {Promise<Object>} Aggregation result
     */
    async triggerMonthlyAggregation() {
        console.log('[SCHEDULER] Manually triggering monthly aggregation...');
        return await measurementAggregationService.aggregateMonthly();
    }
}

module.exports = new AggregationScheduler();

