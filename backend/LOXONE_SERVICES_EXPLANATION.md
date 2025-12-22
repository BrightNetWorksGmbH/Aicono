# Loxone Services Explanation

## Overview

This document explains the relationship between `loxoneStorageService.js` and `db/connection.js`, and how they work together without conflicts.

## Architecture

### 1. Database Connection Layer (`db/connection.js`)

**Purpose**: Establishes and manages the **single MongoDB connection** for the entire application.

**Responsibilities**:
- Creates one Mongoose connection instance
- Manages connection lifecycle (connect, disconnect, reconnect)
- Provides the connection to all services
- Handles connection errors and retries

**Key Points**:
- **Singleton Pattern**: Only one connection exists for the entire backend
- **Shared Resource**: All services use the same connection
- **Connection Pooling**: Mongoose handles connection pooling internally

```javascript
// db/connection.js
async function connectToDatabase() {
  // Creates ONE mongoose connection
  await mongoose.connect(MONGODB_URI, {...});
  // All services use mongoose.connection
}
```

### 2. Loxone Storage Service (`services/loxoneStorageService.js`)

**Purpose**: Handles **Loxone-specific data operations** using the shared MongoDB connection.

**Responsibilities**:
- Per-building structure import (rooms, sensors)
- UUID mapping management (in-memory cache per building)
- Measurement storage in Time Series collection
- Structure file management

**Key Points**:
- **Uses Shared Connection**: Accesses `mongoose.connection` (from `db/connection.js`)
- **Per-Building Isolation**: Uses `buildingId` to isolate data
- **In-Memory Caching**: UUID mappings cached per building in memory
- **No Connection Management**: Does NOT create or manage connections

```javascript
// loxoneStorageService.js
async initializeForBuilding(buildingId) {
  // Uses the shared connection
  const db = mongoose.connection.db;
  // Does NOT create a new connection
}
```

## How They Work Together

### Connection Flow

```
1. Server Starts
   ↓
2. index.js calls connectToDatabase()
   ↓
3. db/connection.js creates ONE mongoose connection
   ↓
4. All services (including loxoneStorageService) use mongoose.connection
   ↓
5. loxoneStorageService accesses mongoose.connection.db for operations
```

### Data Isolation Strategy

Even though all buildings share the same MongoDB connection, data is isolated using:

1. **Building ID in Documents**:
   - Rooms: `building_id` field
   - Sensors: Linked to rooms via `room_id` → `room.building_id`
   - Measurements: `meta.buildingId` field

2. **In-Memory UUID Maps**:
   ```javascript
   const uuidMaps = new Map(); // buildingId -> Map<uuid, sensorMapping>
   ```
   - Each building has its own UUID mapping cache
   - Prevents cross-building UUID conflicts

3. **Structure Files**:
   - Per-building files: `LoxAPP3_<buildingId>.json`
   - Stored in `data/loxone-structure/` directory

## Why No Conflicts?

### 1. **Single Connection, Multiple Operations**

MongoDB connections are designed to handle multiple concurrent operations. The connection pool manages:
- Multiple simultaneous queries
- Concurrent writes
- Different databases/collections

**Example**:
```javascript
// Building 1 operation
await db.collection('measurements').insertMany(docs1);

// Building 2 operation (simultaneous)
await db.collection('measurements').insertMany(docs2);
// Both use the same connection, but are isolated by buildingId
```

### 2. **Transaction Safety**

MongoDB operations are atomic at the document level:
- Each measurement document has `meta.buildingId`
- Queries filter by `buildingId`
- No cross-building data leakage

### 3. **In-Memory Cache Isolation**

```javascript
// Building 1
uuidMaps.set('building1', new Map([...]));

// Building 2
uuidMaps.set('building2', new Map([...]));

// Completely separate, no conflicts
```

## Code Examples

### Connection Initialization (index.js)

```javascript
// 1. Connect to database (once, at startup)
connectToDatabase()
  .then(() => {
    // 2. Server starts
    app.listen(port);
  });
```

### Storage Service Usage (loxoneConnectionManager.js)

```javascript
// When structure file is received
await loxoneStorageService.initializeForBuilding(buildingId);
// Uses mongoose.connection (already established)

await loxoneStorageService.loadStructureMapping(buildingId, json);
// Creates rooms, sensors, UUID mappings

// When measurements arrive
await loxoneStorageService.storeMeasurements(buildingId, measurements);
// Stores in Time Series collection with meta.buildingId
```

### Storage Service Implementation

```javascript
// loxoneStorageService.js
async initializeForBuilding(buildingId) {
  // Uses shared connection (no new connection created)
  const db = mongoose.connection.db;
  
  // Check if Time Series collection exists
  const collections = await db.listCollections({ name: 'measurements' }).toArray();
  
  // Create if needed (shared collection, differentiated by meta.buildingId)
  if (!collectionExists) {
    await db.createCollection('measurements', {
      timeseries: { timeField: 'timestamp', metaField: 'meta' }
    });
  }
}
```

## Key Design Principles

### 1. **Separation of Concerns**

- **db/connection.js**: Connection management only
- **loxoneStorageService.js**: Loxone data operations only
- **loxoneConnectionManager.js**: WebSocket connection management

### 2. **Shared Resources, Isolated Data**

- **Shared**: MongoDB connection, Time Series collection
- **Isolated**: Building data (via `buildingId`), UUID mappings (in-memory per building)

### 3. **No Circular Dependencies**

```
db/connection.js
  ↓ (provides connection)
loxoneStorageService.js
  ↓ (uses connection)
loxoneConnectionManager.js
  ↓ (calls storage service)
```

## Common Questions

### Q: Why not create a separate connection per building?

**A**: 
- Unnecessary overhead (MongoDB handles concurrency well)
- Connection pooling is more efficient with one connection
- Simpler error handling and reconnection logic
- Data isolation is achieved through `buildingId`, not separate connections

### Q: What if two buildings write simultaneously?

**A**: 
- MongoDB handles concurrent writes safely
- Each document has `meta.buildingId` for isolation
- Operations are atomic at the document level
- No data corruption or cross-building conflicts

### Q: What happens if the connection drops?

**A**: 
- `db/connection.js` handles reconnection
- Mongoose automatically retries failed operations
- `loxoneStorageService` checks `mongoose.connection.readyState` before operations
- Loxone connections can continue (WebSocket independent of MongoDB)

## Summary

- **db/connection.js**: Manages ONE MongoDB connection for the entire app
- **loxoneStorageService.js**: Uses that connection for Loxone-specific operations
- **No Conflicts**: Data isolated by `buildingId`, UUID maps isolated in memory
- **Efficient**: Single connection with connection pooling handles all operations
- **Safe**: MongoDB's atomic operations and document-level isolation prevent conflicts

