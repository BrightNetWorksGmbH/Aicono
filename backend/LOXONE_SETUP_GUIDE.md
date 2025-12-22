# Loxone Integration Setup Guide

## Quick Start

### 1. Install Dependencies

```bash
cd backend
npm install ws
```

### 2. Environment Variables

Ensure your `.env` file has:
```env
MONGODB_URI=mongodb://localhost:27017/aicono
# or
MONGODB_URI=mongodb+srv://...
```

### 3. Start the Server

```bash
npm start
# or
npm run dev
```

## API Usage Examples

### Step 1: Create Buildings

```bash
POST /api/v1/buildings/site/:siteId
Content-Type: application/json
Authorization: Bearer <token>

{
  "buildingNames": ["Building 1", "Building 2"]
}
```

### Step 2: Update Building Details

```bash
PATCH /api/v1/buildings/:buildingId
Content-Type: application/json
Authorization: Bearer <token>

{
  "building_size": 500,
  "num_floors": 3,
  "year_of_construction": 2020
}
```

### Step 3: Connect to Loxone

```bash
POST /api/v1/loxone/connect/:buildingId
Content-Type: application/json
Authorization: Bearer <token>

{
  "ip": "192.168.178.201",
  "port": "",
  "protocol": "wss",
  "user": "AICONO_clouduser01",
  "pass": "A9f!Q2m#R7xP",
  "externalAddress": "dns.loxonecloud.com",
  "serialNumber": "504F94D107EE",
  "clientInfo": "Aicono Backend",
  "permission": 2
}
```

**Response:**
```json
{
  "success": true,
  "message": "Connection started",
  "buildingId": "..."
}
```

### Step 4: Check Connection Status

```bash
GET /api/v1/loxone/status/:buildingId
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "connected": true,
    "authenticated": true,
    "structureLoaded": true,
    "reconnectAttempts": 0
  }
}
```

### Step 5: Get Loxone Rooms (for Floor Plan)

```bash
GET /api/v1/loxone/rooms/:buildingId
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "_id": "...",
      "building_id": "...",
      "name": "Serverraum",
      "loxone_room_uuid": "...",
      "createdAt": "...",
      "updatedAt": "..."
    }
  ]
}
```

### Step 6: Create Floor with Local Rooms

```bash
POST /api/v1/floors/building/:buildingId
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "Ground Floor",
  "floor_plan_link": "https://...",
  "rooms": [
    {
      "name": "Serverraum",
      "color": "#FFEB3B",
      "loxone_room_id": "<ObjectId of Loxone Room>"
    },
    {
      "name": "Bürofläche 1",
      "color": "#9C27B0",
      "loxone_room_id": "<ObjectId of Loxone Room>"
    }
  ]
}
```

## Data Flow

1. **Building Created** → Building document in MongoDB
2. **Loxone Connected** → 
   - WebSocket connection established
   - Structure file saved: `data/loxone-structure/LoxAPP3_<buildingId>.json`
   - Loxone Rooms created (linked to `building_id`)
   - Sensors created (linked to Loxone Rooms)
   - UUID mapping loaded (state UUID → sensor_id)
3. **Real-time Data** →
   - Value states received via WebSocket
   - Measurements stored in Time Series collection
   - `meta.buildingId` differentiates measurements per building

## File Locations

- **Structure Files**: `backend/data/loxone-structure/LoxAPP3_<buildingId>.json`
- **Time Series Collection**: `measurements` (shared, differentiated by `meta.buildingId`)

## Troubleshooting

### Connection Fails

1. Check credentials (user, password)
2. Verify IP/external address is correct
3. Check if building exists in database
4. Check server logs for detailed error messages

### No Measurements Stored

1. Verify connection status: `GET /api/v1/loxone/status/:buildingId`
2. Check if structure file was loaded (`structureLoaded: true`)
3. Verify sensors were created: Check MongoDB `sensors` collection
4. Check UUID mapping: Should see logs like `Loaded X UUID mappings`

### Structure File Not Loading

1. Check `data/loxone-structure/` directory exists
2. Verify file permissions
3. Check connection logs for structure file reception

## Notes

- Each building maintains its own WebSocket connection
- Structure files are stored per building
- UUID mappings are cached in memory per building
- Reconnection uses exponential backoff (5s, 10s, 15s, 20s, 25s)
- Max 5 reconnection attempts before giving up

