# Aicono EMS API Endpoints

## Authentication Endpoints

### POST /api/v1/auth/login
Login user and get JWT token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user": {
      "_id": "user_id",
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "position": "Engineer",
      "profile_picture_url": "https://..."
    },
    "token": "jwt_token_here",
    "roles": [
      {
        "role_id": "role_id",
        "role_name": "Admin",
        "permissions": {},
        "bryteswitch_id": "bryteswitch_id",
        "organization_name": "Organization Name",
        "sub_domain": "subdomain"
      }
    ],
    "is_setup_complete": false
  }
}
```

**Error Responses:**
- `400` - Missing email or password
- `401` - Invalid credentials or inactive account
- `500` - Server error

---

### POST /api/v1/auth/forgot-password
Request password reset email.

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "If an account with that email exists, a password reset link has been sent"
}
```

**Error Responses:**
- `400` - Missing email
- `403` - Account is inactive
- `500` - Server error

---

### POST /api/v1/auth/reset-password
Reset password using token from email.

**Request Body:**
```json
{
  "token": "reset_token_from_email",
  "new_password": "newpassword123",
  "confirm_password": "newpassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password has been reset successfully. You can now log in with your new password."
}
```

**Error Responses:**
- `400` - Missing fields, passwords don't match, weak password, or invalid/expired token
- `403` - Account is inactive
- `500` - Server error

---

## Invitation Endpoints

### POST /api/v1/invitations/accept-password
Accept invitation and set password for new user.

**Request Body:**
```json
{
  "invitation_token": "invitation_token_from_link",
  "new_password": "password123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password set successfully and invitation accepted",
  "data": {
    "user": {
      "_id": "user_id",
      "email": "user@example.com",
      "first_name": "",
      "last_name": ""
    }
  }
}
```

**Error Responses:**
- `400` - Missing fields, weak password, invitation already accepted, expired, or invalid status
- `404` - Invalid invitation token
- `500` - Server error

---

## Environment Variables Required

Add these to your `.env` file:

```env
# Server
PORT=3000
NODE_ENV=development

# Database
MONGODB_URI=mongodb+srv://...

# JWT
JWT_SECRET=your-secret-key-change-in-production

# Mailjet (for email sending)
MJ_API_KEY=your_mailjet_api_key
MJ_SECRET_KEY=your_mailjet_secret_key
MJ_FROM_EMAIL=noreply@aicono.com
FROM_NAME=AICONO EMS

# Frontend URL (for password reset links)
FRONTEND_URL=http://localhost:3000

# Optional: Logo URL for emails
AICONO_LOGO_URL=https://your-logo-url.com/logo.png
```

---

## Authentication Flow

1. **User Registration via Invitation:**
   - User receives invitation email with token
   - User clicks link and is taken to password setup page
   - User calls `POST /api/v1/invitations/accept-password` with token and password
   - System creates/updates user, creates UserRole, marks invitation as accepted

2. **User Login:**
   - User calls `POST /api/v1/auth/login` with email and password
   - System verifies credentials and returns JWT token with user info and setup status

3. **Password Reset:**
   - User calls `POST /api/v1/auth/forgot-password` with email
   - System sends password reset email with token
   - User clicks link and calls `POST /api/v1/auth/reset-password` with token and new password
   - System updates password and clears reset token

---

## Security Features

- Passwords are hashed using bcrypt (10 rounds)
- JWT tokens expire after 7 days
- Password reset tokens expire after 10 minutes
- All tokens are hashed before storage
- Email validation and password strength requirements
- Activity logging for security auditing

---

## Dashboard Discovery API Endpoints

The Dashboard Discovery API provides hierarchical data retrieval for the dashboard with nested structures:
**Site → Building → Floor → Room → Sensor**

Each endpoint supports:
- **Time range filtering**: `startDate`, `endDate`, `days` (default: 7 days)
- **Resolution selection**: Automatic based on time range, or override with `resolution` parameter
  - `0` - Raw data (< 1 day)
  - `15` - 15-minute aggregates (1-7 days)
  - `60` - Hourly aggregates (7-90 days)
  - `1440` - Daily aggregates (> 90 days)
  - `10080` - Weekly aggregates
  - `43200` - Monthly aggregates
- **Measurement type filtering**: `measurementType` (e.g., 'Energy', 'Temperature', 'Water')
- **KPI calculations**: Total Consumption, Peak, Base, Average Quality
- **Data quality warnings**: Alert when average quality < 100%

All endpoints require authentication via JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

### GET /api/v1/dashboard/sites

Get all sites for the authenticated user with basic metadata.

**Query Parameters:**
- `bryteswitch_id` (optional): Filter sites by BryteSwitch ID

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "_id": "site_id",
      "name": "Hauptsitz Münster",
      "address": "Münster, Germany",
      "resource_type": "office",
      "bryteswitch_id": "bryteswitch_id",
      "building_count": 2,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  ],
  "count": 1
}
```

**Error Responses:**
- `401` - Unauthorized (invalid or missing token)
- `500` - Server error

---

### GET /api/v1/dashboard/sites/:siteId

Get site details with full hierarchy including all buildings, floors, rooms, sensors, and aggregated KPIs.

**Path Parameters:**
- `siteId` - Site ID

**Query Parameters:**
- `startDate` (optional): Start date in ISO 8601 format (e.g., "2024-01-01T00:00:00Z")
- `endDate` (optional): End date in ISO 8601 format (default: now)
- `days` (optional): Number of days to look back (default: 7, ignored if startDate is provided)
- `resolution` (optional): Override automatic resolution (0, 15, 60, 1440, 10080, 43200)
- `measurementType` (optional): Filter by measurement type (e.g., "Energy", "Temperature")
- `includeMeasurements` (optional): Include measurement data (default: true, set to "false" to exclude)
- `limit` (optional): Limit number of measurements (default: 1000)

**Example Request:**
```
GET /api/v1/dashboard/sites/507f1f77bcf86cd799439011?days=7&measurementType=Energy
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "site_id",
    "name": "Hauptsitz Münster",
    "address": "Münster, Germany",
    "resource_type": "office",
    "bryteswitch_id": "bryteswitch_id",
    "building_count": 2,
    "total_floors": 5,
    "total_rooms": 20,
    "total_sensors": 50,
    "buildings": [
      {
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
            "rooms": [
              {
                "_id": "room_id",
                "name": "Conference Room",
                "buildingId": "building_id",
                "loxone_room_uuid": "uuid",
                "sensor_count": 3,
                "sensors": [
                  {
                    "_id": "sensor_id",
                    "name": "Energy Meter",
                    "unit": "kWh",
                    "roomId": "room_id",
                    "loxone_control_uuid": "control_uuid",
                    "loxone_category_type": "energy"
                  }
                ],
                "created_at": "2024-01-01T00:00:00.000Z",
                "updated_at": "2024-01-01T00:00:00.000Z"
              }
            ],
            "created_at": "2024-01-01T00:00:00.000Z",
            "updated_at": "2024-01-01T00:00:00.000Z"
          }
        ],
        "kpis": {
          "total_consumption": 1250.5,
          "peak": 85.3,
          "base": 12.5,
          "average": 45.2,
          "average_quality": 98.5,
          "unit": "kWh",
          "data_quality_warning": false,
          "breakdown": [
            {
              "measurement_type": "Energy",
              "total": 1250.5,
              "average": 45.2,
              "min": 12.5,
              "max": 85.3,
              "count": 672,
              "unit": "kWh"
            }
          ]
        },
        "created_at": "2024-01-01T00:00:00.000Z",
        "updated_at": "2024-01-01T00:00:00.000Z"
      }
    ],
    "kpis": {
      "total_consumption": 2500.5,
      "peak": 150.8,
      "base": 10.2,
      "average": 48.5,
      "average_quality": 97.8,
      "unit": "kWh",
      "data_quality_warning": true,
      "breakdown": [...]
    },
    "time_range": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-08T00:00:00.000Z"
    },
    "created_at": "2024-01-01T00:00:00.000Z",
    "updated_at": "2024-01-01T00:00:00.000Z"
  }
}
```

**Error Responses:**
- `401` - Unauthorized
- `403` - Access denied to this site
- `404` - Site not found
- `500` - Server error

---

### GET /api/v1/dashboard/buildings/:buildingId

Get building details with nested data (floors, rooms, sensors) and KPIs.

**Path Parameters:**
- `buildingId` - Building ID

**Query Parameters:**
- Same as GET /api/v1/dashboard/sites/:siteId

**Response (200 OK):**
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
    "floors": [...],
    "kpis": {
      "total_consumption": 1250.5,
      "peak": 85.3,
      "base": 12.5,
      "average": 45.2,
      "average_quality": 98.5,
      "unit": "kWh",
      "data_quality_warning": false,
      "breakdown": [...]
    },
    "time_range": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-08T00:00:00.000Z"
    },
    "created_at": "2024-01-01T00:00:00.000Z",
    "updated_at": "2024-01-01T00:00:00.000Z"
  }
}
```

**Error Responses:**
- `401` - Unauthorized
- `403` - Access denied to this building
- `404` - Building not found
- `500` - Server error

---

### GET /api/v1/dashboard/floors/:floorId

Get floor details with nested data (rooms, sensors) and KPIs.

**Path Parameters:**
- `floorId` - Floor ID

**Query Parameters:**
- Same as GET /api/v1/dashboard/sites/:siteId

**Response (200 OK):**
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
    "rooms": [...],
    "kpis": {
      "total_consumption": 450.5,
      "peak": 65.3,
      "base": 8.5,
      "average": 32.2,
      "average_quality": 99.0,
      "unit": "kWh",
      "data_quality_warning": false,
      "breakdown": [...]
    },
    "time_range": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-08T00:00:00.000Z"
    },
    "created_at": "2024-01-01T00:00:00.000Z",
    "updated_at": "2024-01-01T00:00:00.000Z"
  }
}
```

**Error Responses:**
- `401` - Unauthorized
- `403` - Access denied to this floor
- `404` - Floor not found
- `500` - Server error

---

### GET /api/v1/dashboard/rooms/:roomId

Get room details with nested data (sensors) and KPIs. Optionally includes measurement data.

**Path Parameters:**
- `roomId` - Room ID

**Query Parameters:**
- Same as GET /api/v1/dashboard/sites/:siteId

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "room_id",
    "name": "Conference Room",
    "buildingId": "building_id",
    "loxone_room_uuid": "uuid",
    "sensor_count": 3,
    "sensors": [
      {
        "_id": "sensor_id",
        "name": "Energy Meter",
        "unit": "kWh",
        "roomId": "room_id",
        "loxone_control_uuid": "control_uuid",
        "loxone_category_type": "energy",
        "created_at": "2024-01-01T00:00:00.000Z",
        "updated_at": "2024-01-01T00:00:00.000Z"
      }
    ],
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
    },
    "created_at": "2024-01-01T00:00:00.000Z",
    "updated_at": "2024-01-01T00:00:00.000Z"
  }
}
```

**Error Responses:**
- `401` - Unauthorized
- `403` - Access denied to this room
- `404` - Room not found
- `500` - Server error

---

### GET /api/v1/dashboard/sensors/:sensorId

Get sensor details with measurement data and KPIs.

**Path Parameters:**
- `sensorId` - Sensor ID

**Query Parameters:**
- Same as GET /api/v1/dashboard/sites/:siteId, plus:
- `skip` (optional): Skip number of measurements for pagination

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "sensor_id",
    "name": "Energy Meter",
    "unit": "kWh",
    "roomId": "room_id",
    "loxone_control_uuid": "control_uuid",
    "loxone_category_uuid": "category_uuid",
    "loxone_category_name": "Energy",
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
          "resolution_minutes": 15,
          "avgValue": 12.5,
          "minValue": 10.2,
          "maxValue": 15.3,
          "count": 60
        }
      ],
      "count": 672,
      "resolution": 15,
      "resolution_label": "15-minute"
    },
    "time_range": {
      "start": "2024-01-01T00:00:00.000Z",
      "end": "2024-01-08T00:00:00.000Z"
    },
    "created_at": "2024-01-01T00:00:00.000Z",
    "updated_at": "2024-01-01T00:00:00.000Z"
  }
}
```

**Error Responses:**
- `401` - Unauthorized
- `403` - Access denied to this sensor
- `404` - Sensor not found
- `500` - Server error

---

## KPI Calculations

Each level (Site, Building, Floor, Room, Sensor) includes aggregated KPIs:

- **total_consumption**: Sum of all Energy consumption values in the time range
- **peak**: Maximum consumption value in a single period (peak demand)
- **base**: Minimum consumption value in a single period (base load)
- **average**: Average consumption over the time range
- **average_quality**: Average data quality score (0-100)
- **data_quality_warning**: Boolean flag indicating if average quality < 100%
- **unit**: Unit of measurement (typically "kWh" for Energy)
- **breakdown**: Detailed breakdown by measurement type with statistics

## Resolution Selection

The API automatically selects the appropriate resolution based on the time range:
- **< 1 day**: Raw data (resolution: 0)
- **1-7 days**: 15-minute aggregates (resolution: 15)
- **7-90 days**: Hourly aggregates (resolution: 60)
- **> 90 days**: Daily aggregates (resolution: 1440)

You can override this by providing the `resolution` query parameter.

