const dashboardReportsService = require('../services/dashboardReportsService');
const reportContentService = require('../services/reportContentService');
const reportTokenService = require('../services/reportTokenService');
const { asyncHandler } = require('../middleware/errorHandler');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
const Building = require('../models/Building');
const Site = require('../models/Site');
const UserRole = require('../models/UserRole');
const User = require('../models/User');
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
 * Get report content for a specific report (current period)
 * Query parameters:
 * - building_id (optional): Building ID - if not provided, will use first assignment for this report
 * - startDate (optional): Override start date
 * - endDate (optional): Override end date
 * - resolution (optional): Override resolution
 * - measurementType (optional): Filter by measurement type
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

  // Build time range if provided
  let timeRange = null;
  if (startDate && endDate) {
    timeRange = {
      startDate: new Date(startDate),
      endDate: new Date(endDate)
    };
  }

  // Build options
  const options = {};
  if (resolution) options.resolution = parseInt(resolution, 10);
  if (measurementType) options.measurementType = measurementType;
  // For dashboard viewing, use current period (last 7 days) when timeRange is not provided
  options.useCurrentPeriod = !timeRange; // true if timeRange is null/undefined

  // Get report content (uses current period if timeRange not provided)
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
