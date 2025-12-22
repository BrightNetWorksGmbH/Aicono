# Loxone Integration Migration Summary

## Overview

This document summarizes the migration of the Loxone connection implementation from `testLoxoneConnection` to the main backend, supporting multiple simultaneous connections (one per building).

## Architecture Changes

### 1. **Multi-Connection Support**

- **LoxoneConnectionManager**: Singleton service managing multiple WebSocket connections
- **Per-Building State**: Each connection maintains isolated state (authentication, structure data, UUID mappings)
- **Per-Building Structure Files**: `LoxAPP3_<buildingId>.json` stored in `data/loxone-structure/`

### 2. **Data Model Updates**

#### Building Model
- Added Loxone connection fields: `miniserver_ip`, `miniserver_port`, `miniserver_protocol`, `miniserver_user`, `miniserver_pass`, `miniserver_external_address`, `miniserver_serial`
- Added building details: `building_size`, `num_floors`, `year_of_construction`
- All fields optional except `name` and `site_id`
- Unique constraint: `name` + `site_id` (no duplicate building names per site)

#### Room Model (Loxone Rooms)
- **Changed**: `floor_id` → `building_id`
- Represents rooms imported from Loxone structure file
- Linked to building directly (not to floors)

#### LocalRoom Model (NEW)
- Represents rooms created from floor plan
- Fields: `floor_id`, `name`, `color`, `loxone_room_id` (reference to Loxone Room)
- Links local floor plan rooms to Loxone rooms

#### Sensor Model
- Added category fields: `loxone_category_uuid`, `loxone_category_name`, `loxone_category_type`
- Links to Loxone Room (not LocalRoom)

#### MeasurementData Model
- Updated to match Time Series structure from `mongodbStorage.js`
- `meta` object with: `sensorId`, `buildingId`, `measurementType`, `stateType`
- Changed `value` from `Decimal128` to `Number` for Time Series compatibility

## API Endpoints

### Building Management

```
POST   /api/v1/buildings/site/:siteId
       Body: { buildingNames: ["Building 1", "Building 2"] }
       Creates multiple buildings for a site

GET    /api/v1/buildings/site/:siteId
       Returns all buildings for a site

GET    /api/v1/buildings/:buildingId
       Returns a specific building

PATCH  /api/v1/buildings/:buildingId
       Body: { building_size, num_floors, year_of_construction, ... }
       Updates building details
```

### Loxone Connection

```
POST   /api/v1/loxone/connect/:buildingId
       Body: {
         ip, port, protocol, user, pass,
         externalAddress, serialNumber,
         clientUuid, clientInfo, permission
       }
       Establishes Loxone connection for a building

DELETE /api/v1/loxone/disconnect/:buildingId
       Disconnects Loxone connection for a building

GET    /api/v1/loxone/status/:buildingId
       Returns connection status

GET    /api/v1/loxone/connections
       Returns all active connections

GET    /api/v1/loxone/rooms/:buildingId
       Returns all Loxone rooms for a building (for floor plan linking)
```

### Floor Management

```
POST   /api/v1/floors/building/:buildingId
       Body: {
         name, floor_plan_link,
         rooms: [{ name, color, loxone_room_id }]
       }
       Creates a floor with local rooms

GET    /api/v1/floors/building/:buildingId
       Returns all floors with their local rooms

GET    /api/v1/floors/:floorId
       Returns a specific floor with rooms

PATCH  /api/v1/floors/:floorId
       Updates floor details

POST   /api/v1/floors/:floorId/rooms
       Adds a room to a floor

PATCH  /api/v1/floors/rooms/:roomId
       Updates a local room

DELETE /api/v1/floors/rooms/:roomId
       Deletes a local room
```

## Data Flow

### 1. Building Setup Flow

```
Frontend: Add Building Names
    ↓
POST /api/v1/buildings/site/:siteId
    ↓
Backend: Creates Building documents (name, site_id only)
    ↓
Frontend: Fill Building Details
    ↓
PATCH /api/v1/buildings/:buildingId
    ↓
Backend: Updates building_size, num_floors, year_of_construction
```

### 2. Loxone Connection Flow

```
Frontend: Select "Live-Feed mit API oder MQTT" → Loxone
    ↓
Frontend: Collect Loxone Credentials
    ↓
POST /api/v1/loxone/connect/:buildingId
    ↓
Backend: LoxoneConnectionManager.connect()
    ↓
    ├─→ Establishes WebSocket connection
    ├─→ Authenticates (getkey2 → getjwt)
    ├─→ Fetches structure file (data/LoxAPP3.json)
    ├─→ Saves as LoxAPP3_<buildingId>.json
    ├─→ loxoneStorageService.importStructureFromLoxAPP3()
    │   ├─→ Creates Loxone Rooms (building_id)
    │   └─→ Creates Sensors (room_id → Loxone Room)
    ├─→ Loads UUID mapping (state UUID → sensor_id)
    └─→ Enables live updates (enablebinstatusupdate)
    ↓
Real-time measurements arrive
    ↓
handleValueStates() → loxoneStorageService.storeMeasurements()
    ↓
MongoDB Time Series Collection (measurements)
```

### 3. Floor Plan Setup Flow

```
Frontend: Create Floor Plan
    ↓
GET /api/v1/loxone/rooms/:buildingId
    ↓
Backend: Returns all Loxone rooms for building
    ↓
Frontend: User selects rooms from floor plan, links to Loxone rooms
    ↓
POST /api/v1/floors/building/:buildingId
    Body: {
      name: "Ground Floor",
      rooms: [
        { name: "Serverraum", color: "#FFEB3B", loxone_room_id: <ObjectId> },
        { name: "Bürofläche 1", color: "#9C27B0", loxone_room_id: <ObjectId> }
      ]
    }
    ↓
Backend: Creates Floor + LocalRooms
    ↓
LocalRooms link to Loxone Rooms via loxone_room_id
```

## Key Design Decisions

### 1. Separate Connections Per Building

**Decision**: Create one WebSocket connection per building, even if multiple buildings use the same Loxone server.

**Rationale**:
- Each building has its own structure file
- Each building has its own sensor/room mappings
- Simpler state management and error handling
- Independent reconnection logic per building

**Future Optimization**: Could detect matching credentials and reuse connections, but would require routing structure files and state per building.

### 2. Two Room Types

**Loxone Rooms** (`Room` model):
- Imported from Loxone structure file
- Linked to `building_id` (not `floor_id`)
- Contains `loxone_room_uuid` from LoxAPP3.json
- Used for sensor mapping

**Local Rooms** (`LocalRoom` model):
- Created from floor plan
- Linked to `floor_id`
- Contains `name`, `color`, `loxone_room_id` (reference to Loxone Room)
- Used for visualization and user organization

**Connection**: LocalRooms link to Loxone Rooms via `loxone_room_id`, which allows sensors (linked to Loxone Rooms) to be associated with floor plan rooms.

### 3. Per-Building Structure Files

**Format**: `LoxAPP3_<buildingId>.json`

**Location**: `backend/data/loxone-structure/`

**Purpose**: 
- Allows multiple buildings to have different Loxone configurations
- Enables structure reloading per building
- Supports buildings with same Loxone server but different structure versions

## File Structure

```
backend/
├── models/
│   ├── Building.js          (updated - Loxone fields, optional fields)
│   ├── Room.js              (updated - building_id instead of floor_id)
│   ├── LocalRoom.js         (new - floor plan rooms)
│   ├── Sensor.js            (updated - category fields)
│   └── MeasurementData.js   (updated - Time Series structure)
├── services/
│   ├── buildingService.js           (new)
│   ├── loxoneConnectionManager.js   (new - multi-connection manager)
│   ├── loxoneStorageService.js      (new - adapted from mongodbStorage.js)
│   └── floorService.js              (new)
├── controllers/
│   ├── buildingController.js        (new)
│   ├── loxoneController.js          (new)
│   └── floorController.js           (new)
└── routes/
    ├── buildings.js         (new)
    ├── loxone.js            (new)
    └── floors.js            (new)
```

## Migration Checklist

- [x] Update Building model schema
- [x] Update Room model (building_id)
- [x] Create LocalRoom model
- [x] Update Sensor model (category fields)
- [x] Update MeasurementData model (Time Series structure)
- [x] Create BuildingService and BuildingController
- [x] Create LoxoneConnectionManager
- [x] Create LoxoneStorageService (adapted from mongodbStorage.js)
- [x] Create LoxoneController
- [x] Create FloorService and FloorController
- [x] Create routes
- [x] Update main index.js with routes
- [x] Add 'ws' dependency to package.json

## Next Steps

1. **Install Dependencies**: Run `npm install` in backend directory to install `ws` package
2. **Test Building Creation**: Test POST /api/v1/buildings/site/:siteId
3. **Test Building Update**: Test PATCH /api/v1/buildings/:buildingId
4. **Test Loxone Connection**: Test POST /api/v1/loxone/connect/:buildingId
5. **Test Floor Creation**: Test POST /api/v1/floors/building/:buildingId
6. **Verify Data Storage**: Check MongoDB for rooms, sensors, and measurements

## Notes

- All endpoints require authentication (authMiddleware)
- Structure files are stored in `backend/data/loxone-structure/`
- Time Series collection is shared across all buildings (meta.buildingId differentiates)
- UUID mappings are cached per building in memory (uuidMaps Map)
- Reconnection logic uses exponential backoff (5s, 10s, 15s, 20s, 25s)

