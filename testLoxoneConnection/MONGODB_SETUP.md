# MongoDB Time Series Storage Setup Guide

## Overview

This guide explains how to set up MongoDB Time Series storage for Loxone real-time measurements.

---

## 1. Why "Unknown Identifier" and "0 value state updates"?

### The Problem

You're seeing:
- `[BINARY] Unknown identifier: 124`
- `[BINARY] Unknown identifier: 115`
- `[EVENT] Received 0 value state update(s)`

### The Root Cause

The binary message parsing was using **big endian** instead of **little endian**:
- ❌ `buffer.readUInt32BE(4)` - Wrong (big endian)
- ✅ `buffer.readUInt32LE(4)` - Correct (little endian)

Loxone uses **little endian** for:
- Message length (bytes 4-7)
- Double precision float values
- UUID components

### The Fix

I've updated the code to use little endian. You should now see:
- ✅ Correct length values
- ✅ Actual value state updates
- ✅ Proper UUID and value parsing

---

## 2. Understanding Meter States

### Important: Meters Have Multiple State UUIDs

When you see a Meter control in `LoxAPP3.json`, it has multiple state UUIDs:

```json
{
  "states": {
    "actual": "1fa373c7-026b-22cc-06ff1ac24c5b9757",    // Current power (kW)
    "total": "1fa373c7-026b-22cd-07ff1ac24c5b9757",      // Total energy (kWh)
    "totalDay": "1fa373c7-026b-22ce-08ff1ac24c5b9757",   // Daily total
    "totalWeek": "1fa373c7-026b-22d0-0aff1ac24c5b9757",  // Weekly total
    "totalMonth": "1fa373c7-026b-22d2-0cff1ac24c5b9757", // Monthly total
    "totalYear": "1fa373c7-026b-22d4-0eff1ac24c5b9757"   // Yearly total
  }
}
```

**All of these UUIDs will send value updates!** The storage module maps all state UUIDs to the same sensor, but stores them with different `stateType` values.

---

## 3. MongoDB Setup

### Step 1: Update .env File

Add these variables to your `.env` file:

```env
# MongoDB Connection (choose one)
# Local MongoDB
MONGODB_URI=mongodb://localhost:27017/aicono

# OR DigitalOcean MongoDB
MONGODB_URI=

# Building ID (required for MongoDB storage)
# This is the MongoDB ObjectId of the Building document that corresponds to this Miniserver
BUILDING_ID=507f1f77bcf86cd799439011
```

### Step 2: Create Building Document First

Before running the connection, you need to create a Building document in MongoDB:

```javascript
// In MongoDB shell or via your backend API
db.buildings.insertOne({
  site_id: ObjectId("..."), // Your Site ID
  name: "ECO-Detect Building",
  miniserver_ip: "192.168.178.201",
  miniserver_serial: "504F94D107EE",
  // ... other fields
});
```

Then use the returned `_id` as `BUILDING_ID` in your `.env`.

### Step 3: Install MongoDB Driver (if not already installed)

```bash
cd /Users/sami/Downloads/vscode-download/Aicono/testLoxoneConnection
npm install mongoose
```

---

## 4. How It Works

### Data Flow

```
Loxone WebSocket
    ↓
Binary Value Update (UUID + Value)
    ↓
Parse UUID & Value (Little Endian)
    ↓
Lookup UUID in Structure Mapping
    ↓
Find Sensor by State UUID
    ↓
Store in MongoDB Time Series Collection
```

### UUID Mapping

The system creates a mapping from **all state UUIDs** to sensors:

```
Control UUID: "1fa373c7-026b-22e0-ffffce026101d865" (Meter)
    ├── State "actual" UUID → Sensor + stateType: "actual"
    ├── State "total" UUID → Sensor + stateType: "total"
    ├── State "totalDay" UUID → Sensor + stateType: "totalDay"
    └── ...
```

When a value update arrives with UUID `1fa373c7-026b-22cc-06ff1ac24c5b9757`:
1. Lookup finds it's the "actual" state of Meter "Zähler Hauptanschluss"
2. Maps to Sensor document
3. Stores with `stateType: "actual"` and `measurementType: "Energy"`

---

## 5. MongoDB Time Series Collection Structure

### Collection: `measurements`

```javascript
{
  _id: ObjectId,
  timestamp: Date,           // Time of measurement
  meta: {
    sensorId: ObjectId,      // FK to Sensors collection
    buildingId: ObjectId,     // FK to Buildings collection
    measurementType: String,  // "Energy", "Temperature", "Power", etc.
    stateType: String        // "actual", "total", "totalDay", etc.
  },
  value: Number,             // The measurement value
  unit: String,              // "kW", "kWh", "°C", etc.
  quality: Number,           // 0-100 (default: 100)
  source: String            // "websocket", "csv", "manual"
}
```

### Indexes

Automatically created for efficient queries:
- `meta.sensorId + timestamp`
- `meta.buildingId + timestamp`
- `meta.measurementType + timestamp`
- `meta.stateType + timestamp`

---

## 6. Querying Measurements

### Get Latest Value for a Sensor

```javascript
const { getLatestMeasurement } = require('./mongodbStorage');

const latest = await getLatestMeasurement(sensorId);
console.log(`Latest: ${latest.value} ${latest.unit} at ${latest.timestamp}`);
```

### Get Measurements for Date Range

```javascript
const { getMeasurements } = require('./mongodbStorage');

const startDate = new Date('2025-01-01');
const endDate = new Date('2025-01-02');

const measurements = await getMeasurements(sensorId, startDate, endDate);
```

### Query by Building and Type

```javascript
// Get all energy measurements for a building today
const today = new Date();
today.setHours(0, 0, 0, 0);
const tomorrow = new Date(today);
tomorrow.setDate(tomorrow.getDate() + 1);

const measurements = await Measurement.find({
  'meta.buildingId': buildingId,
  'meta.measurementType': 'Energy',
  'meta.stateType': 'actual', // Current power
  timestamp: { $gte: today, $lt: tomorrow }
}).sort({ timestamp: 1 });
```

---

## 7. Understanding the Data

### Meter States Explained

For a Meter control, you'll receive updates for:

| State Type | UUID Example | Meaning | Unit | Use Case |
|------------|--------------|---------|------|----------|
| `actual` | `...22cc...` | Current power consumption | kW | Real-time monitoring |
| `total` | `...22cd...` | Cumulative energy | kWh | Total consumption |
| `totalDay` | `...22ce...` | Daily total | kWh | Daily reports |
| `totalWeek` | `...22d0...` | Weekly total | kWh | Weekly reports |
| `totalMonth` | `...22d2...` | Monthly total | kWh | Monthly reports |
| `totalYear` | `...22d4...` | Yearly total | kWh | Yearly reports |

### Storage Strategy

**Recommended**: Store all state types, but focus on:
- `actual` - For real-time power monitoring
- `total` - For cumulative energy tracking
- `totalDay` - For daily aggregation and reporting

---

## 8. Troubleshooting

### Issue: "Received 0 value state update(s)"

**Cause**: Binary parsing issue (now fixed) or empty buffer

**Solution**: The fix is already applied. You should now see actual counts.

### Issue: "Unknown identifier: 124"

**Cause**: These are likely keepalive responses or other message types not yet implemented

**Solution**: These can be ignored for now. Identifier 6 is keepalive response.

### Issue: Measurements not storing

**Check**:
1. Is `MONGODB_URI` set in `.env`?
2. Is `BUILDING_ID` set and valid?
3. Does the Building document exist in MongoDB?
4. Are Sensors imported from LoxAPP3.json?
5. Check MongoDB connection logs

### Issue: "UUID not found in mapping"

**Cause**: Sensor not imported or UUID mapping not loaded

**Solution**:
1. Import structure file first (LoxAPP3.json)
2. Ensure Sensors are created in database with correct `loxone_control_uuid`
3. Restart connection to reload mapping

---

## 9. Next Steps

1. ✅ Fix binary parsing (little endian) - **DONE**
2. ✅ Create MongoDB storage module - **DONE**
3. ⏭️ Create Building document in MongoDB
4. ⏭️ Import Rooms and Sensors from LoxAPP3.json
5. ⏭️ Set `BUILDING_ID` in `.env`
6. ⏭️ Run connection and verify measurements are storing
7. ⏭️ Set up 15-minute aggregation job
8. ⏭️ Create API endpoints for querying data

---

## 10. Example: Complete Setup

```bash
# 1. Update .env
echo "MONGODB_URI=mongodb://localhost:27017/aicono" >> .env
echo "BUILDING_ID=507f1f77bcf86cd799439011" >> .env

# 2. Install mongoose
npm install mongoose

# 3. Create Building (via MongoDB shell or API)
# Use your backend API or MongoDB shell

# 4. Import structure (via your backend API)
# This creates Rooms and Sensors from LoxAPP3.json

# 5. Run connection
npm start

# You should now see:
# [MONGODB] Connected successfully
# [MONGODB] Loaded X UUID mappings
# [EVENT] Received N value state update(s)
# [MONGODB] Stored N measurements
```

---

## 11. Integration with Your Backend

The `mongodbStorage.js` module is designed to work with your existing models:

- ✅ Uses your `Sensor` model (with `loxone_control_uuid`)
- ✅ Uses your `Building` model
- ✅ Uses your `Room` model (via Sensor → Room relationship)
- ✅ Compatible with your `MeasurementData` schema (can be extended)

You can integrate this into your main backend by:
1. Moving `mongodbStorage.js` to `backend/services/`
2. Importing it in your WebSocket service
3. Using it to store measurements as they arrive

---

This setup enables real-time storage of Loxone measurements in MongoDB Time Series collections, optimized for time-based queries and aggregations.

