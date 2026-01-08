const mongoose = require('mongoose');
const Room = require('../models/Room');
const Sensor = require('../models/Sensor');
const MeasurementData = require('../models/MeasurementData');
const Building = require('../models/Building');

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
function getMeasurementType(sensor, controlType, categoryInfo = null) {
    // Priority 1: Category type
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
    
    // Priority 2: Category name
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
    
    // Priority 3: Control type
    const typeMapping = {
        'Meter': 'Energy',
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

// Get unit from control type
function getUnitFromControlType(controlType) {
    const unitMapping = {
        'Meter': 'kWh',
        'EFM': 'kWh',
        'EnergyMeter': 'kWh',
        'TemperatureController': '°C',
        'WaterMeter': 'L',
        'PowerMeter': 'kW',
        'InfoOnlyAnalog': ''
    };
    return unitMapping[controlType] || '';
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
                let room = await db.collection('rooms').findOne({ loxone_room_uuid: roomUUID });
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
                return null;
            }

            let sensor = await db.collection('sensors').findOne({ loxone_control_uuid: controlUUID });
            if (!sensor) {
                const categoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;
                
                let unit = '°C';
                if (controlData.type === 'EnergyMeter' || controlData.type === 'Meter' || controlData.type === 'EFM') {
                    if (controlData.details && controlData.details.actualFormat && controlData.details.actualFormat.includes('kW')) {
                        unit = 'kW';
                    } else {
                        unit = 'kWh';
                    }
                } else if (controlData.type === 'PowerMeter') {
                    unit = 'kW';
                } else if (controlData.type === 'WaterMeter') {
                    unit = 'L';
                } else if (controlData.type === 'TemperatureController') {
                    unit = '°C';
                } else if (controlData.details && controlData.details.unit) {
                    unit = controlData.details.unit;
                } else if (controlData.details && controlData.details.format) {
                    const formatMatch = controlData.details.format.match(/(kW|kWh|°C|L|W|V|A|m³|m\^3)/);
                    if (formatMatch) {
                        unit = formatMatch[1];
                    }
                }

                const sensorResult = await db.collection('sensors').insertOne({
                    room_id: roomMap.get(roomUUID),
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
            }
            sensorMap.set(controlUUID, sensor._id);
            return sensor;
        };

        if (loxAPP3Data.controls) {
            for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                if (!measurementTypes.includes(controlData.type)) {
                    continue;
                }

                const roomUUID = controlData.room;
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

        console.log(`[LOXONE-STORAGE] [${buildingId}] Imported ${roomMap.size} rooms and ${sensorMap.size} sensors`);
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

                for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                    const sensorId = controlToSensorMap.get(controlUUID);
                    if (!sensorId) continue;

                    const categoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;

                    if (controlData.states) {
                        for (const [stateName, stateUUID] of Object.entries(controlData.states)) {
                            const normalizedUUID = normalizeUUID(stateUUID);
                            uuidToSensorMap.set(normalizedUUID, {
                                sensor_id: sensorId,
                                stateType: stateName,
                                controlType: controlData.type,
                                controlName: controlData.name,
                                categoryInfo: categoryInfo
                            });
                        }
                    } else {
                        const normalizedUUID = normalizeUUID(controlUUID);
                        uuidToSensorMap.set(normalizedUUID, {
                            sensor_id: sensorId,
                            stateType: 'actual',
                            controlType: controlData.type,
                            controlName: controlData.name,
                            categoryInfo: categoryInfo
                        });
                    }
                }
                
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
                                        categoryInfo: parentCategoryInfo
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
            
            console.log(`[LOXONE-STORAGE] [${buildingId}] Loaded ${uuidToSensorMap.size} UUID mappings`);
            return uuidToSensorMap;
        } catch (error) {
            console.error(`[LOXONE-STORAGE] [${buildingId}] Error loading structure mapping:`, error.message);
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

        const uuidToSensorMap = uuidMaps.get(buildingId);
        if (!uuidToSensorMap || uuidToSensorMap.size === 0) {
            console.log(`[LOXONE-STORAGE] [${buildingId}] UUID map is empty, reloading...`);
            // Try to reload from structure file
            const fs = require('fs');
            const path = require('path');
            const structureFilesDir = path.join(__dirname, '../../data/loxone-structure');
            const structureFilePath = path.join(structureFilesDir, `LoxAPP3_${buildingId}.json`);
            if (fs.existsSync(structureFilePath)) {
                const loxAPP3Data = JSON.parse(fs.readFileSync(structureFilePath, 'utf8'));
                await this.loadStructureMapping(buildingId, loxAPP3Data);
            } else {
                console.warn(`[LOXONE-STORAGE] [${buildingId}] No structure file found, skipping measurements`);
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

        // Step 3: Build documents using the sensor map
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
            
            const unit = sensor.unit || getUnitFromControlType(mapping.controlType);
            const categoryInfo = mapping.categoryInfo || (sensor.loxone_category_type || sensor.loxone_category_name ? {
                type: sensor.loxone_category_type,
                name: sensor.loxone_category_name
            } : null);
            const measurementType = getMeasurementType(sensor, mapping.controlType, categoryInfo);
            
            documents.push({
                timestamp: measurement.timestamp || new Date(),
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
        let storedCount = 0;
        if (documents.length > 0) {
            try {
                const collection = db.collection('measurements');
                
                // Create insert operation with timeout protection
                const insertOperation = collection.insertMany(documents, {
                    ordered: false,
                    writeConcern: { w: 1 } // Acknowledge write to primary only (faster, less blocking)
                });
                
                // Add timeout wrapper (30 seconds)
                const timeoutPromise = new Promise((_, reject) => {
                    setTimeout(() => {
                        reject(new Error('Insert operation timeout after 30s'));
                    }, 30000);
                });
                
                const result = await Promise.race([insertOperation, timeoutPromise]);
                storedCount = result.insertedCount || documents.length;
            } catch (error) {
                // Handle duplicate key errors (code 11000)
                if (error.code === 11000) {
                    storedCount = error.insertedCount || 0;
                    console.warn(`[LOXONE-STORAGE] [${buildingId}] Some duplicates skipped: ${storedCount}/${documents.length} inserted`);
                } 
                // Handle timeout and connection errors gracefully
                else if (
                    error.message.includes('timeout') || 
                    error.message.includes('Connection') ||
                    error.message.includes('pool') ||
                    error.name === 'MongoServerError' ||
                    error.name === 'MongoNetworkError'
                ) {
                    console.error(`[LOXONE-STORAGE] [${buildingId}] Connection/timeout error storing measurements:`, error.message);
                    // Don't throw - allow system to recover on next batch
                    return { stored: 0, skipped: measurements.length, error: 'connection_timeout' };
                } 
                // Re-throw unexpected errors
                else {
                    console.error(`[LOXONE-STORAGE] [${buildingId}] Error storing measurements:`, error.message);
                    throw error;
                }
            }
        }

        // Update skipped count to include measurements that couldn't be mapped to sensors
        skippedCount += measurements.length - validMeasurements.length;

        return { stored: storedCount, skipped: skippedCount };
    }
}

module.exports = new LoxoneStorageService();

