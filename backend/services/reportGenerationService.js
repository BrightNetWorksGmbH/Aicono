const Building = require('../models/Building');
const dashboardDiscoveryService = require('./dashboardDiscoveryService');
const analyticsService = require('./analyticsService');

/**
 * Simple in-memory cache for report summary KPIs
 * Key: `${buildingId}_${startDate.toISOString()}_${endDate.toISOString()}_${resolution}`
 * Value: { kpis, timestamp }
 * TTL: 5 minutes (300000ms)
 */
const kpiCache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

/**
 * Report Generation Service
 * 
 * Generates report data for each selected content type using dashboard data methods
 */
class ReportGenerationService {
  /**
   * Get cache key for KPIs
   * @param {String} buildingId - Building ID
   * @param {Date} startDate - Start date
   * @param {Date} endDate - End date
   * @param {Number} resolution - Resolution in minutes
   * @returns {String} Cache key
   */
  _getCacheKey(buildingId, startDate, endDate, resolution) {
    return `${buildingId}_${startDate.toISOString()}_${endDate.toISOString()}_${resolution}`;
  }

  /**
   * Generate content with timeout protection
   * @param {String} contentType - Content type name (for logging)
   * @param {Function} generator - Async function that generates the content
   * @param {Number} timeoutMs - Timeout in milliseconds (default: 10000)
   * @returns {Promise<Object>} Generated content or error object
   */
  async _generateWithTimeout(contentType, generator, timeoutMs = 10000) {
    return Promise.race([
      generator(),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error(`Timeout: ${contentType} exceeded ${timeoutMs}ms`)), timeoutMs)
      )
    ]).catch(error => {
      if (error.message.includes('Timeout')) {
        return {
          error: error.message,
          available: false,
          timeout: true
        };
      }
      throw error; // Re-throw non-timeout errors
    });
  }

  /**
   * Clean expired cache entries
   */
  _cleanExpiredCache() {
    const now = Date.now();
    for (const [key, value] of kpiCache.entries()) {
      if (now - value.timestamp > CACHE_TTL) {
        kpiCache.delete(key);
      }
    }
  }
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
   * Generate report summary (KPIs only, no content types)
   * Used for email sending - much faster than generating full report
   * @param {String} buildingId - Building ID
   * @param {Object} reportConfig - Reporting config with interval
   * @param {Object} timeRange - { startDate, endDate }
   * @param {Object} options - Optional context (assignmentId, etc.)
   * @returns {Promise<Object>} Report summary with building, timeRange, and kpis (no contents)
   */
  async generateReportSummary(buildingId, reportConfig, timeRange, options = {}) {
    const { startDate, endDate } = timeRange;
    const interval = reportConfig.interval;
    const { assignmentId } = options;
    const contextPrefix = assignmentId ? `[Assignment ${assignmentId}]` : `[Building ${buildingId}]`;

    // Get building data
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }

    // Generate base KPIs only (no content types)
    // For reports, force appropriate resolution based on interval and data age
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
    
    console.log(`[REPORT-SUMMARY] ${contextPrefix} Generating ${interval} report summary: timeRange=${startDate.toISOString()} to ${endDate.toISOString()}, daysSinceEndDate=${daysSinceEndDate.toFixed(1)}, preferredResolution=${resolutionOptions.resolution || 'auto'} minutes`);
    
    // Check cache first (only for report summaries to speed up batch processing)
    const cacheKey = this._getCacheKey(buildingId, startDate, endDate, resolutionOptions.resolution);
    this._cleanExpiredCache(); // Clean expired entries periodically
    
    let kpis;
    const kpisStartTime = Date.now();
    
    if (kpiCache.has(cacheKey)) {
      const cached = kpiCache.get(cacheKey);
      const cacheAge = Date.now() - cached.timestamp;
      if (cacheAge < CACHE_TTL) {
        kpis = cached.kpis;
        const kpisDuration = Date.now() - kpisStartTime;
        console.log(`[REPORT-SUMMARY] ${contextPrefix} KPIs retrieved from cache in ${kpisDuration}ms (cache age: ${Math.round(cacheAge / 1000)}s)`);
      } else {
        // Cache expired, remove it
        kpiCache.delete(cacheKey);
      }
    }
    
    // If not in cache or expired, fetch from database
    if (!kpis) {
      // Pass preferred resolution and interval, but getBuildingKPIs will fallback to other resolutions if no data found
      // Interval is used to select appropriate total* stateType for Energy measurements
      resolutionOptions.interval = interval;
      resolutionOptions.isReportSummary = true; // Flag to optimize fallback logic for report summaries
      
      kpis = await dashboardDiscoveryService.getBuildingKPIs(buildingId, startDate, endDate, resolutionOptions);
      const kpisDuration = Date.now() - kpisStartTime;
      
      // Cache the result
      kpiCache.set(cacheKey, {
        kpis,
        timestamp: Date.now()
      });
      
      console.log(`[REPORT-SUMMARY] ${contextPrefix} KPIs retrieved from database in ${kpisDuration}ms (cached for future use)`);
    }
    
    // Return minimal report data structure (no contents field)
    return {
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
        interval: interval,
      },
      kpis: kpis,
    };
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
    console.log("time before calling getBuildingKPIs is ", Date.now());
    const kpis = await dashboardDiscoveryService.getBuildingKPIs(buildingId, startDate, endDate, resolutionOptions);
    console.log("time after calling getBuildingKPIs is ", Date.now());
    console.log("kpis is itelf is also ", kpis);
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
    // Group content types: synchronous (KPIs-based) vs async (database queries)
    const syncContentTypes = ['TotalConsumption', 'PeakLoads', 'MeasurementTypeBreakdown', 'EUI', 'PerCapitaConsumption', 'BenchmarkComparison', 'DataQualityReport'];
    const asyncContentTypes = reportContents.filter(ct => !syncContentTypes.includes(ct));
    
    // Generate synchronous content types first (fast, no database queries)
    for (const contentType of reportContents.filter(ct => syncContentTypes.includes(ct))) {
      try {
        const startTime = Date.now();
        reportData.contents[contentType] = await this.generateReportContent(
          buildingId,
          contentType,
          timeRange,
          { building, kpis, interval: reportConfig.interval, timeRange }
        );
        const duration = Date.now() - startTime;
        console.log(`[REPORT] ${contentType} generated in ${duration}ms`);
      } catch (error) {
        console.error(`[REPORT] Error generating ${contentType} for building ${buildingId}:`, error.message);
        reportData.contents[contentType] = {
          error: error.message,
          available: false,
        };
      }
    }
    
    // Generate async content types in parallel with timeout handling
    if (asyncContentTypes.length > 0) {
      // Content-type-specific timeouts (slower operations need more time)
      const timeoutMap = {
        'ConsumptionByRoom': 30000, // 30 seconds for 36 rooms
        'TemperatureAnalysis': 20000, // 20 seconds for aggregation query
        'BuildingComparison': 20000, // 20 seconds (multiple buildings)
        'PeriodComparison': 20000, // 20 seconds (2 getBuildingKPIs calls)
        'default': 15000 // 15 seconds for others
      };
      
      const asyncPromises = asyncContentTypes.map(async (contentType) => {
        const startTime = Date.now();
        const timeout = timeoutMap[contentType] || timeoutMap.default;
        try {
          const result = await this._generateWithTimeout(
            contentType,
            () => this.generateReportContent(
              buildingId,
              contentType,
              timeRange,
              { building, kpis, interval: reportConfig.interval, timeRange }
            ),
            timeout
          );
          const duration = Date.now() - startTime;
          console.log(`[REPORT] ${contentType} generated in ${duration}ms${result.timeout ? ' (timeout)' : ''}`);
          return { contentType, result };
        } catch (error) {
          const duration = Date.now() - startTime;
          console.error(`[REPORT] Error generating ${contentType} for building ${buildingId} (${duration}ms):`, error.message);
          return {
            contentType,
            result: {
              error: error.message,
              available: false,
            }
          };
        }
      });
      
      // Wait for all async content types to complete (or timeout)
      const asyncResults = await Promise.allSettled(asyncPromises);
      
      // Process results
      asyncResults.forEach((settled, index) => {
        const contentType = asyncContentTypes[index];
        if (settled.status === 'fulfilled') {
          reportData.contents[contentType] = settled.value.result;
        } else {
          console.error(`[REPORT] Promise rejected for ${contentType}:`, settled.reason);
          reportData.contents[contentType] = {
            error: settled.reason?.message || 'Unknown error',
            available: false,
          };
        }
      });
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
        return await analyticsService.generateInefficientUsage(buildingId, timeRange, interval, dashboardDiscoveryService, kpis);
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
