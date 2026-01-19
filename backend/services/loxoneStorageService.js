const mongoose = require('mongoose');
const Room = require('../models/Room');
const Sensor = require('../models/Sensor');
const MeasurementData = require('../models/MeasurementData');
const Building = require('../models/Building');
const plausibilityCheckService = require('./plausibilityCheckService');

// Per-building UUID to Sensor mapping cache
const uuidMaps = new Map(); // buildingId -> Map<uuid, sensorMapping>

// Normalize UUID format
function normalizeUUID(uuid) {
    if (!uuid) return uuid;
    const clean = uuid.replace(/-/g, '');
    if (clean.length !== 32) return uuid;
    return [
        clean.substring(0, 8),
        clean.substring(8, 12),
        clean.substring(12, 16),
        clean.substring(16, 20),
        clean.substring(20, 32)
    ].join('-');
}

// Get measurement type from sensor, control type, and category
/**
 * Determine measurement type from sensor, control type, category, and format
 * Priority: 1. Format string (for Meter controls - most reliable), 2. Category type, 3. Category name, 4. Control type
 * Note: Format strings take priority because Meter controls can be in any category but the format indicates what they measure
 */
function getMeasurementType(sensor, controlType, categoryInfo = null, controlData = null, stateType = null) {
    // Priority 1: Check format string for Meter controls FIRST (most reliable indicator)
    // Meter controls can measure: Energy (kW/kWh), Temperature (°C), Gas/Water (m³/L), etc.
    // Format strings are more reliable than category names for determining what a meter actually measures
    if (controlType === 'Meter' && controlData && controlData.details) {
        // Choose format based on stateType: actualFormat for "actual", totalFormat for "total*" states
        let formatStr = '';
        if (stateType && stateType !== 'actual' && (stateType.startsWith('total') || stateType.startsWith('totalNeg'))) {
            formatStr = (controlData.details.totalFormat || controlData.details.actualFormat || '').toLowerCase();
        } else {
            formatStr = (controlData.details.actualFormat || controlData.details.totalFormat || '').toLowerCase();
        }
        
        // Temperature meter (format string is definitive)
        if (formatStr.includes('°c') || formatStr.includes('°f')) {
            return 'Temperature';
        }
        
        // Water/Gas meter
        if (formatStr.includes('m³') || formatStr.includes('m^3') || formatStr.includes(' l') || formatStr.includes('liter')) {
            // If in heating category, it's heating
            if (categoryInfo && categoryInfo.name && 
                (categoryInfo.name.toLowerCase().includes('heizung') || categoryInfo.name.toLowerCase().includes('heating'))) {
                return 'Heating';
            }
            return 'Water';
        }
        
        // Power meter (kW only, no kWh in format)
        if (formatStr.includes('kw') && !formatStr.includes('kwh')) {
            return 'Power';
        }
        
        // Energy meter (kWh or Wh in format)
        if (formatStr.includes('kwh') || formatStr.includes('wh')) {
            return 'Energy';
        }
    }
    
    // Priority 2: Category type (specific category types)
    if (categoryInfo && categoryInfo.type) {
        const categoryTypeMapping = {
            'indoortemperature': 'Temperature',
            'lights': 'Lighting',
            'shading': 'Shading',
            'media': 'Media',
            'multimedia': 'Media'
        };
        if (categoryTypeMapping[categoryInfo.type]) {
            return categoryTypeMapping[categoryInfo.type];
        }
    }
    
    // Priority 3: Category name (checks category name for keywords)
    if (categoryInfo && categoryInfo.name) {
        const categoryName = categoryInfo.name.toLowerCase();
        if (categoryName.includes('energie') || categoryName.includes('energy') || categoryName.includes('strom')) {
            return 'Energy';
        }
        if (categoryName.includes('temperatur') || categoryName.includes('temperature')) {
            return 'Temperature';
        }
        if (categoryName.includes('wasser') || categoryName.includes('water')) {
            return 'Water';
        }
        if (categoryName.includes('heizung') || categoryName.includes('heating')) {
            return 'Heating';
        }
        if (categoryName.includes('klima') || categoryName.includes('climate')) {
            return 'Climate';
        }
        if (categoryName.includes('beleuchtung') || categoryName.includes('light')) {
            return 'Lighting';
        }
    }
    
    // Priority 4: Control type defaults
    const typeMapping = {
        'Meter': 'Energy', // Default fallback, but should be overridden by format/category above
        'EFM': 'Energy',
        'EnergyMeter': 'Energy',
        'TemperatureController': 'Temperature',
        'WaterMeter': 'Water',
        'PowerMeter': 'Power',
        'AnalogInput': 'Analog',
        'InfoOnlyAnalog': 'Analog',
        'DigitalInput': 'Digital'
    };

    return typeMapping[controlType] || 'Unknown';
}

/**
 * Extract unit from format string (actualFormat, totalFormat, or format field)
 * According to Loxone Structure File spec, format strings contain units like: %.2f°C, %.3fkW, %.0fWh, etc.
 */
function extractUnitFromFormat(formatString) {
    if (!formatString || typeof formatString !== 'string') {
        return null;
    }
    
    const formatLower = formatString.toLowerCase();
    
    // Check for temperature units first (most specific)
    if (formatLower.includes('°c') || formatLower.includes('°c')) {
        return '°C';
    }
    if (formatLower.includes('°f') || formatLower.includes('°f')) {
        return '°F';
    }
    
    // Check for volume units
    if (formatLower.includes('m³') || formatLower.includes('m^3')) {
        // Check if it's per hour (flow rate)
        if (formatLower.includes('/h') || formatLower.includes('/hour')) {
            return 'm³/h';
        }
        return 'm³';
    }
    if (formatLower.includes(' l') || formatLower.includes('liter') || formatLower.includes(' l/h')) {
        return 'L';
    }
    
    // Check for energy/power units (order matters: kWh before kW, kW before W)
    if (formatLower.includes('kwh')) {
        return 'kWh';
    }
    if (formatLower.includes('kw') && !formatLower.includes('kwh')) {
        return 'kW';
    }
    if (formatLower.includes('wh')) {
        return 'Wh';
    }
    if (formatLower.includes('w') && !formatLower.includes('kw') && !formatLower.includes('wh')) {
        return 'W';
    }
    
    // Check for other common units
    if (formatLower.includes('v') || formatLower.includes(' volt')) {
        return 'V';
    }
    if (formatLower.includes('a') || formatLower.includes(' amp')) {
        return 'A';
    }
    if (formatLower.includes('%')) {
        return '%';
    }
    
    return null;
}

/**
 * Get unit from control type and details
 * Priority: 1. Format strings (actualFormat/totalFormat/format), 2. Control type defaults
 */
function getUnitFromControl(controlData) {
    if (!controlData) {
        return '';
    }
    
    // Priority 1: Check format strings in details
    if (controlData.details) {
        // Check actualFormat first (most specific for current value)
        if (controlData.details.actualFormat) {
            const unit = extractUnitFromFormat(controlData.details.actualFormat);
            if (unit) return unit;
        }
        
        // Check totalFormat (for cumulative values)
        if (controlData.details.totalFormat) {
            const unit = extractUnitFromFormat(controlData.details.totalFormat);
            if (unit) return unit;
        }
        
        // Check format field (for InfoOnlyAnalog, etc.)
        if (controlData.details.format) {
            const unit = extractUnitFromFormat(controlData.details.format);
            if (unit) return unit;
        }
        
        // Check unit field directly (if present)
        if (controlData.details.unit) {
            return controlData.details.unit;
        }
    }
    
    // Priority 2: Default based on control type
    const unitMapping = {
        'Meter': 'kWh', // Default fallback, but should be overridden by format check above
        'EFM': 'kWh',
        'EnergyMeter': 'kWh',
        'TemperatureController': '°C',
        'WaterMeter': 'L',
        'PowerMeter': 'kW',
        'InfoOnlyAnalog': '',
        'AnalogInput': ''
    };
    
    return unitMapping[controlData.type] || '';
}

class LoxoneStorageService {
    /**
     * Initialize storage for a building (create Time Series collection if needed)
     */
    async initializeForBuilding(buildingId) {
        try {
            const db = mongoose.connection.db;
            
            // Ensure Time Series collection exists
            const collections = await db.listCollections({ name: 'measurements' }).toArray();
            const collectionExists = collections.length > 0;
            
            let isTimeSeries = false;
            let hasCorrectMetaField = false;
            
            if (collectionExists) {
                const collectionInfo = collections[0];
                const options = collectionInfo.options || {};
                const timeseries = options.timeseries || {};
                isTimeSeries = !!(timeseries && timeseries.timeField);
                hasCorrectMetaField = timeseries.metaField === 'meta';
            }
            
            if (collectionExists && (!isTimeSeries || !hasCorrectMetaField)) {
                console.warn(`[LOXONE-STORAGE] [${buildingId}] Collection exists but is not valid Time Series, dropping...`);
                try {
                    await db.collection('measurements').drop();
                    await db.collection('system.buckets.measurements').drop().catch(() => {});
                    await new Promise(resolve => setTimeout(resolve, 100));
                } catch (error) {
                    if (!error.message.includes('ns not found')) {
                        throw error;
                    }
                }
            }
            
            if (!collectionExists || !isTimeSeries || !hasCorrectMetaField) {
                await db.createCollection('measurements', {
                    timeseries: {
                        timeField: 'timestamp',
                        metaField: 'meta',
                        granularity: 'seconds'
                    }
                });
                console.log(`[LOXONE-STORAGE] [${buildingId}] Created Time Series collection`);
            }

            // Create indexes
            const collection = db.collection('measurements');
            try {
                await collection.createIndex({ 'meta.sensorId': 1, timestamp: -1 });
                await collection.createIndex({ 'meta.buildingId': 1, timestamp: -1 });
                await collection.createIndex({ timestamp: -1 });
            } catch (error) {
                if (!error.message.includes('already exists')) {
                    console.warn(`[LOXONE-STORAGE] [${buildingId}] Index creation warning:`, error.message);
                }
            }
        } catch (error) {
            console.error(`[LOXONE-STORAGE] [${buildingId}] Error initializing:`, error.message);
            throw error;
        }
    }

    /**
     * Import structure from LoxAPP3.json for a building
     */
    async importStructureFromLoxAPP3(buildingId, loxAPP3Data) {
        const db = mongoose.connection.db;
        const buildingObjectId = new mongoose.Types.ObjectId(buildingId);
        
        // Verify building exists
        const building = await db.collection('buildings').findOne({ _id: buildingObjectId });
        if (!building) {
            throw new Error(`Building ${buildingId} not found`);
        }

        console.log(`[LOXONE-STORAGE] [${buildingId}] Importing structure from LoxAPP3.json...`);

        // 1. Import Rooms from LoxAPP3.json (Loxone rooms - with building_id, not floor_id)
        const roomMap = new Map(); // loxone_room_uuid -> room _id
        if (loxAPP3Data.rooms) {
            for (const [roomUUID, roomData] of Object.entries(loxAPP3Data.rooms)) {
                // Check for room by building_id AND loxone_room_uuid (not just UUID)
                // This ensures each building gets its own rooms even if they share the same Loxone server
                let room = await db.collection('rooms').findOne({ 
                    building_id: buildingObjectId,
                    loxone_room_uuid: roomUUID 
                });
                if (!room) {
                    const roomResult = await db.collection('rooms').insertOne({
                        building_id: buildingObjectId,
                        name: roomData.name || 'Unnamed Room',
                        loxone_room_uuid: roomUUID,
                        createdAt: new Date(),
                        updatedAt: new Date()
                    });
                    room = await db.collection('rooms').findOne({ _id: roomResult.insertedId });
                    console.log(`[LOXONE-STORAGE] [${buildingId}] Created Room: ${room.name} (${roomUUID.substring(0, 8)}...)`);
                } else {
                    console.log(`[LOXONE-STORAGE] [${buildingId}] Room already exists: ${room.name} (${roomUUID.substring(0, 8)}...)`);
                }
                roomMap.set(roomUUID, room._id);
            }
        }

        // 2. Import Sensors from LoxAPP3.json controls
        const sensorMap = new Map();
        const measurementTypes = [
            'TemperatureController', 'EnergyMeter', 'WaterMeter', 'PowerMeter',
            'AnalogInput', 'DigitalInput', 'Meter', 'InfoOnlyAnalog', 'EFM'
        ];

        const getCategoryInfo = (categoryUUID) => {
            if (!categoryUUID || !loxAPP3Data || !loxAPP3Data.cats) {
                return null;
            }
            return loxAPP3Data.cats[categoryUUID] || null;
        };

        const importControlAsSensor = async (controlUUID, controlData, roomUUID) => {
            if (!roomUUID || !roomMap.has(roomUUID)) {
                if (!roomUUID) {
                    console.warn(`[LOXONE-STORAGE] [${buildingId}] Control ${controlData?.name || controlUUID.substring(0, 8)} has no room UUID`);
                } else {
                    console.warn(`[LOXONE-STORAGE] [${buildingId}] Room UUID ${roomUUID.substring(0, 8)}... not found in roomMap for control ${controlData?.name || controlUUID.substring(0, 8)}`);
                }
                return null;
            }

            const roomId = roomMap.get(roomUUID);
            
            // Check for sensor by control UUID AND that it belongs to a room in this building
            // Use aggregation to join with rooms and filter by building_id
            // CRITICAL: Check for sensor by control UUID ONLY in the specific room for this building
            // This ensures each building gets its own sensors even when using the same Loxone server
            // We check by room_id directly (which is already scoped to this building) rather than
            // relying on aggregation to avoid any edge cases
            // IMPORTANT: Each building should have its own sensors, even with the same loxone_control_uuid,
            // because they belong to different rooms (via room_id) which belong to different buildings
            // Ensure roomId is an ObjectId (it should be, but verify for safety)
            const roomObjectId = roomId instanceof mongoose.Types.ObjectId 
                ? roomId 
                : new mongoose.Types.ObjectId(roomId);
            
            let sensor = await db.collection('sensors').findOne({
                loxone_control_uuid: controlUUID,
                room_id: roomObjectId  // Direct room_id match ensures sensor belongs to this building's room
            });
            
            if (!sensor) {
                const categoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;
                
                // Get unit from control data (checks format strings first, then defaults)
                const unit = getUnitFromControl(controlData);

                const sensorResult = await db.collection('sensors').insertOne({
                    room_id: roomObjectId,
                    name: controlData.name || 'Unnamed Sensor',
                    unit: unit,
                    loxone_control_uuid: controlUUID,
                    loxone_category_uuid: controlData.cat || null,
                    loxone_category_name: categoryInfo ? categoryInfo.name : null,
                    loxone_category_type: categoryInfo ? categoryInfo.type : null,
                    createdAt: new Date(),
                    updatedAt: new Date()
                });
                sensor = await db.collection('sensors').findOne({ _id: sensorResult.insertedId });
                console.log(`[LOXONE-STORAGE] [${buildingId}] Created Sensor: ${sensor.name} (${controlUUID.substring(0, 8)}...)`);
            } else {
                console.log(`[LOXONE-STORAGE] [${buildingId}] Sensor already exists: ${sensor.name} (${controlUUID.substring(0, 8)}...)`);
            }
            sensorMap.set(controlUUID, sensor._id);
            return sensor;
        };

        // Count controls for logging
        const totalControls = loxAPP3Data.controls ? Object.keys(loxAPP3Data.controls).length : 0;
        let processedControls = 0;
        let skippedControls = 0;
        const progressInterval = 50; // Log progress every 50 controls
        
        console.log(`[LOXONE-STORAGE] [${buildingId}] Starting sensor import from ${totalControls} controls...`);
        
        if (loxAPP3Data.controls) {
            for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                processedControls++;
                
                // Log progress periodically
                if (processedControls % progressInterval === 0) {
                    console.log(`[LOXONE-STORAGE] [${buildingId}] Processing controls... ${processedControls}/${totalControls} (${sensorMap.size} sensors created so far)`);
                }
                
                if (!measurementTypes.includes(controlData.type)) {
                    skippedControls++;
                    continue;
                }

                const roomUUID = controlData.room;
                if (!roomUUID) {
                    console.warn(`[LOXONE-STORAGE] [${buildingId}] Control ${controlData.name || controlUUID.substring(0, 8)} has no room UUID, skipping`);
                    continue;
                }
                
                await importControlAsSensor(controlUUID, controlData, roomUUID);
                
                if (controlData.subControls) {
                    for (const [subControlUUID, subControlData] of Object.entries(controlData.subControls)) {
                        if (subControlData.type === 'Meter') {
                            await importControlAsSensor(subControlUUID, subControlData, roomUUID);
                        }
                    }
                }
            }
        }
        
        console.log(`[LOXONE-STORAGE] [${buildingId}] Processed ${processedControls} controls (${skippedControls} skipped, ${processedControls - skippedControls} processed for sensors)`);

        console.log(`[LOXONE-STORAGE] [${buildingId}] Imported ${roomMap.size} rooms and ${sensorMap.size} sensors`);
        
        // Log sensor creation summary
        const sensorCount = sensorMap.size;
        if (sensorCount > 0) {
            console.log(`[LOXONE-STORAGE] [${buildingId}] ✓ Structure import complete: ${roomMap.size} rooms, ${sensorCount} sensors`);
        } else {
            console.warn(`[LOXONE-STORAGE] [${buildingId}] ⚠️  WARNING: Structure import completed but no sensors were created!`);
        }
        
        return { roomMap, sensorMap };
    }

    /**
     * Load structure mapping for a building
     */
    async loadStructureMapping(buildingId, loxAPP3Data = null) {
        try {
            if (!mongoose.Types.ObjectId.isValid(buildingId)) {
                throw new Error(`Invalid Building ID: ${buildingId}`);
            }

            const buildingObjectId = new mongoose.Types.ObjectId(buildingId);
            const db = mongoose.connection.db;

            const building = await db.collection('buildings').findOne({ _id: buildingObjectId });
            if (!building) {
                throw new Error(`Building ${buildingId} not found`);
            }

            // Check if structure needs to be imported
            const roomCount = await db.collection('rooms').countDocuments({ building_id: buildingObjectId });
            const sensorCount = await db.collection('sensors').aggregate([
                {
                    $lookup: {
                        from: 'rooms',
                        localField: 'room_id',
                        foreignField: '_id',
                        as: 'room'
                    }
                },
                { $unwind: '$room' },
                { $match: { 'room.building_id': buildingObjectId } }
            ]).toArray();

            if (roomCount === 0 || sensorCount.length === 0) {
                if (loxAPP3Data) {
                    console.log(`[LOXONE-STORAGE] [${buildingId}] Importing structure...`);
                    await this.importStructureFromLoxAPP3(buildingId, loxAPP3Data);
                } else {
                    throw new Error('No structure data available');
                }
            } else {
                console.log(`[LOXONE-STORAGE] [${buildingId}] Structure already imported (${sensorCount.length} sensors found)`);
            }

            // Load sensors for this building
            const sensors = await db.collection('sensors').aggregate([
                {
                    $lookup: {
                        from: 'rooms',
                        localField: 'room_id',
                        foreignField: '_id',
                        as: 'room'
                    }
                },
                { $unwind: '$room' },
                { $match: { 'room.building_id': buildingObjectId } }
            ]).toArray();

            console.log(`[LOXONE-STORAGE] [${buildingId}] Found ${sensors.length} sensors for this building`);

            // Build UUID mapping
            const uuidToSensorMap = new Map();
            
            const getCategoryInfo = (categoryUUID) => {
                if (!categoryUUID || !loxAPP3Data || !loxAPP3Data.cats) {
                    return null;
                }
                return loxAPP3Data.cats[categoryUUID] || null;
            };
            
            if (loxAPP3Data && loxAPP3Data.controls) {
                const controlToSensorMap = new Map();
                sensors.forEach(sensor => {
                    if (sensor.loxone_control_uuid) {
                        controlToSensorMap.set(sensor.loxone_control_uuid, sensor._id);
                    }
                });
                
                console.log(`[LOXONE-STORAGE] [${buildingId}] Building UUID mapping from ${controlToSensorMap.size} sensors and ${Object.keys(loxAPP3Data.controls).length} controls`);

                let mappedControls = 0;
                for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                    const sensorId = controlToSensorMap.get(controlUUID);
                    if (!sensorId) continue;
                    
                    mappedControls++;

                    const categoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;

                    if (controlData.states) {
                        for (const [stateName, stateUUID] of Object.entries(controlData.states)) {
                            const normalizedUUID = normalizeUUID(stateUUID);
                            uuidToSensorMap.set(normalizedUUID, {
                                sensor_id: sensorId,
                                stateType: stateName,
                                controlType: controlData.type,
                                controlName: controlData.name,
                                categoryInfo: categoryInfo,
                                controlData: controlData // Include full control data for measurement type detection
                            });
                        }
                    } else {
                        const normalizedUUID = normalizeUUID(controlUUID);
                        uuidToSensorMap.set(normalizedUUID, {
                            sensor_id: sensorId,
                            stateType: 'actual',
                            controlType: controlData.type,
                            controlName: controlData.name,
                            categoryInfo: categoryInfo,
                            controlData: controlData // Include full control data for measurement type detection
                        });
                    }
                }
                
                console.log(`[LOXONE-STORAGE] [${buildingId}] Mapped ${mappedControls} controls to sensors (created ${uuidToSensorMap.size} UUID entries so far)`);
                
                // Map subControls
                for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                    if (controlData.subControls) {
                        const parentCategoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;
                        
                        for (const [subControlUUID, subControlData] of Object.entries(controlData.subControls)) {
                            const sensorId = controlToSensorMap.get(subControlUUID);
                            if (!sensorId) continue;
                            
                            if (subControlData.states) {
                                for (const [stateName, stateUUID] of Object.entries(subControlData.states)) {
                                    const normalizedUUID = normalizeUUID(stateUUID);
                                    uuidToSensorMap.set(normalizedUUID, {
                                        sensor_id: sensorId,
                                        stateType: stateName,
                                        controlType: subControlData.type,
                                        controlName: subControlData.name,
                                        categoryInfo: parentCategoryInfo,
                                        controlData: subControlData // Include full control data for measurement type detection
                                    });
                                }
                            }
                        }
                    }
                }
            } else {
                sensors.forEach(sensor => {
                    if (sensor.loxone_control_uuid) {
                        uuidToSensorMap.set(sensor.loxone_control_uuid, {
                            sensor_id: sensor._id,
                            stateType: 'actual',
                            controlType: 'Unknown',
                            controlName: sensor.name
                        });
                    }
                });
            }

            // Store mapping for this building
            uuidMaps.set(buildingId, uuidToSensorMap);
            
            if (uuidToSensorMap.size === 0) {
                console.warn(`[LOXONE-STORAGE] [${buildingId}] ⚠️  WARNING: UUID mapping is empty! No measurements can be stored for this building.`);
                console.warn(`[LOXONE-STORAGE] [${buildingId}] Sensors found: ${sensors.length}, Controls in structure: ${loxAPP3Data?.controls ? Object.keys(loxAPP3Data.controls).length : 0}`);
            } else {
                console.log(`[LOXONE-STORAGE] [${buildingId}] ✓ Loaded ${uuidToSensorMap.size} UUID mappings`);
            }
            return uuidToSensorMap;
        } catch (error) {
            console.error(`[LOXONE-STORAGE] [${buildingId}] Error loading structure mapping:`, error.message);
            // Check if it's a duplicate key error (index issue)
            if (error.message.includes('E11000') || error.message.includes('duplicate key')) {
                console.error(`[LOXONE-STORAGE] [${buildingId}] ⚠️  Duplicate key error detected!`);
                console.error(`[LOXONE-STORAGE] [${buildingId}] This indicates the old unique indexes still exist in MongoDB.`);
                console.error(`[LOXONE-STORAGE] [${buildingId}] Please run: node scripts/fixRoomSensorIndexes.js`);
                console.error(`[LOXONE-STORAGE] [${buildingId}] Then restart the server to retry structure import.`);
            }
            throw error;
        }
    }

    /**
     * Store measurements for a building
     * Optimized to avoid N+1 queries by batching sensor lookups
     */
    async storeMeasurements(buildingId, measurements) {
        // Check connection health
        if (mongoose.connection.readyState !== 1) {
            console.warn(`[LOXONE-STORAGE] [${buildingId}] MongoDB not connected (readyState: ${mongoose.connection.readyState})`);
            return { stored: 0, skipped: measurements.length, error: 'not_connected' };
        }

        // Import services for plausibility checks (lazy load to avoid circular dependencies)
        
        const alarmService = require('./alarmService');
        const alertNotificationService = require('./alertNotificationService');

        const uuidToSensorMap = uuidMaps.get(buildingId);
        if (!uuidToSensorMap || uuidToSensorMap.size === 0) {
            console.log(`[LOXONE-STORAGE] [${buildingId}] UUID map is empty, reloading...`);
            // Try to reload from structure file
            const fs = require('fs');
            const path = require('path');
            const structureFilesDir = path.join(__dirname, '../../data/loxone-structure');
            const structureFilePath = path.join(structureFilesDir, `LoxAPP3_${buildingId}.json`);
            if (fs.existsSync(structureFilePath)) {
                try {
                    const loxAPP3Data = JSON.parse(fs.readFileSync(structureFilePath, 'utf8'));
                    await this.loadStructureMapping(buildingId, loxAPP3Data);
                    // Verify the map was loaded
                    const reloadedMap = uuidMaps.get(buildingId);
                    if (!reloadedMap || reloadedMap.size === 0) {
                        console.warn(`[LOXONE-STORAGE] [${buildingId}] Structure mapping still empty after reload, skipping measurements`);
                        return { stored: 0, skipped: measurements.length };
                    }
                } catch (reloadError) {
                    console.error(`[LOXONE-STORAGE] [${buildingId}] Error reloading structure mapping:`, reloadError.message);
                    // Check if it's a duplicate key error (index issue)
                    if (reloadError.message.includes('E11000') || reloadError.message.includes('duplicate key')) {
                        console.error(`[LOXONE-STORAGE] [${buildingId}] ⚠️  Duplicate key error detected!`);
                        console.error(`[LOXONE-STORAGE] [${buildingId}] This indicates the old unique indexes still exist in MongoDB.`);
                        console.error(`[LOXONE-STORAGE] [${buildingId}] Please run: node scripts/fixRoomSensorIndexes.js`);
                    }
                    return { stored: 0, skipped: measurements.length, error: 'reload_failed' };
                }
            } else {
                console.warn(`[LOXONE-STORAGE] [${buildingId}] No structure file found at ${structureFilePath}, skipping measurements`);
                return { stored: 0, skipped: measurements.length };
            }
        }

        const db = mongoose.connection.db;
        const currentMap = uuidMaps.get(buildingId) || new Map();

        // Step 1: Collect all unique sensor IDs (optimize N+1 query problem)
        const sensorIds = new Set();
        const validMeasurements = [];
        
        for (const measurement of measurements) {
            const normalizedUUID = normalizeUUID(measurement.uuid);
            const mapping = currentMap.get(normalizedUUID);
            
            if (!mapping || !mapping.sensor_id) {
                continue;
            }
            
            sensorIds.add(mapping.sensor_id);
            validMeasurements.push({
                measurement,
                mapping,
                normalizedUUID
            });
        }

        if (validMeasurements.length === 0) {
            return { stored: 0, skipped: measurements.length };
        }

        // Step 2: Batch fetch all sensors at once (single query instead of N queries)
        let sensorMap = new Map();
        try {
            const sensorIdsArray = Array.from(sensorIds);
            const sensors = await db.collection('sensors')
                .find({ _id: { $in: sensorIdsArray } })
                .toArray();
            
            // Create a map for O(1) lookup
            sensorMap = new Map(
                sensors.map(sensor => [sensor._id.toString(), sensor])
            );
        } catch (error) {
            console.error(`[LOXONE-STORAGE] [${buildingId}] Error fetching sensors:`, error.message);
            return { stored: 0, skipped: measurements.length, error: 'sensor_fetch_failed' };
        }

        // Step 3: Build documents using the sensor map and validate plausibility
        const documents = [];
        let skippedCount = 0;
        const buildingObjectId = mongoose.Types.ObjectId.isValid(buildingId) 
            ? new mongoose.Types.ObjectId(buildingId) 
            : buildingId;

        for (const { measurement, mapping } of validMeasurements) {
            const sensor = sensorMap.get(mapping.sensor_id.toString());
            if (!sensor) {
                skippedCount++;
                continue;
            }
            
            // Get category info from mapping or sensor
            const categoryInfo = mapping.categoryInfo || (sensor.loxone_category_type || sensor.loxone_category_name ? {
                type: sensor.loxone_category_type,
                name: sensor.loxone_category_name
            } : null);
            
            // Use control data from mapping if available (includes format strings), otherwise reconstruct minimal version
            const controlData = mapping.controlData || (mapping.controlType ? {
                type: mapping.controlType,
                details: sensor.unit ? {
                    actualFormat: sensor.unit.includes('°C') ? `%.2f°C` : 
                                  sensor.unit.includes('kW') ? `%.3f${sensor.unit}` :
                                  sensor.unit ? `%.2f${sensor.unit}` : null
                } : null
            } : null);
            
            // Determine unit based on stateType and format strings (actualFormat vs totalFormat)
            // This ensures correct units for different state types (actual vs total*)
            let unit = sensor.unit || ''; // Default to stored unit
            if (controlData && controlData.details && mapping.stateType) {
                // For Meter controls, use the appropriate format based on stateType
                if (mapping.controlType === 'Meter') {
                    let formatStr = '';
                    if (mapping.stateType === 'actual') {
                        formatStr = controlData.details.actualFormat || controlData.details.totalFormat || '';
                    } else if (mapping.stateType.startsWith('total') || mapping.stateType.startsWith('totalNeg')) {
                        formatStr = controlData.details.totalFormat || controlData.details.actualFormat || '';
                    } else {
                        formatStr = controlData.details.actualFormat || controlData.details.totalFormat || '';
                    }
                    
                    // Extract unit from format string
                    const extractedUnit = extractUnitFromFormat(formatStr);
                    if (extractedUnit) {
                        unit = extractedUnit;
                    }
                } else {
                    // For non-Meter controls, extract from format if available
                    const formatStr = controlData.details.actualFormat || controlData.details.totalFormat || controlData.details.format || '';
                    const extractedUnit = extractUnitFromFormat(formatStr);
                    if (extractedUnit) {
                        unit = extractedUnit;
                    }
                }
            }
            
            // Determine measurement type (pass stateType for better detection)
            const measurementType = getMeasurementType(sensor, mapping.controlType, categoryInfo, controlData, mapping.stateType);
            
            // Priority 1: Filter invalid "total*" states for Temperature measurement type
            // Temperature meters' "total" states represent cumulative values (degree-hours) that shouldn't be stored as temperature
            if (measurementType === 'Temperature' && 
                (mapping.stateType.startsWith('total') || mapping.stateType.startsWith('totalNeg'))) {
                // Skip storing cumulative temperature values as temperature measurements
                // console.warn(`[LOXONE-STORAGE] [${buildingId}] Skipping temperature total state: ${mapping.stateType} for sensor ${sensor.name} (value: ${measurement.value})`);
                skippedCount++;
                continue;
            }
            
            // Priority 2: Enhanced Temperature Validation - Check for implausible temperature values
            // Reasonable temperature range: -50°C to 100°C for indoor/outdoor sensors
            if (measurementType === 'Temperature') {
                if (measurement.value < -50 || measurement.value > 100) {
                    console.warn(`[LOXONE-STORAGE] [${buildingId}] Implausible temperature value: ${measurement.value}°C for sensor ${sensor.name} (stateType: ${mapping.stateType}). Skipping measurement.`);
                    skippedCount++;
                    continue;
                }
            }
            
            const measurementTimestamp = measurement.timestamp || new Date();
            
            // Perform plausibility check before storing
            try {
                const validation = await plausibilityCheckService.validateMeasurement(
                    sensor._id,
                    measurement.value,
                    measurementType,
                    measurementTimestamp
                );
                
                // If validation fails, create alarm log entries
                if (!validation.isValid && validation.violations.length > 0) {
                    for (const violation of validation.violations) {
                        try {
                            const alarmLog = await alarmService.createPlausibilityAlarm(
                                violation,
                                sensor._id,
                                measurement.value,
                                measurementTimestamp
                            );
                            
                            // Trigger email notification asynchronously (don't block storage)
                            alertNotificationService.sendAlertReport(alarmLog._id).catch(err => {
                                console.error(`[LOXONE-STORAGE] [${buildingId}] Failed to send alert email for alarm ${alarmLog._id}:`, err.message);
                            });
                        } catch (alarmError) {
                            console.error(`[LOXONE-STORAGE] [${buildingId}] Error creating alarm log:`, alarmError.message);
                            // Continue processing even if alarm creation fails
                        }
                    }
                }
            } catch (validationError) {
                // Log validation error but don't block storage
                console.error(`[LOXONE-STORAGE] [${buildingId}] Error during plausibility check:`, validationError.message);
            }
            
            // Store measurement regardless of validation result (to maintain data integrity)
            documents.push({
                timestamp: measurementTimestamp,
                meta: {
                    sensorId: sensor._id,
                    buildingId: buildingObjectId,
                    measurementType: measurementType,
                    stateType: mapping.stateType
                },
                value: measurement.value,
                unit: unit,
                quality: 100,
                source: 'websocket',
                resolution_minutes: 0
            });
        }

        // Step 4: Insert documents with timeout and error handling
        // Optimize: Split large batches to avoid timeouts, use write concern for better performance
        let storedCount = 0;
        if (documents.length > 0) {
            try {
                const collection = db.collection('measurements');
                
                // Split into smaller batches to avoid timeout (max 100 documents per batch)
                const BATCH_SIZE = 100;
                const batches = [];
                for (let i = 0; i < documents.length; i += BATCH_SIZE) {
                    batches.push(documents.slice(i, i + BATCH_SIZE));
                }
                
                let totalInserted = 0;
                for (const batch of batches) {
                    try {
                        // Use unacknowledged write concern for better performance (w: 0)
                        // This is safe for time-series data where occasional loss is acceptable
                        // vs blocking the entire measurement pipeline
                        const insertOperation = collection.insertMany(batch, {
                            ordered: false,
                            writeConcern: { w: 0 } // Unacknowledged - fastest, non-blocking
                        });
                        
                        // Reduced timeout to 10 seconds per batch (should be enough for 100 docs)
                        const timeoutPromise = new Promise((_, reject) => {
                            setTimeout(() => {
                                reject(new Error('Insert operation timeout after 10s'));
                            }, 10000);
                        });
                        
                        const result = await Promise.race([insertOperation, timeoutPromise]);
                        // With w: 0, insertedCount might be undefined, assume all inserted if no error
                        totalInserted += (result.insertedCount || batch.length);
                    } catch (batchError) {
                        // Log batch error but continue with next batch
                        if (batchError.code === 11000) {
                            // Duplicate key - count as partial success
                            totalInserted += (batchError.insertedCount || 0);
                            console.warn(`[LOXONE-STORAGE] [${buildingId}] Batch duplicate key error: ${batchError.insertedCount || 0}/${batch.length} inserted`);
                        } else if (
                            batchError.message.includes('timeout') ||
                            batchError.message.includes('Connection') ||
                            batchError.message.includes('pool')
                        ) {
                            // Timeout/connection error for this batch - skip it, continue with next
                            // console.warn(`[LOXONE-STORAGE] [${buildingId}] Batch timeout/error (${batch.length} docs), continuing with next batch:`, batchError.message);
                        } else {
                            // Unexpected error - log but continue
                            console.error(`[LOXONE-STORAGE] [${buildingId}] Batch insert error:`, batchError.message);
                        }
                    }
                }
                
                storedCount = totalInserted;
            } catch (error) {
                // Fallback error handling (should not reach here with new batching approach)
                console.error(`[LOXONE-STORAGE] [${buildingId}] Unexpected error in batch insert loop:`, error.message);
                // Return partial success if any batches succeeded
                storedCount = 0;
            }
        }

        // Update skipped count to include measurements that couldn't be mapped to sensors
        skippedCount += measurements.length - validMeasurements.length;

        return { stored: storedCount, skipped: skippedCount };
    }
}

module.exports = new LoxoneStorageService();

