# Real-time Sensor WebSocket Testing Guide

## Overview

The real-time sensor data WebSocket allows frontend clients to receive live sensor updates without polling the database. Data is streamed directly from the Loxone WebSocket connection before storage, ensuring zero database impact and real-time updates.

## WebSocket Connection

### Connection URL

```
ws://localhost:3000/realtime?token=YOUR_JWT_TOKEN
```

or for HTTPS:

```
wss://your-domain.com/realtime?token=YOUR_JWT_TOKEN
```

### Authentication

- JWT token must be provided as query parameter `token`
- Token is validated using the same `JWT_SECRET` as REST API
- User must exist and be active

## Message Protocol

### Client → Server Messages

#### 1. Subscribe to Room
```json
{
  "type": "subscribe",
  "roomId": "507f1f77bcf86cd799439011"
}
```

**Response:**
```json
{
  "type": "initial_state",
  "roomId": "507f1f77bcf86cd799439011",
  "sensors": [
    {
      "sensorId": "507f1f77bcf86cd799439012",
      "value": 23.5,
      "unit": "°C",
      "timestamp": "2024-01-01T12:00:00Z"
    }
  ]
}
```

```json
{
  "type": "subscribe_success",
  "roomId": "507f1f77bcf86cd799439011",
  "message": "Subscribed to 5 sensor(s)"
}
```

#### 2. Subscribe to Single Sensor
```json
{
  "type": "subscribe",
  "sensorId": "507f1f77bcf86cd799439012"
}
```

**Response:**
```json
{
  "type": "initial_state",
  "sensorId": "507f1f77bcf86cd799439012",
  "sensors": [
    {
      "sensorId": "507f1f77bcf86cd799439012",
      "value": 23.5,
      "unit": "°C",
      "timestamp": "2024-01-01T12:00:00Z"
    }
  ]
}
```

```json
{
  "type": "subscribe_success",
  "sensorId": "507f1f77bcf86cd799439012",
  "message": "Subscribed to sensor"
}
```

#### 3. Unsubscribe
```json
{
  "type": "unsubscribe",
  "roomId": "507f1f77bcf86cd799439011"
}
```

or

```json
{
  "type": "unsubscribe",
  "sensorId": "507f1f77bcf86cd799439012"
}
```

#### 4. Disconnect
```json
{
  "type": "disconnect"
}
```

### Server → Client Messages

#### 1. Connection Confirmation
```json
{
  "type": "connected",
  "clientId": "a1b2c3d4e5f6",
  "message": "Connected to real-time sensor data stream"
}
```

#### 2. Sensor Update
```json
{
  "type": "sensor_update",
  "sensorId": "507f1f77bcf86cd799439012",
  "value": 24.2,
  "unit": "°C",
  "timestamp": "2024-01-01T12:00:05Z"
}
```

#### 3. Error
```json
{
  "type": "error",
  "message": "Access denied to this room"
}
```

## Testing with Postman

### Step 1: Get JWT Token

1. Use the existing auth endpoint to login:
   ```
   POST /api/v1/auth/login
   ```

2. Copy the `token` from the response

### Step 2: Get Connection Info (Optional)

```
GET /api/v1/realtime/test
```

This returns the WebSocket URL and message format examples.

### Step 3: Connect via WebSocket

1. In Postman, create a new WebSocket request
2. URL: `ws://localhost:3000/realtime?token=YOUR_JWT_TOKEN`
3. Click "Connect"

### Step 4: Subscribe to Room

Send message:
```json
{
  "type": "subscribe",
  "roomId": "YOUR_LOCAL_ROOM_ID"
}
```

**To get a LocalRoom ID:**
- Use `GET /api/v1/dashboard/rooms/:roomId` endpoint
- The `roomId` in the URL is the LocalRoom ID

### Step 5: Receive Updates

You should receive:
1. `initial_state` message with current sensor values
2. `subscribe_success` confirmation
3. `sensor_update` messages as measurements arrive from Loxone

### Step 6: Test Multiple Clients

1. Open multiple Postman WebSocket connections
2. Subscribe to the same room from different clients
3. All clients should receive the same updates

## REST API Endpoints

### Get Connection Info
```
GET /api/v1/realtime/test
```

**Response:**
```json
{
  "success": true,
  "data": {
    "websocketUrl": "ws://localhost:3000/realtime",
    "message": "Connect to this URL with ?token=YOUR_JWT_TOKEN",
    "example": "ws://localhost:3000/realtime?token=YOUR_JWT_TOKEN",
    "messageFormat": { ... },
    "responseFormat": { ... }
  }
}
```

### Get Subscription Statistics (Requires Auth)
```
GET /api/v1/realtime/subscriptions
Authorization: Bearer YOUR_JWT_TOKEN
```

**Response:**
```json
{
  "success": true,
  "data": {
    "totalClients": 2,
    "totalSensorSubscriptions": 10,
    "totalRoomSubscriptions": 2,
    "clients": [
      {
        "clientId": "a1b2c3d4",
        "userId": "507f1f77bcf86cd799439011",
        "subscriptionCount": 5
      }
    ]
  }
}
```

## Error Scenarios

### Invalid Token
- Connection is rejected with 401 status
- Message: "Unauthorized - Invalid token"

### No Access to Room/Sensor
- Connection remains open
- Error message sent: "Access denied to this room"

### Invalid Room/Sensor ID
- Error message: "Invalid roomId format" or "Invalid sensorId format"

### Loxone Disconnected
- No updates sent (expected behavior)
- Clients remain connected and will receive updates when Loxone reconnects

## Architecture Notes

1. **Zero Database Impact**: Measurements are broadcast from the incoming Loxone stream before storage
2. **Real-time**: Updates are sent immediately as they arrive
3. **Scalable**: Multiple clients can subscribe to the same room/sensor
4. **Efficient**: Uses in-memory maps for O(1) subscription lookups
5. **Non-blocking**: Broadcasting doesn't block measurement storage

## Troubleshooting

### No Updates Received
1. Check if Loxone connection is active: Check server logs for `[LOXONE]` messages
2. Verify room has sensors: Use `GET /api/v1/dashboard/rooms/:roomId`
3. Check if sensors are mapped: Sensors must be in a Loxone Room linked to the LocalRoom
4. Verify UUID mapping: Check server logs for structure loading messages

### Connection Rejected
1. Verify JWT token is valid and not expired
2. Check user is active: `is_active === true`
3. Verify `JWT_SECRET` is set in environment

### Access Denied
1. Verify user has access to the room/sensor via UserRole
2. Check bryteswitch_id matches between user and site

## Example Postman Collection

Create a Postman collection with:
1. **WebSocket Request**: `ws://localhost:3000/realtime?token={{token}}`
2. **Messages**:
   - Subscribe to room
   - Subscribe to sensor
   - Unsubscribe
   - Disconnect

Use environment variables:
- `{{token}}`: JWT token from login
- `{{roomId}}`: LocalRoom ID
- `{{sensorId}}`: Sensor ID
