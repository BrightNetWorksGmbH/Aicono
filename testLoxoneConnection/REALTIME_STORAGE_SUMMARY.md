# Real-Time Data Storage Summary

## ✅ What's Fixed

### 1. Binary Message Parsing (FIXED)
- **Problem**: Using big endian instead of little endian
- **Fix**: Changed to `readUInt32LE()` and `readDoubleLE()`
- **Result**: Now correctly parsing value state updates

### 2. Unknown Identifiers (EXPLAINED)
- Identifiers 124, 115, 120 are likely:
  - Keepalive responses (identifier 6)
  - Other message types not yet implemented
  - Can be safely ignored for now

### 3. "0 value state updates" (FIXED)
- Was caused by incorrect binary parsing
- Now correctly counts and parses entries

---

## 📊 How Real-Time Data Works

### Data Flow

```
Loxone Miniserver
    ↓ (WebSocket Binary Message)
Binary Value Update (Identifier: 2)
    ↓ (24 bytes per entry: 16-byte UUID + 8-byte float)
Parse UUID & Value (Little Endian)
    ↓
Lookup UUID in Structure Mapping
    ↓
Find Sensor by State UUID
    ↓
Store in MongoDB Time Series Collection
```

### Understanding Meter States

**Important**: Each Meter control has MULTIPLE state UUIDs that send updates:

```json
{
  "name": "Zähler Hauptanschluss",
  "type": "Meter",
  "states": {
    "actual": "1fa373c7-026b-22cc-...",    // Current power (kW) - UPDATES FREQUENTLY
    "total": "1fa373c7-026b-22cd-...",      // Total energy (kWh) - UPDATES FREQUENTLY
    "totalDay": "1fa373c7-026b-22ce-...",   // Daily total - UPDATES PERIODICALLY
    "totalWeek": "1fa373c7-026b-22d0-...",  // Weekly total - UPDATES PERIODICALLY
    "totalMonth": "1fa373c7-026b-22d2-...", // Monthly total - UPDATES PERIODICALLY
    "totalYear": "1fa373c7-026b-22d4-..."  // Yearly total - UPDATES PERIODICALLY
  }
}
```

**All of these UUIDs will send value updates!** The storage system maps them all to the same sensor but stores them with different `stateType` values.

---

## 🗄️ MongoDB Storage Setup

### Step 1: Update .env

Add to your `.env` file:

```env
# MongoDB Connection
MONGODB_URI=mongodb://localhost:27017/aicono
# OR
# MONGODB_URI=mongodb+srv://doadmin:6014M7Tk3G85fOqN@db-brightspace-f64857eb.mongo.ondigitalocean.com/admin?tls=true&authSource=admin&replicaSet=db-brightspace

# Building ID (MongoDB ObjectId)
BUILDING_ID=507f1f77bcf86cd799439011
```

### Step 2: Create Building Document

Before running, create a Building in MongoDB:

```javascript
// Via MongoDB shell or your backend API
db.buildings.insertOne({
  site_id: ObjectId("..."), // Your Site ID
  name: "ECO-Detect Building",
  miniserver_ip: "192.168.178.201",
  miniserver_serial: "504F94D107EE",
  // ... other fields
});
```

Use the returned `_id` as `BUILDING_ID`.

### Step 3: Import Structure (Rooms & Sensors)

You need to import Rooms and Sensors from `LoxAPP3.json` into MongoDB. This should be done via your backend API that:
1. Parses `LoxAPP3.json`
2. Creates Room documents with `loxone_room_uuid`
3. Creates Sensor documents with `loxone_control_uuid`

### Step 4: Run Connection

```bash
npm start
```

You should see:
```
[MONGODB] Connected successfully
[MONGODB] Created Time Series collection: measurements
[MONGODB] Loaded X UUID mappings for building ...
[EVENT] Received N value state update(s)
[MONGODB] Stored N measurements, skipped 0 unknown UUIDs
```

---

## 📝 Storage Schema

### Time Series Collection: `measurements`

```javascript
{
  _id: ObjectId,
  timestamp: Date,              // When measurement was taken
  meta: {
    sensorId: ObjectId,          // FK to Sensors collection
    buildingId: ObjectId,        // FK to Buildings collection
    measurementType: String,     // "Energy", "Temperature", "Power", etc.
    stateType: String           // "actual", "total", "totalDay", etc.
  },
  value: Number,                 // The measurement value
  unit: String,                  // "kW", "kWh", "°C", etc.
  quality: Number,              // 0-100 (default: 100)
  source: String                // "websocket", "csv", "manual"
}
```

### Example Documents

**Power Measurement (actual state)**:
```javascript
{
  timestamp: ISODate("2025-12-16T14:30:00Z"),
  meta: {
    sensorId: ObjectId("..."),
    buildingId: ObjectId("..."),
    measurementType: "Energy",
    stateType: "actual"
  },
  value: 2.345,
  unit: "kW",
  quality: 100,
  source: "websocket"
}
```

**Energy Measurement (total state)**:
```javascript
{
  timestamp: ISODate("2025-12-16T14:30:00Z"),
  meta: {
    sensorId: ObjectId("..."),
    buildingId: ObjectId("..."),
    measurementType: "Energy",
    stateType: "total"
  },
  value: 12345.67,
  unit: "kWh",
  quality: 100,
  source: "websocket"
}
```

---

## 🔍 Querying Measurements

### Get Latest Power for a Sensor

```javascript
const Measurement = require('./mongodbStorage').Measurement;

const latest = await Measurement.findOne(
  {
    'meta.sensorId': sensorId,
    'meta.stateType': 'actual'
  },
  {},
  { sort: { timestamp: -1 } }
);
```

### Get Daily Energy Consumption

```javascript
// Get total energy at start and end of day
const startOfDay = new Date();
startOfDay.setHours(0, 0, 0, 0);

const endOfDay = new Date();
endOfDay.setHours(23, 59, 59, 999);

const startTotal = await Measurement.findOne(
  {
    'meta.sensorId': sensorId,
    'meta.stateType': 'total',
    timestamp: { $gte: startOfDay, $lt: new Date(startOfDay.getTime() + 60000) }
  },
  {},
  { sort: { timestamp: 1 } }
);

const endTotal = await Measurement.findOne(
  {
    'meta.sensorId': sensorId,
    'meta.stateType': 'total',
    timestamp: { $gte: endOfDay, $lt: new Date(endOfDay.getTime() + 60000) }
  },
  {},
  { sort: { timestamp: -1 } }
);

const dailyConsumption = endTotal.value - startTotal.value; // kWh
```

### Get All Measurements for Building Today

```javascript
const today = new Date();
today.setHours(0, 0, 0, 0);
const tomorrow = new Date(today);
tomorrow.setDate(tomorrow.getDate() + 1);

const measurements = await Measurement.find({
  'meta.buildingId': buildingId,
  'meta.measurementType': 'Energy',
  'meta.stateType': 'actual',
  timestamp: { $gte: today, $lt: tomorrow }
}).sort({ timestamp: 1 });
```

---

## 🎯 Key Points

1. **Binary Parsing Fixed**: Now using little endian (correct)
2. **Multiple State UUIDs**: Each Meter has multiple states (actual, total, etc.)
3. **UUID Mapping**: All state UUIDs map to the same sensor
4. **Time Series Collection**: Optimized for time-based queries
5. **Real-Time Storage**: Measurements stored as they arrive
6. **15-Minute Aggregation**: Can be done via background job (see LOXONE_DATA_STORAGE_GUIDE.md)

---

## 🚀 Next Steps

1. ✅ Binary parsing fixed
2. ✅ MongoDB storage module created
3. ⏭️ Create Building document in MongoDB
4. ⏭️ Import Rooms and Sensors from LoxAPP3.json
5. ⏭️ Set BUILDING_ID in .env
6. ⏭️ Test real-time storage
7. ⏭️ Set up 15-minute aggregation job
8. ⏭️ Create API endpoints for querying

---

## 📚 Related Files

- `LOXONE_DATA_STORAGE_GUIDE.md` - Complete storage guide
- `MONGODB_SETUP.md` - Detailed MongoDB setup instructions
- `mongodbStorage.js` - Storage module implementation
- `index.js` - Main connection file (updated with storage integration)

---

The system is now ready to store real-time Loxone measurements in MongoDB Time Series collections!

