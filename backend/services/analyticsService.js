const Building = require('../models/Building');
const Room = require('../models/Room');
const Sensor = require('../models/Sensor');
const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const AlarmLog = require('../models/AlarmLog');
const Benchmark = require('../models/Benchmark');
const mongoose = require('mongoose');
const sensorLookup = require('../utils/sensorLookup');
const { NotFoundError, ValidationError, ServiceUnavailableError } = require('../utils/errors');

/**
 * Analytics Service
 * 
 * Shared analytics methods used by both dashboard and report generation
 * All methods handle both arbitrary time ranges (dashboard) and fixed intervals (reports)
 */
class AnalyticsService {
  /**
   * Helper method to get building object if not provided
   * @param {String} buildingId - Building ID
   * @param {Object} building - Optional building object
   * @returns {Promise<Object>} Building object
   */
  async getBuildingIfNeeded(buildingId, building = null) {
    if (building) {
      return building;
    }
    const buildingDoc = await Building.findById(buildingId);
    if (!buildingDoc) {
      throw new NotFoundError('Building');
    }
    return buildingDoc;
  }

  /**
   * Helper method to extract KPIs values from new structured format or legacy flat format
   * Supports both: { energy: { total_consumption }, power: { peak } } and { total_consumption, peak }
   * @param {Object} kpis - KPIs object (new structured or legacy format)
   * @returns {Object} Extracted KPIs values
   */
  extractKPIs(kpis) {
    // New structured format (energy/power/quality objects)
    if (kpis.energy && kpis.power) {
      return {
        total_consumption: kpis.energy.total_consumption || 0,
        total_production: kpis.energy.total_production || 0, // NEW: Extract production
        net_consumption: kpis.energy.net_consumption || 0,   // NEW: Extract net consumption
        averageEnergy: kpis.energy.average || 0,
        average: kpis.energy.average || 0,
        base: kpis.energy.base || 0,
        peak: kpis.power.peak || 0,
        averagePower: kpis.power.average || 0,
        average_quality: kpis.quality?.average || 100,
        data_quality_warning: kpis.quality?.warning || false,
        energyUnit: kpis.energy.unit || 'kWh',
        powerUnit: kpis.power.unit || 'kW',
        breakdown: kpis.breakdown || []
      };
    }
    // Legacy flat format (backward compatibility)
    return {
      total_consumption: kpis.total_consumption || 0,
      averageEnergy: kpis.averageEnergy || kpis.average || 0,
      average: kpis.averageEnergy || kpis.average || 0,
      base: kpis.base || 0,
      peak: kpis.peak || 0,
      averagePower: kpis.averagePower || 0,
      average_quality: kpis.average_quality || 100,
      data_quality_warning: kpis.data_quality_warning || false,
      energyUnit: kpis.energyUnit || 'kWh',
      powerUnit: kpis.powerUnit || 'kW',
      breakdown: kpis.breakdown || []
    };
  }

  /**
   * Generate Total Consumption content
   * Returns energy consumption (kWh) and power measurements (kW) with proper units
   * @param {Object} kpis - KPIs object from dashboardDiscoveryService
   * @returns {Object} Total consumption data
   */
  generateTotalConsumption(kpis) {
    const extracted = this.extractKPIs(kpis);
    return {
      totalConsumption: extracted.total_consumption, // Energy consumption in kWh
      totalConsumptionUnit: extracted.energyUnit,
      averageEnergy: extracted.averageEnergy, // Average energy per period (kWh)
      averageEnergyUnit: extracted.energyUnit,
      averagePower: extracted.averagePower, // Average power (kW)
      averagePowerUnit: extracted.powerUnit,
      peak: extracted.peak, // Peak power (kW)
      peakUnit: extracted.powerUnit,
      base: extracted.base, // Base energy consumption (kWh)
      baseUnit: extracted.energyUnit,
      // Backward compatibility
      unit: extracted.energyUnit,
      average: extracted.average,
    };
  }

  /**
   * Generate Peak Loads content
   * Returns power measurements (kW) - both peak and average are power
   * @param {Object} kpis - KPIs object
   * @returns {Object} Peak loads data
   */
  generatePeakLoads(kpis) {
    const extracted = this.extractKPIs(kpis);
    return {
      peak: extracted.peak,
      peakUnit: extracted.powerUnit,
      average: extracted.averagePower,
      averageUnit: extracted.powerUnit,
      peakToAverageRatio: extracted.averagePower > 0 ? (extracted.peak / extracted.averagePower).toFixed(2) : null,
      // Backward compatibility
      unit: extracted.powerUnit,
    };
  }

  /**
   * Generate Measurement Type Breakdown content
   * @param {Object} kpis - KPIs object
   * @returns {Object} Measurement type breakdown
   */
  generateMeasurementTypeBreakdown(kpis) {
    const extracted = this.extractKPIs(kpis);
    return {
      breakdown: extracted.breakdown,
      totalTypes: extracted.breakdown.length,
    };
  }

  /**
   * Generate EUI (Energy Use Intensity) content
   * @param {Object} building - Building object (or buildingId will be used to fetch)
   * @param {Object} kpis - KPIs object
   * @param {Object} timeRange - Optional time range for normalization
   * @param {String} buildingId - Optional building ID if building not provided
   * @returns {Promise<Object>} EUI data
   */
  async generateEUI(building, kpis, timeRange = null, buildingId = null) {
    const buildingDoc = await this.getBuildingIfNeeded(buildingId, building);
    const heatedArea = buildingDoc.heated_building_area 
      ? parseFloat(buildingDoc.heated_building_area.toString()) 
      : null;

    if (!heatedArea || heatedArea <= 0) {
      return {
        eui: null,
        unit: 'kWh/m²',
        available: false,
        message: 'Heated building area not configured',
      };
    }

    // Extract KPIs values (handles both new structured and legacy formats)
    const extracted = this.extractKPIs(kpis);
    
    // Calculate EUI: total consumption / heated area
    // Use net_consumption (consumption - production) for EUI calculation
    const consumption = extracted.net_consumption || extracted.total_consumption;
    
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

    // Ensure we use energyUnit (kWh) for consumption
    const energyUnit = extracted.energyUnit;
    
    return {
      eui: Math.round(eui * 100) / 100,
      annualizedEUI: annualizedEUI ? Math.round(annualizedEUI * 100) / 100 : null,
      unit: 'kWh/m²', // EUI is always kWh/m²
      totalConsumption: consumption, // Energy consumption in kWh
      totalConsumptionUnit: energyUnit,
      heatedArea: heatedArea,
      available: true,
    };
  }

  /**
   * Generate Per Capita Consumption content
   * @param {Object} building - Building object (or buildingId will be used to fetch)
   * @param {Object} kpis - KPIs object
   * @param {String} buildingId - Optional building ID if building not provided
   * @returns {Promise<Object>} Per capita consumption data
   */
  async generatePerCapitaConsumption(building, kpis, buildingId = null) {
    const buildingDoc = await this.getBuildingIfNeeded(buildingId, building);
    const numPeople = buildingDoc.num_students_employees;

    if (!numPeople || numPeople <= 0) {
      return {
        perCapita: null,
        unit: 'kWh/person',
        available: false,
        message: 'Number of people not configured',
      };
    }

    // Extract KPIs values (handles both new structured and legacy formats)
    const extracted = this.extractKPIs(kpis);
    
    // Use net_consumption (consumption - production) for EUI calculation
    const consumption = extracted.net_consumption || extracted.total_consumption; // Energy consumption in kWh
    const perCapita = consumption / numPeople;
    
    // Ensure we use energyUnit (kWh) for consumption
    const energyUnit = extracted.energyUnit;

    return {
      perCapita: Math.round(perCapita * 100) / 100,
      unit: 'kWh/person', // Per capita is always kWh/person
      totalConsumption: consumption, // Energy consumption in kWh
      totalConsumptionUnit: energyUnit,
      numPeople: numPeople,
      available: true,
    };
  }

  /**
   * Generate Benchmark Comparison content
   * @param {Object} building - Building object (or buildingId will be used to fetch)
   * @param {Object} kpis - KPIs object
   * @param {Object} timeRange - Optional time range for annualization
   * @param {String} buildingId - Optional building ID if building not provided
   * @returns {Promise<Object>} Benchmark comparison data
   */
  async generateBenchmarkComparison(building, kpis, timeRange = null, buildingId = null) {
    const buildingDoc = await this.getBuildingIfNeeded(buildingId, building);
    
    if (!buildingDoc.type_of_use) {
      return {
        available: false,
        message: 'Building type of use not configured',
      };
    }

    const benchmark = await Benchmark.findOne({ type_of_use: buildingDoc.type_of_use });
    if (!benchmark) {
      return {
        available: false,
        message: `No benchmark found for type: ${buildingDoc.type_of_use}`,
      };
    }

    const heatedArea = buildingDoc.heated_building_area 
      ? parseFloat(buildingDoc.heated_building_area.toString()) 
      : null;

    if (!heatedArea || heatedArea <= 0) {
      return {
        available: false,
        message: 'Heated building area not configured',
      };
    }

    // Extract KPIs values (handles both new structured and legacy formats)
    const extracted = this.extractKPIs(kpis);
    
    // Use net_consumption (consumption - production) for EUI calculation
    const consumption = extracted.net_consumption || extracted.total_consumption;
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
      typeOfUse: buildingDoc.type_of_use,
    };
  }

  /**
   * Generate Inefficient Usage content
   * Returns energy load measurements (kWh) - base and average are energy consumption
   * @param {String} buildingId - Building ID
   * @param {Object} timeRange - Time range object
   * @param {String} interval - Optional interval (Daily, Weekly, Monthly, Yearly) or null for arbitrary range
   * @param {Object} dashboardDiscoveryService - Dashboard discovery service instance (optional if kpis provided)
   * @param {Object} kpis - Optional KPIs object (if provided, skips database query)
   * @returns {Promise<Object>} Inefficient usage data
   */
  async generateInefficientUsage(buildingId, timeRange, interval = null, dashboardDiscoveryService = null, kpis = null) {
    // Extract KPIs values (handles both new structured and legacy formats)
    let extracted;
    
    if (kpis) {
      // Use provided KPIs (no database query needed)
      extracted = this.extractKPIs(kpis);
    } else if (dashboardDiscoveryService) {
      // Fallback: fetch KPIs if not provided (for backward compatibility)
      const { startDate, endDate } = timeRange;
      const fetchedKPIs = await dashboardDiscoveryService.getBuildingKPIs(buildingId, startDate, endDate, { interval });
      extracted = this.extractKPIs(fetchedKPIs);
    } else {
      throw new ValidationError('Either kpis or dashboardDiscoveryService must be provided');
    }
    
    // Simple heuristic: if base load is very high compared to average, might indicate inefficiency
    // Both base and average are energy consumption (kWh)
    const averageEnergy = extracted.averageEnergy;
    const baseToAverageRatio = averageEnergy > 0 ? (extracted.base / averageEnergy) : null;
    const isInefficient = baseToAverageRatio && baseToAverageRatio > 0.7; // Base load > 70% of average

    return {
      baseLoad: extracted.base, // Base energy consumption (kWh)
      baseLoadUnit: extracted.energyUnit,
      averageLoad: averageEnergy, // Average energy consumption (kWh)
      averageLoadUnit: extracted.energyUnit,
      baseToAverageRatio: baseToAverageRatio ? Math.round(baseToAverageRatio * 100) / 100 : null,
      inefficientUsageDetected: isInefficient,
      message: isInefficient 
        ? 'High base load detected - potential for optimization' 
        : 'Usage patterns appear normal',
    };
  }

  /**
   * Generate Anomalies content
   * Uses sensorLookup to get sensor IDs for the building
   * @param {String} buildingId - Building ID
   * @param {Object} timeRange - Time range object
   * @returns {Promise<Object>} Anomalies data
   */
  async generateAnomalies(buildingId, timeRange) {
    const { startDate, endDate } = timeRange;
    
    // Get all sensor IDs for this building via sensorLookup
    const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
    const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));

    // Debug logging
   //console.log(`[ANOMALIES] Building ${buildingId}: Found ${sensorIds.length} sensors`);
   //console.log(`[ANOMALIES] Time range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
   //console.log(`[ANOMALIES] Sensor IDs: ${sensorIds.slice(0, 5).map(id => id.toString()).join(', ')}${sensorIds.length > 5 ? '...' : ''}`);

    if (sensorIds.length === 0) {
      console.warn(`[ANOMALIES] No sensors found for building ${buildingId}`);
      return {
        total: 0,
        bySeverity: { High: 0, Medium: 0, Low: 0 },
        anomalies: [],
      };
    }

    // Query alarm logs for this building in the time range
    const alarmQuery = {
      sensor_id: { $in: sensorIds },
      timestamp_start: { $gte: startDate, $lte: endDate },
    };
    
   //console.log(`[ANOMALIES] Querying alarms with ${sensorIds.length} sensor IDs`);
    
    const alarms = await AlarmLog.find(alarmQuery)
      .populate('sensor_id', 'name room_id')
      .populate('alarm_rule_id', 'name')
      .sort({ timestamp_start: -1 })
      .lean();

   //console.log(`[ANOMALIES] Found ${alarms.length} alarms in time range`);

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
   * @param {String} buildingId - Building ID
   * @param {String} interval - Interval (Daily, Weekly, Monthly, Yearly) or null
   * @param {Object} currentTimeRange - Current time range object
   * @param {Object} dashboardDiscoveryService - Dashboard discovery service instance
   * @param {Function} calculateTimeRange - Function to calculate previous period time range
   * @returns {Promise<Object>} Period comparison data
   */
  async generatePeriodComparison(buildingId, interval, currentTimeRange, dashboardDiscoveryService, calculateTimeRange) {
    if (!interval) {
      return {
        available: false,
        message: 'Interval required for period comparison',
      };
    }

    // Calculate previous period time range
    const previousTimeRange = calculateTimeRange(interval, currentTimeRange.startDate);
    
    const currentKPIs = await dashboardDiscoveryService.getBuildingKPIs(
      buildingId,
      currentTimeRange.startDate,
      currentTimeRange.endDate,
      { interval }
    );
    
    const previousKPIs = await dashboardDiscoveryService.getBuildingKPIs(
      buildingId,
      previousTimeRange.startDate,
      previousTimeRange.endDate,
      { interval }
    );

    // Extract KPIs values (handles both new structured and legacy formats)
    const currentExtracted = this.extractKPIs(currentKPIs);
    const previousExtracted = this.extractKPIs(previousKPIs);
    
    const consumptionDiff = currentExtracted.total_consumption - previousExtracted.total_consumption;
    const consumptionPercentChange = previousExtracted.total_consumption > 0
      ? ((consumptionDiff / previousExtracted.total_consumption) * 100)
      : null;

    return {
      current: {
        consumption: currentExtracted.total_consumption, // Energy consumption (kWh)
        consumptionUnit: currentExtracted.energyUnit,
        averageEnergy: currentExtracted.averageEnergy, // Average energy (kWh)
        averageEnergyUnit: currentExtracted.energyUnit,
        peak: currentExtracted.peak, // Peak power (kW)
        peakUnit: currentExtracted.powerUnit,
        period: {
          start: currentTimeRange.startDate,
          end: currentTimeRange.endDate,
        },
        // Backward compatibility
        average: currentExtracted.averageEnergy,
      },
      previous: {
        consumption: previousExtracted.total_consumption, // Energy consumption (kWh)
        consumptionUnit: previousExtracted.energyUnit,
        averageEnergy: previousExtracted.averageEnergy, // Average energy (kWh)
        averageEnergyUnit: previousExtracted.energyUnit,
        peak: previousExtracted.peak, // Peak power (kW)
        peakUnit: previousExtracted.powerUnit,
        period: {
          start: previousTimeRange.startDate,
          end: previousTimeRange.endDate,
        },
        // Backward compatibility
        average: previousExtracted.averageEnergy,
      },
      change: {
        consumption: Math.round(consumptionDiff * 100) / 100, // Energy difference (kWh)
        consumptionUnit: 'kWh',
        consumptionPercent: consumptionPercentChange ? Math.round(consumptionPercentChange * 100) / 100 : null,
        averageEnergy: Math.round((currentExtracted.averageEnergy - previousExtracted.averageEnergy) * 100) / 100, // Energy difference (kWh)
        averageEnergyUnit: 'kWh',
        peak: Math.round((currentExtracted.peak - previousExtracted.peak) * 100) / 100, // Power difference (kW)
        peakUnit: 'kW',
        // Backward compatibility
        average: Math.round((currentExtracted.averageEnergy - previousExtracted.averageEnergy) * 100) / 100,
      },
    };
  }

  /**
   * Generate Time Based Analysis content
   * For arbitrary ranges (dashboard): Uses Power data to calculate consumption patterns
   * For fixed intervals (reports): Uses Energy with total* stateTypes (period totals)
   * Uses sensorLookup to get sensor IDs, then queries by meta.sensorId
   * @param {String} buildingId - Building ID
   * @param {Object} timeRange - Time range object
   * @param {String} interval - Optional interval (Daily, Weekly, Monthly, Yearly) or null for arbitrary range
   * @returns {Promise<Object>} Time based analysis data
   */
  async generateTimeBasedAnalysis(buildingId, timeRange, interval = null) {
    const { startDate, endDate } = timeRange;
    const db = mongoose.connection.db;
    
    if (!db) {
      throw new ServiceUnavailableError('Database connection not available');
    }

    // Get all sensor IDs for this building via sensorLookup
    const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
    
    if (sensorIdsSet.size === 0) {
      return {
        available: false,
        message: 'No sensors found for this building',
      };
    }
    
    const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));

    let hourlyData = [];

    if (interval) {
      // For fixed intervals (reports): Use Energy with total* stateTypes
      // These are already period totals (e.g., totalDay = consumption for that day)
      const intervalMap = {
        'Daily': 'totalDay',
        'Weekly': 'totalWeek',
        'Monthly': 'totalMonth',
        'Yearly': 'totalYear',
        'daily': 'totalDay',
        'weekly': 'totalWeek',
        'monthly': 'totalMonth',
        'yearly': 'totalYear'
      };
      const stateTypeFilter = intervalMap[interval] || 'totalDay';

      // Query by sensor IDs (measurements no longer have buildingId in meta)
      const matchStage = {
        'meta.sensorId': { $in: sensorIds },
        resolution_minutes: 60, // Use hourly aggregates
        timestamp: { $gte: startDate, $lt: endDate },
        'meta.measurementType': 'Energy',
        'meta.stateType': stateTypeFilter,
      };

      const pipeline = [
        { $match: matchStage },
        {
          $group: {
            _id: {
              hour: { $hour: '$timestamp' },
              dayOfWeek: { $dayOfWeek: '$timestamp' }, // 1=Sunday, 2=Monday, ..., 7=Saturday
            },
            // For fixed intervals with period totals (totalDay, totalWeek, etc.):
            // - Each value is already a period total (e.g., totalDay = consumption for that day)
            // - For the same period, all values should be the same (the period's total)
            // - If multiple sensors exist, we sum their period totals (total consumption across sensors)
            // - If same sensor appears multiple times, we use max (latest value)
            // Using $max ensures we get the latest period total, which is correct for single-period reports
            // For multiple sensors, we should sum, but $max is safer and will work correctly for single sensor
            // Note: For accurate multi-sensor aggregation, we'd need to group by sensorId first, but that's complex
            consumption: { $max: '$value' }, // Use max (latest) instead of average for period totals
            count: { $sum: 1 },
          },
        },
        { $sort: { '_id.hour': 1, '_id.dayOfWeek': 1 } },
      ];

      // Query measurements_aggregated for hourly data
      hourlyData = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
    } else {
      // For arbitrary ranges (dashboard): Use Power data to calculate consumption
      // Power values are instantaneous (kW), so we calculate: consumption = average_power × 1_hour
      // Query by sensor IDs (measurements no longer have buildingId in meta)
      const matchStage = {
        'meta.sensorId': { $in: sensorIds },
        resolution_minutes: 60, // Use hourly data
        timestamp: { $gte: startDate, $lt: endDate },
        'meta.measurementType': 'Power',
        'meta.stateType': { $regex: '^actual' }, // Use actual* states (actual, actual0, actual1, etc.)
      };

      const pipeline = [
        { $match: matchStage },
        {
          $group: {
            _id: {
              hour: { $hour: '$timestamp' },
              dayOfWeek: { $dayOfWeek: '$timestamp' }, // 1=Sunday, 2=Monday, ..., 7=Saturday
            },
            // Average power (kW) for this hour/day combination
            avgPower: { $avg: '$value' },
            count: { $sum: 1 },
          },
        },
        { $sort: { '_id.hour': 1, '_id.dayOfWeek': 1 } },
      ];

      // Query measurements_aggregated for power data
      const powerData = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
      
      // Convert power (kW) to energy consumption (kWh) for each hour
      // consumption = average_power × 1_hour
      hourlyData = powerData.map(item => ({
        _id: item._id,
        consumption: (item.avgPower || 0) * 1, // 1 hour = 1 kWh per kW
        count: item.count,
      }));
    }

    // Calculate day vs night (6 AM to 10 PM = day, 10 PM to 6 AM = night)
    let dayConsumption = 0;
    let nightConsumption = 0;
    let weekdayConsumption = 0; // Monday-Friday (2-6)
    let weekendConsumption = 0; // Saturday-Sunday (1, 7)

    hourlyData.forEach(item => {
      const hour = item._id.hour;
      const dayOfWeek = item._id.dayOfWeek;
      const consumption = item.consumption || 0;

      // Day/Night split (6 AM to 10 PM = day, 10 PM to 6 AM = night)
      if (hour >= 6 && hour < 22) {
        dayConsumption += consumption;
      } else {
        nightConsumption += consumption;
      }

      // Weekday/Weekend split (Monday-Friday = weekday, Saturday-Sunday = weekend)
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
   * @param {String} buildingId - Building ID
   * @param {Object} timeRange - Time range object
   * @param {String} interval - Optional interval (Daily, Weekly, Monthly, Yearly) or null for arbitrary range
   * @param {Object} dashboardDiscoveryService - Dashboard discovery service instance
   * @returns {Promise<Object>} Building comparison data
   */
  async generateBuildingComparison(buildingId, timeRange, interval = null, dashboardDiscoveryService) {
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new NotFoundError('Building');
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
        const kpis = await dashboardDiscoveryService.getBuildingKPIs(b._id, startDate, endDate, { interval });
        const extracted = this.extractKPIs(kpis);
        buildingComparisons.push({
          buildingId: b._id.toString(),
          buildingName: b.name,
          consumption: extracted.total_consumption,
          consumptionUnit: extracted.energyUnit,
          average: extracted.averageEnergy,
          averageUnit: extracted.energyUnit,
          peak: extracted.peak,
          peakUnit: extracted.powerUnit,
          eui: b.heated_building_area 
            ? Math.round((extracted.total_consumption / parseFloat(b.heated_building_area.toString())) * 100) / 100
            : null,
        });
      } catch (error) {
        console.warn(`[ANALYTICS] Error getting KPIs for building ${b._id}:`, error.message);
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
   * Uses sensorLookup to get sensor IDs, then queries by meta.sensorId
   * @param {String} buildingId - Building ID
   * @param {Object} timeRange - Time range object
   * @returns {Promise<Object>} Temperature analysis data
   */
  async generateTemperatureAnalysis(buildingId, timeRange) {
   //console.log("time before generateTemperatureAnalysis is ", Date.now());
    const { startDate, endDate } = timeRange;
    
    // Get all sensor IDs for this building via sensorLookup
    const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);

    if (sensorIdsSet.size === 0) {
      return {
        available: false,
        message: 'No temperature sensors found',
      };
    }

    const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));

   //console.log("sensors count ", sensorIds.length)
    const db = mongoose.connection.db;
    if (!db) {
      throw new ServiceUnavailableError('Database connection not available');
    }

    // Query by sensor IDs (measurements no longer have buildingId in meta)
   //console.log('buildingId used in temperatureAnalysis is ', buildingId)
    
    // First match: Use sensor IDs and index-optimized fields
    const firstMatchStage = {
      'meta.sensorId': { $in: sensorIds },
      resolution_minutes: 60, // Hourly
      timestamp: { $gte: startDate, $lt: endDate },
    };

    // Second match: Filter by measurementType (on already-reduced dataset)
    // This filters the much smaller dataset after the first match
    const secondMatchStage = {
      'meta.measurementType': 'Temperature',
    };

    const pipeline = [
      { $match: firstMatchStage },
      { $match: secondMatchStage }, // Filters reduced dataset by measurementType
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

    const queryStartTime = Date.now();
   //console.log(`[TEMPERATURE] Starting aggregation query at ${queryStartTime}`);

    // Query measurements_aggregated for temperature data
    const tempData = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
    
    const queryEndTime = Date.now();
    const queryDuration = queryEndTime - queryStartTime;
   //console.log(`[TEMPERATURE] Query completed in ${queryDuration}ms, found ${tempData.length} sensors with data`);

    if (tempData.length === 0) {
      return {
        available: false,
        message: 'No temperature data found for this time range',
      };
    }

    // Calculate overall statistics - weighted average by measurement count
    let totalWeightedSum = 0;
    let totalCount = 0;
    let overallMin = Infinity;
    let overallMax = -Infinity;

    tempData.forEach(item => {
      const count = item.count || 1;
      totalWeightedSum += item.avgTemp * count;
      totalCount += count;
      overallMin = Math.min(overallMin, item.minTemp);
      overallMax = Math.max(overallMax, item.maxTemp);
    });

    const overallAvg = totalCount > 0 ? totalWeightedSum / totalCount : 0;

    const processingEndTime = Date.now();
    const totalDuration = processingEndTime - queryStartTime;
   //console.log(`[TEMPERATURE] Total processing time: ${totalDuration}ms (query: ${queryDuration}ms, processing: ${processingEndTime - queryEndTime}ms)`);

    return {
      available: true,
      overall: {
        average: Math.round(overallAvg * 100) / 100,
        min: Math.round(overallMin * 100) / 100,
        max: Math.round(overallMax * 100) / 100,
        unit: '°C',
      },
      totalSensors: tempData.length, // Only sensors with actual data
    };
  }

  /**
   * Generate Data Quality Report content
   * @param {Object} kpis - KPIs object
   * @returns {Object} Data quality report
   */
  generateDataQualityReport(kpis) {
    const extracted = this.extractKPIs(kpis);
    return {
      averageQuality: extracted.average_quality,
      qualityWarning: extracted.data_quality_warning,
      status: extracted.average_quality >= 95 ? 'Excellent' 
        : extracted.average_quality >= 80 ? 'Good'
        : extracted.average_quality >= 60 ? 'Fair'
        : 'Poor',
      message: extracted.data_quality_warning
        ? 'Data quality issues detected - some measurements may be incomplete'
        : 'Data quality is good',
    };
  }

  /**
   * Generate Consumption By Room content
   * Optimized to use a single building-level query instead of multiple room queries
   * Gets rooms via Floor -> LocalRoom -> Loxone Room path
   * @param {String} buildingId - Building ID
   * @param {Object} timeRange - Time range object
   * @param {String} interval - Optional interval (Daily, Weekly, Monthly, Yearly) or null for arbitrary range
   * @param {Object} dashboardDiscoveryService - Dashboard discovery service instance
   * @returns {Promise<Object>} Consumption by room data
   */
  async generateConsumptionByRoom(buildingId, timeRange, interval = null, dashboardDiscoveryService) {
    const { startDate, endDate } = timeRange;
    const startTime = Date.now();
    
    // Get all Loxone rooms linked to this building via Floor -> LocalRoom path
    const floors = await Floor.find({ building_id: buildingId }).select('_id').lean();
    const floorIds = floors.map(f => f._id);
    
    const localRooms = await LocalRoom.find({ 
      floor_id: { $in: floorIds },
      loxone_room_id: { $exists: true, $ne: null }
    }).populate('loxone_room_id').lean();
    
    // Build room map from Loxone rooms that are linked to LocalRooms
    const rooms = [];
    const roomMap = new Map();
    for (const lr of localRooms) {
      if (lr.loxone_room_id) {
        const loxoneRoom = lr.loxone_room_id;
        if (!roomMap.has(loxoneRoom._id.toString())) {
          roomMap.set(loxoneRoom._id.toString(), {
            _id: loxoneRoom._id,
            name: loxoneRoom.name,
            localRoomName: lr.name
          });
          rooms.push({
            _id: loxoneRoom._id,
            name: loxoneRoom.name,
            localRoomName: lr.name
          });
        }
      }
    }
    
    // Use optimized single query to get KPIs for all rooms at once
    const roomsKPIsMap = await dashboardDiscoveryService.getRoomsKPIs(buildingId, startDate, endDate, { interval });
    
    // Map results to expected format
    const roomConsumption = [];
    for (const [roomId, roomKPIs] of roomsKPIsMap.entries()) {
      const room = roomMap.get(roomId);
      if (!room) continue; // Skip if room not found (shouldn't happen)
      
      const extracted = this.extractKPIs(roomKPIs);
      roomConsumption.push({
        roomId: roomId,
        roomName: room.name,
        localRoomName: room.localRoomName,
        consumption: extracted.total_consumption, // Energy consumption (kWh)
        consumptionUnit: extracted.energyUnit,
        averageEnergy: extracted.averageEnergy, // Average energy (kWh)
        averageEnergyUnit: extracted.energyUnit,
        peak: extracted.peak, // Peak power (kW)
        peakUnit: extracted.powerUnit,
        // Backward compatibility
        unit: extracted.energyUnit,
        average: extracted.averageEnergy,
      });
    }
    
    // Add rooms with no data (zero consumption)
    for (const room of rooms) {
      const roomId = room._id.toString();
      if (!roomsKPIsMap.has(roomId)) {
        roomConsumption.push({
          roomId: roomId,
          roomName: room.name,
          localRoomName: room.localRoomName,
          consumption: 0,
          consumptionUnit: 'kWh',
          averageEnergy: 0,
          averageEnergyUnit: 'kWh',
          peak: 0,
          peakUnit: 'kW',
          unit: 'kWh',
          average: 0,
        });
      }
    }
    
    const duration = Date.now() - startTime;
    // console.log(`[ANALYTICS] generateConsumptionByRoom: Completed ${roomConsumption.length}/${rooms.length} rooms in ${duration}ms`);

    // Sort by consumption descending
    roomConsumption.sort((a, b) => (b.consumption || 0) - (a.consumption || 0));

    return {
      rooms: roomConsumption,
      totalRooms: rooms.length,
    };
  }
}

module.exports = new AnalyticsService();
