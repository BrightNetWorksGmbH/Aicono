const mongoose = require('mongoose');
const Site = require('../models/Site');
const Building = require('../models/Building');
const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const Room = require('../models/Room');
const Sensor = require('../models/Sensor');
const UserRole = require('../models/UserRole');
const User = require('../models/User');
const measurementQueryService = require('./measurementQueryService');
const analyticsService = require('./analyticsService');
const sensorLookup = require('../utils/sensorLookup');
const { NotFoundError, ValidationError, AuthorizationError, ServiceUnavailableError } = require('../utils/errors');

/**
 * Unit normalization helper functions
 * Convert all units to a standard base unit for aggregation
 */
const unitNormalizers = {
    // Energy units: convert to kWh
    'Wh': (value) => value / 1000,  // Wh → kWh
    'kWh': (value) => value,         // kWh (base unit)
    'MWh': (value) => value * 1000,  // MWh → kWh
    
    // Power units: convert to kW
    'W': (value) => value / 1000,    // W → kW
    'kW': (value) => value,          // kW (base unit)
    'MW': (value) => value * 1000,   // MW → kW
    
    // Volume units: convert to m³ (for gas/water)
    'L': (value) => value / 1000,    // L → m³
    'l': (value) => value / 1000,    // l → m³
    'm³': (value) => value,          // m³ (base unit)
    'm^3': (value) => value,         // m^3 → m³
    
    // Temperature: no conversion needed (use as-is)
    '°C': (value) => value,
    '°F': (value) => (value - 32) * 5/9,  // °F → °C
    
    // Default: return as-is
    '': (value) => value
};

/**
 * Normalize value to base unit
 * @param {Number} value - Value to normalize
 * @param {String} unit - Source unit
 * @returns {Number} Normalized value
 */
function normalizeToBaseUnit(value, unit) {
    if (value === null || value === undefined || isNaN(value)) {
        return 0;
    }
    
    const unitKey = (unit || '').trim();
    const normalizer = unitNormalizers[unitKey];
    
    if (normalizer) {
        return normalizer(value);
    }
    
    // Try case-insensitive match
    const unitLower = unitKey.toLowerCase();
    for (const [key, fn] of Object.entries(unitNormalizers)) {
        if (key.toLowerCase() === unitLower) {
            return fn(value);
        }
    }
    
    // Unknown unit - return as-is
    return value;
}

/**
 * Get base unit for measurement type
 * @param {String} measurementType - Measurement type (Energy, Power, Temperature, etc.)
 * @returns {String} Base unit
 */
function getBaseUnit(measurementType) {
    const baseUnits = {
        'Energy': 'kWh',
        'Power': 'kW',
        'Temperature': '°C',
        'Water': 'm³',
        'Heating': 'm³',
        'Gas': 'm³'
    };
    return baseUnits[measurementType] || '';
}

/**
 * Get appropriate stateType for Energy measurements based on report interval
 * Maps report intervals to corresponding total* stateTypes from Loxone
 * @param {String} interval - Report interval: 'Daily', 'Weekly', 'Monthly', 'Yearly', or null for arbitrary range
 * @returns {String|null} StateType to use for Energy queries, or null if interval doesn't map to a total* state
 */
function getStateTypeForInterval(interval) {
    if (!interval) {
        return null; // Arbitrary range - use Power aggregation method instead
    }
    
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
    
    return intervalMap[interval] || null;
}

/**
 * Helper: Round date to start of day (UTC)
 * @param {Date} date - Date to round
 * @returns {Date} Start of day
 */
function roundToDayStart(date) {
    const d = new Date(date);
    d.setUTCHours(0, 0, 0, 0);
    return d;
}

/**
 * Helper: Round date to start of week (UTC, Monday as first day)
 * @param {Date} date - Date to round
 * @returns {Date} Start of week (Monday)
 */
function roundToWeekStart(date) {
    const d = new Date(date);
    const dayOfWeek = (d.getUTCDay() + 6) % 7; // Monday is 0, Sunday is 6
    d.setUTCDate(d.getUTCDate() - dayOfWeek);
    d.setUTCHours(0, 0, 0, 0);
    return d;
}

/**
 * Helper: Round date to start of month (UTC)
 * @param {Date} date - Date to round
 * @returns {Date} Start of month
 */
function roundToMonthStart(date) {
    const d = new Date(date);
    d.setUTCDate(1);
    d.setUTCHours(0, 0, 0, 0);
    return d;
}

/**
 * Helper: Round date to start of year (UTC)
 * @param {Date} date - Date to round
 * @returns {Date} Start of year
 */
function roundToYearStart(date) {
    const d = new Date(date);
    d.setUTCMonth(0, 1);
    d.setUTCHours(0, 0, 0, 0);
    return d;
}

/**
 * Helper: Check if date is at start of day (00:00:00)
 * @param {Date} date - Date to check
 * @returns {boolean} True if at start of day
 */
function isStartOfDay(date) {
    return date.getUTCHours() === 0 && date.getUTCMinutes() === 0 && date.getUTCSeconds() === 0;
}

/**
 * Helper: Check if date is at end of day (00:00:00 next day)
 * @param {Date} date - Date to check
 * @returns {boolean} True if at end of day (start of next day)
 */
function isEndOfDay(date) {
    return isStartOfDay(date);
}

/**
 * Helper: Get the value just before a timestamp from sorted timestamp/value pairs
 * @param {Array} timestampValuePairs - Array of { timestamp, value } objects, sorted by timestamp
 * @param {Date} targetTimestamp - Target timestamp
 * @returns {number|null} Value just before target, or null if not found
 */
function getValueJustBefore(timestampValuePairs, targetTimestamp) {
    // Find the last value with timestamp < targetTimestamp
    let lastValue = null;
    for (const pair of timestampValuePairs) {
        if (pair.timestamp < targetTimestamp) {
            lastValue = pair.value;
        } else {
            break;
        }
    }
    return lastValue;
}

/**
 * Helper: Get the value at or just before a timestamp from sorted timestamp/value pairs
 * @param {Array} timestampValuePairs - Array of { timestamp, value } objects, sorted by timestamp
 * @param {Date} targetTimestamp - Target timestamp
 * @returns {number|null} Value at or just before target, or null if not found
 */
function getValueAtOrBefore(timestampValuePairs, targetTimestamp) {
    // Find the last value with timestamp <= targetTimestamp
    let lastValue = null;
    for (const pair of timestampValuePairs) {
        if (pair.timestamp <= targetTimestamp) {
            lastValue = pair.value;
        } else {
            break;
        }
    }
    return lastValue;
}

/**
 * Helper: Get the latest value from sorted timestamp/value pairs
 * @param {Array} timestampValuePairs - Array of { timestamp, value } objects, sorted by timestamp
 * @returns {number|null} Latest value, or null if empty
 */
function getLatestValue(timestampValuePairs) {
    if (timestampValuePairs.length === 0) return null;
    return timestampValuePairs[timestampValuePairs.length - 1].value;
}

/**
 * Helper: Group timestamp/value pairs by period (day/week/month/year)
 * @param {Array} timestampValuePairs - Array of { timestamp, value } objects
 * @param {String} periodType - 'day', 'week', 'month', or 'year'
 * @returns {Map} Map of period key -> array of { timestamp, value } pairs
 */
function groupByPeriod(timestampValuePairs, periodType) {
    const groups = new Map();
    
    for (const pair of timestampValuePairs) {
        let periodKey;
        const date = new Date(pair.timestamp);
        
        if (periodType === 'day') {
            periodKey = roundToDayStart(date).toISOString();
        } else if (periodType === 'week') {
            periodKey = roundToWeekStart(date).toISOString();
        } else if (periodType === 'month') {
            periodKey = roundToMonthStart(date).toISOString();
        } else if (periodType === 'year') {
            periodKey = roundToYearStart(date).toISOString();
        } else {
            continue;
        }
        
        if (!groups.has(periodKey)) {
            groups.set(periodKey, []);
        }
        groups.get(periodKey).push(pair);
    }
    
    return groups;
}

/**
 * Helper: Query Energy data with fallback to smaller resolutions if preferred resolution has no data
 * @param {Object} db - MongoDB database connection
 * @param {Object} matchStage - Base match stage (without resolution, must include meta.sensorId or meta.sensorId with $in)
 * @param {Number} preferredResolution - Preferred resolution to try first
 * @param {String} stateType - StateType to query for
 * @param {Date} startDate - Start date for diagnostic query
 * @param {Date} endDate - End date for diagnostic query
 * @returns {Promise<Array>} Query results (from preferred or fallback resolution)
 */
async function queryEnergyWithFallback(db, matchStage, preferredResolution, stateType, startDate, endDate) {
    const baseMatch = {
        ...matchStage,
        'meta.measurementType': 'Energy',
        'meta.stateType': stateType,
        resolution_minutes: preferredResolution,
        timestamp: { $gte: startDate, $lt: endDate }
    };
    
    const pipeline = [
        { $match: baseMatch },
        {
            $group: {
                _id: {
                    measurementType: '$meta.measurementType',
                    stateType: '$meta.stateType',
                    unit: '$unit'
                },
                timestampValuePairs: {
                    $push: {
                        timestamp: '$timestamp',
                        value: '$value',
                        sensorId: '$meta.sensorId'  // Include sensorId for multi-sensor aggregation
                    }
                },
                values: { $push: '$value' },
                units: { $first: '$unit' },
                avgQuality: { $avg: '$quality' },
                count: { $sum: 1 }
            }
        }
    ];
    
    let results = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
    
    // If no results, check what resolutions are available and fallback to smaller ones
    if (results.length === 0) {
        // Diagnostic query to find available resolutions
        const diagnosticMatch = {
            ...matchStage,
            'meta.measurementType': 'Energy',
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const diagnosticPipeline = [
            { $match: diagnosticMatch },
            {
                $group: {
                    _id: {
                        stateType: '$meta.stateType',
                        resolution: '$resolution_minutes'
                    },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const diagnosticResults = await db.collection('measurements_aggregated').aggregate(diagnosticPipeline).toArray();
        
        // Find available resolutions for the requested stateType
        const availableResolutions = diagnosticResults
            .filter(r => r._id.stateType === stateType)
            .map(r => r._id.resolution);
        
        // Try fallback resolutions in descending order (larger aggregates first, then smaller/finer)
        // Strategy: If preferred resolution not found, try larger aggregates first (in case they exist),
        // then try smaller/finer aggregates (which will always have the data we need)
        // Order: 43200 (monthly) → 10080 (weekly) → 1440 (daily) → 60 (hourly) → 15 (15-minute)
        // Example: If looking for daily (1440) and not found, try weekly (10080) first, then hourly (60)
        // Example: If looking for weekly (10080) and not found, try daily (1440), then hourly (60)
        const resolutionPriority = [43200, 10080, 1440, 60, 15]; // All possible resolutions in descending order
        
        // Filter available resolutions (excluding preferred) and sort by priority (larger first)
        const fallbackResolutions = resolutionPriority
            .filter(r => r !== preferredResolution && availableResolutions.includes(r))
            .sort((a, b) => b - a); // Descending order (largest first: 43200 → 10080 → 1440 → 60 → 15)
        
        for (const fallbackResolution of fallbackResolutions) {
            const fallbackMatch = {
                ...baseMatch,
                resolution_minutes: fallbackResolution
            };
            
            const fallbackPipeline = [
                { $match: fallbackMatch },
                {
                    $group: {
                        _id: {
                            measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                            unit: '$unit'
                        },
                        timestampValuePairs: {
                            $push: {
                                timestamp: '$timestamp',
                                value: '$value',
                                sensorId: '$meta.sensorId'  // Include sensorId for multi-sensor aggregation
                            }
                        },
                        values: { $push: '$value' },
                        units: { $first: '$unit' },
                        avgQuality: { $avg: '$quality' },
                        count: { $sum: 1 }
                    }
                }
            ];
            
            const fallbackResults = await db.collection('measurements_aggregated').aggregate(fallbackPipeline).toArray();
            
            if (fallbackResults.length > 0) {
                results = fallbackResults;
                break;
            }
        }
    }
    
    return results;
}

/**
 * Determine optimal query strategy for energy consumption based on time range
 * Analyzes the time range and returns query segments with appropriate resolution and stateType
 * @param {Date} startDate - Start date of the query
 * @param {Date} endDate - End date of the query
 * @param {Object} options - Query options (interval, etc.)
 * @returns {Array} Array of query segments, each with { startDate, endDate, resolution, stateType, preferred }
 */
function determineOptimalEnergyQueryStrategy(startDate, endDate, options = {}) {
    const segments = [];
    const interval = options.interval || null;
    
    // Helper to round date to start of day
    const roundToDay = (date) => {
        const d = new Date(date);
        d.setHours(0, 0, 0, 0);
        return d;
    };
    
    // Helper to round date to start of week (Monday)
    const roundToWeek = (date) => {
        const d = new Date(date);
        const day = d.getDay();
        const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust to Monday
        d.setDate(diff);
        d.setHours(0, 0, 0, 0);
        return d;
    };
    
    // Helper to round date to start of month
    const roundToMonth = (date) => {
        const d = new Date(date);
        d.setDate(1);
        d.setHours(0, 0, 0, 0);
        return d;
    };
    
    // Helper to round date to start of year
    const roundToYear = (date) => {
        const d = new Date(date);
        d.setMonth(0, 1);
        d.setHours(0, 0, 0, 0);
        return d;
    };
    
    // If interval is provided, use it to determine stateType
    if (interval) {
        const stateType = getStateTypeForInterval(interval);
        if (stateType) {
            // For reports with specific intervals, prefer the matching stateType
            // Resolution depends on data age and availability
            const now = new Date();
            const hoursSinceEndDate = (now - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;
            
            let resolution = 60; // Default to hourly
            if (interval === 'Yearly' || interval === 'yearly') {
                // For yearly, prefer monthly aggregates if available, else daily
                resolution = 43200; // monthly (if available)
            } else if (interval === 'Monthly' || interval === 'monthly') {
                // For monthly, prefer daily aggregates
                resolution = 1440; // daily
            } else if (interval === 'Weekly' || interval === 'weekly') {
                // For weekly, prefer weekly aggregates if available, else daily
                resolution = 10080; // weekly (if available)
            } else if (interval === 'Daily' || interval === 'daily') {
                // For daily, prefer daily aggregates
                resolution = 1440; // daily
            }
            
            // Adjust resolution based on data age
            if (daysSinceEndDate > 7) {
                resolution = 1440; // Use daily for older data
            } else if (hoursSinceEndDate > 1) {
                resolution = 60; // Use hourly for data older than 1 hour
            }
            
            segments.push({
                startDate,
                endDate,
                resolution,
                stateType,
                preferred: true
            });
            
            return segments;
        }
    }
    
    // For arbitrary ranges, analyze the time range to determine best strategy
    const start = new Date(startDate);
    const end = new Date(endDate);
    const duration = end - start;
    const days = duration / (1000 * 60 * 60 * 24);
    const now = new Date();
    const hoursSinceEndDate = (now - endDate) / (1000 * 60 * 60);
    const daysSinceEndDate = hoursSinceEndDate / 24;
    
    // Round dates for day boundary checks
    const startDay = roundToDay(start);
    const endDay = roundToDay(end);
    
    // Check if we're querying complete days
    const isStartOfDay = start.getHours() === 0 && start.getMinutes() === 0 && start.getSeconds() === 0;
    const isEndOfDay = end.getHours() === 0 && end.getMinutes() === 0 && end.getSeconds() === 0;
    
    // Strategy 1: Single complete day
    if (days >= 0.9 && days < 1.1 && isStartOfDay && isEndOfDay) {
        // Use daily aggregate if data is old enough (daily aggregation runs at midnight)
        if (daysSinceEndDate >= 1) {
            segments.push({
                startDate: startDay,
                endDate: new Date(startDay.getTime() + 24 * 60 * 60 * 1000),
                resolution: 1440, // daily
                stateType: 'totalDay',
                preferred: true
            });
        } else {
            // Recent data: use hourly aggregates with totalDay
            segments.push({
                startDate: startDay,
                endDate: new Date(startDay.getTime() + 24 * 60 * 60 * 1000),
                resolution: 60, // hourly
                stateType: 'totalDay',
                preferred: true
            });
        }
        return segments;
    }
    
    // Strategy 2: Multiple complete days
    if (days >= 1 && isStartOfDay && isEndOfDay) {
        // Use daily aggregates for complete days
        let currentDay = startDay;
        while (currentDay < endDay) {
            const nextDay = new Date(currentDay.getTime() + 24 * 60 * 60 * 1000);
            const dayEnd = nextDay < endDay ? nextDay : endDay;
            
            // Check if this day is old enough for daily aggregation
            const dayAge = (now - dayEnd) / (1000 * 60 * 60 * 24);
            const resolution = dayAge >= 1 ? 1440 : 60; // daily if old enough, else hourly
            
            segments.push({
                startDate: currentDay,
                endDate: dayEnd,
                resolution,
                stateType: 'totalDay',
                preferred: true
            });
            
            currentDay = nextDay;
        }
        return segments;
    }
    
    // Strategy 3: Mixed range (partial days + complete days)
    // Split into segments: complete days use daily aggregates, partial days use hourly
    
    let currentStart = start;
    let currentEnd = end;
    
    // Handle partial start day
    if (!isStartOfDay) {
        const startDayEnd = new Date(startDay.getTime() + 24 * 60 * 60 * 1000);
        if (startDayEnd <= end) {
            // Use hourly for partial start day
            segments.push({
                startDate: start,
                endDate: startDayEnd,
                resolution: 60, // hourly
                stateType: 'totalDay',
                preferred: false
            });
            currentStart = startDayEnd;
        }
    }
    
    // Handle complete days in the middle
    if (currentStart < end) {
        let currentDay = roundToDay(currentStart);
        const endDayStart = roundToDay(end);
        
        while (currentDay < endDayStart) {
            const nextDay = new Date(currentDay.getTime() + 24 * 60 * 60 * 1000);
            const dayEnd = nextDay < endDayStart ? nextDay : endDayStart;
            
            // Check if this day is old enough for daily aggregation
            const dayAge = (now - dayEnd) / (1000 * 60 * 60 * 24);
            const resolution = dayAge >= 1 ? 1440 : 60; // daily if old enough, else hourly
            
            segments.push({
                startDate: currentDay,
                endDate: dayEnd,
                resolution,
                stateType: 'totalDay',
                preferred: true
            });
            
            currentDay = nextDay;
        }
        
        currentStart = endDayStart;
    }
    
    // Handle partial end day
    if (currentStart < end && !isEndOfDay) {
        segments.push({
            startDate: currentStart,
            endDate: end,
            resolution: 60, // hourly
            stateType: 'totalDay',
            preferred: false
        });
    }
    
    // If no segments created (edge case), create a single segment with hourly
    if (segments.length === 0) {
        segments.push({
            startDate: start,
            endDate: end,
            resolution: 60, // hourly
            stateType: 'totalDay',
            preferred: true
        });
    }
    
    return segments;
}

/**
 * Dashboard Discovery Service
 * 
 * Provides hierarchical data retrieval for the dashboard with nested structures:
 * Site → Building → Floor → Room → Sensor
 * 
 * Each level includes:
 * - Metadata for the entity
 * - Child references (buildings, floors, rooms, sensors)
 * - Aggregated KPIs (Total Consumption, Peak, Base, Average Quality)
 * - Measurement data with time-series support
 */
class DashboardDiscoveryService {
    /**
     * Calculate time range for default view (last 7 days)
     * @param {Object} options - Optional time range overrides
     * @returns {Object} { startDate, endDate }
     */
    getDefaultTimeRange(options = {}) {
        const endDate = options.endDate ? new Date(options.endDate) : new Date();
        const days = options.days || 7;
        const startDate = options.startDate 
            ? new Date(options.startDate) 
            : new Date(endDate.getTime() - days * 24 * 60 * 60 * 1000);
        
        // Ensure startDate is before endDate
        if (startDate >= endDate) {
            throw new ValidationError('Start date must be before end date');
        }
        
        return { startDate, endDate };
    }

    /**
     * Get all sites for a user (with basic metadata only)
     * @param {String} userId - User ID
     * @param {String} bryteswitchId - BryteSwitch ID (optional, for filtering)
     * @returns {Promise<Array>} Sites array
     */
    async getSites(userId, bryteswitchId = null) {
        // Get user's accessible bryteswitch IDs
        const userRoles = await UserRole.find({ 
            user_id: userId
        }).select('bryteswitch_id');
        
        const accessibleBryteswitchIds = userRoles.map(ur => ur.bryteswitch_id);
        
        // Check if user is superadmin
        const user = await User.findById(userId);
        const isSuperadmin = user && user.is_superadmin;
        
        // Build query
        const query = {};
        if (!isSuperadmin) {
            if (accessibleBryteswitchIds.length === 0) {
                return [];
            }
            query.bryteswitch_id = { $in: accessibleBryteswitchIds };
        }
        if (bryteswitchId) {
            query.bryteswitch_id = bryteswitchId;
        }
        
        const sites = await Site.find(query)
            .populate('bryteswitch_id', 'organization_name sub_domain')
            .sort({ name: 1 })
            .lean();
        
        // Get building counts for each site
        const siteIds = sites.map(s => s._id);
        const buildingCounts = await Building.aggregate([
            { $match: { site_id: { $in: siteIds } } },
            { $group: { _id: '$site_id', count: { $sum: 1 } } }
        ]);
        
        const buildingCountMap = new Map(buildingCounts.map(bc => [bc._id.toString(), bc.count]));
        
        return sites.map(site => ({
            _id: site._id,
            name: site.name,
            address: site.address,
            resource_type: site.resource_type,
            bryteswitch_id: site.bryteswitch_id,
            building_count: buildingCountMap.get(site._id.toString()) || 0,
            created_at: site.created_at,
            updated_at: site.updated_at
        }));
    }

    /**
     * Get site details with full hierarchy
     * @param {String} siteId - Site ID
     * @param {String} userId - User ID
     * @param {Object} options - Query options (time range, measurement type, resolution)
     * @returns {Promise<Object>} Site with nested data and KPIs
     */
    async getSiteDetails(siteId, userId, options = {}) {
        // Verify access
        const site = await Site.findById(siteId).populate('bryteswitch_id', 'organization_name');
        if (!site) {
            throw new NotFoundError('Site');
        }
        
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id._id || site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new AuthorizationError('You do not have access to this site');
            }
        }
        
        // Get time range
        const { startDate, endDate } = this.getDefaultTimeRange(options);
        
        // Get all buildings for this site
        const buildings = await Building.find({ site_id: siteId }).sort({ name: 1 }).lean();
        const buildingIds = buildings.map(b => b._id);
        
        // Get floors for all buildings
        const floors = await Floor.find({ building_id: { $in: buildingIds } }).sort({ name: 1 }).lean();
        const floorMap = new Map();
        floors.forEach(floor => {
            const bid = floor.building_id.toString();
            if (!floorMap.has(bid)) {
                floorMap.set(bid, []);
            }
            floorMap.get(bid).push(floor);
        });
        
        // Get LocalRooms for all floors
        const floorIds = floors.map(f => f._id);
        const localRooms = await LocalRoom.find({ floor_id: { $in: floorIds } })
            .populate('loxone_room_id')
            .sort({ name: 1 })
            .lean();
        const localRoomMap = new Map();
        localRooms.forEach(localRoom => {
            const fid = localRoom.floor_id.toString();
            if (!localRoomMap.has(fid)) {
                localRoomMap.set(fid, []);
            }
            localRoomMap.get(fid).push(localRoom);
        });
        
        // Get all linked Loxone Room IDs for sensors
        const loxoneRoomIds = localRooms
            .filter(lr => lr.loxone_room_id && lr.loxone_room_id._id)
            .map(lr => lr.loxone_room_id._id);
        
        // Get sensors for all linked Loxone rooms
        const sensors = await Sensor.find({ room_id: { $in: loxoneRoomIds } }).sort({ name: 1 }).lean();
        const sensorMap = new Map();
        sensors.forEach(sensor => {
            const rid = sensor.room_id.toString();
            if (!sensorMap.has(rid)) {
                sensorMap.set(rid, []);
            }
            sensorMap.get(rid).push(sensor);
        });
        
        // Get KPIs for all buildings in a single optimized query
        const buildingsKPIsMap = await this.getBuildingsKPIs(buildingIds, startDate, endDate, options);
        
        // Build nested structure
        const buildingData = await Promise.all(buildings.map(async (building) => {
            const buildingFloors = floorMap.get(building._id.toString()) || [];
            
            // Get floors with local rooms
            const floorsWithRooms = await Promise.all(buildingFloors.map(async (floor) => {
                const floorLocalRooms = localRoomMap.get(floor._id.toString()) || [];
                
                const floorRooms = floorLocalRooms.map(localRoom => {
                    const loxoneRoom = localRoom.loxone_room_id;
                    const roomSensors = loxoneRoom && loxoneRoom._id 
                        ? (sensorMap.get(loxoneRoom._id.toString()) || [])
                        : [];
                    
                    return {
                        _id: localRoom._id,
                        name: localRoom.name,
                        color: localRoom.color,
                        floorId: localRoom.floor_id,
                        loxone_room_id: loxoneRoom ? {
                            _id: loxoneRoom._id,
                            name: loxoneRoom.name,
                            loxone_room_uuid: loxoneRoom.loxone_room_uuid,
                            buildingId: loxoneRoom.building_id
                        } : null,
                        sensor_count: roomSensors.length,
                        sensors: roomSensors.map(s => ({
                            _id: s._id,
                            name: s.name,
                            unit: s.unit,
                            roomId: s.room_id,
                            loxone_control_uuid: s.loxone_control_uuid,
                            loxone_category_type: s.loxone_category_type
                        })),
                        created_at: localRoom.created_at,
                        updated_at: localRoom.updated_at
                    };
                });
                
                return {
                    _id: floor._id,
                    name: floor.name,
                    buildingId: floor.building_id,
                    floor_plan_link: floor.floor_plan_link,
                    room_count: floorRooms.length,
                    rooms: floorRooms,
                    created_at: floor.created_at,
                    updated_at: floor.updated_at
                };
            }));
            
            // Get building KPIs from the pre-fetched map
            const buildingIdStr = building._id.toString();
            const kpis = buildingsKPIsMap.get(buildingIdStr) || this.getEmptyKPIs();
            
            return {
                _id: building._id,
                name: building.name,
                siteId: building.site_id,
                building_size: building.building_size,
                num_floors: building.num_floors,
                year_of_construction: building.year_of_construction,
                type_of_use: building.type_of_use,
                floor_count: buildingFloors.length,
                room_count: localRooms.filter(lr => {
                    const fid = lr.floor_id.toString();
                    return buildingFloors.some(f => f._id.toString() === fid);
                }).length,
                sensor_count: sensors.length,
                floors: floorsWithRooms,
                kpis,
                created_at: building.created_at,
                updated_at: building.updated_at
            };
        }));
        
        // Get site-level KPIs (aggregate all buildings)
        const siteKPIs = await this.getSiteKPIs(siteId, startDate, endDate, options);
        
        return {
            _id: site._id,
            name: site.name,
            address: site.address,
            resource_type: site.resource_type,
            bryteswitch_id: site.bryteswitch_id,
            building_count: buildings.length,
            total_floors: floors.length,
            total_rooms: localRooms.length,
            total_sensors: sensors.length,
            buildings: buildingData,
            kpis: siteKPIs,
            time_range: {
                start: startDate.toISOString(),
                end: endDate.toISOString()
            },
            created_at: site.created_at,
            updated_at: site.updated_at
        };
    }

    /**
     * Get building details with nested data
     * @param {String} buildingId - Building ID
     * @param {String} userId - User ID
     * @param {Object} options - Query options
     * @returns {Promise<Object>} Building with nested data and KPIs
     */
    async getBuildingDetails(buildingId, userId, options = {}) {
        // Verify access
        const building = await Building.findById(buildingId).populate('site_id');
        if (!building) {
            throw new NotFoundError('Building');
        }
        
        const site = await Site.findById(building.site_id._id || building.site_id);
        if (!site) {
            throw new NotFoundError('Site');
        }
        
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new AuthorizationError('You do not have access to this building');
            }
        }
        
        // Get time range
        const { startDate, endDate } = this.getDefaultTimeRange(options);
        
        // Get floors
        const floors = await Floor.find({ building_id: buildingId }).sort({ name: 1 }).lean();
        const floorIds = floors.map(f => f._id);
        
        // Get LocalRooms for all floors
        const localRooms = await LocalRoom.find({ floor_id: { $in: floorIds } })
            .populate('loxone_room_id')
            .sort({ name: 1 })
            .lean();
        const localRoomMap = new Map();
        localRooms.forEach(localRoom => {
            const fid = localRoom.floor_id.toString();
            if (!localRoomMap.has(fid)) {
                localRoomMap.set(fid, []);
            }
            localRoomMap.get(fid).push(localRoom);
        });
        
        // Get all linked Loxone Room IDs for sensors
        const loxoneRoomIds = localRooms
            .filter(lr => lr.loxone_room_id && lr.loxone_room_id._id)
            .map(lr => lr.loxone_room_id._id);
        
        // Get sensors for all linked Loxone rooms
        const sensors = await Sensor.find({ room_id: { $in: loxoneRoomIds } }).sort({ name: 1 }).lean();
        const sensorMap = new Map();
        sensors.forEach(sensor => {
            const rid = sensor.room_id.toString();
            if (!sensorMap.has(rid)) {
                sensorMap.set(rid, []);
            }
            sensorMap.get(rid).push(sensor);
        });
        
        // Build nested structure
        const floorsWithRooms = await Promise.all(floors.map(async (floor) => {
            const floorLocalRooms = localRoomMap.get(floor._id.toString()) || [];
            
            const floorRooms = floorLocalRooms.map(localRoom => {
                const loxoneRoom = localRoom.loxone_room_id;
                const roomSensors = loxoneRoom && loxoneRoom._id 
                    ? (sensorMap.get(loxoneRoom._id.toString()) || [])
                    : [];
                
                return {
                    _id: localRoom._id,
                    name: localRoom.name,
                    color: localRoom.color,
                    floorId: localRoom.floor_id,
                    loxone_room_id: loxoneRoom ? {
                        _id: loxoneRoom._id,
                        name: loxoneRoom.name,
                        loxone_room_uuid: loxoneRoom.loxone_room_uuid,
                        buildingId: loxoneRoom.building_id
                    } : null,
                    sensor_count: roomSensors.length,
                    sensors: roomSensors.map(s => ({
                        _id: s._id,
                        name: s.name,
                        unit: s.unit,
                        roomId: s.room_id,
                        loxone_control_uuid: s.loxone_control_uuid,
                        loxone_category_type: s.loxone_category_type
                    })),
                    created_at: localRoom.created_at,
                    updated_at: localRoom.updated_at
                };
            });
            
            return {
                _id: floor._id,
                name: floor.name,
                buildingId: floor.building_id,
                floor_plan_link: floor.floor_plan_link,
                room_count: floorRooms.length,
                rooms: floorRooms,
                created_at: floor.created_at,
                updated_at: floor.updated_at
            };
        }));
        
        // Get building KPIs and analytics
        const buildingAnalytics = await this.getBuildingAnalytics(buildingId, startDate, endDate, options);
        
        return {
            _id: building._id,
            name: building.name,
            siteId: building.site_id._id || building.site_id,
            building_size: building.building_size,
            num_floors: building.num_floors,
            year_of_construction: building.year_of_construction,
            type_of_use: building.type_of_use,
            floor_count: floors.length,
            room_count: localRooms.length,
            sensor_count: sensors.length,
            floors: floorsWithRooms,
            kpis: buildingAnalytics.kpis,
            analytics: buildingAnalytics.analytics,
            time_range: {
                start: startDate.toISOString(),
                end: endDate.toISOString()
            },
            created_at: building.created_at,
            updated_at: building.updated_at
        };
    }

    /**
     * Get floor details with nested data
     * @param {String} floorId - Floor ID
     * @param {String} userId - User ID
     * @param {Object} options - Query options
     * @returns {Promise<Object>} Floor with nested data and KPIs
     */
    async getFloorDetails(floorId, userId, options = {}) {
        const floor = await Floor.findById(floorId).populate('building_id');
        if (!floor) {
            throw new NotFoundError('Floor');
        }
        
        const building = await Building.findById(floor.building_id._id || floor.building_id);
        if (!building) {
            throw new NotFoundError('Building');
        }
        
        const site = await Site.findById(building.site_id);
        if (!site) {
            throw new NotFoundError('Site');
        }
        
        // Verify access
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new AuthorizationError('You do not have access to this floor');
            }
        }
        
        // Get time range
        const { startDate, endDate } = this.getDefaultTimeRange(options);
        
        // Get LocalRooms for this floor
        const localRooms = await LocalRoom.find({ floor_id: floorId })
            .populate('loxone_room_id')
            .sort({ name: 1 })
            .lean();
        
        // Get all linked Loxone Room IDs for sensors
        const loxoneRoomIds = localRooms
            .filter(lr => lr.loxone_room_id && lr.loxone_room_id._id)
            .map(lr => lr.loxone_room_id._id);
        
        // Get sensors for all linked Loxone rooms
        const sensors = await Sensor.find({ room_id: { $in: loxoneRoomIds } }).sort({ name: 1 }).lean();
        const sensorMap = new Map();
        sensors.forEach(sensor => {
            const rid = sensor.room_id.toString();
            if (!sensorMap.has(rid)) {
                sensorMap.set(rid, []);
            }
            sensorMap.get(rid).push(sensor);
        });
        
        // Build room structure
        const roomsWithSensors = localRooms.map(localRoom => {
            const loxoneRoom = localRoom.loxone_room_id;
            const roomSensors = loxoneRoom && loxoneRoom._id 
                ? (sensorMap.get(loxoneRoom._id.toString()) || [])
                : [];
            
            return {
                _id: localRoom._id,
                name: localRoom.name,
                color: localRoom.color,
                floorId: localRoom.floor_id,
                loxone_room_id: loxoneRoom ? {
                    _id: loxoneRoom._id,
                    name: loxoneRoom.name,
                    loxone_room_uuid: loxoneRoom.loxone_room_uuid,
                    buildingId: loxoneRoom.building_id
                } : null,
                sensor_count: roomSensors.length,
                sensors: roomSensors.map(s => ({
                    _id: s._id,
                    name: s.name,
                    unit: s.unit,
                    roomId: s.room_id,
                    loxone_control_uuid: s.loxone_control_uuid,
                    loxone_category_type: s.loxone_category_type
                })),
                created_at: localRoom.created_at,
                updated_at: localRoom.updated_at
            };
        });
        
        // Get floor KPIs (only sensors in rooms on this floor)
        const kpis = await this.getFloorKPIs(floorId, startDate, endDate, options);
        
        return {
            _id: floor._id,
            name: floor.name,
            buildingId: floor.building_id._id || floor.building_id,
            floor_plan_link: floor.floor_plan_link,
            room_count: localRooms.length,
            sensor_count: sensors.length,
            rooms: roomsWithSensors,
            kpis,
            time_range: {
                start: startDate.toISOString(),
                end: endDate.toISOString()
            },
            created_at: floor.created_at,
            updated_at: floor.updated_at
        };
    }

    /**
     * Get room details with nested data
     * @param {String} roomId - Room ID
     * @param {String} userId - User ID
     * @param {Object} options - Query options
     * @returns {Promise<Object>} Room with nested data and KPIs
     */
    async getRoomDetails(roomId, userId, options = {}) {
        // roomId is now a LocalRoom ID
        const localRoom = await LocalRoom.findById(roomId).populate('loxone_room_id').populate({
            path: 'floor_id',
            populate: {
                path: 'building_id',
                populate: {
                    path: 'site_id'
                }
            }
        });
        
        if (!localRoom) {
            throw new NotFoundError('Room');
        }
        
        const floor = localRoom.floor_id;
        if (!floor) {
            throw new NotFoundError('Floor');
        }
        
        const building = floor.building_id;
        if (!building) {
            throw new NotFoundError('Building');
        }
        
        const site = building.site_id;
        if (!site) {
            throw new NotFoundError('Site');
        }
        
        // Verify access
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new AuthorizationError('You do not have access to this room');
            }
        }
        
        // Get time range
        const { startDate, endDate } = this.getDefaultTimeRange(options);
        
        // Get sensors in linked Loxone room (if exists)
        const loxoneRoom = localRoom.loxone_room_id;
        const sensors = loxoneRoom && loxoneRoom._id
            ? await Sensor.find({ room_id: loxoneRoom._id }).sort({ name: 1 }).lean()
            : [];
        
        // Get room KPIs (aggregate all sensors in linked Loxone room)
        const kpis = loxoneRoom && loxoneRoom._id
            ? await this.getRoomKPIs(loxoneRoom._id, startDate, endDate, options)
            : this.getEmptyKPIs();
        
        // Get KPIs for each sensor in the room
        const sensorsWithKPIs = await Promise.all(
            sensors.map(async (sensor) => {
                const sensorKPIs = await this.getSensorKPIs(
                    sensor._id,
                    startDate,
                    endDate,
                    options
                );
                
                return {
                    _id: sensor._id,
                    name: sensor.name,
                    unit: sensor.unit,
                    roomId: sensor.room_id,
                    loxone_control_uuid: sensor.loxone_control_uuid,
                    loxone_category_type: sensor.loxone_category_type,
                    kpis: sensorKPIs,
                    created_at: sensor.created_at,
                    updated_at: sensor.updated_at
                };
            })
        );
        
        return {
            _id: localRoom._id,
            name: localRoom.name,
            color: localRoom.color,
            floorId: localRoom.floor_id._id || localRoom.floor_id,
            loxone_room_id: loxoneRoom ? {
                _id: loxoneRoom._id,
                name: loxoneRoom.name,
                loxone_room_uuid: loxoneRoom.loxone_room_uuid,
                buildingId: loxoneRoom.building_id
            } : null,
            sensor_count: sensors.length,
            sensors: sensorsWithKPIs,
            kpis,
            time_range: {
                start: startDate.toISOString(),
                end: endDate.toISOString()
            },
            created_at: localRoom.created_at,
            updated_at: localRoom.updated_at
        };
    }

    /**
     * Get sensor details with measurement data
     * @param {String} sensorId - Sensor ID
     * @param {String} userId - User ID
     * @param {Object} options - Query options
     * @returns {Promise<Object>} Sensor with measurement data and KPIs
     */
    async getSensorDetails(sensorId, userId, options = {}) {
        const sensor = await Sensor.findById(sensorId).populate('room_id');
        if (!sensor) {
            throw new NotFoundError('Sensor');
        }
        
        const room = await Room.findById(sensor.room_id._id || sensor.room_id);
        if (!room) {
            throw new NotFoundError('Room');
        }
        
        // Find building through LocalRoom -> Floor path since Room no longer has building_id
        const localRoom = await LocalRoom.findOne({ loxone_room_id: room._id }).populate({
            path: 'floor_id',
            populate: {
                path: 'building_id',
                populate: {
                    path: 'site_id'
                }
            }
        });
        
        if (!localRoom || !localRoom.floor_id || !localRoom.floor_id.building_id) {
            throw new NotFoundError('Building for sensor');
        }
        
        const building = localRoom.floor_id.building_id;
        const site = building.site_id;
        
        if (!site) {
            throw new NotFoundError('Site');
        }
        
        // Verify access
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new AuthorizationError('You do not have access to this sensor');
            }
        }
        
        // Get time range
        const { startDate, endDate } = this.getDefaultTimeRange(options);
        
        // Get sensor KPIs
        const kpis = await this.getSensorKPIs(sensorId, startDate, endDate, options);
        
        // Get measurement data
        let measurements = null;
        if (options.includeMeasurements !== false) {
            const measurementOptions = {
                resolution: options.resolution,
                measurementType: options.measurementType,
                limit: options.limit || 1000,
                skip: options.skip
            };
            
            const result = await measurementQueryService.getMeasurements(
                sensorId,
                startDate,
                endDate,
                measurementOptions
            );
            
            measurements = {
                data: result.measurements,
                count: result.count,
                resolution: result.resolution,
                resolution_label: result.resolutionLabel
            };
        }
        
        return {
            _id: sensor._id,
            name: sensor.name,
            unit: sensor.unit,
            roomId: sensor.room_id._id || sensor.room_id,
            loxone_control_uuid: sensor.loxone_control_uuid,
            loxone_category_uuid: sensor.loxone_category_uuid,
            loxone_category_name: sensor.loxone_category_name,
            loxone_category_type: sensor.loxone_category_type,
            kpis,
            measurements,
            time_range: {
                start: startDate.toISOString(),
                end: endDate.toISOString()
            },
            created_at: sensor.created_at,
            updated_at: sensor.updated_at
        };
    }

    /**
     * Calculate KPIs from raw aggregation results with unit normalization
     * @param {Array} rawResults - Raw aggregation results from MongoDB
     * @returns {Object} KPIs object with normalized units
     */
    calculateKPIsFromResults(rawResults, options = {}) {
        // Process results: normalize units and aggregate by measurementType and stateType
        const processedResults = new Map();
        
        // Track stateType for Energy measurements to handle totalDay correctly
        const energyStateTypes = new Map(); // measurementType -> Set of stateTypes
        
        for (const result of rawResults) {
            const measurementType = result._id.measurementType;
            const stateType = result._id.stateType || null;
            const unit = result.units || '';
            const baseUnit = getBaseUnit(measurementType);
            
            // Track stateTypes for Energy measurements
            if (measurementType === 'Energy' && stateType) {
                if (!energyStateTypes.has(measurementType)) {
                    energyStateTypes.set(measurementType, new Set());
                }
                energyStateTypes.get(measurementType).add(stateType);
            }
            
            // Use a composite key to separate different stateTypes
            const key = `${measurementType}:${stateType || 'unknown'}`;
            
            if (!processedResults.has(key)) {
                processedResults.set(key, {
                    measurementType: measurementType,
                    stateType: stateType,
                    values: [],
                    timestampValuePairs: [], // Store timestamp/value pairs for partial period calculations
                    baseUnit: baseUnit,
                    avgQuality: [],
                    count: 0
                });
            }
            
            const processed = processedResults.get(key);
            
            // Normalize all values to base unit
            const normalizedValues = result.values.map(v => normalizeToBaseUnit(v, unit));
            processed.values.push(...normalizedValues);
            
            // Process timestamp/value pairs if available
            if (result.timestampValuePairs && Array.isArray(result.timestampValuePairs)) {
                for (const pair of result.timestampValuePairs) {
                    const normalizedValue = normalizeToBaseUnit(pair.value, unit);
                    processed.timestampValuePairs.push({
                        timestamp: pair.timestamp instanceof Date ? pair.timestamp : new Date(pair.timestamp),
                        value: normalizedValue,
                        sensorId: pair.sensorId  // Preserve sensorId for multi-sensor aggregation
                    });
                }
                // Sort by timestamp
                processed.timestampValuePairs.sort((a, b) => a.timestamp - b.timestamp);
            }
            
            processed.avgQuality.push(result.avgQuality || 100);
            processed.count += result.count;
        }
        
        // Calculate statistics for each measurement type
        const breakdown = [];
        let totalConsumption = 0;
        let peak = 0;
        let base = 0;
        let averageEnergy = 0; // Average energy consumption per period (kWh)
        let averagePower = 0; // Average power (kW)
        let avgQuality = 100;
        
        // Separate units for energy and power
        const energyUnit = 'kWh';
        const powerUnit = 'kW';
        
        // Find Energy data for total_consumption, base, averageEnergy
        // Priority order: totalDay > totalWeek > totalMonth > totalYear > total > any Energy
        let energyData = null;
        let energyStateType = null;
        
        // Check for Energy data with different stateTypes
        const energyKeys = Array.from(processedResults.keys()).filter(k => k.startsWith('Energy:'));
        
        if (energyKeys.length > 0) {
            // For reports with interval: prefer the matching stateType
            if (options.interval) {
                const intervalStateType = getStateTypeForInterval(options.interval);
                const preferredKey = `Energy:${intervalStateType}`;
                if (processedResults.has(preferredKey)) {
                    energyData = processedResults.get(preferredKey);
                    energyStateType = intervalStateType;
                } else {
                    // Fallback to any Energy data
                    energyData = processedResults.get(energyKeys[0]);
                    energyStateType = energyData?.stateType;
                }
            } else {
                // For arbitrary ranges: prefer period totals in priority order
                // Priority: totalDay > totalWeek > totalMonth > totalYear > total
                const priorityOrder = ['totalDay', 'totalWeek', 'totalMonth', 'totalYear', 'total'];
                let found = false;
                
                for (const stateType of priorityOrder) {
                    const key = energyKeys.find(k => k.includes(`:${stateType}`));
                    if (key) {
                        energyData = processedResults.get(key);
                        energyStateType = stateType;
                        found = true;
                        break;
                    }
                }
                
                // If no priority stateType found, use any Energy data
                if (!found) {
                    energyData = processedResults.get(energyKeys[0]);
                    energyStateType = energyData?.stateType;
                }
            }
        }
        
        // For dashboard arbitrary ranges: calculate energy from Power if no Energy data
        const powerKey = Array.from(processedResults.keys()).find(k => k.startsWith('Power:'));
        const powerData = powerKey ? processedResults.get(powerKey) : null;
        const usePowerForEnergy = !energyData && powerData && powerData.values.length > 0 && !options.interval;
        
        if (energyData && energyData.values.length > 0) {
            // Filter out negative values (meter resets or data issues)
            const validEnergyValues = energyData.values.filter(v => v >= 0);
            
            if (validEnergyValues.length > 0) {
                const energyValues = validEnergyValues;
                
                // Handle different stateTypes correctly:
                // - totalDay: resets at midnight, cumulative within day
                // - totalWeek: resets at week start (Monday), cumulative within week
                // - totalMonth: resets at month start, cumulative within month
                // - totalYear: resets at year start, cumulative within year
                // - total: cumulative counter (never resets)
                const isPeriodTotal = energyStateType && (
                    energyStateType === 'totalDay' || 
                    energyStateType === 'totalWeek' || 
                    energyStateType === 'totalMonth' || 
                    energyStateType === 'totalYear' ||
                    energyStateType === 'totalNegDay' ||
                    energyStateType === 'totalNegWeek' ||
                    energyStateType === 'totalNegMonth' ||
                    energyStateType === 'totalNegYear'
                );
                
                if (isPeriodTotal) {
                    // Period totals: need to handle full periods, partial periods, and multiple periods
                    const resolution = options.resolution || 60;
                    const startDate = options.startDate ? new Date(options.startDate) : null;
                    const endDate = options.endDate ? new Date(options.endDate) : null;
                    
                    // Get timestamp/value pairs if available (for partial period calculations)
                    let timestampValuePairs = energyData.timestampValuePairs || [];
                    // Filter out negative values from pairs
                    timestampValuePairs = timestampValuePairs.filter(p => p.value >= 0);
                    
                    // Determine period type and boundaries
                    let periodType = null;
                    let periodStartBoundary = null;
                    let periodEndBoundary = null;
                    
                    if (energyStateType === 'totalDay' || energyStateType === 'totalNegDay') {
                        periodType = 'day';
                        if (startDate) periodStartBoundary = roundToDayStart(startDate);
                        if (endDate) periodEndBoundary = roundToDayStart(endDate);
                    } else if (energyStateType === 'totalWeek' || energyStateType === 'totalNegWeek') {
                        periodType = 'week';
                        if (startDate) periodStartBoundary = roundToWeekStart(startDate);
                        if (endDate) periodEndBoundary = roundToWeekStart(endDate);
                    } else if (energyStateType === 'totalMonth' || energyStateType === 'totalNegMonth') {
                        periodType = 'month';
                        if (startDate) periodStartBoundary = roundToMonthStart(startDate);
                        if (endDate) periodEndBoundary = roundToMonthStart(endDate);
                    } else if (energyStateType === 'totalYear' || energyStateType === 'totalNegYear') {
                        periodType = 'year';
                        if (startDate) periodStartBoundary = roundToYearStart(startDate);
                        if (endDate) periodEndBoundary = roundToYearStart(endDate);
                    }
                    
                    // Check if query spans full periods or partial periods
                    const isFullPeriod = startDate && endDate && periodStartBoundary && periodEndBoundary &&
                        isStartOfDay(startDate) && isStartOfDay(endDate) &&
                        startDate.getTime() === periodStartBoundary.getTime() &&
                        endDate.getTime() === periodEndBoundary.getTime();
                    
                    const isPartialPeriod = !isFullPeriod && startDate && endDate;
                    const timeRangeDays = startDate && endDate 
                        ? (endDate - startDate) / (1000 * 60 * 60 * 24)
                        : null;
                    
                    // Determine if single period or multiple periods
                    let isSinglePeriod = false;
                    if (periodType === 'day') {
                        // For days: check if start and end are within the same day, OR if it's close to a full day
                        if (startDate && endDate) {
                            const startDay = roundToDayStart(startDate);
                            const endDay = roundToDayStart(endDate);
                            // Same day OR close to full day (0.9-1.1 days)
                            isSinglePeriod = (startDay.getTime() === endDay.getTime()) || 
                                           (timeRangeDays !== null && timeRangeDays >= 0.9 && timeRangeDays < 1.1);
                        }
                    } else if (periodType === 'week') {
                        isSinglePeriod = timeRangeDays !== null && timeRangeDays >= 6 && timeRangeDays < 8;
                    } else if (periodType === 'month') {
                        isSinglePeriod = timeRangeDays !== null && timeRangeDays >= 28 && timeRangeDays < 32;
                    } else if (periodType === 'year') {
                        isSinglePeriod = timeRangeDays !== null && timeRangeDays >= 360 && timeRangeDays < 370;
                    }
                    
                    // Calculate consumption based on scenario
                    if (isSinglePeriod && isFullPeriod) {
                        // Case 1: Single full period (e.g., full day 00:00-23:59)
                        // For multiple sensors: Group by sensor, get MAX per sensor, then SUM
                        // For single sensor: Use MAX (latest value) = period total
                        const hasSensorId = timestampValuePairs.length > 0 && 
                            timestampValuePairs.some(p => p.sensorId !== undefined && p.sensorId !== null);
                        
                        if (hasSensorId) {
                            // Multiple sensors: Group by sensorId, get MAX per sensor, then SUM
                            const sensorGroups = new Map();
                            for (const pair of timestampValuePairs) {
                                // Handle ObjectId properly - convert to string
                                let sensorIdStr = 'unknown';
                                if (pair.sensorId) {
                                    if (typeof pair.sensorId === 'object' && pair.sensorId.toString) {
                                        sensorIdStr = pair.sensorId.toString();
                                    } else if (typeof pair.sensorId === 'string') {
                                        sensorIdStr = pair.sensorId;
                                    } else {
                                        sensorIdStr = String(pair.sensorId);
                                    }
                                }
                                
                                if (!sensorGroups.has(sensorIdStr)) {
                                    sensorGroups.set(sensorIdStr, []);
                                }
                                sensorGroups.get(sensorIdStr).push(pair);
                            }
                            
                            // Get MAX per sensor (period total for each sensor)
                            const sensorTotals = [];
                            for (const [sensorId, pairs] of sensorGroups.entries()) {
                                const pairValues = pairs.map(p => p.value);
                                const sensorMax = Math.max(...pairValues);
                                sensorTotals.push(sensorMax);
                            }
                            
                            // SUM all sensor totals
                            totalConsumption = sensorTotals.reduce((sum, v) => sum + v, 0);
                            base = Math.min(...sensorTotals);
                            averageEnergy = totalConsumption;
                        } else {
                            // Single sensor: Use MAX (latest value) = period total
                            totalConsumption = Math.max(...energyValues);
                            base = Math.min(...energyValues);
                            averageEnergy = totalConsumption;
                        }
                    } else if (isSinglePeriod && isPartialPeriod && timestampValuePairs.length > 0) {
                        // Case 2: Single partial period (e.g., 12:00-23:59 or 00:00-00:00:59)
                        // For multiple sensors: Calculate consumption per sensor, then SUM
                        // For single sensor: Subtract start value from end value
                        const hasSensorId = timestampValuePairs.some(p => p.sensorId !== undefined && p.sensorId !== null);
                        
                        if (hasSensorId) {
                            // Multiple sensors: Group by sensorId, calculate consumption per sensor, then SUM
                            const sensorGroups = new Map();
                            for (const pair of timestampValuePairs) {
                                // Handle ObjectId properly - convert to string
                                let sensorIdStr = 'unknown';
                                if (pair.sensorId) {
                                    if (typeof pair.sensorId === 'object' && pair.sensorId.toString) {
                                        sensorIdStr = pair.sensorId.toString();
                                    } else if (typeof pair.sensorId === 'string') {
                                        sensorIdStr = pair.sensorId;
                                    } else {
                                        sensorIdStr = String(pair.sensorId);
                                    }
                                }
                                
                                if (!sensorGroups.has(sensorIdStr)) {
                                    sensorGroups.set(sensorIdStr, []);
                                }
                                sensorGroups.get(sensorIdStr).push(pair);
                            }
                            
                            // Calculate consumption per sensor
                            const sensorConsumptions = [];
                            for (const [sensorId, pairs] of sensorGroups.entries()) {
                                // Sort pairs by timestamp for this sensor
                                pairs.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
                                
                                const startValue = getValueJustBefore(pairs, startDate);
                                const endValue = getLatestValue(pairs);
                                
                                if (startValue !== null && endValue !== null && endValue >= startValue) {
                                    const sensorConsumption = endValue - startValue;
                                    sensorConsumptions.push(sensorConsumption);
                                } else {
                                    // Fallback: use MAX for this sensor if subtraction not possible
                                    const sensorMax = Math.max(...pairs.map(p => p.value));
                                    sensorConsumptions.push(sensorMax);
                                }
                            }
                            
                            if (sensorConsumptions.length > 0) {
                                // SUM all sensor consumptions
                                totalConsumption = sensorConsumptions.reduce((sum, v) => sum + v, 0);
                                base = Math.min(...sensorConsumptions);
                                averageEnergy = totalConsumption;
                            } else {
                                // Fallback: use MAX
                                totalConsumption = Math.max(...energyValues);
                                base = Math.min(...energyValues);
                                averageEnergy = totalConsumption;
                            }
                        } else {
                            // Single sensor: Subtract start value from end value
                            const startValue = getValueJustBefore(timestampValuePairs, startDate);
                            const endValue = getLatestValue(timestampValuePairs);
                            
                            if (startValue !== null && endValue !== null && endValue >= startValue) {
                                totalConsumption = endValue - startValue;
                                base = Math.min(...energyValues);
                                averageEnergy = totalConsumption;
                            } else {
                                // Fallback: use MAX if subtraction not possible
                                totalConsumption = Math.max(...energyValues);
                                base = Math.min(...energyValues);
                                averageEnergy = totalConsumption;
                            }
                        }
                    } else if (!isSinglePeriod && resolution === 1440 && (energyStateType === 'totalDay' || energyStateType === 'totalNegDay')) {
                        // Case 3: Multiple days with daily aggregates (resolution 1440)
                        // Each value is one day's total → SUM them
                        totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
                        base = Math.min(...energyValues);
                        averageEnergy = totalConsumption / energyValues.length;
                    } else if (!isSinglePeriod && resolution === 10080 && (energyStateType === 'totalWeek' || energyStateType === 'totalNegWeek')) {
                        // Case 4: Multiple weeks with weekly aggregates (resolution 10080)
                        // Each value is one week's total → SUM them
                        totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
                        base = Math.min(...energyValues);
                        averageEnergy = totalConsumption / energyValues.length;
                    } else if (!isSinglePeriod && resolution === 43200 && (energyStateType === 'totalMonth' || energyStateType === 'totalNegMonth')) {
                        // Case 5: Multiple months with monthly aggregates (resolution 43200)
                        // Each value is one month's total → SUM them
                        totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
                        base = Math.min(...energyValues);
                        averageEnergy = totalConsumption / energyValues.length;
                    } else if (!isSinglePeriod && timestampValuePairs.length > 0) {
                        // Case 6: Multiple periods with finer aggregates (e.g., hourly for multiple days)
                        // For multiple sensors: Group by sensor AND period, get MAX per sensor per period, then SUM
                        // For single sensor: Group by period, get MAX per period, then SUM
                        const hasSensorId = timestampValuePairs.length > 0 && 
                            timestampValuePairs.some(p => p.sensorId !== undefined && p.sensorId !== null);
                        
                        if (hasSensorId) {
                            // Multiple sensors: Group by sensor AND period
                            const sensorPeriodGroups = new Map(); // "sensorId:periodKey" -> array of pairs
                            
                            for (const pair of timestampValuePairs) {
                                // Handle ObjectId properly - convert to string
                                let sensorIdStr = 'unknown';
                                if (pair.sensorId) {
                                    if (typeof pair.sensorId === 'object' && pair.sensorId.toString) {
                                        sensorIdStr = pair.sensorId.toString();
                                    } else if (typeof pair.sensorId === 'string') {
                                        sensorIdStr = pair.sensorId;
                                    } else {
                                        sensorIdStr = String(pair.sensorId);
                                    }
                                }
                                
                                const date = new Date(pair.timestamp);
                                let periodKey;
                                
                                if (periodType === 'day') {
                                    periodKey = roundToDayStart(date).toISOString();
                                } else if (periodType === 'week') {
                                    periodKey = roundToWeekStart(date).toISOString();
                                } else if (periodType === 'month') {
                                    periodKey = roundToMonthStart(date).toISOString();
                                } else if (periodType === 'year') {
                                    periodKey = roundToYearStart(date).toISOString();
                                } else {
                                    continue;
                                }
                                
                                const key = `${sensorIdStr}:${periodKey}`;
                                if (!sensorPeriodGroups.has(key)) {
                                    sensorPeriodGroups.set(key, []);
                                }
                                sensorPeriodGroups.get(key).push(pair);
                            }
                            
                            // Get MAX per sensor per period
                            const sensorPeriodTotals = [];
                            for (const [key, pairs] of sensorPeriodGroups.entries()) {
                                const [sensorId, periodKey] = key.split(':');
                                const pairValues = pairs.map(p => p.value);
                                const periodMax = Math.max(...pairValues);
                                sensorPeriodTotals.push({ sensorId, periodKey, max: periodMax });
                            }
                            
                            // Group by period and sum sensor totals per period
                            const periodTotalsMap = new Map(); // periodKey -> sum of all sensors' MAX for that period
                            for (const { periodKey, max } of sensorPeriodTotals) {
                                if (!periodTotalsMap.has(periodKey)) {
                                    periodTotalsMap.set(periodKey, 0);
                                }
                                periodTotalsMap.set(periodKey, periodTotalsMap.get(periodKey) + max);
                            }
                            
                            const periodTotals = Array.from(periodTotalsMap.values());
                            
                            if (periodTotals.length > 0) {
                                totalConsumption = periodTotals.reduce((sum, v) => sum + v, 0);
                                base = Math.min(...periodTotals);
                                averageEnergy = totalConsumption / periodTotals.length;
                            } else {
                                // Fallback: use MAX
                                totalConsumption = Math.max(...energyValues);
                                base = Math.min(...energyValues);
                                averageEnergy = totalConsumption;
                            }
                        } else {
                            // Single sensor or sensorId not available: use original logic
                            const periodGroups = groupByPeriod(timestampValuePairs, periodType);
                            let periodTotals = [];
                            
                            for (const [periodKey, pairs] of periodGroups.entries()) {
                                if (pairs.length > 0) {
                                    const pairValues = pairs.map(p => p.value);
                                    const periodMax = Math.max(...pairValues);
                                    periodTotals.push(periodMax);
                                }
                            }
                            
                            if (periodTotals.length > 0) {
                                totalConsumption = periodTotals.reduce((sum, v) => sum + v, 0);
                                base = Math.min(...periodTotals);
                                averageEnergy = totalConsumption / periodTotals.length;
                            } else {
                                // Fallback: use MAX
                                totalConsumption = Math.max(...energyValues);
                                base = Math.min(...energyValues);
                                averageEnergy = totalConsumption;
                            }
                        }
                    } else if (!isSinglePeriod && isPartialPeriod && timestampValuePairs.length > 0) {
                        // Case 7: Partial period spanning multiple periods (e.g., Tuesday-Friday)
                        const hasSensorId = timestampValuePairs.length > 0 && timestampValuePairs[0].sensorId !== undefined;
                        
                        if (hasSensorId) {
                            // Multiple sensors: Calculate consumption per sensor, then sum
                            const sensorGroups = new Map();
                            for (const pair of timestampValuePairs) {
                                const sensorId = pair.sensorId?.toString() || 'unknown';
                                if (!sensorGroups.has(sensorId)) {
                                    sensorGroups.set(sensorId, []);
                                }
                                sensorGroups.get(sensorId).push(pair);
                            }
                            
                            let sensorConsumptions = [];
                            
                            if (periodType === 'week' && startDate && endDate) {
                                const weekStart = roundToWeekStart(startDate);
                                const mondayDate = new Date(weekStart.getTime() + 24 * 60 * 60 * 1000);
                                
                                for (const [sensorId, pairs] of sensorGroups.entries()) {
                                    const mondayValue = getValueAtOrBefore(pairs, mondayDate);
                                    const endValue = getLatestValue(pairs);
                                    
                                    if (mondayValue !== null && endValue !== null && endValue >= mondayValue) {
                                        const sensorConsumption = endValue - mondayValue;
                                        sensorConsumptions.push(sensorConsumption);
                                    }
                                }
                            } else {
                                // For other partial periods, use subtraction per sensor
                                for (const [sensorId, pairs] of sensorGroups.entries()) {
                                    const startValue = getValueJustBefore(pairs, startDate);
                                    const endValue = getLatestValue(pairs);
                                    
                                    if (startValue !== null && endValue !== null && endValue >= startValue) {
                                        const sensorConsumption = endValue - startValue;
                                        sensorConsumptions.push(sensorConsumption);
                                    }
                                }
                            }
                            
                            if (sensorConsumptions.length > 0) {
                                totalConsumption = sensorConsumptions.reduce((sum, v) => sum + v, 0);
                                base = Math.min(...sensorConsumptions);
                                averageEnergy = totalConsumption / sensorConsumptions.length;
                            } else {
                                // Fallback: use Case 6 logic (group by period)
                                const periodGroups = groupByPeriod(timestampValuePairs, 'day');
                                let dayTotals = [];
                                for (const [dayKey, pairs] of periodGroups.entries()) {
                                    if (pairs.length > 0) {
                                        // For multi-sensor: group by sensor, get MAX per sensor, then sum
                                        const sensorDayGroups = new Map();
                                        for (const pair of pairs) {
                                            const sensorId = pair.sensorId?.toString() || 'unknown';
                                            if (!sensorDayGroups.has(sensorId)) {
                                                sensorDayGroups.set(sensorId, []);
                                            }
                                            sensorDayGroups.get(sensorId).push(pair);
                                        }
                                        let sensorMaxes = [];
                                        for (const [sensorId, sensorPairs] of sensorDayGroups.entries()) {
                                            const sensorMax = Math.max(...sensorPairs.map(p => p.value));
                                            sensorMaxes.push(sensorMax);
                                        }
                                        const dayTotal = sensorMaxes.reduce((sum, v) => sum + v, 0);
                                        dayTotals.push(dayTotal);
                                    }
                                }
                                totalConsumption = dayTotals.reduce((sum, v) => sum + v, 0);
                                base = Math.min(...dayTotals);
                                averageEnergy = totalConsumption / dayTotals.length;
                            }
                        } else {
                            // Single sensor: use original logic
                            if (periodType === 'week' && startDate && endDate) {
                                const weekStart = roundToWeekStart(startDate);
                                const mondayValue = getValueAtOrBefore(timestampValuePairs, new Date(weekStart.getTime() + 24 * 60 * 60 * 1000));
                                const endValue = getLatestValue(timestampValuePairs);
                                
                                if (mondayValue !== null && endValue !== null && endValue >= mondayValue) {
                                    totalConsumption = endValue - mondayValue;
                                    base = Math.min(...energyValues);
                                    averageEnergy = totalConsumption;
                                } else {
                                    // Fallback: group by day and sum
                                    const dayGroups = groupByPeriod(timestampValuePairs, 'day');
                                    let dayTotals = [];
                                    for (const [dayKey, pairs] of dayGroups.entries()) {
                                        if (pairs.length > 0) {
                                            const dayMax = Math.max(...pairs.map(p => p.value));
                                            dayTotals.push(dayMax);
                                        }
                                    }
                                    totalConsumption = dayTotals.reduce((sum, v) => sum + v, 0);
                                    base = Math.min(...dayTotals);
                                    averageEnergy = totalConsumption / dayTotals.length;
                                }
                            } else {
                                // For other partial periods, use subtraction if possible
                                const startValue = getValueJustBefore(timestampValuePairs, startDate);
                                const endValue = getLatestValue(timestampValuePairs);
                                
                                if (startValue !== null && endValue !== null && endValue >= startValue) {
                                    totalConsumption = endValue - startValue;
                                    base = Math.min(...energyValues);
                                    averageEnergy = totalConsumption;
                                } else {
                                    // Fallback: use MAX
                                    totalConsumption = Math.max(...energyValues);
                                    base = Math.min(...energyValues);
                                    averageEnergy = totalConsumption;
                                }
                            }
                        }
                    } else {
                        // Fallback: use MAX for single period, SUM for multiple
                        if (isSinglePeriod) {
                            totalConsumption = Math.max(...energyValues);
                            base = Math.min(...energyValues);
                            averageEnergy = totalConsumption;
                        } else {
                            totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
                            base = Math.min(...energyValues);
                            averageEnergy = totalConsumption / energyValues.length;
                        }
                    }
                } else {
                    // Cumulative counter (total) or unknown: sum all values
                    totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
                    base = Math.min(...energyValues);
                    averageEnergy = totalConsumption / energyValues.length;
                }
                
                // Calculate quality from Energy measurements
                const qualitySum = energyData.avgQuality.reduce((sum, q) => sum + q, 0);
                avgQuality = qualitySum / energyData.avgQuality.length;
            } else {
                // All values were negative - log warning but set to 0
                console.warn(`[KPI] All Energy values were negative (meter resets detected), setting consumption to 0`);
                totalConsumption = 0;
                base = 0;
                averageEnergy = 0;
                avgQuality = energyData.avgQuality.length > 0 
                    ? energyData.avgQuality.reduce((sum, q) => sum + q, 0) / energyData.avgQuality.length 
                    : 100;
            }
        } else if (usePowerForEnergy && powerData && powerData.values.length > 0) {
            // For dashboard arbitrary ranges: calculate energy consumption from Power
            // Each power value represents average power during its time period
            // Energy (kWh) = Sum of (Power_i (kW) × Time_Period_i (hours))
            
            // Get resolution from options (default to 60 minutes/hourly if not provided)
            const resolutionMinutes = options.resolution || 60;
            const resolutionHours = resolutionMinutes / 60;
            
            // Calculate total energy by summing energy from each measurement period
            // Each power value represents average power during that period
            totalConsumption = powerData.values.reduce((sum, power) => sum + (power * resolutionHours), 0);
            
            // Base is minimum energy consumption (kWh), calculated from minimum power × resolution
            // Note: This differs from breakdown.min for Power (which is in kW) - base is in kWh (energy)
            base = Math.min(...powerData.values) * resolutionHours;
            
            // Average energy per measurement period
            averageEnergy = totalConsumption / powerData.values.length;
            
            // Average power (kW)
            const avgPower = powerData.values.reduce((sum, v) => sum + v, 0) / powerData.values.length;
            averagePower = avgPower;
            
            // Calculate quality from Power measurements
            const qualitySum = powerData.avgQuality.reduce((sum, q) => sum + q, 0);
            avgQuality = qualitySum / powerData.avgQuality.length;
        }
        
        // Find Power data for peak power (instantaneous maximum) and average power
        // Peak is maximum instantaneous power (kW) from Power measurements, not from Energy
        // Note: Peak is in kW (power), while base is in kWh (energy) - they represent different metrics
        if (powerData && powerData.values.length > 0) {
            const powerValues = powerData.values;
            peak = Math.max(...powerValues); // Maximum instantaneous power (kW)
            // Calculate average power if not already set
            if (averagePower === 0) {
                averagePower = powerValues.reduce((sum, v) => sum + v, 0) / powerValues.length;
            }
        } else if (energyData && energyData.values.length > 0) {
            // Fallback: use Energy max if no Power data available (less ideal, but provides a value)
            peak = Math.max(...energyData.values);
        }
        
        // Build breakdown for ALL measurement types found in the data
        // Group by measurementType (combine different stateTypes for same measurementType)
        // Track stateTypes to handle period totals correctly
        const breakdownMap = new Map();
        
        for (const [key, data] of processedResults.entries()) {
            const measurementType = data.measurementType;
            const stateType = data.stateType;
            const values = data.values;
            if (values.length === 0) continue;
            
            if (!breakdownMap.has(measurementType)) {
                breakdownMap.set(measurementType, {
                    measurement_type: measurementType,
                    values: [],
                    timestampValuePairs: [], // Preserve timestampValuePairs for multi-sensor breakdown calculation
                    stateTypes: new Set(), // Track all stateTypes for this measurementType
                    avgQuality: [],
                    count: 0,
                    baseUnit: data.baseUnit
                });
            }
            
            const breakdownItem = breakdownMap.get(measurementType);
            breakdownItem.values.push(...values);
            // Preserve timestampValuePairs for multi-sensor aggregation
            if (data.timestampValuePairs && Array.isArray(data.timestampValuePairs)) {
                breakdownItem.timestampValuePairs.push(...data.timestampValuePairs);
            }
            if (stateType) {
                breakdownItem.stateTypes.add(stateType);
            }
            breakdownItem.avgQuality.push(...data.avgQuality);
            breakdownItem.count += data.count;
        }
        
        // Sort timestampValuePairs by timestamp for each measurementType in breakdownMap
        for (const [measurementType, item] of breakdownMap.entries()) {
            if (item.timestampValuePairs && item.timestampValuePairs.length > 0) {
                item.timestampValuePairs.sort((a, b) => 
                    new Date(a.timestamp) - new Date(b.timestamp)
                );
            }
        }
        
        // Calculate statistics for each measurement type
        for (const [measurementType, item] of breakdownMap.entries()) {
            const values = item.values;
            const stateTypes = Array.from(item.stateTypes);
            
            // Check if this measurementType contains period totals (totalDay, totalWeek, etc.)
            const hasPeriodTotals = stateTypes.some(st => 
                st === 'totalDay' || st === 'totalWeek' || st === 'totalMonth' || st === 'totalYear' ||
                st === 'totalNegDay' || st === 'totalNegWeek' || st === 'totalNegMonth' || st === 'totalNegYear'
            );
            
            // Get timestampValuePairs for this measurementType (already preserved in breakdownMap)
            const timestampValuePairs = item.timestampValuePairs || [];
            
            // For Energy/Water/Heating with period totals: calculate total same way as main consumption
            // For cumulative counters or other types: sum all values
            let total;
            let min;
            let max;
            
            if ((measurementType === 'Energy' || measurementType === 'Water' || measurementType === 'Heating') && hasPeriodTotals) {
                // Period totals with multiple sensors: group by sensor, get MAX per sensor, then SUM
                // This matches the logic used for totalConsumption calculation
                const hasSensorId = timestampValuePairs.length > 0 && 
                    timestampValuePairs.some(p => p.sensorId !== undefined && p.sensorId !== null);
                
                if (hasSensorId) {
                    // Multiple sensors: Group by sensorId, get MAX per sensor, then SUM
                    const sensorGroups = new Map();
                    for (const pair of timestampValuePairs) {
                        // Handle ObjectId properly - convert to string
                        let sensorIdStr = 'unknown';
                        if (pair.sensorId) {
                            if (typeof pair.sensorId === 'object' && pair.sensorId.toString) {
                                sensorIdStr = pair.sensorId.toString();
                            } else if (typeof pair.sensorId === 'string') {
                                sensorIdStr = pair.sensorId;
                            } else {
                                sensorIdStr = String(pair.sensorId);
                            }
                        }
                        
                        if (!sensorGroups.has(sensorIdStr)) {
                            sensorGroups.set(sensorIdStr, []);
                        }
                        sensorGroups.get(sensorIdStr).push(pair);
                    }
                    
                    // Get MAX per sensor (period total for each sensor)
                    const sensorTotals = [];
                    for (const [sensorId, pairs] of sensorGroups.entries()) {
                        const pairValues = pairs.map(p => p.value);
                        const sensorMax = Math.max(...pairValues);
                        sensorTotals.push(sensorMax);
                    }
                    
                    // SUM all sensor totals (matches totalConsumption calculation)
                    total = sensorTotals.reduce((sum, v) => sum + v, 0);
                    min = Math.min(...sensorTotals);
                    max = Math.max(...sensorTotals);
                } else {
                    // Single sensor: use MAX (latest period total)
                    total = Math.max(...values);
                    min = Math.min(...values);
                    max = Math.max(...values);
                }
            } else {
                // Cumulative counters or other types: sum all values
                total = values.reduce((sum, v) => sum + v, 0);
                min = Math.min(...values);
                max = Math.max(...values);
            }
            
            const avg = values.length > 0 ? total / values.length : 0;
            const qualitySum = item.avgQuality.reduce((sum, q) => sum + q, 0);
            const avgQ = qualitySum / item.avgQuality.length;
            
            breakdown.push({
                measurement_type: measurementType,
                total: Math.round(total * 1000) / 1000,  // Round to 3 decimals
                average: Math.round(avg * 1000) / 1000,
                min: Math.round(min * 1000) / 1000, // Raw min value in native unit (kW for Power, °C for Temperature, etc.)
                max: Math.round(max * 1000) / 1000, // Raw max value in native unit
                count: item.count,
                unit: item.baseUnit // Native unit for this measurement type
            });
        }
        
        // Return structured KPIs with clear grouping by type (energy/power/quality)
        // Base calculation note: base is minimum energy consumption (kWh), calculated from Power min × hours
        // when using Power for energy. Breakdown min for Power shows raw power value (kW), which differs from
        // base (kWh) - this is expected and correct since base represents energy, not power.
        const kpis = {
            // Energy metrics (kWh) - consumption over time period
            energy: {
                total_consumption: Math.round(totalConsumption * 1000) / 1000, // Total energy consumed (kWh)
                average: Math.round(averageEnergy * 1000) / 1000, // Average energy per measurement period (kWh)
                base: Math.round(base * 1000) / 1000, // Minimum energy consumption (kWh) - calculated from Power min × hours when using Power for energy
                unit: 'kWh'
            },
            // Power metrics (kW) - instantaneous power measurements
            power: {
                peak: Math.round(peak * 1000) / 1000, // Maximum instantaneous power (kW)
                average: Math.round(averagePower * 1000) / 1000, // Average power (kW)
                unit: 'kW'
            },
            // Quality metrics
            quality: {
                average: Math.round(avgQuality * 100) / 100, // Average data quality percentage
                warning: avgQuality < 100 // True if quality issues detected
            },
            // Breakdown by measurement type (includes ALL types: Power, Temperature, Heating, Analog, etc.)
            // All measurement types found in the data are included here
            breakdown: breakdown
        };
        
        // Add backward compatibility fields only if explicitly requested (for legacy clients)
        // This reduces redundancy in the default response
        if (options.includeLegacyFields) {
            kpis.total_consumption = kpis.energy.total_consumption;
            kpis.peak = kpis.power.peak;
            kpis.base = kpis.energy.base;
            kpis.average = kpis.energy.average; // Same as energy.average
            kpis.averagePower = kpis.power.average; // Same as power.average
            kpis.averageEnergy = kpis.energy.average; // Same as energy.average (redundant with average)
            kpis.average_quality = kpis.quality.average; // Same as quality.average
            kpis.unit = energyUnit; // Backward compatibility (defaults to kWh)
            kpis.energyUnit = energyUnit; // Always 'kWh'
            kpis.powerUnit = powerUnit; // Always 'kW'
            kpis.data_quality_warning = kpis.quality.warning; // Same as quality.warning
        }
        
        return kpis;
    }

    /**
     * Get site-level KPIs (aggregate all buildings in site)
     * Uses sensorLookup to get sensor IDs for the site, then queries by meta.sensorId
     * @param {String} siteId - Site ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getSiteKPIs(siteId, startDate, endDate, options = {}) {
        // Get all sensor IDs for the site via sensorLookup
        const sensorIdsSet = await sensorLookup.getSensorIdsForSite(siteId);
        
        if (sensorIdsSet.size === 0) {
            return this.getEmptyKPIs();
        }
        
        const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));
        
        // Aggregate all sensors in the site
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution based on time range AND data age
        // For week-old data, we need to use hourly/daily aggregates (15-min may be deleted)
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            // Check how old the data is (hours since endDate)
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;
            
            if (days > 90 || daysSinceEndDate > 7) {
                // Very old data or long periods: use daily aggregates
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                // Week-old data or periods > 7 days: use hourly aggregates
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                // Data older than 1 hour: use hourly aggregates
                // (15-minute aggregates are deleted after 1 hour)
                resolution = 60; // hourly
            } else {
                // Recent data (within last hour): use 15-minute aggregates
                resolution = 15; // 15-minute
            }
        }
        
        // Query by sensor IDs (measurements no longer have buildingId in meta)
        const firstMatchStage = {
            'meta.sensorId': { $in: sensorIds },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        // Use smart query strategy for Energy measurements
        const interval = options.interval || null;
        const energySegments = determineOptimalEnergyQueryStrategy(startDate, endDate, options);
        
        // Collect all results from different segments
        const rawResults = [];
        const foundMeasurementTypes = new Set();
        
        // Query Energy measurements using total* states from each segment
        for (const segment of energySegments) {
            // Use fallback helper to query with automatic resolution fallback
            const baseMatchStage = {
                'meta.sensorId': { $in: sensorIds }
            };
            
            const segmentResults = await queryEnergyWithFallback(
                db,
                baseMatchStage,
                segment.resolution,
                segment.stateType,
                segment.startDate,
                segment.endDate
            );
            
            // Merge segment results
            for (const result of segmentResults) {
                const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                const existingResult = rawResults.find(r => 
                    r._id.measurementType === result._id.measurementType &&
                    r._id.stateType === result._id.stateType &&
                    r._id.unit === result._id.unit
                );
                
                if (existingResult) {
                    // Merge values, timestamps, and quality
                    existingResult.values.push(...result.values);
                    if (result.timestampValuePairs) {
                        if (!existingResult.timestampValuePairs) {
                            existingResult.timestampValuePairs = [];
                        }
                        existingResult.timestampValuePairs.push(...result.timestampValuePairs);
                        // Re-sort after merging
                        existingResult.timestampValuePairs.sort((a, b) => 
                            new Date(a.timestamp) - new Date(b.timestamp)
                        );
                    }
                    existingResult.count += result.count;
                    existingResult.avgQuality = (existingResult.avgQuality * (existingResult.count - result.count) + result.avgQuality * result.count) / existingResult.count;
        } else {
                    rawResults.push(result);
                    foundMeasurementTypes.add(result._id.measurementType);
                }
            }
        }
        
        // Also query Power measurements separately for peak power calculations
        const powerMatchStage = {
            'meta.sensorId': { $in: sensorIds },
            'meta.measurementType': 'Power',
            'meta.stateType': { $regex: '^actual' },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const powerPipeline = [
            { $match: powerMatchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const powerResults = await db.collection('measurements_aggregated').aggregate(powerPipeline).toArray();
        rawResults.push(...powerResults);
        foundMeasurementTypes.add('Power');
        
        // Query other measurement types if not filtering by measurementType
        if (!options.measurementType) {
            const otherMatchStage = {
                'meta.sensorId': { $in: sensorIds },
                'meta.measurementType': { $nin: ['Energy', 'Power'] },
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.stateType) {
                otherMatchStage['meta.stateType'] = options.stateType;
            }
            
            const otherPipeline = [
                { $match: otherMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                                unit: '$unit'
                            },
                            values: { $push: '$value' },
                            units: { $first: '$unit' },
                            avgQuality: { $avg: '$quality' },
                            count: { $sum: 1 }
                        }
                    }
                ];
                
            const otherResults = await db.collection('measurements_aggregated').aggregate(otherPipeline).toArray();
            rawResults.push(...otherResults);
            for (const result of otherResults) {
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }
        
        // Determine resolution for KPI calculation (use the most common resolution from segments)
        const finalResolution = energySegments.length > 0 && energySegments[0].preferred 
            ? energySegments[0].resolution 
            : resolution;
        
        // Pass time range and resolution for energy calculation
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval, finalResolution });
    }

    /**
     * Get building-level KPIs
     * Uses sensorLookup to get sensor IDs for the building, then queries by meta.sensorId
     * @param {String} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getBuildingKPIs(buildingId, startDate, endDate, options = {}) {
        const functionStartTime = Date.now();
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new ValidationError(`Invalid buildingId: ${buildingId}`);
        }
        
        // Get all sensor IDs for this building via sensorLookup
        const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
        
        if (sensorIdsSet.size === 0) {
            return this.getEmptyKPIs();
        }
        
        const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution based on time range AND data age
        // For week-old data, we need to use hourly/daily aggregates (15-min may be deleted)
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            // Check how old the data is (hours since endDate)
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;
            
            if (days > 90 || daysSinceEndDate > 7) {
                // Very old data or long periods: use daily aggregates
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                // Week-old data or periods > 7 days: use hourly aggregates
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                // Data older than 1 hour: use hourly aggregates
                // (15-minute aggregates are deleted after 1 hour)
                resolution = 60; // hourly
            } else {
                // Recent data (within last hour): use 15-minute aggregates
                resolution = 15; // 15-minute
            }
        }
        
        // Start timing matchStage construction
        const matchStageStartTime = Date.now();
        
        // Query by sensor IDs (measurements no longer have buildingId in meta)
        const matchStage = {
            'meta.sensorId': { $in: sensorIds },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        // Use smart query strategy for Energy measurements
        const interval = options.interval || null;
        const energySegments = determineOptimalEnergyQueryStrategy(startDate, endDate, options);
        
        // Collect all results from different segments
        const rawResults = [];
        const foundMeasurementTypes = new Set();
        
        // Query Energy measurements using total* states from each segment
        for (const segment of energySegments) {
            // Use fallback helper to query with automatic resolution fallback
            const baseMatchStage = {
                'meta.sensorId': { $in: sensorIds }
            };
            
            const segmentResults = await queryEnergyWithFallback(
                db,
                baseMatchStage,
                segment.resolution,
                segment.stateType,
                segment.startDate,
                segment.endDate
            );
            
            // Merge segment results
            for (const result of segmentResults) {
                const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                const existingResult = rawResults.find(r => 
                    r._id.measurementType === result._id.measurementType &&
                    r._id.stateType === result._id.stateType &&
                    r._id.unit === result._id.unit
                );
                
                if (existingResult) {
                    // Merge values, timestamps, and quality
                    existingResult.values.push(...result.values);
                    if (result.timestampValuePairs) {
                        if (!existingResult.timestampValuePairs) {
                            existingResult.timestampValuePairs = [];
                        }
                        existingResult.timestampValuePairs.push(...result.timestampValuePairs);
                        // Re-sort after merging
                        existingResult.timestampValuePairs.sort((a, b) => 
                            new Date(a.timestamp) - new Date(b.timestamp)
                        );
                    }
                    existingResult.count += result.count;
                    existingResult.avgQuality = (existingResult.avgQuality * (existingResult.count - result.count) + result.avgQuality * result.count) / existingResult.count;
        } else {
                    rawResults.push(result);
                    foundMeasurementTypes.add(result._id.measurementType);
                }
            }
        }
        
        // Also query Power measurements separately for peak power calculations
        const powerMatchStage = {
            'meta.sensorId': { $in: sensorIds },
            'meta.measurementType': 'Power',
            'meta.stateType': { $regex: '^actual' },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const powerPipeline = [
            { $match: powerMatchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const powerResults = await db.collection('measurements_aggregated').aggregate(powerPipeline).toArray();
        rawResults.push(...powerResults);
        foundMeasurementTypes.add('Power');
        
        // Query other measurement types if not filtering by measurementType
        if (!options.measurementType) {
            const otherMatchStage = {
                'meta.sensorId': { $in: sensorIds },
                'meta.measurementType': { $nin: ['Energy', 'Power'] },
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.stateType) {
                otherMatchStage['meta.stateType'] = options.stateType;
            }
            
            const otherPipeline = [
                { $match: otherMatchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
            const otherResults = await db.collection('measurements_aggregated').aggregate(otherPipeline).toArray();
            rawResults.push(...otherResults);
            for (const result of otherResults) {
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }
        
        const matchStageDuration = Date.now() - matchStageStartTime;
        const aggregationStartTime = Date.now();
        
        // If no results and querying recent data (resolution 15 or 0), try measurements_raw as fallback
        if (rawResults.length === 0 && (resolution === 15 || resolution === 0)) {
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            if (hoursSinceEndDate < 1) {
                // Recent data - try measurements_raw
                const rawMatchStage = {
                    ...matchStage,
                    resolution_minutes: 0
                };
                const rawPipeline = [
                    { $match: rawMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
                                stateType: '$meta.stateType', // Track stateType to distinguish total vs totalDay
                                unit: '$unit'
                            },
                            values: { $push: '$value' },
                            units: { $first: '$unit' },
                            avgQuality: { $avg: '$quality' },
                            count: { $sum: 1 }
                        }
                    }
                ];
                const rawDataResults = await db.collection('measurements_raw').aggregate(rawPipeline).toArray();
                if (rawDataResults.length > 0) {
                    rawResults = rawDataResults;
                }
            }
        }
        
        const aggregationDuration = Date.now() - aggregationStartTime;
        const totalDuration = Date.now() - functionStartTime;
        
        // Determine resolution for KPI calculation (use the most common resolution from segments)
        const finalResolution = energySegments.length > 0 && energySegments[0].preferred 
            ? energySegments[0].resolution 
            : resolution;
        
        // Pass time range and resolution for energy calculation
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval, finalResolution });
    }

    /**
     * Get building analytics (KPIs + additional analytics)
     * Combines KPIs with analytics like EUI, per capita, benchmark, etc.
     * @param {String} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options (interval, resolution, etc.)
     * @returns {Promise<Object>} Combined KPIs and analytics object
     */
    async getBuildingAnalytics(buildingId, startDate, endDate, options = {}) {
        // Get building object
        const building = await Building.findById(buildingId);
        if (!building) {
            throw new NotFoundError('Building');
        }

        // Get KPIs
        const kpis = await this.getBuildingKPIs(buildingId, startDate, endDate, options);

        // Prepare time range object for analytics
        const timeRange = {
            startDate,
            endDate
        };

        // Generate analytics (handle errors gracefully)
        // Group into: (1) Fast synchronous (use KPIs), (2) Independent async (can parallelize)
        const analytics = {};

        // Generate fast synchronous analytics first (use KPIs, no database queries)
        try {
            analytics.eui = await analyticsService.generateEUI(building, kpis, timeRange, buildingId);
        } catch (error) {
            console.warn(`[DASHBOARD] Error generating EUI for building ${buildingId}:`, error.message);
            analytics.eui = { available: false, message: error.message };
        }

        try {
            analytics.perCapita = await analyticsService.generatePerCapitaConsumption(building, kpis, buildingId);
        } catch (error) {
            console.warn(`[DASHBOARD] Error generating per capita consumption for building ${buildingId}:`, error.message);
            analytics.perCapita = { available: false, message: error.message };
        }

        try {
            analytics.benchmark = await analyticsService.generateBenchmarkComparison(building, kpis, timeRange, buildingId);
        } catch (error) {
            console.warn(`[DASHBOARD] Error generating benchmark comparison for building ${buildingId}:`, error.message);
            analytics.benchmark = { available: false, message: error.message };
        }

        try {
            analytics.dataQuality = analyticsService.generateDataQualityReport(kpis);
        } catch (error) {
            console.warn(`[DASHBOARD] Error generating data quality report for building ${buildingId}:`, error.message);
            analytics.dataQuality = { available: false, message: error.message };
        }

        // Generate async analytics in parallel with timeout protection
        const asyncAnalytics = [
            {
                key: 'inefficientUsage',
                generator: () => analyticsService.generateInefficientUsage(buildingId, timeRange, options.interval || null, this, kpis),
                timeout: 10000 // 10 seconds
            },
            {
                key: 'anomalies',
                generator: () => analyticsService.generateAnomalies(buildingId, timeRange),
                timeout: 15000 // 15 seconds
            },
            {
                key: 'timeBasedAnalysis',
                generator: () => analyticsService.generateTimeBasedAnalysis(buildingId, timeRange, options.interval || null),
                timeout: 15000 // 15 seconds
            },
            {
                key: 'buildingComparison',
                generator: () => analyticsService.generateBuildingComparison(buildingId, timeRange, options.interval || null, this),
                timeout: 20000 // 20 seconds (multiple buildings)
            },
            {
                key: 'temperatureAnalysis',
                generator: () => analyticsService.generateTemperatureAnalysis(buildingId, timeRange),
                timeout: 20000 // 20 seconds
            }
        ];

        // Helper function to generate with timeout
        const generateWithTimeout = async (key, generator, timeoutMs) => {
            return Promise.race([
                generator(),
                new Promise((_, reject) => 
                    setTimeout(() => reject(new Error(`Timeout: ${key} exceeded ${timeoutMs}ms`)), timeoutMs)
                )
            ]).catch(error => {
                if (error.message.includes('Timeout')) {
                    console.warn(`[DASHBOARD] Timeout generating ${key} for building ${buildingId}: ${error.message}`);
                    return { available: false, message: error.message, timeout: true };
                }
                throw error;
            });
        };

        // Process all async analytics in parallel
        const asyncPromises = asyncAnalytics.map(async ({ key, generator, timeout }) => {
            const startTime = Date.now();
            try {
                const result = await generateWithTimeout(key, generator, timeout);
                const duration = Date.now() - startTime;
                return { key, result };
            } catch (error) {
                const duration = Date.now() - startTime;
                return {
                    key,
                    result: {
                        available: false,
                        message: error.message,
                        timeout: error.message.includes('Timeout')
                    }
                };
            }
        });

        // Wait for all async analytics to complete (or timeout)
        const asyncResults = await Promise.allSettled(asyncPromises);

        // Process results
        asyncResults.forEach((settled) => {
            if (settled.status === 'fulfilled') {
                const { key, result } = settled.value;
                analytics[key] = result;
            } else {
                console.error(`[DASHBOARD] Promise rejected for analytics:`, settled.reason);
            }
        });

        // Set default values for failed analytics
        if (!analytics.anomalies) {
            analytics.anomalies = { total: 0, bySeverity: { High: 0, Medium: 0, Low: 0 }, anomalies: [] };
        }

        return {
            kpis,
            analytics
        };
    }

    /**
     * Get floor-level KPIs (aggregate all sensors in all rooms on floor)
     * @param {String} floorId - Floor ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getFloorKPIs(floorId, startDate, endDate, options = {}) {
        // Get all LocalRooms for this floor
        const localRooms = await LocalRoom.find({ floor_id: floorId })
            .populate('loxone_room_id')
            .lean();
        
        // Get all linked Loxone Room IDs for sensors
        const loxoneRoomIds = localRooms
            .filter(lr => lr.loxone_room_id && lr.loxone_room_id._id)
            .map(lr => lr.loxone_room_id._id);
        
        if (loxoneRoomIds.length === 0) {
            return this.getEmptyKPIs();
        }
        
        // Get all sensors for all linked Loxone rooms on this floor
        const sensors = await Sensor.find({ room_id: { $in: loxoneRoomIds } }).select('_id').lean();
        const sensorIds = sensors.map(s => s._id);
        
        if (sensorIds.length === 0) {
            return this.getEmptyKPIs();
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution based on time range AND data age
        // 15-minute aggregates are only kept for 1 hour, then deleted
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            // Check how old the data is (hours since endDate)
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;
            
            if (days > 90 || daysSinceEndDate > 7) {
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                // Data older than 1 hour: use hourly aggregates
                // (15-minute aggregates are deleted after 1 hour)
                resolution = 60; // hourly
            } else {
                // Recent data (within last hour): use 15-minute aggregates
                resolution = 15; // 15-minute
            }
        }
        
        // Use smart query strategy for Energy measurements
        const interval = options.interval || null;
        const energySegments = determineOptimalEnergyQueryStrategy(startDate, endDate, options);
        
        // Collect all results from different segments
        const rawResults = [];
        const foundMeasurementTypes = new Set();
        
        // Query Energy measurements using total* states from each segment
        for (const segment of energySegments) {
            // Use fallback helper to query with automatic resolution fallback
            const baseMatchStage = {
                'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) }
            };
            
            const segmentResults = await queryEnergyWithFallback(
                db,
                baseMatchStage,
                segment.resolution,
                segment.stateType,
                segment.startDate,
                segment.endDate
            );
            
            // Merge segment results
            for (const result of segmentResults) {
                const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                const existingResult = rawResults.find(r => 
                    r._id.measurementType === result._id.measurementType &&
                    r._id.stateType === result._id.stateType &&
                    r._id.unit === result._id.unit
                );
                
                if (existingResult) {
                    // Merge values, timestamps, and quality
                    existingResult.values.push(...result.values);
                    if (result.timestampValuePairs) {
                        if (!existingResult.timestampValuePairs) {
                            existingResult.timestampValuePairs = [];
                        }
                        existingResult.timestampValuePairs.push(...result.timestampValuePairs);
                        // Re-sort after merging
                        existingResult.timestampValuePairs.sort((a, b) => 
                            new Date(a.timestamp) - new Date(b.timestamp)
                        );
                    }
                    existingResult.count += result.count;
                    existingResult.avgQuality = (existingResult.avgQuality * (existingResult.count - result.count) + result.avgQuality * result.count) / existingResult.count;
        } else {
                    rawResults.push(result);
                    foundMeasurementTypes.add(result._id.measurementType);
                }
            }
        }
        
        // Also query Power measurements separately for peak power calculations
        const powerMatchStage = {
            'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
            'meta.measurementType': 'Power',
            'meta.stateType': { $regex: '^actual' },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const powerPipeline = [
            { $match: powerMatchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const powerResults = await db.collection('measurements_aggregated').aggregate(powerPipeline).toArray();
        rawResults.push(...powerResults);
        foundMeasurementTypes.add('Power');
        
        // Query other measurement types if not filtering by measurementType
        if (!options.measurementType) {
            const otherMatchStage = {
                'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
                'meta.measurementType': { $nin: ['Energy', 'Power'] },
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.stateType) {
                otherMatchStage['meta.stateType'] = options.stateType;
            }
            
            const otherPipeline = [
                { $match: otherMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                                unit: '$unit'
                            },
                            values: { $push: '$value' },
                            units: { $first: '$unit' },
                            avgQuality: { $avg: '$quality' },
                            count: { $sum: 1 }
                        }
                    }
                ];
                
            const otherResults = await db.collection('measurements_aggregated').aggregate(otherPipeline).toArray();
            rawResults.push(...otherResults);
            for (const result of otherResults) {
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }
        
        // Determine resolution for KPI calculation (use the most common resolution from segments)
        const finalResolution = energySegments.length > 0 && energySegments[0].preferred 
            ? energySegments[0].resolution 
            : resolution;
        
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval, finalResolution });
    }

    /**
     * Get room-level KPIs (aggregate all sensors in room)
     * @param {String} roomId - Room ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getRoomKPIs(roomId, startDate, endDate, options = {}) {
        // roomId is a Loxone Room ID (for sensor queries)
        const sensors = await Sensor.find({ room_id: roomId }).select('_id').lean();
        const sensorIds = sensors.map(s => s._id);
        
        if (sensorIds.length === 0) {
            return this.getEmptyKPIs();
        }
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution based on time range AND data age
        // 15-minute aggregates are only kept for 1 hour, then deleted
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            // Check how old the data is (hours since endDate)
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;
            
            if (days > 90 || daysSinceEndDate > 7) {
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                // Data older than 1 hour: use hourly aggregates
                // (15-minute aggregates are deleted after 1 hour)
                resolution = 60; // hourly
            } else {
                // Recent data (within last hour): use 15-minute aggregates
                resolution = 15; // 15-minute
            }
        }
        
        const matchStage = {
            'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        // Use smart query strategy for Energy measurements
        const interval = options.interval || null;
        const energySegments = determineOptimalEnergyQueryStrategy(startDate, endDate, options);
        
        // Collect all results from different segments
        const rawResults = [];
        const foundMeasurementTypes = new Set();
        
        // Query Energy measurements using total* states from each segment
        for (const segment of energySegments) {
            // Use fallback helper to query with automatic resolution fallback
            const baseMatchStage = {
                'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) }
            };
            
            const segmentResults = await queryEnergyWithFallback(
                db,
                baseMatchStage,
                segment.resolution,
                segment.stateType,
                segment.startDate,
                segment.endDate
            );
            
            // Merge segment results
            for (const result of segmentResults) {
                const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                const existingResult = rawResults.find(r => 
                    r._id.measurementType === result._id.measurementType &&
                    r._id.stateType === result._id.stateType &&
                    r._id.unit === result._id.unit
                );
                
                if (existingResult) {
                    // Merge values, timestamps, and quality
                    existingResult.values.push(...result.values);
                    if (result.timestampValuePairs) {
                        if (!existingResult.timestampValuePairs) {
                            existingResult.timestampValuePairs = [];
                        }
                        existingResult.timestampValuePairs.push(...result.timestampValuePairs);
                        // Re-sort after merging
                        existingResult.timestampValuePairs.sort((a, b) => 
                            new Date(a.timestamp) - new Date(b.timestamp)
                        );
                    }
                    existingResult.count += result.count;
                    existingResult.avgQuality = (existingResult.avgQuality * (existingResult.count - result.count) + result.avgQuality * result.count) / existingResult.count;
        } else {
                    rawResults.push(result);
                    foundMeasurementTypes.add(result._id.measurementType);
                }
            }
        }
        
        // Also query Power measurements separately for peak power calculations
        const powerMatchStage = {
            'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
            'meta.measurementType': 'Power',
            'meta.stateType': { $regex: '^actual' },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const powerPipeline = [
            { $match: powerMatchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const powerResults = await db.collection('measurements_aggregated').aggregate(powerPipeline).toArray();
        rawResults.push(...powerResults);
        foundMeasurementTypes.add('Power');
        
        // Query other measurement types if not filtering by measurementType
        if (!options.measurementType) {
            const otherMatchStage = {
                'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
                'meta.measurementType': { $nin: ['Energy', 'Power'] },
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.stateType) {
                otherMatchStage['meta.stateType'] = options.stateType;
            }
            
            const otherPipeline = [
                { $match: otherMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                                unit: '$unit'
                            },
                            values: { $push: '$value' },
                            units: { $first: '$unit' },
                            avgQuality: { $avg: '$quality' },
                            count: { $sum: 1 }
                        }
                    }
                ];
                
            const otherResults = await db.collection('measurements_aggregated').aggregate(otherPipeline).toArray();
            rawResults.push(...otherResults);
            for (const result of otherResults) {
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }
        
        // Determine resolution for KPI calculation (use the most common resolution from segments)
        const finalResolution = energySegments.length > 0 && energySegments[0].preferred 
            ? energySegments[0].resolution 
            : resolution;
        
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval, finalResolution });
    }

    /**
     * Get KPIs for all rooms in a building (optimized single query)
     * Uses sensorLookup to get sensor IDs, then queries by meta.sensorId
     * @param {String} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Map>} Map of roomId -> KPIs object
     */
    async getRoomsKPIs(buildingId, startDate, endDate, options = {}) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }

        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new ValidationError(`Invalid buildingId: ${buildingId}`);
        }

        // Get all sensor IDs for this building via sensorLookup
        const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
        
        if (sensorIdsSet.size === 0) {
            return new Map();
        }
        
        const sensorIds = Array.from(sensorIdsSet).map(id => new mongoose.Types.ObjectId(id));

        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);

        // Determine resolution based on time range AND data age
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;

            if (days > 90 || daysSinceEndDate > 7) {
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                resolution = 60; // hourly
            } else {
                resolution = 15; // 15-minute
            }
        }

        // Query by sensor IDs (measurements no longer have buildingId in meta)
        const firstMatchStage = {
            'meta.sensorId': { $in: sensorIds },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate },
        };

        // Determine stateType filtering based on options
        const interval = options.interval || null;
        const energyStateType = getStateTypeForInterval(interval);

        // Build second match stage for measurement types
        const secondMatchStage = {};
        if (options.measurementType) {
            secondMatchStage['meta.measurementType'] = options.measurementType;
            if (options.measurementType === 'Energy') {
                if (energyStateType) {
                    secondMatchStage['meta.stateType'] = energyStateType;
                } else {
                    secondMatchStage['meta.measurementType'] = 'Power';
                    secondMatchStage['meta.stateType'] = { $regex: '^actual' };
                }
            } else if (options.measurementType === 'Power') {
                secondMatchStage['meta.stateType'] = options.stateType || { $regex: '^actual' };
            } else if (options.stateType) {
                secondMatchStage['meta.stateType'] = options.stateType;
            }
        } else {
            const orConditions = [];
            if (energyStateType) {
                orConditions.push({ 'meta.measurementType': 'Energy', 'meta.stateType': energyStateType });
            } else {
                orConditions.push({ 'meta.measurementType': 'Power', 'meta.stateType': { $regex: '^actual' } });
            }
            orConditions.push({ 'meta.measurementType': 'Power', 'meta.stateType': { $regex: '^actual' } });
            orConditions.push({ 'meta.measurementType': { $nin: ['Energy', 'Power'] } });
            secondMatchStage.$or = orConditions;
        }

        // Pipeline: match -> lookup sensors -> group by room and measurementType
        const pipeline = [
            { $match: firstMatchStage }, // Uses compound index
            { $match: secondMatchStage }, // Filters reduced dataset
            {
                $lookup: {
                    from: 'sensors',
                    localField: 'meta.sensorId',
                    foreignField: '_id',
                    as: 'sensor'
                }
            },
            { $unwind: { path: '$sensor', preserveNullAndEmptyArrays: false } }, // Only keep measurements with valid sensors
            {
                $group: {
                    _id: {
                        roomId: '$sensor.room_id',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType', // Track stateType to distinguish total vs totalDay
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];

        // Query measurements_aggregated for aggregated data
        let rawResults = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();

        // Try fallback resolutions if no results
        if (rawResults.length === 0) {
            const fallbackResolutions = [];
            if (resolution === 15) {
                fallbackResolutions.push(60, 1440);
            } else if (resolution === 60) {
                fallbackResolutions.push(1440);
            }

            for (const fallbackResolution of fallbackResolutions) {
                const fallbackFirstMatch = {
                    ...firstMatchStage,
                    resolution_minutes: fallbackResolution
                };
                const fallbackPipeline = [
                    { $match: fallbackFirstMatch },
                    { $match: secondMatchStage },
                    {
                        $lookup: {
                            from: 'sensors',
                            localField: 'meta.sensorId',
                            foreignField: '_id',
                            as: 'sensor'
                        }
                    },
                    { $unwind: { path: '$sensor', preserveNullAndEmptyArrays: false } },
                    {
                        $group: {
                            _id: {
                                roomId: '$sensor.room_id',
                                measurementType: '$meta.measurementType',
                                stateType: '$meta.stateType', // Track stateType to distinguish total vs totalDay
                                unit: '$unit'
                            },
                            values: { $push: '$value' },
                            units: { $first: '$unit' },
                            avgQuality: { $avg: '$quality' },
                            count: { $sum: 1 }
                        }
                    }
                ];

                const fallbackResults = await db.collection('measurements_aggregated').aggregate(fallbackPipeline).toArray();
                if (fallbackResults.length > 0) {
                    rawResults = fallbackResults;
                    break;
                }
            }
        }

        // Group results by roomId
        const roomResultsMap = new Map();
        for (const result of rawResults) {
            const roomId = result._id.roomId?.toString();
            if (!roomId) continue;

            if (!roomResultsMap.has(roomId)) {
                roomResultsMap.set(roomId, []);
            }
            roomResultsMap.get(roomId).push(result);
        }

        // Calculate KPIs for each room
        const roomsKPIsMap = new Map();
        for (const [roomId, roomResults] of roomResultsMap.entries()) {
            const kpis = this.calculateKPIsFromResults(roomResults, { startDate, endDate, interval, resolution });
            roomsKPIsMap.set(roomId, kpis);
        }

        return roomsKPIsMap;
    }

    /**
     * Get KPIs for all buildings in a site (optimized single query)
     * Uses sensorLookup to get sensor IDs for all buildings, then queries by meta.sensorId
     * @param {Array<String>} buildingIds - Array of Building IDs
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Map>} Map of buildingId -> KPIs object
     */
    async getBuildingsKPIs(buildingIds, startDate, endDate, options = {}) {
        if (!buildingIds || buildingIds.length === 0) {
            return new Map();
        }

        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }

        // Validate all building IDs
        const validBuildingIds = buildingIds.filter(id => mongoose.Types.ObjectId.isValid(id));
        if (validBuildingIds.length === 0) {
            return new Map();
        }

        // Build sensor-to-building map and collect all sensor IDs
        const sensorToBuildingMap = new Map(); // sensorId (string) -> buildingId (string)
        const allSensorIds = [];
        
        for (const buildingId of validBuildingIds) {
            const sensorIdsSet = await sensorLookup.getSensorIdsForBuilding(buildingId);
            for (const sensorId of sensorIdsSet) {
                sensorToBuildingMap.set(sensorId, buildingId.toString());
                allSensorIds.push(new mongoose.Types.ObjectId(sensorId));
            }
        }
        
        if (allSensorIds.length === 0) {
            return new Map();
        }

        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);

        // Determine resolution based on time range AND data age
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;

            if (days > 90 || daysSinceEndDate > 7) {
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                resolution = 60; // hourly
            } else {
                resolution = 15; // 15-minute
            }
        }

        // Use smart query strategy for Energy measurements (same as getBuildingKPIs)
        const interval = options.interval || null;
        const energySegments = determineOptimalEnergyQueryStrategy(startDate, endDate, options);
        
        // Collect all results from different segments, grouped by building
        const buildingResultsMap = new Map(); // buildingId -> array of results
        const foundMeasurementTypes = new Set();
        
        // Query Energy measurements using total* states from each segment
        for (const segment of energySegments) {
            // Use fallback helper to query with automatic resolution fallback
            const baseMatchStage = {
                'meta.sensorId': { $in: allSensorIds }
            };
            
            const segmentResults = await queryEnergyWithFallback(
                db,
                baseMatchStage,
                segment.resolution,
                segment.stateType,
                segment.startDate,
                segment.endDate
            );
            
            // Group segment results by building
            for (const result of segmentResults) {
                // Group timestampValuePairs by building
                const buildingPairsMap = new Map(); // buildingId -> array of pairs
                
                if (result.timestampValuePairs && Array.isArray(result.timestampValuePairs)) {
                    for (const pair of result.timestampValuePairs) {
                        if (pair.sensorId) {
                            const sensorIdStr = pair.sensorId.toString();
                            const buildingId = sensorToBuildingMap.get(sensorIdStr);
                            if (buildingId) {
                                if (!buildingPairsMap.has(buildingId)) {
                                    buildingPairsMap.set(buildingId, []);
                                }
                                buildingPairsMap.get(buildingId).push(pair);
                            }
                        }
                    }
                }
                
                // Create building-specific results
                for (const [buildingId, buildingPairs] of buildingPairsMap.entries()) {
                    if (buildingPairs.length > 0) {
                        if (!buildingResultsMap.has(buildingId)) {
                            buildingResultsMap.set(buildingId, []);
                        }
                        
                        const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                        // Check if we already have a result for this building with the same key
                        const existingResult = buildingResultsMap.get(buildingId).find(r => 
                            r._id.measurementType === result._id.measurementType &&
                            r._id.stateType === result._id.stateType &&
                            r._id.unit === result._id.unit
                        );
                        
                        if (existingResult) {
                            // Merge with existing result
                            existingResult.timestampValuePairs.push(...buildingPairs);
                            existingResult.values.push(...buildingPairs.map(p => p.value));
                            existingResult.count += buildingPairs.length;
                            // Re-sort after merging
                            existingResult.timestampValuePairs.sort((a, b) => 
                                new Date(a.timestamp) - new Date(b.timestamp)
                            );
                        } else {
                            // Create new result for this building
                            const buildingResult = {
                                _id: {
                                    measurementType: result._id.measurementType,
                                    stateType: result._id.stateType,
                                    unit: result._id.unit
                                },
                                timestampValuePairs: buildingPairs,
                                values: buildingPairs.map(p => p.value),
                                units: result.units,
                                avgQuality: result.avgQuality,
                                count: buildingPairs.length
                            };
                            buildingResultsMap.get(buildingId).push(buildingResult);
                        }
                    }
                }
                
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }
        
        // Also query Power measurements separately for peak power calculations
        const powerMatchStage = {
            'meta.sensorId': { $in: allSensorIds },
            'meta.measurementType': 'Power',
            'meta.stateType': { $regex: '^actual' },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const powerPipeline = [
            { $match: powerMatchStage },
            {
                $group: {
                    _id: {
                        sensorId: '$meta.sensorId',
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    timestampValuePairs: {
                        $push: {
                            timestamp: '$timestamp',
                            value: '$value',
                            sensorId: '$meta.sensorId'
                        }
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const powerResults = await db.collection('measurements_aggregated').aggregate(powerPipeline).toArray();
        
        // Group Power results by building
        for (const result of powerResults) {
            const sensorId = result._id.sensorId?.toString();
            if (!sensorId) continue;
            
            const buildingId = sensorToBuildingMap.get(sensorId);
            if (!buildingId) continue;
            
            if (!buildingResultsMap.has(buildingId)) {
                buildingResultsMap.set(buildingId, []);
            }
            buildingResultsMap.get(buildingId).push(result);
        }
        foundMeasurementTypes.add('Power');
        
        // Query other measurement types if not filtering by measurementType
        if (!options.measurementType) {
            const otherMatchStage = {
                'meta.sensorId': { $in: allSensorIds },
                'meta.measurementType': { $nin: ['Energy', 'Power'] },
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.stateType) {
                otherMatchStage['meta.stateType'] = options.stateType;
            }
            
            const otherPipeline = [
                { $match: otherMatchStage },
                {
                    $group: {
                        _id: {
                            sensorId: '$meta.sensorId',
                            measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                            unit: '$unit'
                        },
                        timestampValuePairs: {
                            $push: {
                                timestamp: '$timestamp',
                                value: '$value',
                                sensorId: '$meta.sensorId'
                            }
                        },
                        values: { $push: '$value' },
                        units: { $first: '$unit' },
                        avgQuality: { $avg: '$quality' },
                        count: { $sum: 1 }
                    }
                }
            ];
            
            const otherResults = await db.collection('measurements_aggregated').aggregate(otherPipeline).toArray();
            
            // Group other results by building
            for (const result of otherResults) {
                const sensorId = result._id.sensorId?.toString();
                if (!sensorId) continue;
                
                const buildingId = sensorToBuildingMap.get(sensorId);
                if (!buildingId) continue;
                
                if (!buildingResultsMap.has(buildingId)) {
                    buildingResultsMap.set(buildingId, []);
                }
                buildingResultsMap.get(buildingId).push(result);
            }
            for (const result of otherResults) {
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }

        // Calculate KPIs for each building (merge results for same measurementType/stateType/unit)
        const buildingsKPIsMap = new Map();
        for (const [buildingId, buildingResults] of buildingResultsMap.entries()) {
            // Merge results by measurementType, stateType, and unit
            const mergedResultsMap = new Map();
            for (const result of buildingResults) {
                const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                if (!mergedResultsMap.has(key)) {
                    mergedResultsMap.set(key, {
                        _id: {
                            measurementType: result._id.measurementType,
                            stateType: result._id.stateType,
                            unit: result._id.unit
                        },
                        values: [],
                        timestampValuePairs: [], // Preserve timestampValuePairs with sensorId
                        units: result.units,
                        avgQuality: 0,
                        count: 0,
                        qualitySum: 0
                    });
                }
                const merged = mergedResultsMap.get(key);
                merged.values.push(...result.values);
                // Merge timestampValuePairs while preserving sensorId
                if (result.timestampValuePairs && Array.isArray(result.timestampValuePairs)) {
                    merged.timestampValuePairs.push(...result.timestampValuePairs);
                }
                merged.count += result.count;
                merged.qualitySum = (merged.qualitySum || 0) + (result.avgQuality * result.count);
            }
            
            // Finalize merged results - sort timestampValuePairs by timestamp
            const mergedResults = [];
            for (const merged of mergedResultsMap.values()) {
                merged.avgQuality = merged.count > 0 ? merged.qualitySum / merged.count : 0;
                delete merged.qualitySum;
                // Sort timestampValuePairs by timestamp for proper processing
                if (merged.timestampValuePairs && merged.timestampValuePairs.length > 0) {
                    merged.timestampValuePairs.sort((a, b) => 
                        new Date(a.timestamp) - new Date(b.timestamp)
                    );
                }
                mergedResults.push(merged);
            }
            
            // Determine resolution for KPI calculation (use the most common resolution from segments)
            const finalResolution = energySegments.length > 0 && energySegments[0].preferred 
                ? energySegments[0].resolution 
                : resolution;
            
            const kpis = this.calculateKPIsFromResults(mergedResults, { startDate, endDate, interval, finalResolution });
            buildingsKPIsMap.set(buildingId, kpis);
        }

        return buildingsKPIsMap;
    }

    /**
     * Get sensor-level KPIs
     * @param {String} sensorId - Sensor ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getSensorKPIs(sensorId, startDate, endDate, options = {}) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        if (!mongoose.Types.ObjectId.isValid(sensorId)) {
            throw new ValidationError(`Invalid sensorId: ${sensorId}`);
        }
        
        const sensorObjectId = new mongoose.Types.ObjectId(sensorId);
        const interval = options.interval || null;
        
        // Use smart query strategy for Energy measurements
        const energySegments = determineOptimalEnergyQueryStrategy(startDate, endDate, options);
        
        // Collect all results from different segments
        const rawResults = [];
        const foundMeasurementTypes = new Set();
        
        // Query Energy measurements using total* states from each segment
        for (const segment of energySegments) {
            // Use fallback helper to query with automatic resolution fallback
            const baseMatchStage = {
                'meta.sensorId': sensorObjectId
            };
            
            const segmentResults = await queryEnergyWithFallback(
                db,
                baseMatchStage,
                segment.resolution,
                segment.stateType,
                segment.startDate,
                segment.endDate
            );
            
            // Merge segment results
            for (const result of segmentResults) {
                const key = `${result._id.measurementType}:${result._id.stateType || 'unknown'}:${result._id.unit}`;
                const existingResult = rawResults.find(r => 
                    r._id.measurementType === result._id.measurementType &&
                    r._id.stateType === result._id.stateType &&
                    r._id.unit === result._id.unit
                );
                
                if (existingResult) {
                    // Merge values, timestamps, and quality
                    existingResult.values.push(...result.values);
                    if (result.timestampValuePairs) {
                        if (!existingResult.timestampValuePairs) {
                            existingResult.timestampValuePairs = [];
                        }
                        existingResult.timestampValuePairs.push(...result.timestampValuePairs);
                        // Re-sort after merging
                        existingResult.timestampValuePairs.sort((a, b) => 
                            new Date(a.timestamp) - new Date(b.timestamp)
                        );
                    }
                    existingResult.count += result.count;
                    existingResult.avgQuality = (existingResult.avgQuality * (existingResult.count - result.count) + result.avgQuality * result.count) / existingResult.count;
        } else {
                    rawResults.push(result);
                    foundMeasurementTypes.add(result._id.measurementType);
                }
            }
        }
        
        // Also query Power measurements separately for peak power calculations
        // Use the most appropriate resolution for Power (not necessarily the same as Energy)
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
        const daysSinceEndDate = hoursSinceEndDate / 24;
        
        let powerResolution = 15;
        if (options.resolution !== undefined) {
            powerResolution = options.resolution;
        } else {
            if (days > 90 || daysSinceEndDate > 7) {
                powerResolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                powerResolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                powerResolution = 60; // hourly
            } else {
                powerResolution = 15; // 15-minute
            }
        }
        
        const powerMatchStage = {
            'meta.sensorId': sensorObjectId,
            'meta.measurementType': 'Power',
            'meta.stateType': { $regex: '^actual' },
            resolution_minutes: powerResolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        const powerPipeline = [
            { $match: powerMatchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        stateType: '$meta.stateType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const powerResults = await db.collection('measurements_aggregated').aggregate(powerPipeline).toArray();
        rawResults.push(...powerResults);
        foundMeasurementTypes.add('Power');
        
        // Query other measurement types if not filtering by measurementType
        if (!options.measurementType) {
            const otherMatchStage = {
                'meta.sensorId': sensorObjectId,
                'meta.measurementType': { $nin: ['Energy', 'Power'] },
                resolution_minutes: powerResolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.stateType) {
                otherMatchStage['meta.stateType'] = options.stateType;
            }
            
            const otherPipeline = [
                { $match: otherMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
                            stateType: '$meta.stateType',
                                unit: '$unit'
                            },
                            values: { $push: '$value' },
                            units: { $first: '$unit' },
                            avgQuality: { $avg: '$quality' },
                            count: { $sum: 1 }
                        }
                    }
                ];
                
            const otherResults = await db.collection('measurements_aggregated').aggregate(otherPipeline).toArray();
            rawResults.push(...otherResults);
            for (const result of otherResults) {
                foundMeasurementTypes.add(result._id.measurementType);
            }
        }
        
        // If no Energy results found with total* states, try fallback to Power calculation
        if (!foundMeasurementTypes.has('Energy') && rawResults.length > 0) {
            // This will trigger Power-based energy calculation in calculateKPIsFromResults
            // No additional query needed - Power data is already in rawResults
        }
        
        // Determine resolution for KPI calculation (use the most common resolution from segments)
        const resolution = energySegments.length > 0 && energySegments[0].preferred 
            ? energySegments[0].resolution 
            : powerResolution;
        
        // Pass time range and resolution for energy calculation
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval, resolution });
    }

    /**
     * Get room measurements (all sensors in room)
     * @param {String} roomId - Room ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Array>} Measurements array
     */
    async getRoomMeasurements(roomId, startDate, endDate, options = {}) {
        // roomId is a Loxone Room ID (for sensor queries)
        const db = mongoose.connection.db;
        if (!db) {
            throw new ServiceUnavailableError('Database connection not available');
        }
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution based on time range AND data age
        // 15-minute aggregates are only kept for 1 hour, then deleted
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            // Check how old the data is (hours since endDate)
            const hoursSinceEndDate = (new Date() - endDate) / (1000 * 60 * 60);
            const daysSinceEndDate = hoursSinceEndDate / 24;
            
            if (days > 90 || daysSinceEndDate > 7) {
                resolution = 1440; // daily
            } else if (days > 7 || daysSinceEndDate > 1) {
                resolution = 60; // hourly
            } else if (hoursSinceEndDate > 1) {
                // Data older than 1 hour: use hourly aggregates
                // (15-minute aggregates are deleted after 1 hour)
                resolution = 60; // hourly
            } else {
                // Recent data (within last hour): use 15-minute aggregates
                resolution = 15; // 15-minute
            }
        }
        
        // Query by sensor IDs (measurements no longer have buildingId in meta)
            const sensors = await Sensor.find({ room_id: roomId }).select('_id').lean();
            const sensorIds = sensors.map(s => s._id);
            
            if (sensorIds.length === 0) {
                return {
                    data: [],
                    count: 0,
                    resolution: 15,
                    resolution_label: '15-minute'
                };
            }
            
            const matchStage = {
                'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate }
            };
            
            if (options.measurementType) {
                matchStage['meta.measurementType'] = options.measurementType;
            }
            
            // Query appropriate collection based on resolution
            const collectionName = resolution === 0 ? 'measurements_raw' : 'measurements_aggregated';
        const measurements = await db.collection(collectionName)
                .find(matchStage)
                .sort({ timestamp: 1 })
                .limit(options.limit || 1000)
                .toArray();
        
        return {
            data: measurements,
            count: measurements.length,
            resolution,
            resolution_label: this.getResolutionLabel(resolution)
        };
    }

    /**
     * Get empty KPIs object (when no data available)
     * @returns {Object} Empty KPIs
     */
    getEmptyKPIs() {
        return {
            total_consumption: 0,
            peak: 0,
            base: 0,
            average: 0,
            average_quality: 100,
            unit: 'kWh',
            data_quality_warning: false,
            breakdown: []
        };
    }

    /**
     * Get resolution label
     * @param {Number} resolution - Resolution in minutes
     * @returns {String} Resolution label
     */
    getResolutionLabel(resolution) {
        const labels = {
            0: 'raw',
            15: '15-minute',
            60: 'hourly',
            1440: 'daily',
            10080: 'weekly',
            43200: 'monthly'
        };
        return labels[resolution] || `${resolution}-minute`;
    }
}

module.exports = new DashboardDiscoveryService();

