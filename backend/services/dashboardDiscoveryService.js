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
            throw new Error('Start date must be before end date');
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
        console.log("get sites is called",userId)
        // Get user's accessible bryteswitch IDs
        const userRoles = await UserRole.find({ 
            user_id: userId
        }).select('bryteswitch_id');
        
        console.log('userRoles in getsites', userRoles);
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
        console.log('siteIds', siteIds);
        console.log('buildingCounts', buildingCounts);
        
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
            throw new Error('Site not found');
        }
        
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id._id || site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new Error('You do not have access to this site');
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
        console.log('getBuildingDetails', buildingId, userId, options);
        // Verify access
        const building = await Building.findById(buildingId).populate('site_id');
        if (!building) {
            throw new Error('Building not found');
        }
        
        const site = await Site.findById(building.site_id._id || building.site_id);
        if (!site) {
            throw new Error('Site not found');
        }
        
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new Error('You do not have access to this building');
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
        console.log('getFloorDetails', floorId, userId, options);
        const floor = await Floor.findById(floorId).populate('building_id');
        if (!floor) {
            throw new Error('Floor not found');
        }
        
        const building = await Building.findById(floor.building_id._id || floor.building_id);
        if (!building) {
            throw new Error('Building not found');
        }
        
        const site = await Site.findById(building.site_id);
        if (!site) {
            throw new Error('Site not found');
        }
        
        // Verify access
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new Error('You do not have access to this floor');
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
        
        // Get building KPIs (floor belongs to building)
        const kpis = await this.getBuildingKPIs(building._id, startDate, endDate, options);
        
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
            throw new Error('Room not found');
        }
        
        const floor = localRoom.floor_id;
        if (!floor) {
            throw new Error('Floor not found');
        }
        
        const building = floor.building_id;
        if (!building) {
            throw new Error('Building not found');
        }
        
        const site = building.site_id;
        if (!site) {
            throw new Error('Site not found');
        }
        
        // Verify access
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new Error('You do not have access to this room');
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
        
        // Get measurement data for room sensors if requested
        let measurements = null;
        if (options.includeMeasurements !== false && loxoneRoom && loxoneRoom._id) {
            // Pass buildingId for optimization if available
            const roomOptions = {
                ...options,
                buildingId: loxoneRoom.building_id || building._id
            };
            measurements = await this.getRoomMeasurements(loxoneRoom._id, startDate, endDate, roomOptions);
        }
        
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
            sensors: sensors.map(s => ({
                _id: s._id,
                name: s.name,
                unit: s.unit,
                roomId: s.room_id,
                loxone_control_uuid: s.loxone_control_uuid,
                loxone_category_type: s.loxone_category_type,
                created_at: s.created_at,
                updated_at: s.updated_at
            })),
            kpis,
            measurements,
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
            throw new Error('Sensor not found');
        }
        
        const room = await Room.findById(sensor.room_id._id || sensor.room_id);
        if (!room) {
            throw new Error('Room not found');
        }
        
        const building = await Building.findById(room.building_id);
        if (!building) {
            throw new Error('Building not found');
        }
        
        const site = await Site.findById(building.site_id);
        if (!site) {
            throw new Error('Site not found');
        }
        
        // Verify access
        const userRole = await UserRole.findOne({
            user_id: userId,
            bryteswitch_id: site.bryteswitch_id
        });
        
        if (!userRole) {
            const user = await User.findById(userId);
            if (!user || !user.is_superadmin) {
                throw new Error('You do not have access to this sensor');
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
        // Process results: normalize units and aggregate by measurementType
        console.log("rawResults", rawResults);
        const processedResults = new Map();
        
        for (const result of rawResults) {
            const measurementType = result._id.measurementType;
            const unit = result.units || '';
            const baseUnit = getBaseUnit(measurementType);
            
            if (!processedResults.has(measurementType)) {
                processedResults.set(measurementType, {
                    measurementType: measurementType,
                    values: [],
                    baseUnit: baseUnit,
                    avgQuality: [],
                    count: 0
                });
            }
            
            const processed = processedResults.get(measurementType);
            
            // Normalize all values to base unit
            const normalizedValues = result.values.map(v => normalizeToBaseUnit(v, unit));
            processed.values.push(...normalizedValues);
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
        const energyData = processedResults.get('Energy');
        // For dashboard arbitrary ranges: calculate energy from Power if no Energy data
        const powerData = processedResults.get('Power');
        const usePowerForEnergy = !energyData && powerData && powerData.values.length > 0 && !options.interval;
        // console.log(`[DEBUG] calculateKPIsFromResults:`, {
        //     hasEnergyData: !!energyData,
        //     energyValuesCount: energyData?.values?.length || 0,
        //     allMeasurementTypes: Array.from(processedResults.keys()),
        //     rawResultsCount: rawResults.length
        // });
        if (energyData && energyData.values.length > 0) {
            // Filter out negative values (meter resets or data issues)
            // Consumption cannot be negative - negative values indicate meter resets
            const validEnergyValues = energyData.values.filter(v => v >= 0);
            
            if (validEnergyValues.length > 0) {
                const energyValues = validEnergyValues;
                totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
                // Base is minimum energy consumption (kWh) from Energy measurements
                base = Math.min(...energyValues);
                averageEnergy = totalConsumption / energyValues.length;
                
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
            // Energy (kWh) = Average Power (kW) × Time Duration (hours)
            const avgPower = powerData.values.reduce((sum, v) => sum + v, 0) / powerData.values.length;
            const timeDurationHours = options.startDate && options.endDate
                ? (new Date(options.endDate) - new Date(options.startDate)) / (1000 * 60 * 60)
                : 0;
            
            if (timeDurationHours > 0) {
                totalConsumption = avgPower * timeDurationHours;
                // Base is minimum energy consumption (kWh), calculated from minimum power × hours
                // Note: This differs from breakdown.min for Power (which is in kW) - base is in kWh (energy)
                base = Math.min(...powerData.values) * timeDurationHours;
                // Average energy per measurement period = total consumption / number of measurement periods
                averageEnergy = totalConsumption / powerData.values.length;
                averagePower = avgPower; // Average power (kW)
                
                // Calculate quality from Power measurements
                const qualitySum = powerData.avgQuality.reduce((sum, q) => sum + q, 0);
                avgQuality = qualitySum / powerData.avgQuality.length;
            }
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
        // Includes: Power, Energy, Temperature, Analog, Heating, and any other measurement types that have data
        // Note: Breakdown shows raw values in their native units (kW for Power, °C for Temperature, m³ for Heating, etc.)
        // For Power: breakdown.min is in kW (power), while KPIs.base is in kWh (energy) - they represent different metrics
        // Temperature, Analog, and other non-energy types are included for informational purposes but don't contribute to total_consumption
        // All measurement types that have data will appear in the breakdown
        for (const [measurementType, data] of processedResults.entries()) {
            const values = data.values;
            if (values.length === 0) continue;
            
            const total = values.reduce((sum, v) => sum + v, 0);
            const avg = total / values.length;
            const min = Math.min(...values);
            const max = Math.max(...values);
            const qualitySum = data.avgQuality.reduce((sum, q) => sum + q, 0);
            const avgQ = qualitySum / data.avgQuality.length;
            
            breakdown.push({
                measurement_type: measurementType,
                total: Math.round(total * 1000) / 1000,  // Round to 3 decimals
                average: Math.round(avg * 1000) / 1000,
                min: Math.round(min * 1000) / 1000, // Raw min value in native unit (kW for Power, °C for Temperature, etc.)
                max: Math.round(max * 1000) / 1000, // Raw max value in native unit
                count: data.count,
                unit: data.baseUnit // Native unit for this measurement type
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
     * @param {String} siteId - Site ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getSiteKPIs(siteId, startDate, endDate, options = {}) {
        const buildings = await Building.find({ site_id: siteId }).select('_id').lean();
        const buildingIds = buildings.map(b => b._id);
        
        if (buildingIds.length === 0) {
            return this.getEmptyKPIs();
        }
        
        // Aggregate all buildings
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
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
        
        // Two-stage match for index optimization:
        // 1. First match uses compound index: { 'meta.buildingId': 1, resolution_minutes: 1, timestamp: -1 }
        // 2. Second match filters by measurementType/stateType on already-reduced dataset
        const firstMatchStage = {
            'meta.buildingId': { $in: buildingIds.map(id => new mongoose.Types.ObjectId(id)) },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        // Determine stateType filtering (same logic as getBuildingKPIs)
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
        
        const pipeline = [
            { $match: firstMatchStage }, // Uses compound index
            { $match: secondMatchStage }, // Filters reduced dataset
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
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
        
        // Track which measurement types we've found
        const foundMeasurementTypes = new Set(rawResults.map(r => r._id.measurementType));
        
        // Try fallback resolutions if:
        // 1. No results found at all, OR
        // 2. We're querying all measurement types (no measurementType filter) and might be missing some types
        const shouldTryFallback = rawResults.length === 0 || (!options.measurementType && foundMeasurementTypes.size < 5);
        
        if (shouldTryFallback) {
            const fallbackResolutions = [];
            
            // Determine fallback resolutions based on current resolution
            if (resolution === 15) {
                // Try hourly, then daily
                fallbackResolutions.push(60, 1440);
            } else if (resolution === 60) {
                // Try daily
                fallbackResolutions.push(1440);
            }
            
            // Try each fallback resolution and merge results
            for (const fallbackResolution of fallbackResolutions) {
                const fallbackFirstMatch = {
                    ...firstMatchStage,
                    resolution_minutes: fallbackResolution
                };
                
                const fallbackPipeline = [
                    { $match: fallbackFirstMatch },
                    { $match: secondMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
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
                    // Merge fallback results with existing results
                    // Only add measurement types we haven't found yet
                    for (const fallbackResult of fallbackResults) {
                        const measurementType = fallbackResult._id.measurementType;
                        if (!foundMeasurementTypes.has(measurementType)) {
                            rawResults.push(fallbackResult);
                            foundMeasurementTypes.add(measurementType);
                            // console.log(`[DEBUG] getSiteKPIs: Found ${measurementType} at resolution ${fallbackResolution} (preferred was ${resolution})`);
                        }
                    }
                    
                    // If we had no results initially, use fallback results and stop
                    if (rawResults.length === 0) {
                        rawResults = fallbackResults;
                        // console.log(`[DEBUG] getSiteKPIs: No data at resolution ${resolution}, found ${rawResults.length} results at resolution ${fallbackResolution}`);
                        break; // Found data, stop trying fallbacks
                    }
                }
            }
        }
        
        // Pass time range for energy calculation from Power
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval });
    }

    /**
     * Get building-level KPIs
     * @param {String} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Object>} KPIs object
     */
    async getBuildingKPIs(buildingId, startDate, endDate, options = {}) {
        const functionStartTime = Date.now();
        // console.log(`[PERF] getBuildingKPIs called at ${functionStartTime}`);
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new Error(`Invalid buildingId: ${buildingId}`);
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
        
        // Start timing matchStage construction
        const matchStageStartTime = Date.now();
        
        const matchStage = {
            'meta.buildingId': { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        // Determine stateType filtering based on options
        // For reports: use appropriate total* stateType based on interval
        // For dashboard (arbitrary ranges): use Power (actual* states) for energy calculation
        const interval = options.interval || null;
        const energyStateType = getStateTypeForInterval(interval);
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
            // For Energy measurements:
            // - If interval is specified (report): use appropriate total* stateType
            // - If no interval (dashboard arbitrary range): use Power (actual* states) for calculation
            if (options.measurementType === 'Energy') {
                if (energyStateType) {
                    // Report with fixed interval: use totalDay/totalWeek/totalMonth/totalYear
                    matchStage['meta.stateType'] = energyStateType;
                } else {
                    // Dashboard arbitrary range: use Power (actual* states) for energy calculation
                    // We'll calculate energy from Power data: energy = average_power × hours
                    matchStage['meta.measurementType'] = 'Power';
                    matchStage['meta.stateType'] = { $regex: '^actual' }; // actual, actual0, actual1, etc.
                }
            } else if (options.measurementType === 'Power') {
                // Power measurements: use actual* states
                matchStage['meta.stateType'] = options.stateType || { $regex: '^actual' };
            } else if (options.stateType) {
                // Allow explicit stateType for other measurement types
                matchStage['meta.stateType'] = options.stateType;
            }
        } else {
            // When querying all measurement types (no measurementType filter):
            // - Energy: use total* states if interval specified, otherwise use Power (actual*)
            // - Power: use actual* states
            // - Others (Temperature, Analog, Heating, etc.): no stateType filter - include ALL types
            const orConditions = [];
            
            if (energyStateType) {
                // Report: Energy with total* stateType
                orConditions.push({ 'meta.measurementType': 'Energy', 'meta.stateType': energyStateType });
            } else {
                // Dashboard: Use Power (actual* states) for energy calculation
                orConditions.push({ 'meta.measurementType': 'Power', 'meta.stateType': { $regex: '^actual' } });
            }
            
            // Power measurements: actual* states
            orConditions.push({ 'meta.measurementType': 'Power', 'meta.stateType': { $regex: '^actual' } });
            
            // Other measurement types (Temperature, Analog, Heating, etc.): no stateType filter
            // This ensures ALL measurement types are included in the breakdown
            orConditions.push({ 'meta.measurementType': { $nin: ['Energy', 'Power'] } });
            
            matchStage.$or = orConditions;
        }
        
        const matchStageDuration = Date.now() - matchStageStartTime;
        // console.log(`[PERF] getBuildingKPIs: matchStage construction took ${matchStageDuration}ms`);
        
        // Start timing pipeline construction
        const pipelineStartTime = Date.now();
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
                        unit: '$unit'
                    },
                    values: { $push: '$value' },
                    units: { $first: '$unit' },
                    avgQuality: { $avg: '$quality' },
                    count: { $sum: 1 }
                }
            }
        ];
        
        const pipelineDuration = Date.now() - pipelineStartTime;
        // console.log(`[PERF] getBuildingKPIs: pipeline construction took ${pipelineDuration}ms`);
        
        // Start timing aggregation execution
        const aggregationStartTime = Date.now();
        // console.log(`[PERF] getBuildingKPIs: starting aggregation at ${aggregationStartTime}`);
        
        // Query measurements_aggregated for aggregated data
        let rawResults = await db.collection('measurements_aggregated').aggregate(pipeline).toArray();
        
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
                    // console.log(`[DEBUG] getBuildingKPIs: Found ${rawResults.length} results in measurements_raw for recent data`);
                }
            }
        }
        
        const aggregationDuration = Date.now() - aggregationStartTime;
        const totalDuration = Date.now() - functionStartTime;
        // console.log(`[PERF] getBuildingKPIs: aggregation completed in ${aggregationDuration}ms (total function time: ${totalDuration}ms)`);
        // console.log(`[DEBUG] getBuildingKPIs query [${aggregationDuration}ms]:`, {
        //     buildingId,
        //     resolution,
        //     startDate: startDate.toISOString(),
        //     endDate: endDate.toISOString(),
        //     matchStage,
        //     resultCount: rawResults.length,
        //     resultTypes: rawResults.map(r => r._id.measurementType)
        // });
        
        // Track which measurement types we've found
        const foundMeasurementTypes = new Set(rawResults.map(r => r._id.measurementType));
        
        // Try fallback resolutions if:
        // 1. No results found at all, OR
        // 2. We're querying all measurement types (no measurementType filter) and might be missing some types
        // For report summaries, we only need Energy, Power, and Heating - so we can relax the condition
        // This ensures we find Temperature, Analog, and other types that might be at different resolutions
        // For report summaries (when options.isReportSummary is true), only try fallback if no results or missing critical types
        const isReportSummary = options.isReportSummary === true;
        const shouldTryFallback = rawResults.length === 0 || (!options.measurementType && (
            isReportSummary 
                ? (foundMeasurementTypes.size < 2 && (!foundMeasurementTypes.has('Energy') || !foundMeasurementTypes.has('Power')))
                : foundMeasurementTypes.size < 5
        ));
        
        if (shouldTryFallback) {
            const fallbackResolutions = [];
            
            // Determine fallback resolutions based on current resolution
            if (resolution === 15) {
                // Try hourly, then daily
                fallbackResolutions.push(60, 1440);
            } else if (resolution === 60) {
                // Try daily
                fallbackResolutions.push(1440);
            }
            
            // Try each fallback resolution and merge results
            for (const fallbackResolution of fallbackResolutions) {
                const fallbackStartTime = Date.now();
                const fallbackMatchStage = {
                    ...matchStage,
                    resolution_minutes: fallbackResolution
                };
                // Preserve $or structure if it exists
                if (matchStage.$or) {
                    fallbackMatchStage.$or = matchStage.$or;
                }
                
                const fallbackPipeline = [
                    { $match: fallbackMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
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
                const fallbackDuration = Date.now() - fallbackStartTime;
                
                if (fallbackResults.length > 0) {
                    // Merge fallback results with existing results
                    // Only add measurement types we haven't found yet
                    for (const fallbackResult of fallbackResults) {
                        const measurementType = fallbackResult._id.measurementType;
                        if (!foundMeasurementTypes.has(measurementType)) {
                            rawResults.push(fallbackResult);
                            foundMeasurementTypes.add(measurementType);
                            // console.log(`[DEBUG] getBuildingKPIs [${fallbackDuration}ms]: Found ${measurementType} at resolution ${fallbackResolution} (preferred was ${resolution})`);
                        }
                    }
                    
                    // If we had no results initially, use fallback results and stop
                    if (rawResults.length === 0) {
                        rawResults = fallbackResults;
                        // console.log(`[DEBUG] getBuildingKPIs [${fallbackDuration}ms]: No data at resolution ${resolution}, found ${rawResults.length} results at resolution ${fallbackResolution}`);
                        break; // Found data, stop trying fallbacks
                    }
                }
            }
        }
        // console.log("after calculateKPIsFromResults the time is ", Date.now());
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval: options.interval });
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
            throw new Error(`Building with ID ${buildingId} not found`);
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
                // console.log(`[DASHBOARD] ${key} generated in ${duration}ms${result.timeout ? ' (timeout)' : ''}`);
                return { key, result };
            } catch (error) {
                const duration = Date.now() - startTime;
                // console.warn(`[DASHBOARD] Error generating ${key} for building ${buildingId} (${duration}ms):`, error.message);
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
            throw new Error('Database connection not available');
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
        
        // Determine stateType filtering based on options (same logic as getBuildingKPIs)
        const interval = options.interval || null;
        const energyStateType = getStateTypeForInterval(interval);
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
            if (options.measurementType === 'Energy') {
                if (energyStateType) {
                    matchStage['meta.stateType'] = energyStateType;
                } else {
                    matchStage['meta.measurementType'] = 'Power';
                    matchStage['meta.stateType'] = { $regex: '^actual' };
                }
            } else if (options.measurementType === 'Power') {
                matchStage['meta.stateType'] = options.stateType || { $regex: '^actual' };
            } else if (options.stateType) {
                matchStage['meta.stateType'] = options.stateType;
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
            
            matchStage.$or = orConditions;
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
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
        
        // Track which measurement types we've found
        const foundMeasurementTypes = new Set(rawResults.map(r => r._id.measurementType));
        
        // Try fallback resolutions if:
        // 1. No results found at all, OR
        // 2. We're querying all measurement types (no measurementType filter) and might be missing some types
        const shouldTryFallback = rawResults.length === 0 || (!options.measurementType && foundMeasurementTypes.size < 5);
        
        if (shouldTryFallback) {
            const fallbackResolutions = [];
            
            // Determine fallback resolutions based on current resolution
            if (resolution === 15) {
                // Try hourly, then daily
                fallbackResolutions.push(60, 1440);
            } else if (resolution === 60) {
                // Try daily
                fallbackResolutions.push(1440);
            }
            
            // Try each fallback resolution and merge results
            for (const fallbackResolution of fallbackResolutions) {
                const fallbackMatchStage = {
                    ...matchStage,
                    resolution_minutes: fallbackResolution
                };
                // Preserve $or structure if it exists
                if (matchStage.$or) {
                    fallbackMatchStage.$or = matchStage.$or;
                }
                
                const fallbackPipeline = [
                    { $match: fallbackMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
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
                    // Merge fallback results with existing results
                    // Only add measurement types we haven't found yet
                    for (const fallbackResult of fallbackResults) {
                        const measurementType = fallbackResult._id.measurementType;
                        if (!foundMeasurementTypes.has(measurementType)) {
                            rawResults.push(fallbackResult);
                            foundMeasurementTypes.add(measurementType);
                            // console.log(`[DEBUG] getRoomKPIs: Found ${measurementType} at resolution ${fallbackResolution} (preferred was ${resolution})`);
                        }
                    }
                    
                    // If we had no results initially, use fallback results and stop
                    if (rawResults.length === 0) {
                        rawResults = fallbackResults;
                        // console.log(`[DEBUG] getRoomKPIs: No data at resolution ${resolution}, found ${rawResults.length} results at resolution ${fallbackResolution}`);
                        break; // Found data, stop trying fallbacks
                    }
                }
            }
        }
        
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval: options.interval });
    }

    /**
     * Get KPIs for all rooms in a building (optimized single query)
     * Uses meta.buildingId compound index instead of multiple meta.sensorId queries
     * @param {String} buildingId - Building ID
     * @param {Date} startDate - Start date
     * @param {Date} endDate - End date
     * @param {Object} options - Query options
     * @returns {Promise<Map>} Map of roomId -> KPIs object
     */
    async getRoomsKPIs(buildingId, startDate, endDate, options = {}) {
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }

        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new Error(`Invalid buildingId: ${buildingId}`);
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

        // Two-stage match for index optimization:
        // 1. First match uses compound index: { 'meta.buildingId': 1, resolution_minutes: 1, timestamp: -1 }
        // 2. Second match filters by measurementType/stateType on already-reduced dataset
        const firstMatchStage = {
            'meta.buildingId': new mongoose.Types.ObjectId(buildingId),
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
            const kpis = this.calculateKPIsFromResults(roomResults, { startDate, endDate, interval });
            roomsKPIsMap.set(roomId, kpis);
        }

        return roomsKPIsMap;
    }

    /**
     * Get KPIs for all buildings in a site (optimized single query)
     * Uses meta.buildingId compound index instead of multiple parallel queries
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
            throw new Error('Database connection not available');
        }

        // Validate all building IDs
        const validBuildingIds = buildingIds.filter(id => mongoose.Types.ObjectId.isValid(id));
        if (validBuildingIds.length === 0) {
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

        // Two-stage match for index optimization:
        // 1. First match uses compound index: { 'meta.buildingId': 1, resolution_minutes: 1, timestamp: -1 }
        // 2. Second match filters by measurementType/stateType on already-reduced dataset
        const firstMatchStage = {
            'meta.buildingId': { $in: validBuildingIds.map(id => new mongoose.Types.ObjectId(id)) },
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

        // Pipeline: match -> group by building and measurementType
        const pipeline = [
            { $match: firstMatchStage }, // Uses compound index
            { $match: secondMatchStage }, // Filters reduced dataset
            {
                $group: {
                    _id: {
                        buildingId: '$meta.buildingId',
                        measurementType: '$meta.measurementType',
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
                        $group: {
                            _id: {
                                buildingId: '$meta.buildingId',
                                measurementType: '$meta.measurementType',
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

        // Group results by buildingId
        const buildingResultsMap = new Map();
        for (const result of rawResults) {
            const buildingId = result._id.buildingId?.toString();
            if (!buildingId) continue;

            if (!buildingResultsMap.has(buildingId)) {
                buildingResultsMap.set(buildingId, []);
            }
            buildingResultsMap.get(buildingId).push(result);
        }

        // Calculate KPIs for each building
        const buildingsKPIsMap = new Map();
        for (const [buildingId, buildingResults] of buildingResultsMap.entries()) {
            const kpis = this.calculateKPIsFromResults(buildingResults, { startDate, endDate, interval });
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
            throw new Error('Database connection not available');
        }
        
        if (!mongoose.Types.ObjectId.isValid(sensorId)) {
            throw new Error(`Invalid sensorId: ${sensorId}`);
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
            'meta.sensorId': new mongoose.Types.ObjectId(sensorId),
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        // Determine stateType filtering (same logic as getBuildingKPIs)
        const interval = options.interval || null;
        const energyStateType = getStateTypeForInterval(interval);
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
            if (options.measurementType === 'Energy') {
                if (energyStateType) {
                    matchStage['meta.stateType'] = energyStateType;
                } else {
                    matchStage['meta.measurementType'] = 'Power';
                    matchStage['meta.stateType'] = { $regex: '^actual' };
                }
            } else if (options.measurementType === 'Power') {
                matchStage['meta.stateType'] = options.stateType || { $regex: '^actual' };
            } else if (options.stateType) {
                matchStage['meta.stateType'] = options.stateType;
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
            
            matchStage.$or = orConditions;
        }
        
        const pipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        measurementType: '$meta.measurementType',
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
        
        // Track which measurement types we've found
        const foundMeasurementTypes = new Set(rawResults.map(r => r._id.measurementType));
        
        // Try fallback resolutions if:
        // 1. No results found at all, OR
        // 2. We're querying all measurement types (no measurementType filter) and might be missing some types
        const shouldTryFallback = rawResults.length === 0 || (!options.measurementType && foundMeasurementTypes.size < 5);
        
        if (shouldTryFallback) {
            const fallbackResolutions = [];
            
            // Determine fallback resolutions based on current resolution
            if (resolution === 15) {
                // Try hourly, then daily
                fallbackResolutions.push(60, 1440);
            } else if (resolution === 60) {
                // Try daily
                fallbackResolutions.push(1440);
            }
            
            // Try each fallback resolution and merge results
            for (const fallbackResolution of fallbackResolutions) {
                const fallbackMatchStage = {
                    ...matchStage,
                    resolution_minutes: fallbackResolution
                };
                // Preserve $or structure if it exists
                if (matchStage.$or) {
                    fallbackMatchStage.$or = matchStage.$or;
                }
                
                const fallbackPipeline = [
                    { $match: fallbackMatchStage },
                    {
                        $group: {
                            _id: {
                                measurementType: '$meta.measurementType',
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
                    // Merge fallback results with existing results
                    // Only add measurement types we haven't found yet
                    for (const fallbackResult of fallbackResults) {
                        const measurementType = fallbackResult._id.measurementType;
                        if (!foundMeasurementTypes.has(measurementType)) {
                            rawResults.push(fallbackResult);
                            foundMeasurementTypes.add(measurementType);
                            // console.log(`[DEBUG] getSensorKPIs: Found ${measurementType} at resolution ${fallbackResolution} (preferred was ${resolution})`);
                        }
                    }
                    
                    // If we had no results initially, use fallback results and stop
                    if (rawResults.length === 0) {
                        rawResults = fallbackResults;
                        // console.log(`[DEBUG] getSensorKPIs: No data at resolution ${resolution}, found ${rawResults.length} results at resolution ${fallbackResolution}`);
                        break; // Found data, stop trying fallbacks
                    }
                }
            }
        }
        
        // Pass time range for energy calculation from Power
        return this.calculateKPIsFromResults(rawResults, { startDate, endDate, interval });
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
            throw new Error('Database connection not available');
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
        
        let measurements = [];
        
        // Optimize: If buildingId is provided, use buildingId query with sensor lookup
        // This uses the compound index and is faster than sensorId queries
        if (options.buildingId && mongoose.Types.ObjectId.isValid(options.buildingId)) {
            // Two-stage match for index optimization
            const firstMatchStage = {
                'meta.buildingId': new mongoose.Types.ObjectId(options.buildingId),
                resolution_minutes: resolution,
                timestamp: { $gte: startDate, $lt: endDate },
            };
            
            const secondMatchStage = {};
            if (options.measurementType) {
                secondMatchStage['meta.measurementType'] = options.measurementType;
            }
            
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
                { $unwind: { path: '$sensor', preserveNullAndEmptyArrays: false } },
                { $match: { 'sensor.room_id': new mongoose.Types.ObjectId(roomId) } }, // Filter by room
                { $sort: { timestamp: 1 } },
                { $limit: options.limit || 1000 }
            ];
            
            // Query measurements_aggregated (or measurements_raw for resolution 0)
            const collectionName = resolution === 0 ? 'measurements_raw' : 'measurements_aggregated';
            measurements = await db.collection(collectionName).aggregate(pipeline).toArray();
        } else {
            // Fallback: Use sensorId query (original implementation)
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
            measurements = await db.collection(collectionName)
                .find(matchStage)
                .sort({ timestamp: 1 })
                .limit(options.limit || 1000)
                .toArray();
        }
        
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

