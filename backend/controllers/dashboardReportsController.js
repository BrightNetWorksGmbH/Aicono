const dashboardReportsService = require('../services/dashboardReportsService');
const reportContentService = require('../services/reportContentService');
const reportTokenService = require('../services/reportTokenService');
const { asyncHandler } = require('../middleware/errorHandler');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
const Building = require('../models/Building');
const Site = require('../models/Site');
const UserRole = require('../models/UserRole');
const User = require('../models/User');
const Reporting = require('../models/Reporting');
/**
 * GET /api/v1/dashboard/reports/sites
 * Get all sites with reports for the authenticated user
 * Query parameters:
 * - bryteswitch_id (optional): Filter by bryteswitch ID
 */
exports.getSites = asyncHandler(async (req, res) => {
  const userId = req.user._id;
  const { bryteswitch_id } = req.query;

  const sites = await dashboardReportsService.getSitesWithReports(
    userId,
    bryteswitch_id || null
  );

  res.json({
    success: true,
    data: sites,
    count: sites.length
  });
});

/**
 * GET /api/v1/dashboard/reports/sites/:siteId/buildings
 * Get buildings in a site with their reports
 */
exports.getBuildings = asyncHandler(async (req, res) => {
  const { siteId } = req.params;
  const userId = req.user._id;

  const buildings = await dashboardReportsService.getBuildingsWithReports(siteId, userId);

  res.json({
    success: true,
    data: buildings,
    count: buildings.length
  });
});

/**
 * GET /api/v1/dashboard/reports/buildings/:buildingId/reports
 * Get all reports for a building, grouped by report name with recipients
 */
exports.getReports = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const userId = req.user._id;

  const reports = await dashboardReportsService.getBuildingReports(buildingId, userId);

  res.json({
    success: true,
    data: reports,
    count: reports.length
  });
});

/**
 * GET /api/v1/dashboard/reports/view/:reportId
 * Get report content for a specific report
 * Query parameters:
 * - building_id (optional): Building ID - if not provided, will use first assignment for this report
 * - startDate (optional): Start date for the report period (ISO 8601 format). If provided, endDate will be calculated based on report interval
 * - endDate (optional): End date (ISO 8601 format). If not provided and startDate is provided, will be calculated from startDate + interval
 * - resolution (optional): Override resolution
 * - measurementType (optional): Filter by measurement type
 * 
 * Time Range Logic:
 * - If both startDate and endDate provided: use them directly
 * - If only startDate provided: calculate endDate based on report interval (Daily = same day, Weekly = week containing startDate, etc.)
 * - If neither provided: use report interval to calculate previous period (Daily = previous day, Weekly = previous week, etc.)
 */
exports.getReportContent = asyncHandler(async (req, res) => {
  const { reportId } = req.params;
  const { building_id, startDate, endDate, resolution, measurementType } = req.query;
  const userId = req.user._id;

  let buildingId = building_id;

  // If building_id not provided, find it from the first assignment for this report
  if (!buildingId) {
    
    const assignment = await BuildingReportingAssignment.findOne({ reporting_id: reportId })
      .populate('building_id', 'site_id')
      .lean();

    if (!assignment) {
      return res.status(404).json({
        success: false,
        error: 'No assignment found for this report. Please provide building_id.'
      });
    }

    buildingId = assignment.building_id._id.toString();

    // Verify user has access to this building
 

    const building = await Building.findById(buildingId).populate('site_id');
    if (!building) {
      return res.status(404).json({
        success: false,
        error: 'Building not found'
      });
    }

    const site = await Site.findById(building.site_id._id || building.site_id);
    if (!site) {
      return res.status(404).json({
        success: false,
        error: 'Site not found'
      });
    }

    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: site.bryteswitch_id
    });

    if (!userRole) {
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        return res.status(403).json({
          success: false,
          error: 'You do not have access to this building'
        });
      }
    }
  }

  // Get reporting configuration to access interval

  const reporting = await Reporting.findById(reportId);
  if (!reporting) {
    return res.status(404).json({
      success: false,
      error: 'Reporting configuration not found'
    });
  }

  const reportGenerationService = require('../services/reportGenerationService');
  let timeRange = null;

  // Build time range based on query parameters and report interval
  if (startDate && endDate) {
    // Both dates provided: use them directly
    timeRange = {
      startDate: new Date(startDate),
      endDate: new Date(endDate)
    };
  } else if (startDate) {
    // Only startDate provided: calculate endDate based on report interval
    timeRange = reportGenerationService.calculateTimeRangeFromStart(reporting.interval, new Date(startDate));
  } else {
    // Neither provided: use report interval to calculate previous period
    // This matches the behavior of scheduled reports (previous day/week/month/year)
    timeRange = reportGenerationService.calculateTimeRange(reporting.interval);
  }

  // Build options
  const options = {};
  if (resolution) options.resolution = parseInt(resolution, 10);
  if (measurementType) options.measurementType = measurementType;
  // Always pass the interval so analytics can use it
  options.interval = reporting.interval;

  // Get report content
  const reportContent = await reportContentService.getReportContent(
    buildingId,
    reportId,
    timeRange,
    options
  );

  res.json({
    success: true,
    data: reportContent
  });
});

/**
 * GET /api/v1/reports/view?token=...
 * Get report content from token (public endpoint, no auth required)
 * This is used when users click "View now" from email
 */
exports.getReportContentByToken = asyncHandler(async (req, res) => {
    console.log("req.query", req.query);
  const { token } = req.query;
  console.log("token to be displayed", token);

  if (!token) {
    return res.status(400).json({
      success: false,
      error: 'Token query parameter is required'
    });
  }

  try {
    // Verify and extract token info
    const tokenInfo = reportTokenService.extractReportInfo(token);
    console.log("tokenInfo", tokenInfo);

    // Get report content for the specific time range from token
    const reportContent = await reportContentService.getReportContentFromToken(tokenInfo);

    res.json({
      success: true,
      data: reportContent
    });
  } catch (error) {
    if (error.message.includes('expired') || error.message.includes('Invalid')) {
      return res.status(401).json({
        success: false,
        error: error.message
      });
    }
    
    console.error('[REPORT-VIEW] Error getting report content from token:', error.message);
    return res.status(500).json({
      success: false,
      error: 'Failed to retrieve report content'
    });
  }
});
