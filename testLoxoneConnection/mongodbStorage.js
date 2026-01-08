const mongoose = require('mongoose');
const path = require('path');

// Normalize UUID format (structure file might not have dash in last segment)
function normalizeUUID(uuid) {
    if (!uuid) return uuid;
    // Remove all dashes and re-add in correct positions
    const clean = uuid.replace(/-/g, '');
    if (clean.length !== 32) return uuid; // Invalid UUID
    return [
        clean.substring(0, 8),
        clean.substring(8, 12),
        clean.substring(12, 16),
        clean.substring(16, 20),
        clean.substring(20, 32)
    ].join('-');
}

// MongoDB Connection
let isConnected = false;
let dbConnection = null;

// Connect to MongoDB
async function connectToMongoDB(connectionString) {
    if (isConnected && dbConnection) {
        return dbConnection;
    }

    try {
        await mongoose.connect(connectionString, {
            autoIndex: false, // Disable auto-index to avoid conflicts
            serverSelectionTimeoutMS: 15000,
            socketTimeoutMS: 45000,
            maxPoolSize: 10,
        });

        // Wait for connection to be ready
        await mongoose.connection.db.admin().ping();

        isConnected = true;
        dbConnection = mongoose.connection;
        console.log('[MONGODB] Connected successfully');
        return dbConnection;
    } catch (error) {
        console.error('[MONGODB] Connection error:', error.message);
        throw error;
    }
}

// Measurement Schema for Time Series Collection
const measurementSchema = new mongoose.Schema({
    // Time Series Fields (must be first for MongoDB Time Series)
    timestamp: {
        type: Date,
        required: true
    },
    // Meta Field (for Time Series - must be an object/document)
    meta: {
        sensorId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Sensor',
            required: true
        },
        buildingId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'Building',
            required: true
        },
        measurementType: String,
        stateType: String
    },
    // Measurement Data
    value: {
        type: Number,
        required: true
    },
    unit: String,
    quality: Number,
    source: String,
    resolution_minutes: {
        type: Number,
        default: 0 // 0 for real-time, 15 for aggregated
    }
}, {
    timestamps: false, // We use timestamp field instead
    collection: 'measurements'
});

// Create Time Series Collection (run once)
async function createTimeSeriesCollection() {
    try {
        const db = mongoose.connection.db;
        
        // Check if collection exists
        const collections = await db.listCollections({ name: 'measurements' }).toArray();
        const collectionExists = collections.length > 0;
        
        // Check if it's a Time Series collection by examining its options
        let isTimeSeries = false;
        let hasCorrectMetaField = false;
        
        if (collectionExists) {
            const collectionInfo = collections[0];
            const options = collectionInfo.options || {};
            const timeseries = options.timeseries || {};
            
            // Check if it's a Time Series collection
            isTimeSeries = !!(timeseries && timeseries.timeField);
            hasCorrectMetaField = timeseries.metaField === 'meta';
        }
        
        // If collection exists but is not a proper Time Series collection, drop it
        if (collectionExists && (!isTimeSeries || !hasCorrectMetaField)) {
            console.warn('[MONGODB] ⚠️  Collection "measurements" exists but is not a valid Time Series collection.');
            if (!isTimeSeries) {
                console.warn('[MONGODB] ⚠️  It is a regular collection, not a Time Series collection.');
            } else if (!hasCorrectMetaField) {
                console.warn('[MONGODB] ⚠️  Time Series exists but has wrong metaField:', collections[0].options?.timeseries?.metaField, 'Expected: meta');
            }
            console.warn('[MONGODB] ⚠️  Dropping existing collection and recreating as Time Series...');
            
            try {
                // Drop the measurements collection (whether it's a view or regular collection)
                await db.collection('measurements').drop();
                console.log('[MONGODB] Dropped existing measurements collection');
            } catch (dropError) {
                // If drop fails, it might be because it's already dropped or doesn't exist
                if (!dropError.message.includes('ns not found')) {
                    console.error('[MONGODB] Error dropping collection:', dropError.message);
                    throw dropError;
                }
            }
            
            // Also try to drop the underlying bucket collection if it exists
            try {
                await db.collection('system.buckets.measurements').drop();
                console.log('[MONGODB] Dropped underlying bucket collection');
            } catch (bucketError) {
                // Ignore if bucket collection doesn't exist
                if (!bucketError.message.includes('ns not found')) {
                    console.warn('[MONGODB] Warning dropping bucket collection:', bucketError.message);
                }
            }
            
            // Small delay to ensure MongoDB has fully cleaned up
            await new Promise(resolve => setTimeout(resolve, 100));
        }
        
        // Create Time Series Collection (only if it doesn't exist or was dropped)
        if (!collectionExists || !isTimeSeries || !hasCorrectMetaField) {
            try {
                await db.createCollection('measurements', {
                    timeseries: {
                        timeField: 'timestamp',
                        metaField: 'meta',
                        granularity: 'seconds'
                    }
                });
                console.log('[MONGODB] ✓ Created Time Series collection: measurements');
            } catch (createError) {
                // If creation fails because collection already exists, try to drop and recreate
                if (createError.message.includes('already exists')) {
                    console.warn('[MONGODB] ⚠️  Collection still exists after drop attempt, forcing recreation...');
                    try {
                        await db.collection('measurements').drop();
                        await db.collection('system.buckets.measurements').drop().catch(() => {});
                        await new Promise(resolve => setTimeout(resolve, 200));
                        await db.createCollection('measurements', {
                            timeseries: {
                                timeField: 'timestamp',
                                metaField: 'meta',
                                granularity: 'seconds'
                            }
                        });
                        console.log('[MONGODB] ✓ Created Time Series collection: measurements (after forced cleanup)');
                    } catch (retryError) {
                        console.error('[MONGODB] Error creating Time Series collection after retry:', retryError.message);
                        throw retryError;
                    }
                } else {
                    throw createError;
                }
            }
        } else {
            // Time Series collection exists with correct structure
            console.log('[MONGODB] ✓ Time Series collection already exists with correct structure');
        }

        // Create indexes for efficient queries
        const collection = db.collection('measurements');
        try {
            await collection.createIndex({ 'meta.sensorId': 1, timestamp: -1 });
            await collection.createIndex({ 'meta.buildingId': 1, timestamp: -1 });
            await collection.createIndex({ timestamp: -1 });
            console.log('[MONGODB] Indexes created');
        } catch (indexError) {
            // Indexes might already exist, that's okay
            if (!indexError.message.includes('already exists')) {
                console.warn('[MONGODB] Index creation warning:', indexError.message);
            }
        }
    } catch (error) {
        console.error('[MONGODB] Error creating Time Series collection:', error.message);
        throw error;
    }
}

// Measurement Model
const Measurement = mongoose.model('Measurement', measurementSchema);

// UUID to Sensor mapping cache
let uuidToSensorMap = new Map();
let structureData = null;

// Import structure from LoxAPP3.json
async function importStructureFromLoxAPP3(buildingId, loxAPP3Data) {
    const db = dbConnection.db;
    const buildingObjectId = new mongoose.Types.ObjectId(buildingId);
    
    // Verify building exists
    const building = await db.collection('buildings').findOne({ _id: buildingObjectId });
    if (!building) {
        throw new Error(`Building ${buildingId} not found`);
    }

    console.log('[MONGODB] Importing structure from LoxAPP3.json...');

    // 1. Create a default Floor if none exists
    let floor = await db.collection('floors').findOne({ building_id: buildingObjectId });
    if (!floor) {
        const floorResult = await db.collection('floors').insertOne({
            building_id: buildingObjectId,
            name: 'Ground Floor',
            createdAt: new Date(),
            updatedAt: new Date()
        });
        floor = await db.collection('floors').findOne({ _id: floorResult.insertedId });
        console.log(`[MONGODB] Created default Floor: ${floor._id}`);
    }

    // 2. Import Rooms from LoxAPP3.json
    const roomMap = new Map(); // loxone_room_uuid -> room _id
    if (loxAPP3Data.rooms) {
        for (const [roomUUID, roomData] of Object.entries(loxAPP3Data.rooms)) {
            // Check if room already exists
            let room = await db.collection('rooms').findOne({ loxone_room_uuid: roomUUID });
            if (!room) {
                const roomResult = await db.collection('rooms').insertOne({
                    floor_id: floor._id,
                    name: roomData.name || 'Unnamed Room',
                    loxone_room_uuid: roomUUID,
                    createdAt: new Date(),
                    updatedAt: new Date()
                });
                room = await db.collection('rooms').findOne({ _id: roomResult.insertedId });
                console.log(`[MONGODB] Created Room: ${room.name} (${roomUUID.substring(0, 8)}...)`);
            }
            roomMap.set(roomUUID, room._id);
        }
    }

    // 3. Import Sensors from LoxAPP3.json controls (including subControls)
    const sensorMap = new Map(); // loxone_control_uuid -> sensor _id
    const measurementTypes = [
        'TemperatureController', 'EnergyMeter', 'WaterMeter', 'PowerMeter',
        'AnalogInput', 'DigitalInput', 'Meter', 'InfoOnlyAnalog', 'EFM'
    ];

    // Helper function to get category info
    const getCategoryInfo = (categoryUUID) => {
        if (!categoryUUID || !loxAPP3Data.cats) {
            return null;
        }
        return loxAPP3Data.cats[categoryUUID] || null;
    };

    // Helper function to import a control as a sensor
    const importControlAsSensor = async (controlUUID, controlData, roomUUID) => {
        if (!roomUUID || !roomMap.has(roomUUID)) {
            return null; // Skip if no room or room not found
        }

        // Check if sensor already exists
        let sensor = await db.collection('sensors').findOne({ loxone_control_uuid: controlUUID });
        if (!sensor) {
            // Get category information for measurement type inference
            const categoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;
            
            // Determine unit from control type or control data
            let unit = '°C'; // Default
            if (controlData.type === 'EnergyMeter' || controlData.type === 'Meter' || controlData.type === 'EFM') {
                // Check if it's power (kW) or energy (kWh) based on name or format
                if (controlData.details && controlData.details.actualFormat && controlData.details.actualFormat.includes('kW')) {
                    unit = 'kW';
                } else if (controlData.details && controlData.details.totalFormat && controlData.details.totalFormat.includes('kWh')) {
                    unit = 'kWh';
                } else {
                    unit = 'kWh'; // Default for Meter/EFM
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
                // Try to extract unit from format string
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
            console.log(`[MONGODB] Created Sensor: ${sensor.name} (${controlUUID.substring(0, 8)}...)`);
        }
        sensorMap.set(controlUUID, sensor._id);
        return sensor;
    };

    if (loxAPP3Data.controls) {
        for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
            // Only import measurement devices
            if (!measurementTypes.includes(controlData.type)) {
                continue;
            }

            // Get room UUID from control
            const roomUUID = controlData.room;
            await importControlAsSensor(controlUUID, controlData, roomUUID);
            
            // Also import subControls if they are Meters (e.g., EFM subControls)
            if (controlData.subControls) {
                for (const [subControlUUID, subControlData] of Object.entries(controlData.subControls)) {
                    if (subControlData.type === 'Meter') {
                        // Use the same room as parent control
                        await importControlAsSensor(subControlUUID, subControlData, roomUUID);
                    }
                }
            }
        }
    }

    console.log(`[MONGODB] Imported ${roomMap.size} rooms and ${sensorMap.size} sensors`);
    return { roomMap, sensorMap };
}

// Load structure file and build UUID mapping
async function loadStructureMapping(buildingId, loxAPP3Data = null) {
    try {
        // Validate buildingId is a valid ObjectId
        if (!mongoose.Types.ObjectId.isValid(buildingId)) {
            throw new Error(`Invalid Building ID format: "${buildingId}". It must be a valid MongoDB ObjectId (24 hex characters).`);
        }

        // Convert to ObjectId
        const buildingObjectId = new mongoose.Types.ObjectId(buildingId);
        const db = dbConnection.db;

        // Verify building exists using native driver
        const building = await db.collection('buildings').findOne({ _id: buildingObjectId });
        if (!building) {
            throw new Error(`Building ${buildingId} not found`);
        }

        // Load structure file if not provided
        if (!loxAPP3Data) {
            const fs = require('fs');
            const structurePath = path.join(__dirname, 'LoxAPP3.json');
            if (fs.existsSync(structurePath)) {
                loxAPP3Data = JSON.parse(fs.readFileSync(structurePath, 'utf8'));
            }
        }

        // Check if sensors exist for this building
        const floor = await db.collection('floors').findOne({ building_id: buildingObjectId });
        const sensorCount = await db.collection('sensors').countDocuments({});
        
        // Import structure if no floor exists OR if no sensors exist (structure might be incomplete)
        if (!floor || sensorCount === 0) {
            // No structure imported yet or incomplete - import it now
            if (loxAPP3Data) {
                console.log('[MONGODB] Importing structure from LoxAPP3.json...');
                await importStructureFromLoxAPP3(buildingId, loxAPP3Data);
            } else {
                throw new Error('No structure data available. Please ensure LoxAPP3.json exists or is provided.');
            }
        } else {
            console.log(`[MONGODB] Structure already imported (${sensorCount} sensors found)`);
        }

        // Load sensors using native driver (via aggregation to join with rooms and floors)
        const sensors = await db.collection('sensors').aggregate([
            {
                $lookup: {
                    from: 'rooms',
                    localField: 'room_id',
                    foreignField: '_id',
                    as: 'room'
                }
            },
            { $unwind: { path: '$room', preserveNullAndEmptyArrays: true } },
            {
                $lookup: {
                    from: 'floors',
                    localField: 'room.floor_id',
                    foreignField: '_id',
                    as: 'floor'
                }
            },
            { $unwind: { path: '$floor', preserveNullAndEmptyArrays: true } },
            {
                $match: {
                    'floor.building_id': buildingObjectId
                }
            }
        ]).toArray();

        // Build UUID mapping from LoxAPP3.json
        uuidToSensorMap.clear();
        
        // Helper function to get category info
        const getCategoryInfo = (categoryUUID) => {
            if (!categoryUUID || !loxAPP3Data || !loxAPP3Data.cats) {
                return null;
            }
            return loxAPP3Data.cats[categoryUUID] || null;
        };
        
        if (loxAPP3Data && loxAPP3Data.controls) {
            // Create a map of control UUID to sensor _id
            const controlToSensorMap = new Map();
            sensors.forEach(sensor => {
                if (sensor.loxone_control_uuid) {
                    controlToSensorMap.set(sensor.loxone_control_uuid, sensor._id);
                }
            });

            // Map all state UUIDs from controls to sensors
            for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                const sensorId = controlToSensorMap.get(controlUUID);
                if (!sensorId) {
                    continue; // Sensor not found for this control
                }

                // Get category info for this control
                const categoryInfo = controlData.cat ? getCategoryInfo(controlData.cat) : null;

                // Map all state UUIDs to this sensor
                if (controlData.states) {
                    for (const [stateName, stateUUID] of Object.entries(controlData.states)) {
                        // Normalize UUID format (structure file might not have dash in last segment)
                        const normalizedUUID = normalizeUUID(stateUUID);
                        uuidToSensorMap.set(normalizedUUID, {
                            sensor_id: sensorId,
                            stateType: stateName, // 'actual', 'total', 'totalDay', etc.
                            controlType: controlData.type,
                            controlName: controlData.name,
                            categoryInfo: categoryInfo  // Include category info for measurement type inference
                        });
                    }
                } else {
                    // Fallback: map control UUID directly (for simple controls without states)
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
            
            // Also map subControls (with category info from parent)
            for (const [controlUUID, controlData] of Object.entries(loxAPP3Data.controls)) {
                if (controlData.subControls) {
                    // Get parent category info
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
                                    categoryInfo: parentCategoryInfo  // Inherit from parent
                                });
                            }
                        }
                    }
                }
            }
        } else {
            // Fallback: only map control UUIDs (won't work for Meter states)
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

        console.log(`[MONGODB] Loaded ${uuidToSensorMap.size} UUID mappings for building ${buildingId}`);
        
        // Debug: Show sample mappings
        if (uuidToSensorMap.size > 0) {
            const sampleMappings = Array.from(uuidToSensorMap.entries()).slice(0, 3);
            console.log(`[MONGODB] Sample UUID mappings:`);
            sampleMappings.forEach(([uuid, mapping]) => {
                console.log(`  ${uuid.substring(0, 8)}... -> Sensor: ${mapping.sensor_id}, State: ${mapping.stateType}`);
            });
        } else {
            console.warn(`[MONGODB] ⚠️  No UUID mappings found! This means measurements won't be stored.`);
            console.warn(`[MONGODB] Check if sensors have loxone_control_uuid set correctly.`);
        }
        
        return uuidToSensorMap;
    } catch (error) {
        console.error('[MONGODB] Error loading structure mapping:', error.message);
        throw error;
    }
}

// Store measurements in MongoDB
async function storeMeasurements(measurements, buildingId) {
    if (!isConnected || !dbConnection) {
        console.warn('[MONGODB] Not connected, skipping measurement storage');
        return;
    }

    if (uuidToSensorMap.size === 0 && buildingId) {
        // Load mapping if not already loaded
        console.log('[MONGODB] UUID map is empty, reloading structure mapping...');
        await loadStructureMapping(buildingId);
    }
    
    if (uuidToSensorMap.size === 0) {
        console.warn('[MONGODB] ⚠️  UUID map is still empty after reload! Measurements will be skipped.');
        return { stored: 0, skipped: measurements.length };
    }

    const db = dbConnection.db;
    const documents = [];
    let storedCount = 0;
    let skippedCount = 0;

    for (const measurement of measurements) {
        // Normalize UUID for lookup (in case of format differences)
        const normalizedUUID = normalizeUUID(measurement.uuid);
        const mapping = uuidToSensorMap.get(normalizedUUID);
        
        if (!mapping || !mapping.sensor_id) {
            skippedCount++;
            // Debug: Log first few skipped UUIDs
            if (skippedCount <= 3) {
                console.log(`[MONGODB] Skipped UUID (not in mapping): ${normalizedUUID.substring(0, 8)}...`);
            }
            continue; // Skip if UUID not found in mapping
        }

        // Get sensor document to get unit
        const sensor = await db.collection('sensors').findOne({ _id: mapping.sensor_id });
        if (!sensor) {
            skippedCount++;
            continue;
        }
        
        // Get measurement type and unit from sensor
        const unit = sensor.unit || getUnitFromControlType(mapping.controlType);
        
        // Build category info from sensor document or mapping (mapping takes priority)
        const categoryInfo = mapping.categoryInfo || (sensor.loxone_category_type || sensor.loxone_category_name ? {
            type: sensor.loxone_category_type,
            name: sensor.loxone_category_name
        } : null);
        
        const measurementType = getMeasurementType(sensor, mapping.controlType, categoryInfo);

        // Use provided buildingId or skip if not available
        if (!buildingId) {
            skippedCount++;
            continue;
        }

        // MongoDB Time Series requires meta field to be an object
        documents.push({
            timestamp: measurement.timestamp || new Date(),
            meta: {
                sensorId: sensor._id,
                buildingId: buildingId,
                measurementType: measurementType,
                stateType: mapping.stateType
            },
            value: measurement.value,
            unit: unit,
            quality: 100,
            source: 'websocket',
            resolution_minutes: 0 // Real-time data
        });
    }

    // Bulk insert using native driver for better performance
    if (documents.length > 0) {
        try {
            const collection = db.collection('measurements');
            const result = await collection.insertMany(documents, { ordered: false });
            storedCount = result.insertedCount || documents.length;
            console.log(`[MONGODB] ✓ Stored ${storedCount} measurements, skipped ${skippedCount} unknown UUIDs`);
            
            // Debug: Show sample document structure
            if (storedCount > 0 && documents.length > 0) {
                const sample = documents[0];
                console.log(`[MONGODB] Sample document: timestamp=${sample.timestamp.toISOString()}, sensorId=${sample.meta.sensorId}, value=${sample.value}, unit=${sample.unit}`);
            }
        } catch (error) {
            // Handle duplicate key errors gracefully
            if (error.code === 11000) {
                console.warn('[MONGODB] Some measurements already exist (duplicate key)');
                storedCount = error.insertedCount || 0;
            } else {
                console.error('[MONGODB] Error storing measurements:', error.message);
                console.error('[MONGODB] Error details:', error);
                // Log first document structure for debugging
                if (documents.length > 0) {
                    console.error('[MONGODB] Sample document structure:', JSON.stringify(documents[0], null, 2));
                }
                throw error;
            }
        }
    } else {
        console.log(`[MONGODB] No valid measurements to store (${skippedCount} skipped)`);
    }

    return { stored: storedCount, skipped: skippedCount };
}

// Helper: Get measurement type from sensor, control type, and category
function getMeasurementType(sensor, controlType, categoryInfo = null) {
    // Priority 1: Try to infer from category type (most specific)
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
    
    // Priority 2: Try to infer from category name (if type is "undefined")
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
    
    // Priority 3: Try to infer from control type (fallback)
    const typeMapping = {
        'Meter': 'Energy',
        'EFM': 'Energy',  // Energy Flow Monitor
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

// Helper: Get unit from control type
function getUnitFromControlType(controlType) {
    const unitMapping = {
        'Meter': 'kWh',
        'EFM': 'kWh',  // Energy Flow Monitor
        'EnergyMeter': 'kWh',
        'TemperatureController': '°C',
        'WaterMeter': 'L',
        'PowerMeter': 'kW',
        'InfoOnlyAnalog': ''  // Unit depends on format/details
    };

    return unitMapping[controlType] || '';
}

// Get latest measurement for a sensor
async function getLatestMeasurement(sensorId) {
    try {
        return await Measurement.findOne(
            { 'meta.sensorId': sensorId },
            {},
            { sort: { timestamp: -1 } }
        );
    } catch (error) {
        console.error('[MONGODB] Error getting latest measurement:', error.message);
        throw error;
    }
}

// Get measurements for a date range
async function getMeasurements(sensorId, startDate, endDate) {
    try {
        return await Measurement.find({
            'meta.sensorId': sensorId,
            timestamp: {
                $gte: startDate,
                $lt: endDate
            }
        }).sort({ timestamp: 1 });
    } catch (error) {
        console.error('[MONGODB] Error getting measurements:', error.message);
        throw error;
    }
}

module.exports = {
    connectToMongoDB,
    createTimeSeriesCollection,
    loadStructureMapping,
    storeMeasurements,
    getLatestMeasurement,
    getMeasurements,
    uuidToSensorMap // Export for direct access if needed
};

