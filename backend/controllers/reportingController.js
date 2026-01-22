const reportingService = require('../services/reportingService');
const reportingScheduler = require('../services/reportingScheduler');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * POST /api/v1/reporting/setup
 * Setup reporting for multiple buildings (Scenario 2)
 * Assigns recipients and report config to multiple buildings at once
 */
exports.handleReportSetup = asyncHandler(async (req, res) => {
    console.log('handleReportSetup', req.body);
  const { recipients, reportConfig, buildingIds } = req.body;

  // Validate recipients
  if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'recipients array is required and must not be empty'
    });
  }

  // Validate reportConfig
  if (!reportConfig || typeof reportConfig !== 'object' || reportConfig === null) {
    return res.status(400).json({
      success: false,
      error: 'reportConfig object is required'
    });
  }

  if (!reportConfig.name || typeof reportConfig.name !== 'string') {
    return res.status(400).json({
      success: false,
      error: 'reportConfig.name is required and must be a string'
    });
  }

  const validIntervals = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  const validReportContents = [
    'TotalConsumption',
    'ConsumptionByRoom',
    'PeakLoads',
    'MeasurementTypeBreakdown',
    'EUI',
    'PerCapitaConsumption',
    'BenchmarkComparison',
    'InefficientUsage',
    'Anomalies',
    'PeriodComparison',
    'TimeBasedAnalysis',
    'BuildingComparison',
    'TemperatureAnalysis',
    'DataQualityReport'
  ];
  
  if (!reportConfig.interval || !validIntervals.includes(reportConfig.interval)) {
    return res.status(400).json({
      success: false,
      error: `reportConfig.interval is required and must be one of: ${validIntervals.join(', ')}`
    });
  }

  // Validate reportContents if provided
  if (reportConfig.reportContents !== undefined) {
    if (!Array.isArray(reportConfig.reportContents)) {
      return res.status(400).json({
        success: false,
        error: 'reportConfig.reportContents must be an array'
      });
    }

    // Validate each content type
    for (const content of reportConfig.reportContents) {
      if (!validReportContents.includes(content)) {
        return res.status(400).json({
          success: false,
          error: `Invalid reportContent: ${content}. Must be one of: ${validReportContents.join(', ')}`
        });
      }
    }
  }

  // Validate buildingIds
  if (!buildingIds || !Array.isArray(buildingIds) || buildingIds.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'buildingIds array is required and must not be empty'
    });
  }

  // Validate each recipient in array
  for (const recipient of recipients) {
    if (typeof recipient === 'string') {
      // Valid - it's an ID reference
    } else if (typeof recipient === 'object' && recipient !== null) {
      // Validate object structure
      if (recipient.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient.email)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid email format in recipients'
        });
      }
    } else {
      return res.status(400).json({
        success: false,
        error: 'Each item in recipients must be either a string ID or an object with name, email, and optional phone'
      });
    }
  }

  // Process recipients: resolve each one (create if object, get if ID)
  const recipientIds = [];
  for (const recipientInput of recipients) {
    const recipientId = await reportingService.resolveRecipient(recipientInput);
    recipientIds.push(recipientId);
  }

  // Create single Reporting from reportConfig
  const reporting = await reportingService.createReporting(reportConfig);

  // Create assignments for each building + each recipient + the reporting
  const assignments = [];
  for (const buildingId of buildingIds) {
    for (const recipientId of recipientIds) {
      try {
        const assignment = await reportingService.createOrUpdateAssignment(
          buildingId,
          recipientId,
          reporting._id.toString()
        );
        assignments.push(assignment);
      } catch (error) {
        // If building doesn't exist, include error in response but continue with others
        if (error.message.includes('not found')) {
          assignments.push({
            buildingId,
            recipientId,
            error: error.message
          });
        } else {
          throw error;
        }
      }
    }
  }

  res.status(201).json({
    success: true,
    message: `Created reporting setup for ${buildingIds.length} building(s) and ${recipientIds.length} recipient(s)`,
    data: {
      reporting,
      assignments,
      recipientIds,
      buildingIds
    }
  });
});

/**
 * POST /api/v1/reporting/trigger/:interval
 * Manually trigger report generation for a specific interval (for testing)
 * @param {String} interval - 'Daily', 'Weekly', 'Monthly', 'Yearly'
 */
exports.triggerReportGeneration = asyncHandler(async (req, res) => {
  const { interval } = req.params;
  console.log("triggerReportGeneration", req.params);
  
  const validIntervals = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  if (!validIntervals.includes(interval)) {
    return res.status(400).json({
      success: false,
      error: `Invalid interval. Must be one of: ${validIntervals.join(', ')}`
    });
  }

  const result = await reportingScheduler.triggerReportGeneration(interval);
  console.log("the result of the triggered generation is ", result);

  res.json({
    success: true,
    message: `Triggered ${interval} report generation`,
    data: result
  });
});

/**
 * GET /api/v1/reporting/scheduler/status
 * Get reporting scheduler status
 */
exports.getSchedulerStatus = asyncHandler(async (req, res) => {
  const status = reportingScheduler.getStatus();

  res.json({
    success: true,
    data: status
  });
});
