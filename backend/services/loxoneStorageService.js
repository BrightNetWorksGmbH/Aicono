const mongoose = require('mongoose');
const Room = require('../models/Room');
const Sensor = require('../models/Sensor');
const MeasurementData = require('../models/MeasurementData');
const Building = require('../models/Building');
const plausibilityCheckService = require('./plausibilityCheckService');
// 🔥 REMOVED: Pool statistics imports - throttling is now handled by measurementQueueService
// const { getPoolStatistics, PRIORITY, canAcquireConnection, waitForConnection } = require('../db/connection');

// Per-server UUID to Sensor mapping cache
const uuidMaps = new Map(); // serialNumber -> Map<uuid, sensorMapping>
// Track last warning time for UUID empty warnings (to avoid spam)
const lastUuidEmptyWarning = new Map(); // serialNumber -> timestamp

// 🔥 NEW: Structure loading state tracking to prevent duplicate loads
const structureLoadingState = new Map(); // serialNumber -> { loading: boolean, lastLoaded: timestamp }
const STRUCTURE_LOAD_COOLDOWN = 60000; // Don't reload structure more than once per minute

// 🔥 NEW: Sensor cache to avoid repeated database queries
const sensorCache = new Map(); // serialNumber -> Map<sensorId, sensor>
const SENSOR_CACHE_TTL = 300000; // Cache sensors for 5 minutes

// 🔥 NEW: Cache for allowed sensor IDs (sensors in rooms mapped to LocalRooms)
// This prevents querying the database on every measurement batch
const allowedSensorIdsCache = new Map(); // serialNumber -> { sensorIds: Set, timestamp: number }
const ALLOWED_SENSOR_IDS_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

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
 * Priority: 1. StateType + Format string (for Meter controls - most reliable), 2. Category type, 3. Category name, 4. Control type
 * Note: For Meter controls, stateType determines Power vs Energy:
 * - actual* states (actual, actual0, actual1, etc.) = Power (instantaneous, W/kW)
 * - total* states (total, totalDay, totalWeek, etc.) = Energy (cumulative, Wh/kWh)
 */
function getMeasurementType(sensor, controlType, categoryInfo = null, controlData = null, stateType = null) {
    // Priority 1: For Meter controls, stateType + format string combination is most reliable
    // Meter controls can measure: Energy (kW/kWh), Temperature (°C), Gas/Water (m³/L), etc.
    if (controlType === 'Meter' && controlData && controlData.details) {
        // CRITICAL: StateType determines Power vs Energy for Meter controls
        // actual* states = Power (instantaneous), total* states = Energy (cumulative)
        if (stateType && stateType.startsWith('actual')) {
            // actual, actual0, actual1, etc. → Power (instantaneous)
            // Choose format based on stateType: actualFormat for "actual*" states
            let formatStr = (controlData.details.actualFormat || controlData.details.totalFormat || '').toLowerCase();

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

            // Power meter: W, kW (but NOT kWh/Wh)
            // Check for W or kW, but exclude kWh/Wh
            if ((formatStr.includes('w') || formatStr.includes('kw')) &&
                !formatStr.includes('kwh') && !formatStr.includes('wh')) {
                return 'Power';
            }

            // If format contains kWh/Wh, it's still Power for actual* states (unusual but possible)
            // The stateType takes precedence: actual* = Power
            if (formatStr.includes('kwh') || formatStr.includes('wh')) {
                // This is unusual - actual state with energy format, but stateType says Power
                // Trust stateType: actual* = Power
                return 'Power';
            }
        } else if (stateType && (stateType.startsWith('total') || stateType.startsWith('totalNeg'))) {
            // total, totalDay, totalWeek, totalMonth, totalYear, totalNeg, etc. → Energy (cumulative)
            // Choose format based on stateType: totalFormat for "total*" states
            let formatStr = (controlData.details.totalFormat || controlData.details.actualFormat || '').toLowerCase();

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

            // Energy meter: kWh or Wh in format
            if (formatStr.includes('kwh') || formatStr.includes('wh')) {
                return 'Energy';
            }

            // If format is W/kW (not kWh), but stateType is total*, it's still Energy (cumulative counter)
            // The stateType takes precedence: total* = Energy
            if (formatStr.includes('w') || formatStr.includes('kw')) {
                return 'Energy';
            }
        } else {
            // No stateType or unknown stateType - fall back to format string analysis
            let formatStr = (controlData.details.actualFormat || controlData.details.totalFormat || '').toLowerCase();

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

            // Power meter: W, kW (but NOT kWh/Wh)
            if ((formatStr.includes('w') || formatStr.includes('kw')) &&
                !formatStr.includes('kwh') && !formatStr.includes('wh')) {
                return 'Power';
            }

            // Energy meter: kWh or Wh in format
            if (formatStr.includes('kwh') || formatStr.includes('wh')) {
                return 'Energy';
            }
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
     * Initialize storage for a server (create Time Series collections if needed)
     */
    async initializeForBuilding(serialNumber) {
        try {
            // Use measurementCollectionService to ensure both collections exist
            const measurementCollectionService = require('./measurementCollectionService');
            await measurementCollectionService.ensureCollectionsExist();
        } catch (error) {
            // console.error(`[LOXONE-STORAGE] [${serialNumber}] Error initializing:`, error.message);
            throw error;
        }
    }

    /**
     * Import structure from LoxAPP3.json for a server
     */
    async importStructureFromLoxAPP3(serialNumber, loxAPP3Data) {
        const db = mongoose.connection.db;

        if (!serialNumber) {
            throw new Error('Serial number is required');
        }

        // console.log(`[LOXONE-STORAGE] [${serialNumber}] Importing structure from LoxAPP3.json...`);

        // 1. Import Rooms from LoxAPP3.json (Loxone rooms - scoped to server serial, not building)
        const roomMap = new Map(); // loxone_room_uuid -> room _id
        if (loxAPP3Data.rooms) {
            for (const [roomUUID, roomData] of Object.entries(loxAPP3Data.rooms)) {
                // Check for room by miniserver_serial AND loxone_room_uuid
                // This ensures rooms are shared across buildings using the same server
                let room = await db.collection('rooms').findOne({
                    miniserver_serial: serialNumber,
                    loxone_room_uuid: roomUUID
                });
                if (!room) {
                    const roomResult = await db.collection('rooms').insertOne({
                        miniserver_serial: serialNumber,
                        name: roomData.name || 'Unnamed Room',
                        loxone_room_uuid: roomUUID,
                        createdAt: new Date(),
                        updatedAt: new Date()
                    });
                    room = await db.collection('rooms').findOne({ _id: roomResult.insertedId });
                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] Created Room: ${room.name} (${roomUUID.substring(0, 8)}...)`);
                } else {
                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] Room already exists: ${room.name} (${roomUUID.substring(0, 8)}...)`);
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
                    console.warn(`[LOXONE-STORAGE] [${serialNumber}] Control ${controlData?.name || controlUUID.substring(0, 8)} has no room UUID`);
                } else {
                    console.warn(`[LOXONE-STORAGE] [${serialNumber}] Room UUID ${roomUUID.substring(0, 8)}... not found in roomMap for control ${controlData?.name || controlUUID.substring(0, 8)}`);
                }
                return null;
            }

            const roomId = roomMap.get(roomUUID);

            // Check for sensor by control UUID AND that it belongs to a room for this server
            // Sensors are scoped to rooms, which are scoped to server serial
            // Ensure roomId is an ObjectId (it should be, but verify for safety)
            const roomObjectId = roomId instanceof mongoose.Types.ObjectId
                ? roomId
                : new mongoose.Types.ObjectId(roomId);

            let sensor = await db.collection('sensors').findOne({
                loxone_control_uuid: controlUUID,
                room_id: roomObjectId  // Direct room_id match ensures sensor belongs to this server's room
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
                // console.log(`[LOXONE-STORAGE] [${serialNumber}] Created Sensor: ${sensor.name} (${controlUUID.substring(0, 8)}...)`);
            } else {
                // console.log(`[LOXONE-STORAGE] [${serialNumber}] Sensor already exists: ${sensor.name} (${controlUUID.substring(0, 8)}...)`);
            }
            sensorMap.set(controlUUID, sensor._id);
            return sensor;
        };

        // Count controls for logging
        const totalControls = loxAPP3Data.controls ? Object.keys(loxAPP3Data.controls).length : 0;
        let processedControls = 0;
        let skippedControls = 0;
        const progressInterval = 50; // Log progress every 50 controls

        // console.log(`[LOXONE-STORAGE] [${serialNumber}] Starting sensor import from ${totalControls} controls...`);

        if (loxAPP3Data.controls) {
            for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                processedControls++;

                // Log progress periodically
                if (processedControls % progressInterval === 0) {
                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] Processing controls... ${processedControls}/${totalControls} (${sensorMap.size} sensors created so far)`);
                }

                if (!measurementTypes.includes(controlData.type)) {
                    skippedControls++;
                    continue;
                }

                const roomUUID = controlData.room;
                if (!roomUUID) {
                    console.warn(`[LOXONE-STORAGE] [${serialNumber}] Control ${controlData.name || controlUUID.substring(0, 8)} has no room UUID, skipping`);
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

        // console.log(`[LOXONE-STORAGE] [${serialNumber}] Processed ${processedControls} controls (${skippedControls} skipped, ${processedControls - skippedControls} processed for sensors)`);

        // console.log(`[LOXONE-STORAGE] [${serialNumber}] Imported ${roomMap.size} rooms and ${sensorMap.size} sensors`);

        // Log sensor creation summary
        const sensorCount = sensorMap.size;
        if (sensorCount > 0) {
            console.log(`[LOXONE-STORAGE] [${serialNumber}] ✓ Structure import complete: ${roomMap.size} rooms, ${sensorCount} sensors`);
        } else {
            console.warn(`[LOXONE-STORAGE] [${serialNumber}] ⚠️  WARNING: Structure import completed but no sensors were created!`);
        }

        return { roomMap, sensorMap };
    }

    /**
     * 🔥 OPTIMIZED: Load structure mapping for a server (with duplicate load prevention)
     */
    async loadStructureMapping(serialNumber, loxAPP3Data = null) {
        try {
            if (!serialNumber) {
                throw new Error(`Invalid Serial Number: ${serialNumber}`);
            }

            // 🔥 NEW: Check if structure is already loading or recently loaded
            const loadingState = structureLoadingState.get(serialNumber);
            if (loadingState) {
                if (loadingState.loading) {
                    // Structure is currently being loaded by another process - wait for it
                    console.log(`[LOXONE-STORAGE] [${serialNumber}] Structure is already loading, waiting...`);
                    // Wait up to 30 seconds for the other load to complete
                    for (let i = 0; i < 60; i++) {
                        await new Promise(resolve => setTimeout(resolve, 500));
                        const currentState = structureLoadingState.get(serialNumber);
                        if (!currentState || !currentState.loading) {
                            // Loading completed
                            const existingMap = uuidMaps.get(serialNumber);
                            if (existingMap && existingMap.size > 0) {
                                console.log(`[LOXONE-STORAGE] [${serialNumber}] ✓ Structure loaded by another process (${existingMap.size} UUID mappings)`);
                                return existingMap;
                            }
                            break;
                        }
                    }
                    // If still loading after 30s, proceed anyway (but log warning)
                    if (structureLoadingState.get(serialNumber)?.loading) {
                        console.warn(`[LOXONE-STORAGE] [${serialNumber}] Structure loading timeout, proceeding with new load`);
                    }
                }

                // Check if recently loaded (within cooldown period)
                const timeSinceLoad = Date.now() - (loadingState.lastLoaded || 0);
                if (timeSinceLoad < STRUCTURE_LOAD_COOLDOWN) {
                    const existingMap = uuidMaps.get(serialNumber);
                    if (existingMap && existingMap.size > 0) {
                        console.log(`[LOXONE-STORAGE] [${serialNumber}] ✓ Using cached structure (loaded ${Math.round(timeSinceLoad / 1000)}s ago)`);
                        return existingMap;
                    }
                }
            }

            // 🔥 NEW: Mark as loading
            structureLoadingState.set(serialNumber, { loading: true, lastLoaded: Date.now() });

            try {
                const db = mongoose.connection.db;

                // Check if structure needs to be imported
                const roomCount = await db.collection('rooms').countDocuments({ miniserver_serial: serialNumber });
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
                    { $match: { 'room.miniserver_serial': serialNumber } }
                ]).toArray();

                if (roomCount === 0 || sensorCount.length === 0) {
                    if (loxAPP3Data) {
                        // console.log(`[LOXONE-STORAGE] [${serialNumber}] Importing structure...`);
                        await this.importStructureFromLoxAPP3(serialNumber, loxAPP3Data);
                    } else {
                        throw new Error('No structure data available');
                    }
                } else {
                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] Structure already imported (${sensorCount.length} sensors found)`);
                }

                // 🔥 OPTIMIZED: Load sensors with simpler query (no aggregation)
                // Only load the fields we need to reduce memory and network usage
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
                    { $match: { 'room.miniserver_serial': serialNumber } },
                    {
                        $project: {
                            _id: 1,
                            name: 1,
                            unit: 1,
                            loxone_control_uuid: 1,
                            loxone_category_uuid: 1,
                            loxone_category_name: 1,
                            loxone_category_type: 1
                        }
                    }
                ]).toArray();

                // 🔥 NEW: Cache sensors for this server
                const serverSensorCache = new Map();
                sensors.forEach(sensor => {
                    serverSensorCache.set(sensor._id.toString(), sensor);
                });
                sensorCache.set(serialNumber, {
                    sensors: serverSensorCache,
                    timestamp: Date.now()
                });

                // console.log(`[LOXONE-STORAGE] [${serialNumber}] Found ${sensors.length} sensors for this server`);

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

                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] Building UUID mapping from ${controlToSensorMap.size} sensors and ${Object.keys(loxAPP3Data.controls).length} controls`);

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

                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] Mapped ${mappedControls} controls to sensors (created ${uuidToSensorMap.size} UUID entries so far)`);

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

                // Store mapping for this server
                uuidMaps.set(serialNumber, uuidToSensorMap);

                if (uuidToSensorMap.size === 0) {
                    // console.warn(`[LOXONE-STORAGE] [${serialNumber}] ⚠️  WARNING: UUID mapping is empty! No measurements can be stored for this server.`);
                    // console.warn(`[LOXONE-STORAGE] [${serialNumber}] Sensors found: ${sensors.length}, Controls in structure: ${loxAPP3Data?.controls ? Object.keys(loxAPP3Data.controls).length : 0}`);
                } else {
                    // console.log(`[LOXONE-STORAGE] [${serialNumber}] ✓ Loaded ${uuidToSensorMap.size} UUID mappings`);
                }

                // 🔥 NEW: Mark loading as complete
                structureLoadingState.set(serialNumber, { loading: false, lastLoaded: Date.now() });

                return uuidToSensorMap;
            } catch (error) {
                // 🔥 NEW: Mark loading as failed
                structureLoadingState.set(serialNumber, { loading: false, lastLoaded: Date.now() });
                throw error;
            }
        } catch (error) {
            console.error(`[LOXONE-STORAGE] [${serialNumber}] Error loading structure mapping:`, error.message);
            // Check if it's a duplicate key error (index issue)
            if (error.message.includes('E11000') || error.message.includes('duplicate key')) {
                console.error(`[LOXONE-STORAGE] [${serialNumber}] ⚠️  Duplicate key error detected!`);
                console.error(`[LOXONE-STORAGE] [${serialNumber}] This indicates the old unique indexes still exist in MongoDB.`);
                console.error(`[LOXONE-STORAGE] [${serialNumber}] Please run: node scripts/fixRoomSensorIndexes.js`);
                console.error(`[LOXONE-STORAGE] [${serialNumber}] Then restart the server to retry structure import.`);
            }
            throw error;
        }
    }

    /**
     * 🔥 NEW: Get cached sensor data
     */
    getCachedSensor(serialNumber, sensorId) {
        const cache = sensorCache.get(serialNumber);
        if (!cache) return null;

        // Check cache expiry
        if (Date.now() - cache.timestamp > SENSOR_CACHE_TTL) {
            sensorCache.delete(serialNumber);
            return null;
        }

        return cache.sensors.get(sensorId.toString());
    }

    /**
     * Get sensor IDs for sensors in rooms mapped to LocalRooms for a server
     * Only sensors in rooms that are mapped to LocalRooms should have measurements stored
     * 🔥 OPTIMIZED: Uses caching to avoid DB queries on every measurement batch
     */
    async getMappedSensorIdsForServer(serialNumber, forceRefresh = false) {
        // 🔥 Check cache first to avoid DB queries on every measurement batch
        if (!forceRefresh) {
            const cached = allowedSensorIdsCache.get(serialNumber);
            if (cached && (Date.now() - cached.timestamp) < ALLOWED_SENSOR_IDS_CACHE_TTL) {
                return cached.sensorIds;
            }
        }

        const db = mongoose.connection.db;
        const LocalRoom = require('../models/LocalRoom');

        try {
            // Get all LocalRooms that have loxone_room_id set
            const localRooms = await LocalRoom.find({
                loxone_room_id: { $exists: true, $ne: null }
            }).populate('loxone_room_id');
            
            // Filter to only LocalRooms whose Loxone Room belongs to this server
            const mappedLoxoneRoomIds = localRooms
                .filter(lr => lr.loxone_room_id && lr.loxone_room_id.miniserver_serial === serialNumber)
                .map(lr => lr.loxone_room_id._id);

            if (mappedLoxoneRoomIds.length === 0) {
                console.warn(`[LOXONE-STORAGE] [${serialNumber}] ⚠️  No LocalRooms mapped to Loxone Rooms for this server - ALL measurements will be filtered out!`);
                // 🔥 Cache empty result to avoid repeated queries
                const emptySet = new Set();
                allowedSensorIdsCache.set(serialNumber, { sensorIds: emptySet, timestamp: Date.now() });
                return emptySet;
            }

            // Get all sensors in those Loxone Rooms
            const sensors = await db.collection('sensors').find({
                room_id: { $in: mappedLoxoneRoomIds }
            }).project({ _id: 1 }).toArray();

            // Return Set of sensor IDs
            const sensorIds = new Set(sensors.map(s => s._id.toString()));
            
            // Log only when cache refreshes (every 5 minutes)
            console.log(`[LOXONE-STORAGE] [${serialNumber}] 🔄 Cache refresh: ${sensorIds.size} sensor(s) from ${mappedLoxoneRoomIds.length} LocalRoom(s) allowed`);
            
            // 🔥 Cache the result
            allowedSensorIdsCache.set(serialNumber, { sensorIds, timestamp: Date.now() });
            
            return sensorIds;
        } catch (error) {
            console.error(`[LOXONE-STORAGE] [${serialNumber}] Error getting mapped sensor IDs:`, error.message);
            // Return empty set on error - this will cause all measurements to be filtered out
            // Better to be safe than store unwanted data
            return new Set();
        }
    }
    
    /**
     * Invalidate the allowed sensor IDs cache for a server
     * Call this when LocalRooms are created, updated, or deleted
     */
    invalidateAllowedSensorIdsCache(serialNumber = null) {
        if (serialNumber) {
            allowedSensorIdsCache.delete(serialNumber);
        } else {
            allowedSensorIdsCache.clear();
        }
    }

    /**
     * Store measurements for a server
     * Optimized to avoid N+1 queries by batching sensor lookups
     * Only stores measurements for sensors in rooms mapped to LocalRooms
     */
    async storeMeasurements(serialNumber, measurements, options = {}) {
        const now = Date.now();

        // 🔥 EARLY EXIT: Check cache first to avoid ANY DB queries when no LocalRooms configured
        // This is critical for performance - measurements come in very frequently
        const cachedAllowed = allowedSensorIdsCache.get(serialNumber);
        if (cachedAllowed && 
            cachedAllowed.sensorIds.size === 0 && 
            (Date.now() - cachedAllowed.timestamp) < ALLOWED_SENSOR_IDS_CACHE_TTL) {
            // Cache confirms no mapped rooms - skip all measurements without DB query
            return { stored: 0, skipped: measurements.length, error: 'no_mapped_rooms' };
        }

        // Check connection health
        if (mongoose.connection.readyState !== 1) {
            console.warn(`[LOXONE-STORAGE] [${serialNumber}] MongoDB not connected (readyState: ${mongoose.connection.readyState})`);
            return { stored: 0, skipped: measurements.length, error: 'not_connected' };
        }

        // Import services for plausibility checks (lazy load to avoid circular dependencies)
        const alarmService = require('./alarmService');
        const alertNotificationService = require('./alertNotificationService');

        // 🔥 OPTIMIZED: Get UUID map without automatic reload
        let uuidToSensorMap = uuidMaps.get(serialNumber);

        // 🔥 REMOVED: Don't automatically reload structure here!
        // The structure should be loaded once during connection setup
        // If it's missing, something is wrong and we should just skip measurements
        if (!uuidToSensorMap || uuidToSensorMap.size === 0) {
            // Only log warning once per minute to avoid spam
            const lastWarning = lastUuidEmptyWarning.get(serialNumber) || 0;

            if (now - lastWarning > 60000) {
                console.warn(`[LOXONE-STORAGE] [${serialNumber}] ⚠️  UUID mapping is empty, skipping ${measurements.length} measurement(s)`);
                console.warn(`[LOXONE-STORAGE] [${serialNumber}] Structure file should be loaded during connection setup. Check connection manager.`);
                lastUuidEmptyWarning.set(serialNumber, now);
            }

            return { stored: 0, skipped: measurements.length, error: 'no_mapping' };
        }

        // 🔥 NEW: Get allowed sensor IDs (only sensors in mapped LocalRooms)
        const allowedSensorIds = await this.getMappedSensorIdsForServer(serialNumber);
        if (allowedSensorIds.size === 0) {
            // No mapped rooms for this server - skip all measurements
            return { stored: 0, skipped: measurements.length, error: 'no_mapped_rooms' };
        }

        const db = mongoose.connection.db;
        const currentMap = uuidToSensorMap;

        // Step 1: Collect all unique sensor IDs (optimize N+1 query problem)
        // Filter to only sensors in mapped rooms
        const sensorIds = new Set();
        const validMeasurements = [];

        for (const measurement of measurements) {
            const normalizedUUID = normalizeUUID(measurement.uuid);
            const mapping = currentMap.get(normalizedUUID);

            if (!mapping || !mapping.sensor_id) {
                continue;
            }

            const sensorIdStr = mapping.sensor_id.toString();
            
            // 🔥 CRITICAL: Only include sensors that are in mapped LocalRooms
            if (!allowedSensorIds.has(sensorIdStr)) {
                continue; // Skip sensors not in mapped rooms
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

        // 🔥 OPTIMIZED: Try to use cached sensors first, only fetch missing ones
        let sensorMap = new Map();
        const missingIds = [];

        for (const sensorId of sensorIds) {
            const cachedSensor = this.getCachedSensor(serialNumber, sensorId);
            if (cachedSensor) {
                sensorMap.set(sensorId.toString(), cachedSensor);
            } else {
                missingIds.push(sensorId);
            }
        }

        // Only fetch sensors that aren't in cache
        if (missingIds.length > 0) {
            try {
                const fetchedSensors = await db.collection('sensors')
                    .find({ _id: { $in: missingIds } })
                    .project({ _id: 1, name: 1, unit: 1, loxone_category_name: 1, loxone_category_type: 1 })
                    .toArray();

                // Add to sensor map and cache
                const cache = sensorCache.get(serialNumber);
                const serverCache = cache?.sensors || new Map();

                fetchedSensors.forEach(sensor => {
                    const sensorIdStr = sensor._id.toString();
                    sensorMap.set(sensorIdStr, sensor);
                    serverCache.set(sensorIdStr, sensor);
                });

                // Update cache
                sensorCache.set(serialNumber, {
                    sensors: serverCache,
                    timestamp: Date.now()
                });
            } catch (error) {
                console.error(`[LOXONE-STORAGE] [${serialNumber}] Error fetching sensors:`, error.message);
                return { stored: 0, skipped: measurements.length, error: 'sensor_fetch_failed' };
            }
        }

        // Step 3: Build documents using the sensor map and validate plausibility
        const documents = [];
        let skippedCount = 0;
        
        // 🔥 CHANGED: Don't use buildingId in meta - measurements are server-scoped
        // If buildingId is needed for queries, we can add it later via aggregation

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
                // console.warn(`[LOXONE-STORAGE] [${serialNumber}] Skipping temperature total state: ${mapping.stateType} for sensor ${sensor.name} (value: ${measurement.value})`);
                skippedCount++;
                continue;
            }

            // Priority 2: Enhanced Temperature Validation - Check for implausible temperature values
            // Reasonable temperature range: -50°C to 100°C for indoor/outdoor sensors
            if (measurementType === 'Temperature') {
                if (measurement.value < -50 || measurement.value > 100) {
                    console.warn(`[LOXONE-STORAGE] [${serialNumber}] Implausible temperature value: ${measurement.value}°C for sensor ${sensor.name} (stateType: ${mapping.stateType}). Skipping measurement.`);
                    skippedCount++;
                    continue;
                }
            }

            const measurementTimestamp = measurement.timestamp || new Date();

            // 🔥 FIX: Fire-and-forget plausibility check - DON'T AWAIT
            // This was a major bottleneck causing queue to fill up
            // Plausibility checks are important but should not block measurement storage
            if (!options.skipPlausibilityCheck) {
                // Run asynchronously without awaiting (fire-and-forget)
                plausibilityCheckService.validateMeasurement(
                    sensor._id,
                    measurement.value,
                    measurementType,
                    measurementTimestamp,
                    sensor // Pass pre-fetched sensor to avoid database query
                ).then(validation => {
                    // If validation fails, create alarm log entries (also non-blocking)
                    if (!validation.isValid && validation.violations.length > 0) {
                        for (const violation of validation.violations) {
                            alarmService.createPlausibilityAlarm(
                                violation,
                                sensor._id,
                                measurement.value,
                                measurementTimestamp
                            ).then(alarmLog => {
                                // Trigger email notification asynchronously
                                alertNotificationService.sendAlertReport(alarmLog._id).catch(err => {
                                    // Silent fail - don't spam logs
                                });
                            }).catch(alarmError => {
                                // Silent fail for alarm creation - don't block or spam logs
                            });
                        }
                    }
                }).catch(validationError => {
                    // Silent fail for validation - don't block or spam logs
                });
            }

            // Store measurement regardless of validation result (to maintain data integrity)
            // 🔥 CHANGED: Removed buildingId from meta - measurements are server-scoped
            // buildingId can be derived via sensor -> room -> building relationship if needed
            documents.push({
                timestamp: measurementTimestamp,
                meta: {
                    sensorId: sensor._id,
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
        // Write to measurements_raw collection (raw data only, resolution_minutes: 0)
        // Use HIGH priority for real-time data storage
        let storedCount = 0;
        if (documents.length > 0) {
            try {
                // 🔥 FIX: REMOVED pool wait - the queue service handles throttling now
                // Waiting here causes queue to back up. Just proceed with storage.
                // Real-time data storage is HIGH priority and should always proceed.
                
                const collection = db.collection('measurements_raw');

                // 🔥 INCREASED: Larger batches for better throughput (was 100, now 500)
                const BATCH_SIZE = 500;
                const batches = [];
                for (let i = 0; i < documents.length; i += BATCH_SIZE) {
                    batches.push(documents.slice(i, i + BATCH_SIZE));
                }

                let totalInserted = 0;
                for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
                    const batch = batches[batchIndex];

                    try {
                        // 🔥 FIX: REMOVED per-batch pool check - causes latency and queue backup
                        // The queue service handles throttling at a higher level
                        
                        // Use unacknowledged write concern for better performance (w: 0)
                        // This is safe for time-series data where occasional loss is acceptable
                        // vs blocking the entire measurement pipeline
                        const insertOperation = collection.insertMany(batch, {
                            ordered: false,
                            writeConcern: { w: 0 } // Unacknowledged - fastest, non-blocking
                        });

                        // Increased timeout to 15 seconds per batch (500 docs now)
                        const timeoutPromise = new Promise((_, reject) => {
                            setTimeout(() => {
                                reject(new Error('Insert operation timeout after 15s'));
                            }, 15000);
                        });

                        const result = await Promise.race([insertOperation, timeoutPromise]);
                        // With w: 0, insertedCount might be undefined, assume all inserted if no error
                        totalInserted += (result.insertedCount || batch.length);
                    } catch (batchError) {
                        // Log batch error but continue with next batch
                        if (batchError.code === 11000) {
                            // Duplicate key - count as partial success
                            totalInserted += (batchError.insertedCount || 0);
                            console.warn(`[LOXONE-STORAGE] [${serialNumber}] Batch duplicate key error: ${batchError.insertedCount || 0}/${batch.length} inserted`);
                        } else if (
                            batchError.message.includes('timeout') ||
                            batchError.message.includes('Connection') ||
                            batchError.message.includes('pool')
                        ) {
                            // Timeout/connection error for this batch - skip it, continue with next
                            // console.warn(`[LOXONE-STORAGE] [${serialNumber}] Batch timeout/error (${batch.length} docs), continuing with next batch:`, batchError.message);
                        } else {
                            // Unexpected error - log but continue
                            console.error(`[LOXONE-STORAGE] [${serialNumber}] Batch insert error:`, batchError.message);
                        }
                    }
                }

                storedCount = totalInserted;
            } catch (error) {
                // Fallback error handling (should not reach here with new batching approach)
                console.error(`[LOXONE-STORAGE] [${serialNumber}] Unexpected error in batch insert loop:`, error.message);
                // Return partial success if any batches succeeded
                storedCount = 0;
            }
        }

        // Update skipped count to include measurements that couldn't be mapped to sensors
        skippedCount += measurements.length - validMeasurements.length;

        return { stored: storedCount, skipped: skippedCount };
    }

    /**
     * Get UUID map for a server (for real-time broadcasting)
     * @param {string} serialNumber - Server serial number
     * @returns {Map|null} UUID to sensor mapping or null if not loaded
     */
    getUuidMap(serialNumber) {
        return uuidMaps.get(serialNumber) || null;
    }
}

module.exports = new LoxoneStorageService();
