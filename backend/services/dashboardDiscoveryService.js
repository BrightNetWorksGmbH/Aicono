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
            
            // Get building KPIs
            const kpis = await this.getBuildingKPIs(building._id, startDate, endDate, options);
            
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
        
        // Get building KPIs
        const kpis = await this.getBuildingKPIs(buildingId, startDate, endDate, options);
        
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
            kpis,
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
            measurements = await this.getRoomMeasurements(loxoneRoom._id, startDate, endDate, options);
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
    calculateKPIsFromResults(rawResults) {
        // Process results: normalize units and aggregate by measurementType
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
        let average = 0;
        let avgQuality = 100;
        let mainUnit = 'kWh';
        
        // Find Energy data for total_consumption, base, average
        const energyData = processedResults.get('Energy');
        if (energyData && energyData.values.length > 0) {
            const energyValues = energyData.values;
            totalConsumption = energyValues.reduce((sum, v) => sum + v, 0);
            base = Math.min(...energyValues);
            average = totalConsumption / energyValues.length;
            mainUnit = energyData.baseUnit || 'kWh';
            
            // Calculate quality from Energy measurements
            const qualitySum = energyData.avgQuality.reduce((sum, q) => sum + q, 0);
            avgQuality = qualitySum / energyData.avgQuality.length;
        }
        
        // Find Power data for peak power (instantaneous maximum)
        // Peak should be maximum instantaneous power (from Power measurements), not from Energy
        const powerData = processedResults.get('Power');
        if (powerData && powerData.values.length > 0) {
            const powerValues = powerData.values;
            peak = Math.max(...powerValues);
            // If we have Power data, update unit to kW for peak
            if (!mainUnit || mainUnit === 'kWh') {
                mainUnit = 'kW'; // Peak is in kW (power), not kWh (energy)
            }
        } else if (energyData && energyData.values.length > 0) {
            // Fallback: use Energy max if no Power data available
            peak = Math.max(...energyData.values);
        }
        
        // Build breakdown for all measurement types
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
                min: Math.round(min * 1000) / 1000,
                max: Math.round(max * 1000) / 1000,
                count: data.count,
                unit: data.baseUnit
            });
        }
        
        return {
            total_consumption: Math.round(totalConsumption * 1000) / 1000,
            peak: Math.round(peak * 1000) / 1000,
            base: Math.round(base * 1000) / 1000,
            average: Math.round(average * 1000) / 1000,
            average_quality: Math.round(avgQuality * 100) / 100,
            unit: mainUnit,
            data_quality_warning: avgQuality < 100,
            breakdown: breakdown
        };
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
        console.log('getSiteKPIs', siteId, startDate, endDate, options);
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
        
        // Determine resolution
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440; // daily
            } else if (days > 7) {
                resolution = 60; // hourly
            }
        }
        
        const matchStage = {
            'meta.buildingId': { $in: buildingIds.map(id => new mongoose.Types.ObjectId(id)) },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
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
        
        const rawResults = await db.collection('measurements').aggregate(pipeline).toArray();
        return this.calculateKPIsFromResults(rawResults);
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
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new Error(`Invalid buildingId: ${buildingId}`);
        }
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440; // daily
            } else if (days > 7) {
                resolution = 60; // hourly
            }
        }
        
        const matchStage = {
            'meta.buildingId': { 
                $in: [new mongoose.Types.ObjectId(buildingId), buildingId] 
            },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
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
        
        const rawResults = await db.collection('measurements').aggregate(pipeline).toArray();
        return this.calculateKPIsFromResults(rawResults);
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
        
        // Determine resolution
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440;
            } else if (days > 7) {
                resolution = 60;
            }
        }
        
        const matchStage = {
            'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
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
        
        const rawResults = await db.collection('measurements').aggregate(pipeline).toArray();
        return this.calculateKPIsFromResults(rawResults);
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
        
        // Determine resolution
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440;
            } else if (days > 7) {
                resolution = 60;
            }
        }
        
        const matchStage = {
            'meta.sensorId': new mongoose.Types.ObjectId(sensorId),
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
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
        
        const rawResults = await db.collection('measurements').aggregate(pipeline).toArray();
        return this.calculateKPIsFromResults(rawResults);
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
        
        const db = mongoose.connection.db;
        if (!db) {
            throw new Error('Database connection not available');
        }
        
        const duration = endDate - startDate;
        const days = duration / (1000 * 60 * 60 * 24);
        
        // Determine resolution
        let resolution = 15;
        if (options.resolution !== undefined) {
            resolution = options.resolution;
        } else {
            if (days > 90) {
                resolution = 1440;
            } else if (days > 7) {
                resolution = 60;
            }
        }
        
        const matchStage = {
            'meta.sensorId': { $in: sensorIds.map(id => new mongoose.Types.ObjectId(id)) },
            resolution_minutes: resolution,
            timestamp: { $gte: startDate, $lt: endDate }
        };
        
        if (options.measurementType) {
            matchStage['meta.measurementType'] = options.measurementType;
        }
        
        const measurements = await db.collection('measurements')
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

