const cron = require('node-cron');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
const Building = require('../models/Building');
const ReportingRecipient = require('../models/ReportingRecipient');
const reportGenerationService = require('./reportGenerationService');
const reportEmailService = require('./reportEmailService');

/**
 * Reporting Scheduler
 * 
 * Manages cron jobs for automatic scheduled report generation and delivery:
 * - Daily at 6:00 AM UTC: Generate and send daily reports (previous day)
 * - Weekly on Monday at 7:00 AM UTC: Generate and send weekly reports (previous week)
 * - Monthly on 1st at 8:00 AM UTC: Generate and send monthly reports (previous month)
 * - Yearly on January 1st at 9:00 AM UTC: Generate and send yearly reports (previous year)
 */
class ReportingScheduler {
  constructor() {
    this.jobs = [];
    this.isRunning = false;
    this.startedAt = null;
    this.lastRun = {
      daily: null,
      weekly: null,
      monthly: null,
      yearly: null,
    };
  }

  /**
   * Start all reporting cron jobs
   * Should be called after database connection is established
   */
  start() {
    if (this.isRunning) {
      console.log('[REPORTING-SCHEDULER] ⚠️  Scheduler is already running. Stopping existing jobs before restart...');
      this.stop();
    }

    console.log('[REPORTING-SCHEDULER] 🚀 Starting reporting scheduler...');

    // Job 1: Daily reports (runs at 6:00 AM UTC, covers previous day)
    const jobDaily = cron.schedule('0 6 * * *', async () => {
      const timestamp = new Date().toISOString();
      this.lastRun.daily = timestamp;
      console.log(`[REPORTING-SCHEDULER] [${timestamp}] ⏰ Running daily reports (cron triggered)...`);
      try {
        await this.processReportsForInterval('Daily');
        console.log(`[REPORTING-SCHEDULER] [${timestamp}] ✅ Daily reports completed`);
      } catch (error) {
        console.error(`[REPORTING-SCHEDULER] [${timestamp}] ❌ Daily reports failed:`, error.message);
      }
    }, {
      scheduled: false,
      timezone: 'UTC'
    });

    // Job 2: Weekly reports (runs on Monday at 7:00 AM UTC, covers previous week)
    const jobWeekly = cron.schedule('0 7 * * 1', async () => {
      const timestamp = new Date().toISOString();
      this.lastRun.weekly = timestamp;
      console.log(`[REPORTING-SCHEDULER] [${timestamp}] ⏰ Running weekly reports (cron triggered)...`);
      try {
        await this.processReportsForInterval('Weekly');
        console.log(`[REPORTING-SCHEDULER] [${timestamp}] ✅ Weekly reports completed`);
      } catch (error) {
        console.error(`[REPORTING-SCHEDULER] [${timestamp}] ❌ Weekly reports failed:`, error.message);
      }
    }, {
      scheduled: false,
      timezone: 'UTC'
    });

    // Job 3: Monthly reports (runs on 1st of month at 8:00 AM UTC, covers previous month)
    const jobMonthly = cron.schedule('0 8 1 * *', async () => {
      const timestamp = new Date().toISOString();
      this.lastRun.monthly = timestamp;
      console.log(`[REPORTING-SCHEDULER] [${timestamp}] ⏰ Running monthly reports (cron triggered)...`);
      try {
        await this.processReportsForInterval('Monthly');
        console.log(`[REPORTING-SCHEDULER] [${timestamp}] ✅ Monthly reports completed`);
      } catch (error) {
        console.error(`[REPORTING-SCHEDULER] [${timestamp}] ❌ Monthly reports failed:`, error.message);
      }
    }, {
      scheduled: false,
      timezone: 'UTC'
    });

    // Job 4: Yearly reports (runs on January 1st at 9:00 AM UTC, covers previous year)
    const jobYearly = cron.schedule('0 9 1 1 *', async () => {
      const timestamp = new Date().toISOString();
      this.lastRun.yearly = timestamp;
      console.log(`[REPORTING-SCHEDULER] [${timestamp}] ⏰ Running yearly reports (cron triggered)...`);
      try {
        await this.processReportsForInterval('Yearly');
        console.log(`[REPORTING-SCHEDULER] [${timestamp}] ✅ Yearly reports completed`);
      } catch (error) {
        console.error(`[REPORTING-SCHEDULER] [${timestamp}] ❌ Yearly reports failed:`, error.message);
      }
    }, {
      scheduled: false,
      timezone: 'UTC'
    });

    // Store job references
    this.jobs = [
      { name: 'daily', job: jobDaily },
      { name: 'weekly', job: jobWeekly },
      { name: 'monthly', job: jobMonthly },
      { name: 'yearly', job: jobYearly },
    ];

    // Start all jobs
    this.jobs.forEach(({ name, job }) => {
      job.start();
      console.log(`[REPORTING-SCHEDULER] Started ${name} reporting job`);
    });

    this.isRunning = true;
    this.startedAt = new Date().toISOString();
    console.log('[REPORTING-SCHEDULER] ✓ Reporting scheduler started successfully');
    console.log(`[REPORTING-SCHEDULER] Started at: ${this.startedAt}`);
    console.log('[REPORTING-SCHEDULER] Jobs: Daily (6 AM UTC), Weekly (Mon 7 AM UTC), Monthly (1st 8 AM UTC), Yearly (Jan 1 9 AM UTC)');
  }

  /**
   * Stop all reporting cron jobs
   */
  stop() {
    if (!this.isRunning) {
      console.log('[REPORTING-SCHEDULER] Scheduler is not running');
      return;
    }

    this.jobs.forEach(({ name, job }) => {
      job.stop();
      console.log(`[REPORTING-SCHEDULER] Stopped ${name} reporting job`);
    });

    this.jobs = [];
    this.isRunning = false;
    console.log('[REPORTING-SCHEDULER] Reporting scheduler stopped');
  }

  /**
   * Get status of all jobs
   * @returns {Object} Status of all scheduled jobs
   */
  getStatus() {
    const now = new Date();
    
    // Calculate next run times
    const nextDaily = new Date(now);
    nextDaily.setUTCHours(6, 0, 0, 0);
    if (nextDaily <= now) {
      nextDaily.setUTCDate(nextDaily.getUTCDate() + 1);
    }

    // Next weekly (Monday 7 AM UTC)
    const nextWeekly = new Date(now);
    nextWeekly.setUTCHours(7, 0, 0, 0);
    const dayOfWeek = nextWeekly.getUTCDay(); // 0=Sunday, 1=Monday, ..., 6=Saturday
    const daysUntilMonday = dayOfWeek === 0 ? 1 : (dayOfWeek === 1 ? (nextWeekly <= now ? 7 : 0) : (8 - dayOfWeek));
    if (daysUntilMonday > 0) {
      nextWeekly.setUTCDate(nextWeekly.getUTCDate() + daysUntilMonday);
    }

    // Next monthly (1st 8 AM UTC)
    const nextMonthly = new Date(now);
    nextMonthly.setUTCDate(1);
    nextMonthly.setUTCHours(8, 0, 0, 0);
    if (nextMonthly <= now) {
      nextMonthly.setUTCMonth(nextMonthly.getUTCMonth() + 1);
    }

    // Next yearly (January 1st 9 AM UTC)
    const nextYearly = new Date(now);
    nextYearly.setUTCMonth(0); // January
    nextYearly.setUTCDate(1);
    nextYearly.setUTCHours(9, 0, 0, 0);
    if (nextYearly <= now) {
      nextYearly.setUTCFullYear(nextYearly.getUTCFullYear() + 1);
    }

    return {
      isRunning: this.isRunning,
      startedAt: this.startedAt,
      uptime: this.startedAt ? Math.round((now - new Date(this.startedAt)) / 1000) : 0, // seconds
      lastRun: this.lastRun,
      nextRun: {
        daily: nextDaily.toISOString(),
        weekly: nextWeekly.toISOString(),
        monthly: nextMonthly.toISOString(),
        yearly: nextYearly.toISOString(),
      },
      jobs: this.jobs.map(({ name, job }) => ({
        name,
        running: job.running || false,
        lastRun: this.lastRun[name] || null
      })),
    };
  }

  /**
   * Process all reports for a given interval
   * @param {String} interval - 'Daily', 'Weekly', 'Monthly', 'Yearly'
   * @returns {Promise<Object>} Processing result
   */
  async processReportsForInterval(interval) {
    try {
      // Find all assignments with reports matching this interval
      // Use select to ensure we get the interval field
      const assignments = await BuildingReportingAssignment.find()
        .populate({
          path: 'reporting_id',
          match: { interval: interval },
          select: 'name interval reportContents' // Explicitly select required fields
        })
        .populate('recipient_id')
        .populate('building_id')
        .exec();

      // Filter out assignments where reporting_id is null (populate didn't match)
      // Also validate that reporting_id has the interval field
      const validAssignments = assignments.filter(a => {
        if (!a.reporting_id || !a.recipient_id || !a.building_id) {
          return false;
        }
        // Check if reporting_id is populated (object) and has interval field
        if (typeof a.reporting_id === 'object' && !a.reporting_id.interval) {
          console.warn(`[REPORTING-SCHEDULER] Assignment ${a._id} has reporting_id but missing interval field`);
          return false;
        }
        return true;
      });

      if (validAssignments.length === 0) {
        console.log(`[REPORTING-SCHEDULER] No ${interval} reports to process`);
        return { processed: 0, success: 0, failed: 0 };
      }

      console.log(`[REPORTING-SCHEDULER] Processing ${validAssignments.length} ${interval} report(s)...`);

      // Debug: Log assignment details
      for (const assignment of validAssignments) {
        const reportingType = typeof assignment.reporting_id;
        const hasInterval = assignment.reporting_id && assignment.reporting_id.interval;
        console.log(`[REPORTING-SCHEDULER] Assignment ${assignment._id}: reporting_id type=${reportingType}, hasInterval=${hasInterval}, interval=${assignment.reporting_id?.interval || 'N/A'}`);
      }

      let successCount = 0;
      let failCount = 0;

      // Process each assignment
      for (const assignment of validAssignments) {
        try {
          console.log("generating and sending report for assignment", assignment);
          await this.generateAndSendReport(assignment, interval);
          successCount++;
        } catch (error) {
          console.error(`[REPORTING-SCHEDULER] Failed to process report for assignment ${assignment._id}:`, error.message);
          console.error(`[REPORTING-SCHEDULER] Error details:`, {
            assignmentId: assignment._id,
            reportingId: assignment.reporting_id?._id || assignment.reporting_id,
            reportingType: typeof assignment.reporting_id,
            hasInterval: assignment.reporting_id?.interval ? true : false,
            error: error.message,
            stack: error.stack
          });
          failCount++;
          // Continue with next assignment even if one fails
        }
      }

      console.log(`[REPORTING-SCHEDULER] ${interval} reports: ${successCount} succeeded, ${failCount} failed`);
      return { processed: validAssignments.length, success: successCount, failed: failCount };
    } catch (error) {
      console.error(`[REPORTING-SCHEDULER] Error processing ${interval} reports:`, error.message);
      throw error;
    }
  }

  /**
   * Generate and send report for a single assignment
   * @param {Object} assignment - BuildingReportingAssignment document (populated)
   * @param {String} interval - Report interval
   * @returns {Promise<Object>} Result
   */
  async generateAndSendReport(assignment, interval) {
    const { building_id, recipient_id, reporting_id } = assignment;
    console.log("generateAndSendReport's building_id is ", building_id);
    console.log("generateAndSendReport's recipient_id is ", recipient_id);
    console.log("generateAndSendReport's reporting_id is ", reporting_id);  
    // Validate that reporting_id is populated and has required fields
    if (!reporting_id) {
      throw new Error(`Reporting ID is null or not populated for assignment ${assignment._id}`);
    }

    // If reporting_id is just an ObjectId string, we need to populate it
    let reporting;
    if (typeof reporting_id === 'string' || reporting_id instanceof require('mongoose').Types.ObjectId) {
      const Reporting = require('../models/Reporting');
      reporting = await Reporting.findById(reporting_id);
      if (!reporting) {
        throw new Error(`Reporting with ID ${reporting_id} not found`);
      }
    } else {
      reporting = reporting_id;
    }

    // Validate required fields
    if (!reporting.interval) {
      throw new Error(`Reporting ${reporting._id} is missing 'interval' field. Expected: ${interval}`);
    }

    if (reporting.interval !== interval) {
      throw new Error(`Reporting interval mismatch: expected ${interval}, got ${reporting.interval}`);
    }

    // Calculate time range for this interval
    const timeRange = reportGenerationService.calculateTimeRange(interval);
    console.log("generateAndSendReport's timeRange is ", timeRange);

    // Generate report data
    const reportData = await reportGenerationService.generateFullReport(
      building_id._id.toString(),
      {
        interval: reporting.interval,
        reportContents: reporting.reportContents || [],
        name: reporting.name,
      },
      timeRange
    );
    console.log("generateAndSendReport's reportData is ", reportData);
    // Send email
    const emailResult = await reportEmailService.sendScheduledReport(
      recipient_id,
      building_id,
      reportData,
      {
        name: reporting.name,
        interval: reporting.interval,
        reportContents: reporting.reportContents || [],
      }
    );

    if (emailResult.ok) {
      console.log(`[REPORTING-SCHEDULER] ✓ Report sent to ${recipient_id.email} for building ${building_id.name}`);
    } else {
      throw new Error(`Failed to send email: ${emailResult.error}`);
    }

    return emailResult;
  }

  /**
   * Manually trigger report generation for a specific interval (for testing)
   * @param {String} interval - 'Daily', 'Weekly', 'Monthly', 'Yearly'
   * @returns {Promise<Object>} Processing result
   */
  async triggerReportGeneration(interval) {
    const timestamp = new Date().toISOString();
    console.log(`[REPORTING-SCHEDULER] [${timestamp}] 🔧 Manually triggering ${interval} report generation...`);
    const result = await this.processReportsForInterval(interval);
    if (result.processed > 0) {
      this.lastRun[interval.toLowerCase()] = timestamp;
    }
    return result;
  }
}

module.exports = new ReportingScheduler();
