const reportGenerationService = require('./reportGenerationService');
const dashboardDiscoveryService = require('./dashboardDiscoveryService');
const Building = require('../models/Building');
const Reporting = require('../models/Reporting');
const Site = require('../models/Site');

/**
 * Report Content Service
 * 
 * Common service for fetching report content for both:
 * - Dashboard (current period)
 * - Email token links (specific historical period)
 */
class ReportContentService {
  /**
   * Get report content for a building and reporting configuration
   * @param {String} buildingId - Building ID
   * @param {String} reportingId - Reporting ID
   * @param {Object} timeRange - { startDate, endDate } (optional, if not provided uses current period)
   * @param {Object} options - Query options (resolution, measurementType, useCurrentPeriod, etc.)
   *   - useCurrentPeriod: if true and timeRange is null, use last 7 days (default: false for backward compatibility)
   * @returns {Promise<Object>} Report content data
   */
  async getReportContent(buildingId, reportingId, timeRange = null, options = {}) {
    // Validate building exists and get site for address
    const building = await Building.findById(buildingId).populate('site_id');
    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }
    let address = null;
    if (building.site_id) {
      const site = await Site.findById(building.site_id._id || building.site_id).lean();
      address = site?.address || null;
    }

    // Validate reporting exists
    const reporting = await Reporting.findById(reportingId);
    if (!reporting) {
      throw new Error(`Reporting with ID ${reportingId} not found`);
    }

    // If timeRange not provided, determine based on useCurrentPeriod flag
    let reportTimeRange = timeRange;
    if (!reportTimeRange) {
      if (options.useCurrentPeriod) {
        // For dashboard viewing: use last 7 days (current/recent data)
        reportTimeRange = dashboardDiscoveryService.getDefaultTimeRange({ days: 7 });
      } else {
        // For scheduled reports: use interval-based calculation (historical period)
        reportTimeRange = reportGenerationService.calculateTimeRange(reporting.interval);
      }
    }

    // Generate full report
    const reportData = await reportGenerationService.generateFullReport(
      buildingId,
      {
        interval: reporting.interval,
        reportContents: reporting.reportContents || [],
        name: reporting.name,
      },
      reportTimeRange
    );

    return {
      building: {
        id: building._id.toString(),
        name: building.name,
        address: address,
        size: building.building_size,
        heatedArea: building.heated_building_area ? parseFloat(building.heated_building_area.toString()) : null,
        typeOfUse: building.type_of_use,
        numPeople: building.num_students_employees,
      },
      reporting: {
        id: reporting._id.toString(),
        name: reporting.name,
        interval: reporting.interval,
        reportContents: reporting.reportContents || [],
      },
      reportData: reportData,
      timeRange: reportTimeRange,
    };
  }

  /**
   * Get report content from token (for email links)
   * @param {Object} tokenInfo - Token info from reportTokenService.extractReportInfo()
   * @param {Object} options - Query options
   * @returns {Promise<Object>} Report content data
   */
  async getReportContentFromToken(tokenInfo, options = {}) {
    return this.getReportContent(
      tokenInfo.buildingId,
      tokenInfo.reportingId,
      tokenInfo.timeRange,
      options
    );
  }
}

module.exports = new ReportContentService();
