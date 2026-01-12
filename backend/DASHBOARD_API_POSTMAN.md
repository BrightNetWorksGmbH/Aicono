# Dashboard Discovery API - Postman Testing Guide

This document provides endpoint details for testing the Dashboard Discovery API with Postman.

## Base URL
```
http://localhost:3000/api/v1/dashboard
```

## Authentication
All endpoints require JWT authentication. Include the token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

To get a token, first login:
```
POST http://localhost:3000/api/v1/auth/login
Body (JSON):
{
  "email": "user@example.com",
  "password": "password123"
}
```

---

## Endpoint 1: Get All Sites

**Method:** `GET`  
**URL:** `{{baseUrl}}/sites`  
**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters (Optional):**
- `bryteswitch_id` - Filter sites by BryteSwitch ID

**Example Request:**
```
GET http://localhost:3000/api/v1/dashboard/sites
GET http://localhost:3000/api/v1/dashboard/sites?bryteswitch_id=507f1f77bcf86cd799439011
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "site_id",
      "name": "Hauptsitz Münster",
      "address": "Münster, Germany",
      "resource_type": "office",
      "bryteswitch_id": {...},
      "building_count": 2,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  ],
  "count": 1
}
```

---

## Endpoint 2: Get Site Details

**Method:** `GET`  
**URL:** `{{baseUrl}}/sites/:siteId`  
**Headers:**
```
Authorization: Bearer <token>
```

**Path Parameters:**
- `siteId` - Site ID (e.g., `507f1f77bcf86cd799439011`)

**Query Parameters (Optional):**
- `startDate` - Start date (ISO 8601): `2024-01-01T00:00:00Z`
- `endDate` - End date (ISO 8601): `2024-01-08T00:00:00Z`
- `days` - Number of days to look back (default: 7)
- `resolution` - Override resolution: `0`, `15`, `60`, `1440`, `10080`, `43200`
- `measurementType` - Filter by type: `Energy`, `Temperature`, etc.
- `includeMeasurements` - Include measurement data: `true` or `false` (default: `true`)
- `limit` - Limit measurements: `1000` (default: 1000)

**Example Requests:**
```
GET http://localhost:3000/api/v1/dashboard/sites/507f1f77bcf86cd799439011
GET http://localhost:3000/api/v1/dashboard/sites/507f1f77bcf86cd799439011?days=7
GET http://localhost:3000/api/v1/dashboard/sites/507f1f77bcf86cd799439011?days=7&measurementType=Energy
GET http://localhost:3000/api/v1/dashboard/sites/507f1f77bcf86cd799439011?startDate=2024-01-01T00:00:00Z&endDate=2024-01-08T00:00:00Z
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "site_id",
    "name": "Hauptsitz Münster",
    "address": "Münster, Germany",
    "resource_type": "office",
    "bryteswitch_id": {...},
    "building_count": 2,
    "total_floors": 5,
    "total_rooms": 20,
    "total_sensors": 50,
    "buildings": [
      {
        "_id": "building_id",
        "name": "Main Building",
        "siteId": "site_id",
        "floors": [...],
        "kpis": {...}
      }
    ],
    "kpis": {
      "total_consumption": 2500.5,
      "peak": 150.8,
      "base": 10.2,
      "average": 48.5,
      "average_quality": 97.8,
      "unit": "kWh",
      "data_quality_warning": true
    },
    "time_range": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-08T00:00:00.000Z"
    }
  }
}
```

---

## Endpoint 3: Get Building Details

**Method:** `GET`  
**URL:** `{{baseUrl}}/buildings/:buildingId`  
**Headers:**
```
Authorization: Bearer <token>
```

**Path Parameters:**
- `buildingId` - Building ID

**Query Parameters (Same as Site Details):**
- `startDate`, `endDate`, `days`, `resolution`, `measurementType`, `includeMeasurements`, `limit`

**Example Request:**
```
GET http://localhost:3000/api/v1/dashboard/buildings/507f1f77bcf86cd799439012?days=7
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "building_id",
    "name": "Main Building",
    "siteId": "site_id",
    "building_size": 5000,
    "num_floors": 3,
    "year_of_construction": 2020,
    "type_of_use": "office",
    "floor_count": 3,
    "room_count": 10,
    "sensor_count": 25,
    "floors": [
      {
        "_id": "floor_id",
        "name": "Ground Floor",
        "buildingId": "building_id",
        "floor_plan_link": "https://...",
        "room_count": 5,
        "rooms": [...]
      }
    ],
    "kpis": {...},
    "time_range": {...}
  }
}
```

---

## Endpoint 4: Get Floor Details

**Method:** `GET`  
**URL:** `{{baseUrl}}/floors/:floorId`  
**Headers:**
```
Authorization: Bearer <token>
```

**Path Parameters:**
- `floorId` - Floor ID

**Query Parameters (Same as Site Details):**
- `startDate`, `endDate`, `days`, `resolution`, `measurementType`, `includeMeasurements`, `limit`

**Example Request:**
```
GET http://localhost:3000/api/v1/dashboard/floors/507f1f77bcf86cd799439013?days=7
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "floor_id",
    "name": "Ground Floor",
    "buildingId": "building_id",
    "floor_plan_link": "https://...",
    "room_count": 5,
    "sensor_count": 15,
    "rooms": [
      {
        "_id": "localroom_id",
        "name": "Conference Room",
        "color": "#FF5733",
        "floorId": "floor_id",
        "loxone_room_id": {...},
        "sensor_count": 3,
        "sensors": [...]
      }
    ],
    "kpis": {...},
    "time_range": {...}
  }
}
```

---

## Endpoint 5: Get Room Details

**Method:** `GET`  
**URL:** `{{baseUrl}}/rooms/:roomId`  
**Headers:**
```
Authorization: Bearer <token>
```

**Path Parameters:**
- `roomId` - LocalRoom ID (not Loxone Room ID)

**Query Parameters (Same as Site Details):**
- `startDate`, `endDate`, `days`, `resolution`, `measurementType`, `includeMeasurements`, `limit`

**Example Request:**
```
GET http://localhost:3000/api/v1/dashboard/rooms/507f1f77bcf86cd799439014?days=7&includeMeasurements=true
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "localroom_id",
    "name": "Conference Room",
    "color": "#FF5733",
    "floorId": "floor_id",
    "loxone_room_id": {
      "_id": "loxone_room_id",
      "name": "Conference Room",
      "loxone_room_uuid": "uuid",
      "buildingId": "building_id"
    },
    "sensor_count": 3,
    "sensors": [
      {
        "_id": "sensor_id",
        "name": "Energy Meter",
        "unit": "kWh",
        "roomId": "loxone_room_id",
        "loxone_control_uuid": "control_uuid",
        "loxone_category_type": "energy"
      }
    ],
    "kpis": {
      "total_consumption": 125.5,
      "peak": 15.3,
      "base": 2.5,
      "average": 8.2,
      "average_quality": 98.5,
      "unit": "kWh",
      "data_quality_warning": false
    },
    "measurements": {
      "data": [...],
      "count": 672,
      "resolution": 15,
      "resolution_label": "15-minute"
    },
    "time_range": {...}
  }
}
```

---

## Endpoint 6: Get Sensor Details

**Method:** `GET`  
**URL:** `{{baseUrl}}/sensors/:sensorId`  
**Headers:**
```
Authorization: Bearer <token>
```

**Path Parameters:**
- `sensorId` - Sensor ID

**Query Parameters:**
- `startDate`, `endDate`, `days`, `resolution`, `measurementType`, `includeMeasurements`, `limit`, `skip`

**Example Requests:**
```
GET http://localhost:3000/api/v1/dashboard/sensors/507f1f77bcf86cd799439015?days=7
GET http://localhost:3000/api/v1/dashboard/sensors/507f1f77bcf86cd799439015?days=30&resolution=60
GET http://localhost:3000/api/v1/dashboard/sensors/507f1f77bcf86cd799439015?startDate=2024-01-01T00:00:00Z&endDate=2024-01-08T00:00:00Z&limit=500
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "sensor_id",
    "name": "Energy Meter",
    "unit": "kWh",
    "roomId": "loxone_room_id",
    "loxone_control_uuid": "control_uuid",
    "loxone_category_type": "energy",
    "kpis": {
      "total_consumption": 125.5,
      "peak": 15.3,
      "base": 2.5,
      "average": 8.2,
      "average_quality": 98.5,
      "unit": "kWh",
      "data_quality_warning": false,
      "breakdown": [...]
    },
    "measurements": {
      "data": [
        {
          "_id": "measurement_id",
          "timestamp": "2024-01-01T00:00:00.000Z",
          "meta": {
            "sensorId": "sensor_id",
            "buildingId": "building_id",
            "measurementType": "Energy",
            "stateType": "actual"
          },
          "value": 12.5,
          "unit": "kWh",
          "quality": 100,
          "resolution_minutes": 15
        }
      ],
      "count": 672,
      "resolution": 15,
      "resolution_label": "15-minute"
    },
    "time_range": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-08T00:00:00.000Z"
    }
  }
}
```

---

## Testing Checklist

### 1. Authentication Test
- [ ] Login and get JWT token
- [ ] Verify token works with Authorization header
- [ ] Test with invalid token (should return 401)

### 2. Get All Sites
- [ ] Test without query parameters
- [ ] Test with `bryteswitch_id` filter
- [ ] Verify response includes building_count

### 3. Get Site Details
- [ ] Test with default parameters (7 days)
- [ ] Test with custom `days` parameter
- [ ] Test with `startDate` and `endDate`
- [ ] Test with `measurementType` filter
- [ ] Test with `resolution` override
- [ ] Test with `includeMeasurements=false`
- [ ] Verify nested structure (buildings → floors → rooms → sensors)
- [ ] Verify KPIs are calculated correctly

### 4. Get Building Details
- [ ] Test with valid buildingId
- [ ] Test with query parameters
- [ ] Verify floors and rooms are nested correctly
- [ ] Verify KPIs

### 5. Get Floor Details
- [ ] Test with valid floorId
- [ ] Verify LocalRooms are returned
- [ ] Verify sensors are linked correctly
- [ ] Verify KPIs

### 6. Get Room Details
- [ ] Test with valid LocalRoom ID
- [ ] Test with `includeMeasurements=true`
- [ ] Test with `includeMeasurements=false`
- [ ] Verify linked Loxone room information
- [ ] Verify sensors and measurements

### 7. Get Sensor Details
- [ ] Test with valid sensorId
- [ ] Test with different time ranges
- [ ] Test with different resolutions
- [ ] Test with `measurementType` filter
- [ ] Test with `limit` and `skip` for pagination
- [ ] Verify KPIs and measurement data

### 8. Error Handling
- [ ] Test with invalid IDs (should return 404)
- [ ] Test without authentication (should return 401)
- [ ] Test with unauthorized access (should return 403)
- [ ] Test with invalid date ranges (should return 400)

---

## Postman Collection Variables

Create these variables in Postman:

```
baseUrl: http://localhost:3000/api/v1/dashboard
authToken: <paste_jwt_token_here>
siteId: <paste_site_id_here>
buildingId: <paste_building_id_here>
floorId: <paste_floor_id_here>
roomId: <paste_localroom_id_here>
sensorId: <paste_sensor_id_here>
```

Then use them in requests like:
```
GET {{baseUrl}}/sites/{{siteId}}
Authorization: Bearer {{authToken}}
```

---

## Common Query Parameter Combinations

### Last 7 days with Energy data only
```
?days=7&measurementType=Energy
```

### Last 30 days with hourly resolution
```
?days=30&resolution=60
```

### Specific date range
```
?startDate=2024-01-01T00:00:00Z&endDate=2024-01-31T23:59:59Z
```

### Exclude measurements (faster, for navigation only)
```
?includeMeasurements=false
```

### Paginated measurements
```
?limit=500&skip=0
```

---

## Notes

1. **Room ID**: The `/rooms/:roomId` endpoint expects a **LocalRoom ID**, not a Loxone Room ID. LocalRooms belong to Floors and can optionally link to Loxone Rooms.

2. **Resolution**: The API automatically selects resolution based on time range:
   - < 1 day: Raw (0)
   - 1-7 days: 15-minute (15)
   - 7-90 days: Hourly (60)
   - > 90 days: Daily (1440)

3. **Time Zones**: All dates should be in ISO 8601 format. The API uses UTC internally.

4. **Data Quality**: If `average_quality < 100`, the `data_quality_warning` flag will be `true`.

5. **Performance**: Use `includeMeasurements=false` when you only need hierarchical structure and KPIs (e.g., for navigation sidebar).

