# Loxone Data Storage Guide for BryteSwitch EMS

## Overview

This guide explains how to store Loxone Miniserver data in MongoDB, including:
- Master Data (Structure) from `LoxAPP3.json`
- Real-time measurements in MongoDB Time Series Collections
- Data hierarchy mapping (Site → Building → Floor → Room → Sensor)
- 15-minute aggregation strategy

---

## 1. Connection Status ✅

Your connection is **working successfully**! The structure file (`LoxAPP3.json`) is being received, which contains all the master data needed for your database.

---

## 2. Data Hierarchy & Mapping

### Proposed Mapping Strategy

```
Site/Property (Manual)
  └── Building (1:1 with Miniserver)
      └── Floor/Zone (Manual grouping)
          └── Room (1:1 with Loxone Room UUID)
              └── Sensor/Meter (1:1 with Loxone Control UUID)
```

### MongoDB Collections Structure

#### 2.1 Master Data Collections (Regular Collections)

**Sites Collection**
```javascript
{
  _id: ObjectId,
  name: String,
  address: String,
  resourceType: String,
  createdAt: Date,
  updatedAt: Date
}
```

**Buildings Collection**
```javascript
{
  _id: ObjectId,
  siteId: ObjectId, // FK to Sites
  name: String,
  address: String,
  year: Number,
  contactPerson: String,
  // Loxone Connection Info
  miniserverIP: String,
  miniserverSerial: String, // e.g., "504F94D107EE"
  loxoneUser: String,
  loxoneToken: String, // JWT token
  // Building Properties
  size: Number, // m²
  typeOfUse: String, // Enum: Residential, Commercial, Industrial, etc.
  heatedArea: Number, // m² (for EUI calculations)
  energyCarrier: String, // Enum: Gas, Electricity, District Heating, etc.
  numberOfPeople: Number, // For per capita calculations
  hotWaterPrep: String, // Enum: Centralized, Decentralized
  createdAt: Date,
  updatedAt: Date
}
```

**Floors Collection**
```javascript
{
  _id: ObjectId,
  buildingId: ObjectId, // FK to Buildings
  name: String,
  floorPlanFile: String, // URL/path to floor plan image
  numberOfRooms: Number,
  order: Number, // For sorting floors
  createdAt: Date,
  updatedAt: Date
}
```

**Rooms Collection**
```javascript
{
  _id: ObjectId,
  floorId: ObjectId, // FK to Floors (can be null if no floor assigned)
  buildingId: ObjectId, // FK to Buildings (for direct access)
  // Loxone Mapping
  loxoneRoomUUID: String, // From LoxAPP3.json "rooms" object
  name: String, // From Loxone room name
  color: String, // From Loxone room color
  icon: String, // UUID of icon
  createdAt: Date,
  updatedAt: Date
}
```

**Sensors Collection**
```javascript
{
  _id: ObjectId,
  roomId: ObjectId, // FK to Rooms
  buildingId: ObjectId, // FK to Buildings (for direct queries)
  // Loxone Mapping
  loxoneControlUUID: String, // From LoxAPP3.json "controls" object
  name: String, // From Loxone control name
  // Sensor Properties
  measurementType: String, // Enum: Temperature, Power, Energy, Water, etc.
  unit: String, // "°C", "kW", "kWh", "L", etc.
  dataType: String, // "analog" or "digital"
  // Loxone Control Info
  controlType: String, // e.g., "TemperatureController", "EnergyMeter", etc.
  category: String, // From Loxone category
  isActive: Boolean,
  createdAt: Date,
  updatedAt: Date
}
```

#### 2.2 Time Series Collection (MongoDB Time Series)

**Measurements Collection (Time Series)**
```javascript
{
  _id: ObjectId,
  // Time Series Fields (must be first)
  timeField: Date, // Timestamp of measurement
  metaField: {
    sensorId: ObjectId, // FK to Sensors
    buildingId: ObjectId, // For efficient queries
    measurementType: String // For filtering
  },
  // Measurement Data
  value: Number, // The actual measurement value
  unit: String, // Unit of measurement
  // Optional metadata
  quality: Number, // Data quality indicator (0-100)
  source: String // "websocket" or "csv" or "manual"
}
```

**15-Minute Aggregated Measurements (Time Series)**
```javascript
{
  _id: ObjectId,
  // Time Series Fields
  timeField: Date, // Start of 15-minute bucket (e.g., 10:00, 10:15, 10:30)
  metaField: {
    sensorId: ObjectId,
    buildingId: ObjectId,
    measurementType: String
  },
  // Aggregated Data
  avgValue: Number, // Average value in the 15-minute window
  minValue: Number, // Minimum value
  maxValue: Number, // Maximum value
  sumValue: Number, // Sum (for cumulative meters like energy)
  count: Number, // Number of raw measurements in this bucket
  // For Energy Meters
  consumption: Number, // Total consumption in this period (kWh)
  // Metadata
  source: String // "aggregated" or "csv"
}
```

---

## 3. Parsing LoxAPP3.json Structure

### 3.1 Structure File Overview

The `LoxAPP3.json` file contains:
- **rooms**: Array of room objects with UUIDs
- **controls**: Array of control objects (sensors, actuators, etc.)
- **cats**: Categories for organizing controls
- **weatherServer**: Weather data configuration
- **lastModified**: Timestamp of last configuration change

### 3.2 Parsing Logic

```javascript
// Example parsing function
function parseLoxAPP3(loxAPP3Data, buildingId) {
  const rooms = [];
  const sensors = [];
  
  // 1. Parse Rooms
  if (loxAPP3Data.rooms) {
    for (const [uuid, roomData] of Object.entries(loxAPP3Data.rooms)) {
      rooms.push({
        buildingId: buildingId,
        loxoneRoomUUID: uuid,
        name: roomData.name || 'Unnamed Room',
        color: roomData.color || '#FFFFFF',
        icon: roomData.icon || null
      });
    }
  }
  
  // 2. Parse Controls (Sensors/Meters)
  if (loxAPP3Data.controls) {
    for (const [uuid, controlData] of Object.entries(loxAPP3Data.controls)) {
      // Filter for measurement devices only
      const measurementTypes = [
        'TemperatureController',
        'EnergyMeter',
        'WaterMeter',
        'PowerMeter',
        'AnalogInput',
        'DigitalInput'
      ];
      
      if (measurementTypes.includes(controlData.type)) {
        const roomUUID = controlData.room;
        const room = rooms.find(r => r.loxoneRoomUUID === roomUUID);
        
        if (room) {
          sensors.push({
            roomId: room._id, // Will be set after room is saved
            buildingId: buildingId,
            loxoneControlUUID: uuid,
            name: controlData.name || 'Unnamed Sensor',
            measurementType: mapControlTypeToMeasurementType(controlData.type),
            unit: getUnitFromControl(controlData),
            dataType: controlData.isAnalog ? 'analog' : 'digital',
            controlType: controlData.type,
            category: controlData.cat || null,
            isActive: true
          });
        }
      }
    }
  }
  
  return { rooms, sensors };
}

// Helper function to map Loxone control types to measurement types
function mapControlTypeToMeasurementType(loxoneType) {
  const mapping = {
    'TemperatureController': 'Temperature',
    'EnergyMeter': 'Energy',
    'WaterMeter': 'Water',
    'PowerMeter': 'Power',
    'AnalogInput': 'Analog',
    'DigitalInput': 'Digital'
  };
  return mapping[loxoneType] || 'Unknown';
}

// Helper function to extract unit from control
function getUnitFromControl(control) {
  // Check format string or default based on control type
  if (control.format) {
    if (control.format.includes('°C') || control.format.includes('°')) return '°C';
    if (control.format.includes('kW')) return 'kW';
    if (control.format.includes('kWh')) return 'kWh';
    if (control.format.includes('L')) return 'L';
  }
  
  // Default based on type
  const defaults = {
    'TemperatureController': '°C',
    'EnergyMeter': 'kWh',
    'PowerMeter': 'kW',
    'WaterMeter': 'L'
  };
  return defaults[control.type] || '';
}
```

---

## 4. Storing Real-Time Measurements

### 4.1 MongoDB Time Series Collection Setup

```javascript
// Create Time Series Collection
db.createCollection('measurements', {
  timeseries: {
    timeField: 'timeField',
    metaField: 'metaField',
    granularity: 'seconds' // or 'minutes' for 15-min buckets
  }
});

// Create Indexes for efficient queries
db.measurements.createIndex({ 'metaField.sensorId': 1, timeField: -1 });
db.measurements.createIndex({ 'metaField.buildingId': 1, timeField: -1 });
db.measurements.createIndex({ 'metaField.measurementType': 1, timeField: -1 });
```

### 4.2 Storing WebSocket Events

When you receive binary value updates from the WebSocket:

```javascript
// In your handleValueStates function
function handleValueStates(buffer, sensorsMap) {
  const entrySize = 24; // 16 bytes UUID + 8 bytes float
  const entryCount = Math.floor(buffer.length / entrySize);
  
  const measurements = [];
  
  for (let i = 0; i < entryCount; i++) {
    const offset = i * entrySize;
    
    // Extract UUID (16 bytes)
    const uuidBytes = buffer.slice(offset, offset + 16);
    const uuid = formatUUID(uuidBytes);
    
    // Extract value (8 bytes, double precision float)
    const value = buffer.readDoubleBE(offset + 16);
    
    // Find sensor by UUID
    const sensor = sensorsMap.get(uuid);
    
    if (sensor) {
      measurements.push({
        timeField: new Date(),
        metaField: {
          sensorId: sensor._id,
          buildingId: sensor.buildingId,
          measurementType: sensor.measurementType
        },
        value: value,
        unit: sensor.unit,
        source: 'websocket',
        quality: 100 // Assume good quality from live connection
      });
    }
  }
  
  // Bulk insert to MongoDB
  if (measurements.length > 0) {
    db.measurements.insertMany(measurements, { ordered: false });
  }
}
```

### 4.3 15-Minute Aggregation Strategy

**Interpretation**: Store both raw data AND aggregated 15-minute buckets.

**Approach A: Real-time Aggregation (Recommended)**

Use MongoDB's `$setWindowFields` or a background job to aggregate:

```javascript
// Aggregation pipeline to create 15-minute buckets
function aggregate15MinuteBuckets(sensorId, startTime, endTime) {
  return db.measurements.aggregate([
    {
      $match: {
        'metaField.sensorId': sensorId,
        timeField: { $gte: startTime, $lt: endTime }
      }
    },
    {
      $group: {
        _id: {
          $dateTrunc: {
            date: '$timeField',
            unit: 'minute',
            binSize: 15
          }
        },
        avgValue: { $avg: '$value' },
        minValue: { $min: '$value' },
        maxValue: { $max: '$value' },
        sumValue: { $sum: '$value' },
        count: { $sum: 1 },
        firstValue: { $first: '$value' },
        lastValue: { $last: '$value' }
      }
    },
    {
      $project: {
        _id: 0,
        timeField: '$_id',
        metaField: {
          sensorId: sensorId,
          buildingId: buildingId,
          measurementType: measurementType
        },
        avgValue: 1,
        minValue: 1,
        maxValue: 1,
        sumValue: 1,
        count: 1,
        // For energy meters, calculate consumption
        consumption: {
          $cond: {
            if: { $eq: ['$measurementType', 'Energy'] },
            then: { $subtract: ['$lastValue', '$firstValue'] },
            else: null
          }
        },
        source: 'aggregated'
      }
    },
    {
      $merge: {
        into: 'measurements_15min',
        whenMatched: 'replace',
        whenNotMatched: 'insert'
      }
    }
  ]);
}
```

**Approach B: Background Job (Every 15 minutes)**

```javascript
// Run every 15 minutes via cron/scheduler
async function aggregateRecentMeasurements() {
  const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
  const now = new Date();
  
  // Get all active sensors
  const sensors = await db.sensors.find({ isActive: true }).toArray();
  
  for (const sensor of sensors) {
    await aggregate15MinuteBuckets(
      sensor._id,
      fifteenMinutesAgo,
      now
    );
  }
}
```

---

## 5. Data Models for Your Requirements

### 5.1 Renovations Collection (Module M2)

```javascript
{
  _id: ObjectId,
  buildingId: ObjectId, // FK to Buildings
  name: String, // e.g., "South Wing Window Replacement"
  description: String, // Objective/description
  startDate: Date,
  endDate: Date,
  status: String, // Enum: "Planned", "In implementation", "Completed", "Aborted"
  category: String, // Enum: "Roof", "Windows", "Heating", "Lighting", etc.
  responsiblePerson: ObjectId, // FK to Users
  executiveCompany: String,
  // Financial
  investmentCost: Number, // Gross cost
  netCostAdjustment: Number, // Adjustments
  fundingSubsidies: Number, // Funding/subsidies received
  // Energy Impact
  energyBenefitAnnual: Number, // kWh/year savings
  co2Savings: Number, // CO₂ savings (kg/year)
  currencyConversion: Number, // Energy tariff for conversion
  // Documentation
  documentationLinks: [String], // Array of URLs
  referenceBasis: String, // Reference for calculations
  internalNotes: String, // Internal comments
  // Evaluation
  evaluationStatus: String, // Enum: "Complete - Success", "Complete - Failure", etc.
  roi: Number, // Return on Investment
  createdAt: Date,
  updatedAt: Date
}
```

### 5.2 Tariffs Collection (Module M3)

```javascript
{
  _id: ObjectId,
  buildingId: ObjectId, // FK to Buildings
  energyCarrier: String, // "Electricity", "Gas", etc.
  tariffName: String,
  unitPrice: Number, // Price per kWh or m³
  currency: String, // "EUR", "USD", etc.
  validFrom: Date,
  validTo: Date,
  isActive: Boolean,
  createdAt: Date,
  updatedAt: Date
}
```

---

## 6. Implementation Steps

### Step 1: Initial Structure Import

```javascript
// After successful connection and receiving LoxAPP3.json
async function importLoxoneStructure(buildingId, loxAPP3Data) {
  const { rooms, sensors } = parseLoxAPP3(loxAPP3Data, buildingId);
  
  // 1. Save Rooms
  const savedRooms = await db.rooms.insertMany(rooms);
  const roomMap = new Map();
  savedRooms.insertedIds.forEach((id, index) => {
    roomMap.set(rooms[index].loxoneRoomUUID, id);
  });
  
  // 2. Update sensors with room IDs
  sensors.forEach(sensor => {
    const room = rooms.find(r => r.loxoneRoomUUID === sensor.roomUUID);
    if (room) {
      sensor.roomId = roomMap.get(room.loxoneRoomUUID);
    }
  });
  
  // 3. Save Sensors
  await db.sensors.insertMany(sensors);
  
  // 4. Create UUID to Sensor mapping for real-time updates
  const sensorsList = await db.sensors.find({ buildingId }).toArray();
  const uuidMap = new Map();
  sensorsList.forEach(sensor => {
    uuidMap.set(sensor.loxoneControlUUID, sensor);
  });
  
  return uuidMap;
}
```

### Step 2: Real-Time Data Storage

```javascript
// In your WebSocket message handler
const sensorsMap = new Map(); // UUID -> Sensor document

ws.on('message', async (data, isBinary) => {
  if (isBinary) {
    const identifier = data.readUInt8(1);
    
    if (identifier === 2) { // Value-States
      const measurements = handleValueStates(data.slice(8), sensorsMap);
      
      // Store in time series collection
      if (measurements.length > 0) {
        await db.measurements.insertMany(measurements, { ordered: false });
        
        // Optionally trigger aggregation for recent data
        // (or do this in background job)
      }
    }
  }
});
```

### Step 3: Background Aggregation Job

```javascript
// Run every 15 minutes
const cron = require('node-cron');

cron.schedule('*/15 * * * *', async () => {
  console.log('Running 15-minute aggregation...');
  await aggregateRecentMeasurements();
});
```

---

## 7. Querying Time Series Data

### Example Queries

```javascript
// Get latest measurement for a sensor
db.measurements.findOne(
  { 'metaField.sensorId': sensorId },
  { sort: { timeField: -1 } }
);

// Get 15-minute aggregated data for a date range
db.measurements_15min.find({
  'metaField.sensorId': sensorId,
  timeField: {
    $gte: new Date('2025-01-01'),
    $lt: new Date('2025-01-02')
  }
}).sort({ timeField: 1 });

// Get all energy measurements for a building today
db.measurements.find({
  'metaField.buildingId': buildingId,
  'metaField.measurementType': 'Energy',
  timeField: {
    $gte: new Date().setHours(0, 0, 0, 0),
    $lt: new Date()
  }
});

// Calculate daily consumption (for energy meters)
db.measurements_15min.aggregate([
  {
    $match: {
      'metaField.sensorId': sensorId,
      timeField: { $gte: startDate, $lt: endDate }
    }
  },
  {
    $group: {
      _id: { $dateToString: { format: '%Y-%m-%d', date: '$timeField' } },
      totalConsumption: { $sum: '$consumption' },
      avgPower: { $avg: '$avgValue' }
    }
  }
]);
```

---

## 8. Best Practices

1. **Indexing**: Always index `metaField` fields and `timeField` for efficient queries
2. **Batch Inserts**: Use `insertMany` for bulk inserts to improve performance
3. **Error Handling**: Handle WebSocket disconnections and implement retry logic
4. **Data Validation**: Validate measurements before storing (range checks, unit consistency)
5. **Retention Policy**: Consider archiving old raw data and keeping only aggregated data
6. **Monitoring**: Track data quality, missing measurements, and connection status

---

## 9. Next Steps

1. ✅ Connection established and working
2. ⏭️ Implement structure parsing and database import
3. ⏭️ Set up MongoDB Time Series collections
4. ⏭️ Implement real-time measurement storage
5. ⏭️ Set up 15-minute aggregation job
6. ⏭️ Create API endpoints for querying data
7. ⏭️ Implement data validation and quality checks

---

## 10. Questions Answered

**Q: Multiple servers per building, or multiple buildings per server?**
- Your current mapping assumes 1:1 (Building:Miniserver)
- If needed, you can modify the Building model to support multiple Miniserver serials

**Q: 15-minute interval clarification?**
- **Recommended**: Store raw data + aggregated 15-minute buckets
- Raw data for detailed analysis
- 15-minute buckets for reporting and benchmarking
- Use background job to aggregate every 15 minutes

**Q: Sensor linkage confirmation?**
- Yes, all measurements link to Sensor entity
- Sensor links to Room → Floor → Building → Site
- This hierarchy enables all required calculations (EUI, per capita, etc.)

---

This guide provides the foundation for storing Loxone data in your MongoDB-based EMS system. Adjust the data models and aggregation logic based on your specific requirements and performance needs.

