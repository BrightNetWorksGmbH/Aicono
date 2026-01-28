# Dashboard API Test URLs for Postman

## Base URL
```
http://localhost:3000/api/v1/dashboard
```

## Authentication
All endpoints require authentication. Include your auth token in the request headers.

---

## 1. Get Building Details

### Basic Request (Default: Last 7 days)
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338
```

### With Days Parameter
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=7
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=30
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=90
```

### With Date Range
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?startDate=2024-01-01T00:00:00Z&endDate=2024-01-08T00:00:00Z
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?startDate=2026-01-21T00:00:00Z&endDate=2026-01-28T00:00:00Z
```

### Filter by Measurement Type
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?measurementType=Energy
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?measurementType=Power
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?measurementType=Temperature
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?measurementType=Heating
```

### With Resolution Override
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?resolution=15
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?resolution=60
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?resolution=1440
```

### Combined Parameters
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=7&measurementType=Energy&resolution=60
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?startDate=2026-01-21T00:00:00Z&endDate=2026-01-28T00:00:00Z&measurementType=Power&resolution=15
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=30&measurementType=Temperature&includeMeasurements=false
```

### Exclude Measurements
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?includeMeasurements=false
```

### With Limit
```
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?limit=100
GET http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=7&limit=500
```

---

## 2. Get Site Details

### Basic Request
```
GET http://localhost:3000/api/v1/dashboard/sites/6948dc4d13537bff98eb732e
```

### With Query Parameters
```
GET http://localhost:3000/api/v1/dashboard/sites/6948dc4d13537bff98eb732e?days=7
GET http://localhost:3000/api/v1/dashboard/sites/6948dc4d13537bff98eb732e?startDate=2026-01-21T00:00:00Z&endDate=2026-01-28T00:00:00Z
GET http://localhost:3000/api/v1/dashboard/sites/6948dc4d13537bff98eb732e?days=30&measurementType=Power&resolution=60
```

---

## 3. Get Floor Details

### Basic Request
```
GET http://localhost:3000/api/v1/dashboard/floors/696f19d76edb6ab86709d13e
```

### With Query Parameters
```
GET http://localhost:3000/api/v1/dashboard/floors/696f19d76edb6ab86709d13e?days=7
GET http://localhost:3000/api/v1/dashboard/floors/696f19d76edb6ab86709d13e?startDate=2026-01-21T00:00:00Z&endDate=2026-01-28T00:00:00Z
GET http://localhost:3000/api/v1/dashboard/floors/696f19d76edb6ab86709d13e?days=7&measurementType=Energy
```

---

## 4. Get Room Details

### Basic Request
```
GET http://localhost:3000/api/v1/dashboard/rooms/696f19d76edb6ab86709d140
```

### With Query Parameters
```
GET http://localhost:3000/api/v1/dashboard/rooms/696f19d76edb6ab86709d140?days=7
GET http://localhost:3000/api/v1/dashboard/rooms/696f19d76edb6ab86709d140?startDate=2026-01-21T00:00:00Z&endDate=2026-01-28T00:00:00Z
GET http://localhost:3000/api/v1/dashboard/rooms/696f19d76edb6ab86709d140?days=7&measurementType=Power&includeMeasurements=false
```

---

## 5. Get Sensor Details

### Basic Request
```
GET http://localhost:3000/api/v1/dashboard/sensors/696a1041eec5cd2babccdc7b
```

### With Query Parameters
```
GET http://localhost:3000/api/v1/dashboard/sensors/696a1041eec5cd2babccdc7b?days=7
GET http://localhost:3000/api/v1/dashboard/sensors/696a1041eec5cd2babccdc7b?startDate=2026-01-21T00:00:00Z&endDate=2026-01-28T00:00:00Z
GET http://localhost:3000/api/v1/dashboard/sensors/696a1041eec5cd2babccdc7b?days=7&measurementType=Power&limit=100
GET http://localhost:3000/api/v1/dashboard/sensors/696a1041eec5cd2babccdc7b?days=7&limit=500&skip=0
```

---

## 6. Get All Sites

### Basic Request
```
GET http://localhost:3000/api/v1/dashboard/sites
```

### Filter by BryteSwitch ID
```
GET http://localhost:3000/api/v1/dashboard/sites?bryteswitch_id=YOUR_BRYTESWITCH_ID
```

---

## Query Parameters Reference

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `startDate` | ISO 8601 Date | Start date for time range | Calculated from `days` |
| `endDate` | ISO 8601 Date | End date for time range | Current date/time |
| `days` | Integer | Number of days to look back | 7 |
| `resolution` | Integer | Resolution override (0, 15, 60, 1440, 10080, 43200) | Auto-determined |
| `measurementType` | String | Filter by measurement type (Energy, Power, Temperature, Heating, etc.) | All types |
| `includeMeasurements` | Boolean | Include measurement data | true |
| `limit` | Integer | Limit number of measurements | 1000 |
| `skip` | Integer | Skip number of measurements (for pagination) | 0 |

---

## Resolution Values

- `0` - Raw data (no aggregation)
- `15` - 15-minute aggregates
- `60` - Hourly aggregates
- `1440` - Daily aggregates
- `10080` - Weekly aggregates
- `43200` - Monthly aggregates

---

## Measurement Types

- `Energy` - Energy consumption measurements
- `Power` - Power measurements
- `Temperature` - Temperature measurements
- `Heating` - Heating consumption (gas/water)
- `Analog` - Analog sensor readings
- (Other types as configured)

---

## Notes

1. **Date Format**: Use ISO 8601 format: `YYYY-MM-DDTHH:mm:ssZ` (e.g., `2026-01-21T00:00:00Z`)
2. **Default Time Range**: If neither `startDate`/`endDate` nor `days` is provided, defaults to last 7 days
3. **Resolution**: If not specified, resolution is automatically determined based on time range and data age
4. **Measurement Type**: When filtering by `Energy`, the system automatically uses appropriate stateType based on whether it's a fixed interval report or arbitrary dashboard range
5. **Authentication**: All endpoints require valid authentication token in headers

---

## Example Postman Collection Structure

```json
{
  "info": {
    "name": "Dashboard API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Buildings",
      "item": [
        {
          "name": "Get Building Details (Default)",
          "request": {
            "method": "GET",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer YOUR_TOKEN"
              }
            ],
            "url": {
              "raw": "http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338",
              "protocol": "http",
              "host": ["localhost"],
              "port": "3000",
              "path": ["api", "v1", "dashboard", "buildings", "6948dcd113537bff98eb7338"]
            }
          }
        },
        {
          "name": "Get Building Details (7 days, Power only)",
          "request": {
            "method": "GET",
            "header": [
              {
                "key": "Authorization",
                "value": "Bearer YOUR_TOKEN"
              }
            ],
            "url": {
              "raw": "http://localhost:3000/api/v1/dashboard/buildings/6948dcd113537bff98eb7338?days=7&measurementType=Power",
              "protocol": "http",
              "host": ["localhost"],
              "port": "3000",
              "path": ["api", "v1", "dashboard", "buildings", "6948dcd113537bff98eb7338"],
              "query": [
                {"key": "days", "value": "7"},
                {"key": "measurementType", "value": "Power"}
              ]
            }
          }
        }
      ]
    }
  ]
}
```
