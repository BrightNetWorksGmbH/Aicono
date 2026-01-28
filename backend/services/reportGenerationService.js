const Building = require('../models/Building');
const dashboardDiscoveryService = require('./dashboardDiscoveryService');
const analyticsService = require('./analyticsService');

/**
 * Report Generation Service
 * 
 * Generates report data for each selected content type using dashboard data methods
 */
class ReportGenerationService {
  /**
   * Calculate time range for a given interval
   * @param {String} interval - 'Daily', 'Weekly', 'Monthly', 'Yearly'
   * @param {Date} referenceDate - Reference date (default: now)
   * @returns {Object} { startDate, endDate }
   */
  calculateTimeRange(interval, referenceDate = new Date()) {
    const now = new Date(referenceDate);
    let startDate, endDate;

    switch (interval) {
      case 'Daily':
        // Previous day (00:00 to 23:59)
        // Use UTC to avoid timezone issues
        const yesterday = new Date(Date.UTC(
          now.getUTCFullYear(),
          now.getUTCMonth(),
          now.getUTCDate() - 1,
          0, 0, 0, 0
        ));
        startDate = yesterday;
        endDate = new Date(Date.UTC(
          yesterday.getUTCFullYear(),
          yesterday.getUTCMonth(),
          yesterday.getUTCDate(),
          23, 59, 59, 999
        ));
        console.log(`[DEBUG] calculateTimeRange Daily: now=${now.toISOString()}, yesterday=${yesterday.toISOString()}, startDate=${startDate.toISOString()}, endDate=${endDate.toISOString()}`);
        break;

      case 'Weekly':
        // Previous week (Monday 00:00 to Sunday 23:59)
        // If today is Monday, previous week is last Monday to last Sunday
        // If today is any other day, previous week is the Monday-Sunday period that just ended
        const dayOfWeek = now.getUTCDay(); // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
        let daysToLastMonday;
        if (dayOfWeek === 0) {
          // Today is Sunday, previous week ended yesterday (Saturday), so go back 6 days to last Monday
          daysToLastMonday = 6;
        } else if (dayOfWeek === 1) {
          // Today is Monday, previous week ended yesterday (Sunday), so go back 7 days to last Monday
          daysToLastMonday = 7;
        } else {
          // Today is Tuesday-Saturday, previous week ended on Sunday, so go back (dayOfWeek + 6) days
          daysToLastMonday = dayOfWeek + 6;
        }
        startDate = new Date(now);
        startDate.setUTCDate(startDate.getUTCDate() - daysToLastMonday);
        startDate.setUTCHours(0, 0, 0, 0);
        endDate = new Date(startDate);
        endDate.setUTCDate(endDate.getUTCDate() + 6); // Sunday of that week
        endDate.setUTCHours(23, 59, 59, 999);
        break;

      case 'Monthly':
        // Previous month (1st 00:00 to last day 23:59)
        startDate = new Date(now.getUTCFullYear(), now.getUTCMonth() - 1, 1);
        startDate.setUTCHours(0, 0, 0, 0);
        endDate = new Date(now.getUTCFullYear(), now.getUTCMonth(), 0); // Last day of previous month
        endDate.setUTCHours(23, 59, 59, 999);
        break;

      case 'Yearly':
        // Previous year (Jan 1 00:00 to Dec 31 23:59)
        startDate = new Date(now.getUTCFullYear() - 1, 0, 1);
        startDate.setUTCHours(0, 0, 0, 0);
        endDate = new Date(now.getUTCFullYear() - 1, 11, 31);
        endDate.setUTCHours(23, 59, 59, 999);
        break;

      default:
        throw new Error(`Invalid interval: ${interval}`);
    }

    return { startDate, endDate };
  }

  /**
   * Generate full report with all selected contents
   * @param {String} buildingId - Building ID
   * @param {Object} reportConfig - Reporting config with reportContents array
   * @param {Object} timeRange - { startDate, endDate }
   * @returns {Promise<Object>} Complete report data
   */
  async generateFullReport(buildingId, reportConfig, timeRange) {
    console.log("generateFullReport's buildingId is ", buildingId);
    const { startDate, endDate } = timeRange;
    const { reportContents = [] } = reportConfig;

    // Get building data
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }

    // Generate base KPIs (used by multiple content types)
    // For reports, force appropriate resolution based on interval and data age
    const interval = reportConfig.interval; // Get interval from reportConfig
    const daysSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60 * 24);
    const resolutionOptions = {};
    
    // Determine resolution based on interval and data age
    // Daily reports: previous day → always use hourly (60) aggregates (15-min may not exist yet)
    // Weekly reports: previous week (7+ days old) → use hourly (60) or daily (1440) aggregates
    // Monthly/Yearly: very old data → use daily (1440) aggregates
    if (daysSinceEndDate > 7 || interval === 'Monthly' || interval === 'Yearly') {
        resolutionOptions.resolution = 1440; // daily for old data
    } else if (daysSinceEndDate >= 1 || interval === 'Weekly' || interval === 'Daily') {
        // For Daily reports, always use hourly (60) since 15-minute aggregates may not exist for yesterday
        // For Weekly reports, use hourly for week-old data
        resolutionOptions.resolution = 60; // hourly for daily/weekly reports
    } else {
        resolutionOptions.resolution = 15; // 15-minute for recent data (today)
    }
    
    console.log(`[REPORT] Generating ${interval} report for building ${buildingId}: timeRange=${startDate.toISOString()} to ${endDate.toISOString()}, daysSinceEndDate=${daysSinceEndDate.toFixed(1)}, preferredResolution=${resolutionOptions.resolution || 'auto'} minutes`);
    
    // Pass preferred resolution and interval, but getBuildingKPIs will fallback to other resolutions if no data found
    // Interval is used to select appropriate total* stateType for Energy measurements
    resolutionOptions.interval = interval;
    const kpis = await dashboardDiscoveryService.getBuildingKPIs(buildingId, startDate, endDate, resolutionOptions);

    // Generate each selected content
    const reportData = {
      building: {
        id: building._id.toString(),
        name: building.name,
        size: building.building_size,
        heatedArea: building.heated_building_area ? parseFloat(building.heated_building_area.toString()) : null,
        typeOfUse: building.type_of_use,
        numPeople: building.num_students_employees,
      },
      timeRange: {
        start: startDate,
        end: endDate,
        interval: reportConfig.interval,
      },
      kpis: kpis,
      contents: {},
    };

    // Generate each selected content type
    for (const contentType of reportContents) {
      try {
        reportData.contents[contentType] = await this.generateReportContent(
          buildingId,
          contentType,
          timeRange,
          { building, kpis, interval: reportConfig.interval, timeRange }
        );
      } catch (error) {
        console.error(`[REPORT] Error generating ${contentType} for building ${buildingId}:`, error.message);
        reportData.contents[contentType] = {
          error: error.message,
          available: false,
        };
      }
    }

    return reportData;
  }

  /**
   * Generate specific report content
   * @param {String} buildingId - Building ID
   * @param {String} contentType - Content type to generate
   * @param {Object} timeRange - { startDate, endDate }
   * @param {Object} options - Additional options (building, kpis, interval, etc.)
   * @returns {Promise<Object>} Content data
   */
  async generateReportContent(buildingId, contentType, timeRange, options = {}) {
    const { building, kpis, interval, timeRange: timeRangeOption } = options;
    const { startDate, endDate } = timeRange;

    switch (contentType) {
      case 'TotalConsumption':
        return analyticsService.generateTotalConsumption(kpis);
      case 'ConsumptionByRoom':
        return await analyticsService.generateConsumptionByRoom(buildingId, timeRange, interval, dashboardDiscoveryService);
      case 'PeakLoads':
        return analyticsService.generatePeakLoads(kpis);
      case 'MeasurementTypeBreakdown':
        return analyticsService.generateMeasurementTypeBreakdown(kpis);
      case 'EUI':
        return await analyticsService.generateEUI(building, kpis, timeRangeOption || timeRange, buildingId);
      case 'PerCapitaConsumption':
        return await analyticsService.generatePerCapitaConsumption(building, kpis, buildingId);
      case 'BenchmarkComparison':
        return await analyticsService.generateBenchmarkComparison(building, kpis, timeRangeOption || timeRange, buildingId);
      case 'InefficientUsage':
        return await analyticsService.generateInefficientUsage(buildingId, timeRange, interval, dashboardDiscoveryService);
      case 'Anomalies':
        return await analyticsService.generateAnomalies(buildingId, timeRange);
      case 'PeriodComparison':
        return await analyticsService.generatePeriodComparison(buildingId, interval, timeRange, dashboardDiscoveryService, this.calculateTimeRange.bind(this));
      case 'TimeBasedAnalysis':
        return await analyticsService.generateTimeBasedAnalysis(buildingId, timeRange, interval);
      case 'BuildingComparison':
        return await analyticsService.generateBuildingComparison(buildingId, timeRange, interval, dashboardDiscoveryService);
      case 'TemperatureAnalysis':
        return await analyticsService.generateTemperatureAnalysis(buildingId, timeRange);
      case 'DataQualityReport':
        return analyticsService.generateDataQualityReport(kpis);
      default:
        throw new Error(`Unknown content type: ${contentType}`);
    }
  }

}

module.exports = new ReportGenerationService();
