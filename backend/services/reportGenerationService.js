const Building = require('../models/Building');
const Room = require('../models/Room');
const Sensor = require('../models/Sensor');
const AlarmLog = require('../models/AlarmLog');
const Benchmark = require('../models/Benchmark');
const Site = require('../models/Site');
const dashboardDiscoveryService = require('./dashboardDiscoveryService');
const mongoose = require('mongoose');

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
        startDate = new Date(now);
        startDate.setUTCDate(startDate.getUTCDate() - 1);
        startDate.setUTCHours(0, 0, 0, 0);
        endDate = new Date(startDate);
        endDate.setUTCHours(23, 59, 59, 999);
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
    const { startDate, endDate } = timeRange;
    const { reportContents = [] } = reportConfig;

    // Get building data
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }

    // Generate base KPIs (used by multiple content types)
    const kpis = await dashboardDiscoveryService.getBuildingKPIs(buildingId, startDate, endDate);

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
        return this.generateTotalConsumption(kpis);
      case 'ConsumptionByRoom':
        return await this.generateConsumptionByRoom(buildingId, timeRange);
      case 'PeakLoads':
        return this.generatePeakLoads(kpis);
      case 'MeasurementTypeBreakdown':
        return this.generateMeasurementTypeBreakdown(kpis);
      case 'EUI':
        return this.generateEUI(building, kpis, timeRangeOption || timeRange);
      case 'PerCapitaConsumption':
        return this.generatePerCapitaConsumption(building, kpis);
      case 'BenchmarkComparison':
        return await this.generateBenchmarkComparison(building, kpis, timeRangeOption || timeRange);
      case 'InefficientUsage':
        return await this.generateInefficientUsage(buildingId, timeRange);
      case 'Anomalies':
        return await this.generateAnomalies(buildingId, timeRange);
      case 'PeriodComparison':
        return await this.generatePeriodComparison(buildingId, interval, timeRange);
      case 'TimeBasedAnalysis':
        return await this.generateTimeBasedAnalysis(buildingId, timeRange);
      case 'BuildingComparison':
        return await this.generateBuildingComparison(buildingId, timeRange);
      case 'TemperatureAnalysis':
        return await this.generateTemperatureAnalysis(buildingId, timeRange);
      case 'DataQualityReport':
        return this.generateDataQualityReport(kpis);
      default:
        throw new Error(`Unknown content type: ${contentType}`);
    }
  }

  /**
   * Generate Total Consumption content
   */
  generateTotalConsumption(kpis) {
    return {
      totalConsumption: kpis.total_consumption,
      unit: kpis.unit,
      average: kpis.average,
      peak: kpis.peak,
      base: kpis.base,
    };
  }

  /**
   * Generate Consumption By Room content
   */
  async generateConsumptionByRoom(buildingId, timeRange) {
    const { startDate, endDate } = timeRange;
    const rooms = await Room.find({ building_id: buildingId }).lean();
    
    const roomConsumption = [];
    for (const room of rooms) {
      try {
        const roomKPIs = await dashboardDiscoveryService.getRoomKPIs(room._id, startDate, endDate);
        roomConsumption.push({
          roomId: room._id.toString(),
          roomName: room.name,
          consumption: roomKPIs.total_consumption,
          unit: roomKPIs.unit,
          average: roomKPIs.average,
          peak: roomKPIs.peak,
        });
      } catch (error) {
        console.warn(`[REPORT] Error getting KPIs for room ${room._id}:`, error.message);
      }
    }

    // Sort by consumption descending
    roomConsumption.sort((a, b) => (b.consumption || 0) - (a.consumption || 0));

    return {
      rooms: roomConsumption,
      totalRooms: rooms.length,
    };
  }

  /**
   * Generate Peak Loads content
   */
  generatePeakLoads(kpis) {
    return {
      peak: kpis.peak,
      unit: kpis.unit === 'kWh' ? 'kW' : kpis.unit, // Peak is power, not energy
      average: kpis.average,
      peakToAverageRatio: kpis.average > 0 ? (kpis.peak / kpis.average).toFixed(2) : null,
    };
  }

  /**
   * Generate Measurement Type Breakdown content
   */
  generateMeasurementTypeBreakdown(kpis) {
    return {
      breakdown: kpis.breakdown || [],
      totalTypes: (kpis.breakdown || []).length,
    };
  }

  /**
   * Generate EUI (Energy Use Intensity) content
   * @param {Object} building - Building object
   * @param {Object} kpis - KPIs object
   * @param {Object} timeRange - Optional time range for normalization
   * @returns {Object} EUI data
   */
  generateEUI(building, kpis, timeRange = null) {
    const heatedArea = building.heated_building_area 
      ? parseFloat(building.heated_building_area.toString()) 
      : null;

    if (!heatedArea || heatedArea <= 0) {
      return {
        eui: null,
        unit: 'kWh/m²',
        available: false,
        message: 'Heated building area not configured',
      };
    }

    // Calculate EUI: total consumption / heated area
    const consumption = kpis.total_consumption || 0;
    
    // Calculate period-based EUI (not annualized - shows actual period EUI)
    const eui = consumption / heatedArea;

    // If timeRange is provided, also calculate annualized EUI for comparison
    let annualizedEUI = null;
    if (timeRange) {
      const days = (timeRange.endDate - timeRange.startDate) / (1000 * 60 * 60 * 24);
      if (days > 0) {
        const annualizedConsumption = (consumption / days) * 365;
        annualizedEUI = annualizedConsumption / heatedArea;
      }
    }

    return {
      eui: Math.round(eui * 100) / 100,
      annualizedEUI: annualizedEUI ? Math.round(annualizedEUI * 100) / 100 : null,
      unit: 'kWh/m²',
      totalConsumption: consumption,
      heatedArea: heatedArea,
      available: true,
    };
  }

  /**
   * Generate Per Capita Consumption content
   */
  generatePerCapitaConsumption(building, kpis) {
    const numPeople = building.num_students_employees;

    if (!numPeople || numPeople <= 0) {
      return {
        perCapita: null,
        unit: 'kWh/person',
        available: false,
        message: 'Number of people not configured',
      };
    }

    const consumption = kpis.total_consumption || 0;
    const perCapita = consumption / numPeople;

    return {
      perCapita: Math.round(perCapita * 100) / 100,
      unit: 'kWh/person',
      totalConsumption: consumption,
      numPeople: numPeople,
      available: true,
    };
  }

  /**
   * Generate Benchmark Comparison content
   * @param {Object} building - Building object
   * @param {Object} kpis - KPIs object
   * @param {Object} timeRange - Optional time range for annualization
   * @returns {Promise<Object>} Benchmark comparison data
   */
  async generateBenchmarkComparison(building, kpis, timeRange = null) {
    if (!building.type_of_use) {
      return {
        available: false,
        message: 'Building type of use not configured',
      };
    }

    const benchmark = await Benchmark.findOne({ type_of_use: building.type_of_use });
    if (!benchmark) {
      return {
        available: false,
        message: `No benchmark found for type: ${building.type_of_use}`,
      };
    }

    const heatedArea = building.heated_building_area 
      ? parseFloat(building.heated_building_area.toString()) 
      : null;

    if (!heatedArea || heatedArea <= 0) {
      return {
        available: false,
        message: 'Heated building area not configured',
      };
    }

    const consumption = kpis.total_consumption || 0;
    const targetEUI = parseFloat(benchmark.target_eui_kwh_m2_year.toString());
    
    // Calculate annualized EUI for comparison with benchmark (which is annual)
    let annualizedEUI = null;
    if (timeRange) {
      const days = (timeRange.endDate - timeRange.startDate) / (1000 * 60 * 60 * 24);
      if (days > 0) {
        const annualizedConsumption = (consumption / days) * 365;
        annualizedEUI = annualizedConsumption / heatedArea;
      }
    } else {
      // Fallback: use period EUI if timeRange not provided
      annualizedEUI = consumption / heatedArea;
    }

    if (!annualizedEUI) {
      return {
        available: false,
        message: 'Unable to calculate annualized EUI',
      };
    }

    const difference = annualizedEUI - targetEUI;
    const percentageDiff = targetEUI > 0 ? ((difference / targetEUI) * 100) : null;

    return {
      available: true,
      buildingEUI: Math.round(annualizedEUI * 100) / 100,
      targetEUI: Math.round(targetEUI * 100) / 100,
      difference: Math.round(difference * 100) / 100,
      percentageDifference: percentageDiff ? Math.round(percentageDiff * 100) / 100 : null,
      status: difference > 0 ? 'Above Target' : difference < 0 ? 'Below Target' : 'On Target',
      benchmarkSource: benchmark.source,
      typeOfUse: building.type_of_use,
    };
  }

  /**
   * Generate Inefficient Usage content
   */
  async generateInefficientUsage(buildingId, timeRange) {
    // This is a placeholder - actual implementation would analyze usage patterns
    // For now, return basic underutilization indicators
    const { startDate, endDate } = timeRange;
    const kpis = await dashboardDiscoveryService.getBuildingKPIs(buildingId, startDate, endDate);
    
    // Simple heuristic: if base load is very high compared to average, might indicate inefficiency
    const baseToAverageRatio = kpis.average > 0 ? (kpis.base / kpis.average) : null;
    const isInefficient = baseToAverageRatio && baseToAverageRatio > 0.7; // Base load > 70% of average

    return {
      baseLoad: kpis.base,
      averageLoad: kpis.average,
      baseToAverageRatio: baseToAverageRatio ? Math.round(baseToAverageRatio * 100) / 100 : null,
      inefficientUsageDetected: isInefficient,
      message: isInefficient 
        ? 'High base load detected - potential for optimization' 
        : 'Usage patterns appear normal',
    };
  }

  /**
   * Generate Anomalies content
   */
  async generateAnomalies(buildingId, timeRange) {
    const { startDate, endDate } = timeRange;
    
    // Get all sensors for this building
    const rooms = await Room.find({ building_id: buildingId }).select('_id').lean();
    const roomIds = rooms.map(r => r._id);
    const sensors = await Sensor.find({ room_id: { $in: roomIds } }).select('_id').lean();
    const sensorIds = sensors.map(s => s._id);

    if (sensorIds.length === 0) {
      return {
        total: 0,
        bySeverity: { High: 0, Medium: 0, Low: 0 },
        anomalies: [],
      };
    }

    // Query alarm logs for this building in the time range
    const alarms = await AlarmLog.find({
      sensor_id: { $in: sensorIds },
      timestamp_start: { $gte: startDate, $lte: endDate },
    })
      .populate('sensor_id', 'name room_id')
      .populate('alarm_rule_id', 'name')
      .sort({ timestamp_start: -1 })
      .lean();

    const bySeverity = { High: 0, Medium: 0, Low: 0 };
    alarms.forEach(alarm => {
      if (alarm.severity && bySeverity[alarm.severity] !== undefined) {
        bySeverity[alarm.severity]++;
      }
    });

    return {
      total: alarms.length,
      bySeverity,
      anomalies: alarms.slice(0, 20).map(alarm => ({
        timestamp: alarm.timestamp_start,
        sensorName: alarm.sensor_id?.name || 'Unknown',
        violatedRule: alarm.violatedRule || 'Unknown',
        severity: alarm.severity,
        value: alarm.value,
        status: alarm.status,
      })),
    };
  }

  /**
   * Generate Period Comparison content
   */
  async generatePeriodComparison(buildingId, interval, currentTimeRange) {
    // Calculate previous period time range
    const previousTimeRange = this.calculateTimeRange(interval, currentTimeRange.startDate);
    
    const currentKPIs = await dashboardDiscoveryService.getBuildingKPIs(
      buildingId,
      currentTimeRange.startDate,
      currentTimeRange.endDate
    );
    
    const previousKPIs = await dashboardDiscoveryService.getBuildingKPIs(
      buildingId,
      previousTimeRange.startDate,
      previousTimeRange.endDate
    );

    const consumptionDiff = currentKPIs.total_consumption - previousKPIs.total_consumption;
    const consumptionPercentChange = previousKPIs.total_consumption > 0
      ? ((consumptionDiff / previousKPIs.total_consumption) * 100)
      : null;

    return {
      current: {
        consumption: currentKPIs.total_consumption,
        average: currentKPIs.average,
        peak: currentKPIs.peak,
        period: {
          start: currentTimeRange.startDate,
          end: currentTimeRange.endDate,
        },
      },
      previous: {
        consumption: previousKPIs.total_consumption,
        average: previousKPIs.average,
        peak: previousKPIs.peak,
        period: {
          start: previousTimeRange.startDate,
          end: previousTimeRange.endDate,
        },
      },
      change: {
        consumption: Math.round(consumptionDiff * 100) / 100,
        consumptionPercent: consumptionPercentChange ? Math.round(consumptionPercentChange * 100) / 100 : null,
        average: Math.round((currentKPIs.average - previousKPIs.average) * 100) / 100,
        peak: Math.round((currentKPIs.peak - previousKPIs.peak) * 100) / 100,
      },
    };
  }

  /**
   * Generate Time Based Analysis content
   */
  async generateTimeBasedAnalysis(buildingId, timeRange) {
    const { startDate, endDate } = timeRange;
    const db = mongoose.connection.db;
    
    if (!db) {
      throw new Error('Database connection not available');
    }

    // Get measurements grouped by hour and day of week
    const matchStage = {
      'meta.buildingId': new mongoose.Types.ObjectId(buildingId),
      resolution_minutes: 60, // Use hourly data
      timestamp: { $gte: startDate, $lt: endDate },
      'meta.measurementType': 'Energy',
    };

    const pipeline = [
      { $match: matchStage },
      {
        $group: {
          _id: {
            hour: { $hour: '$timestamp' },
            dayOfWeek: { $dayOfWeek: '$timestamp' }, // 1=Sunday, 2=Monday, ..., 7=Saturday
          },
          consumption: { $sum: '$value' },
          count: { $sum: 1 },
        },
      },
      { $sort: { '_id.hour': 1, '_id.dayOfWeek': 1 } },
    ];

    const hourlyData = await db.collection('measurements').aggregate(pipeline).toArray();

    // Calculate day vs night (6 AM to 10 PM = day, 10 PM to 6 AM = night)
    let dayConsumption = 0;
    let nightConsumption = 0;
    let weekdayConsumption = 0; // Monday-Friday (2-6)
    let weekendConsumption = 0; // Saturday-Sunday (1, 7)

    hourlyData.forEach(item => {
      const hour = item._id.hour;
      const dayOfWeek = item._id.dayOfWeek;
      const consumption = item.consumption || 0;

      // Day/Night split
      if (hour >= 6 && hour < 22) {
        dayConsumption += consumption;
      } else {
        nightConsumption += consumption;
      }

      // Weekday/Weekend split
      if (dayOfWeek >= 2 && dayOfWeek <= 6) {
        weekdayConsumption += consumption;
      } else {
        weekendConsumption += consumption;
      }
    });

    return {
      dayNight: {
        day: Math.round(dayConsumption * 100) / 100,
        night: Math.round(nightConsumption * 100) / 100,
        dayPercentage: (dayConsumption + nightConsumption) > 0
          ? Math.round((dayConsumption / (dayConsumption + nightConsumption)) * 100)
          : null,
      },
      weekdayWeekend: {
        weekday: Math.round(weekdayConsumption * 100) / 100,
        weekend: Math.round(weekendConsumption * 100) / 100,
        weekdayPercentage: (weekdayConsumption + weekendConsumption) > 0
          ? Math.round((weekdayConsumption / (weekdayConsumption + weekendConsumption)) * 100)
          : null,
      },
      hourlyPattern: hourlyData.map(item => ({
        hour: item._id.hour,
        dayOfWeek: item._id.dayOfWeek,
        consumption: Math.round(item.consumption * 100) / 100,
      })),
    };
  }

  /**
   * Generate Building Comparison content
   */
  async generateBuildingComparison(buildingId, timeRange) {
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }

    // Get all buildings in the same site
    const buildings = await Building.find({ site_id: building.site_id }).lean();
    
    if (buildings.length <= 1) {
      return {
        available: false,
        message: 'Only one building in site - comparison not available',
      };
    }

    const { startDate, endDate } = timeRange;
    const buildingComparisons = [];

    for (const b of buildings) {
      try {
        const kpis = await dashboardDiscoveryService.getBuildingKPIs(b._id, startDate, endDate);
        buildingComparisons.push({
          buildingId: b._id.toString(),
          buildingName: b.name,
          consumption: kpis.total_consumption,
          average: kpis.average,
          peak: kpis.peak,
          eui: b.heated_building_area 
            ? Math.round((kpis.total_consumption / parseFloat(b.heated_building_area.toString())) * 100) / 100
            : null,
        });
      } catch (error) {
        console.warn(`[REPORT] Error getting KPIs for building ${b._id}:`, error.message);
      }
    }

    // Sort by consumption descending
    buildingComparisons.sort((a, b) => (b.consumption || 0) - (a.consumption || 0));

    return {
      available: true,
      buildings: buildingComparisons,
      totalBuildings: buildings.length,
    };
  }

  /**
   * Generate Temperature Analysis content
   */
  async generateTemperatureAnalysis(buildingId, timeRange) {
    const { startDate, endDate } = timeRange;
    
    // Get all temperature sensors for this building
    const rooms = await Room.find({ building_id: buildingId }).select('_id').lean();
    const roomIds = rooms.map(r => r._id);
    const sensors = await Sensor.find({ 
      room_id: { $in: roomIds },
      // Note: We'd need to identify temperature sensors - this is a simplified version
    }).select('_id name room_id').lean();

    if (sensors.length === 0) {
      return {
        available: false,
        message: 'No temperature sensors found',
      };
    }

    const db = mongoose.connection.db;
    if (!db) {
      throw new Error('Database connection not available');
    }

    const sensorIds = sensors.map(s => s._id);
    const matchStage = {
      'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
      'meta.measurementType': 'Temperature',
      resolution_minutes: 60, // Hourly
      timestamp: { $gte: startDate, $lt: endDate },
    };

    const pipeline = [
      { $match: matchStage },
      {
        $group: {
          _id: '$meta.sensorId',
          avgTemp: { $avg: '$value' },
          minTemp: { $min: '$value' },
          maxTemp: { $max: '$value' },
          count: { $sum: 1 },
        },
      },
    ];

    const tempData = await db.collection('measurements').aggregate(pipeline).toArray();
    
    // Map sensor IDs to sensor names
    const sensorMap = new Map(sensors.map(s => [s._id.toString(), s]));

    const temperatureAnalysis = tempData.map(item => {
      const sensor = sensorMap.get(item._id.toString());
      return {
        sensorId: item._id.toString(),
        sensorName: sensor?.name || 'Unknown',
        average: Math.round(item.avgTemp * 100) / 100,
        min: Math.round(item.minTemp * 100) / 100,
        max: Math.round(item.maxTemp * 100) / 100,
        unit: '°C',
      };
    });

    // Calculate overall statistics
    const allTemps = tempData.flatMap(item => [item.avgTemp, item.minTemp, item.maxTemp]);
    const overallAvg = allTemps.reduce((sum, t) => sum + t, 0) / allTemps.length;
    const overallMin = Math.min(...tempData.map(item => item.minTemp));
    const overallMax = Math.max(...tempData.map(item => item.maxTemp));

    return {
      available: true,
      sensors: temperatureAnalysis,
      overall: {
        average: Math.round(overallAvg * 100) / 100,
        min: Math.round(overallMin * 100) / 100,
        max: Math.round(overallMax * 100) / 100,
        unit: '°C',
      },
      totalSensors: sensors.length,
    };
  }

  /**
   * Generate Data Quality Report content
   */
  generateDataQualityReport(kpis) {
    return {
      averageQuality: kpis.average_quality,
      qualityWarning: kpis.data_quality_warning,
      status: kpis.average_quality >= 95 ? 'Excellent' 
        : kpis.average_quality >= 80 ? 'Good'
        : kpis.average_quality >= 60 ? 'Fair'
        : 'Poor',
      message: kpis.data_quality_warning
        ? 'Data quality issues detected - some measurements may be incomplete'
        : 'Data quality is good',
    };
  }
}

module.exports = new ReportGenerationService();
