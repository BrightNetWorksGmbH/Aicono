const reportingService = require('../services/reportingService');
const reportingScheduler = require('../services/reportingScheduler');
const reportTokenService = require('../services/reportTokenService');
const { asyncHandler } = require('../middleware/errorHandler');
const { checkReportingPermissionByReporting, checkReportingPermissionByBuilding } = require('../utils/buildingPermissions');
const ReportingRecipient = require('../models/ReportingRecipient');
const Building = require('../models/Building');
const Reporting = require('../models/Reporting');

/**
 * POST /api/v1/reporting/setup
 * Setup reporting for multiple buildings (Scenario 2)
 * Assigns recipients and report config to multiple buildings at once
 */
exports.handleReportSetup = asyncHandler(async (req, res) => {
    // console.log('handleReportSetup', req.body);
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
  console.log("triggerReportGeneration body for testing", req.params);
  
  const validIntervals = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  if (!validIntervals.includes(interval)) {
    return res.status(400).json({
      success: false,
      error: `Invalid interval. Must be one of: ${validIntervals.join(', ')}`
    });
  }

  // Start report generation asynchronously to prevent timeout
  // Return immediately, report generation continues in background
  reportingScheduler.triggerReportGeneration(interval)
    .then(result => {
      console.log("the result of the triggered generation is ", result);
    })
    .catch(error => {
      console.error(`[REPORTING] Error generating ${interval} reports:`, error.message);
    });

  // Return immediately with processing status
  res.json({
    success: true,
    message: `${interval} report generation started in background`,
    data: {
      status: 'processing',
      interval: interval,
      note: 'Report generation is running asynchronously. Check email for results.'
    }
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

/**
 * GET /api/v1/reporting/recipients
 * Get all reporting recipients with optional filtering
 * Query parameters:
 * - site_id (optional): Filter recipients by site ID
 * - building_id (optional): Filter recipients by building ID
 */
exports.getRecipients = asyncHandler(async (req, res) => {
  const { site_id, building_id } = req.query;

  const filters = {};
  if (site_id) filters.site_id = site_id;
  if (building_id) filters.building_id = building_id;

  const recipients = await reportingService.getRecipients(filters);

  res.json({
    success: true,
    data: recipients,
    count: recipients.length
  });
});

/**
 * GET /api/v1/reporting/token/info
 * Get report information from token
 * Query parameters:
 * - token (required): JWT token from report link
 * @returns {Object} Report details including recipient, building, and reporting information
 */
exports.getReportInfoFromToken = asyncHandler(async (req, res) => {
  const { token } = req.query;

  // Validate token parameter
  if (!token || typeof token !== 'string' || token.trim() === '') {
    return res.status(400).json({
      success: false,
      error: 'Token parameter is required'
    });
  }

  try {
    // Extract report information from token
    const reportInfo = reportTokenService.extractReportInfo(token);

    // Fetch related entities in parallel for better performance
    const [recipient, building, reporting] = await Promise.all([
      ReportingRecipient.findById(reportInfo.recipientId).lean(),
      Building.findById(reportInfo.buildingId).lean(),
      Reporting.findById(reportInfo.reportingId).lean()
    ]);

    // Validate that all entities exist
    if (!recipient) {
      return res.status(404).json({
        success: false,
        error: 'Recipient not found'
      });
    }

    if (!building) {
      return res.status(404).json({
        success: false,
        error: 'Building not found'
      });
    }

    if (!reporting) {
      return res.status(404).json({
        success: false,
        error: 'Reporting not found'
      });
    }

    // Return structured response
    res.json({
      success: true,
      data: {
        recipient: {
          id: recipient._id.toString(),
          name: recipient.name || recipient.email.split('@')[0], // Fallback to email prefix if name not set
          email: recipient.email
        },
        building: {
          id: building._id.toString(),
          name: building.name
        },
        reporting: {
          id: reporting._id.toString(),
          name: reporting.name,
          interval: reporting.interval,
          reportContents: reporting.reportContents || []
        },
        timeRange: {
          startDate: reportInfo.timeRange.startDate,
          endDate: reportInfo.timeRange.endDate
        },
        interval: reportInfo.interval,
        generatedAt: reportInfo.generatedAt
      }
    });
  } catch (error) {
    // Handle token verification errors
    if (error.message.includes('expired')) {
      return res.status(401).json({
        success: false,
        error: 'Report link has expired. Please request a new report.'
      });
    } else if (error.message.includes('Invalid')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid report link. Please check the URL.'
      });
    } else {
      // Log unexpected errors for debugging
      console.error('[REPORTING] Error getting report info from token:', error);
      return res.status(500).json({
        success: false,
        error: 'Failed to retrieve report information'
      });
    }
  }
});

/**
 * DELETE /api/v1/reporting/:reportingId
 * Delete a report and all related assignments
 */
exports.deleteReport = asyncHandler(async (req, res) => {
  const { reportingId } = req.params;
  const userId = req.user._id;

  // Check permission - user must be Owner, Admin, or Expert (not Read-Only)
  await checkReportingPermissionByReporting(userId, reportingId);

  const result = await reportingService.deleteReporting(reportingId);

  res.json({
    success: true,
    message: `Report "${result.reportingName}" deleted successfully`,
    data: result
  });
});

/**
 * PATCH /api/v1/reporting/:reportingId
 * Update a report (name, interval, reportContents)
 */
exports.updateReport = asyncHandler(async (req, res) => {
  const { reportingId } = req.params;
  const userId = req.user._id;
  const updateData = req.body;

  // Validate that at least one field is provided
  if (!updateData || Object.keys(updateData).length === 0) {
    return res.status(400).json({
      success: false,
      error: 'At least one field (name, interval, or reportContents) must be provided for update'
    });
  }

  // Check permission - user must be Owner, Admin, or Expert (not Read-Only)
  await checkReportingPermissionByReporting(userId, reportingId);

  const updatedReporting = await reportingService.updateReporting(reportingId, updateData);

  res.json({
    success: true,
    message: 'Report updated successfully',
    data: updatedReporting
  });
});

/**
 * POST /api/v1/reporting/:reportingId/recipients
 * Add recipients to a report for a specific building
 * Body: { recipients: [string|object], buildingId }
 * Recipients can be:
 *   - String IDs: "697b3bd9234121f6ca541e2b" (existing recipient)
 *   - Objects: { name, email, phone? } (new recipient to create)
 */
exports.addRecipientToReport = asyncHandler(async (req, res) => {
  const { reportingId } = req.params;
  const userId = req.user._id;
  const { recipients, buildingId } = req.body;

  // Validate required fields
  if (!recipients || !Array.isArray(recipients) || recipients.length === 0) {
    return res.status(400).json({
      success: false,
      error: 'recipients array is required and must not be empty'
    });
  }

  if (!buildingId) {
    return res.status(400).json({
      success: false,
      error: 'buildingId is required in request body'
    });
  }

  // Validate each recipient in array
  for (const recipient of recipients) {
    if (typeof recipient === 'string') {
      // Valid - it's an ID reference
      if (recipient.trim() === '') {
        return res.status(400).json({
          success: false,
          error: 'Recipient ID cannot be empty'
        });
      }
    } else if (typeof recipient === 'object' && recipient !== null) {
      // Validate object structure
      if (!recipient.email) {
        return res.status(400).json({
          success: false,
          error: 'Email is required for new recipient objects'
        });
      }
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient.email)) {
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

  // Check permission - user must be Owner, Admin, or Expert (not Read-Only)
  // Check based on building since that's what we're working with
  await checkReportingPermissionByBuilding(userId, buildingId);

  const result = await reportingService.addRecipientsToReport(
    reportingId,
    recipients,
    buildingId
  );

  res.status(201).json({
    success: true,
    message: `Added ${result.assignments.length} recipient(s) to report successfully`,
    data: result
  });
});

/**
 * DELETE /api/v1/reporting/:reportingId/recipients/:recipientId
 * Remove a recipient from a report for a specific building
 * Body: { buildingId }
 */
exports.removeRecipientFromReport = asyncHandler(async (req, res) => {
  const { reportingId, recipientId } = req.params;
  const userId = req.user._id;
  const { buildingId } = req.body;

  // Validate required field
  if (!buildingId) {
    return res.status(400).json({
      success: false,
      error: 'buildingId is required in request body'
    });
  }

  // Check permission - user must be Owner, Admin, or Expert (not Read-Only)
  // Check based on building since that's what we're working with
  await checkReportingPermissionByBuilding(userId, buildingId);

  const result = await reportingService.removeRecipientFromReport(
    reportingId,
    recipientId,
    buildingId
  );

  res.json({
    success: true,
    message: 'Recipient removed from report successfully',
    data: result
  });
});
