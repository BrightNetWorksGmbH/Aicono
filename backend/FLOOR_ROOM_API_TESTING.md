# Floor and Local Room API Testing Guide

This document provides comprehensive testing instructions for the Floor and Local Room API endpoints, including role-based access control and activity logging.

## Base URL
```
http://localhost:3000/api/v1/floors
```

## Authentication
All endpoints require authentication. Include the Bearer token in the Authorization header:
```
Authorization: Bearer <your-token>
```

---

## 1. Create Floor with Rooms

**Endpoint:** `POST /api/v1/floors/building/:buildingId`

**Description:** Creates a floor with optional local rooms.

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 1.1: Create Floor with Rooms (Success)
```bash
curl -X POST http://localhost:3000/api/v1/floors/building/<buildingId> \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ground Floor",
    "floor_plan_link": "https://example.com/floor-plan.pdf",
    "rooms": [
      {
        "name": "Room 101",
        "color": "#FF5733",
        "loxone_room_id": "loxone-room-id-here"
      },
      {
        "name": "Room 102",
        "color": "#33FF57"
      }
    ]
  }'
```

**Expected Response:** 201 Created
```json
{
  "success": true,
  "message": "Floor created successfully",
  "data": {
    "floor": {
      "_id": "...",
      "name": "Ground Floor",
      "floor_plan_link": "https://example.com/floor-plan.pdf",
      "building_id": "...",
      ...
    },
    "rooms": [
      {
        "_id": "...",
        "name": "Room 101",
        "color": "#FF5733",
        "loxone_room_id": "...",
        ...
      },
      ...
    ]
  }
}
```

**Activity Log:** Creates entries for:
- Floor creation
- Each room creation (with Loxone mapping status)

#### Test 1.2: Read-Only User Attempt (Should Fail)
```bash
curl -X POST http://localhost:3000/api/v1/floors/building/<buildingId> \
  -H "Authorization: Bearer <read-only-user-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ground Floor"
  }'
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "Read-Only users cannot perform this action"
}
```

---

## 2. Update Floor

**Endpoint:** `PATCH /api/v1/floors/:floorId`

**Description:** Updates floor details (name, floor_plan_link).

**Allowed Fields:**
- `name` - Floor name
- `floor_plan_link` - Link to floor plan

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 2.1: Update Floor (Success)
```bash
curl -X PATCH http://localhost:3000/api/v1/floors/<floorId> \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Floor Name",
    "floor_plan_link": "https://example.com/new-floor-plan.pdf"
  }'
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Floor updated successfully",
  "data": {
    "_id": "...",
    "name": "Updated Floor Name",
    "floor_plan_link": "https://example.com/new-floor-plan.pdf",
    ...
  }
}
```

**Activity Log:** Records updated fields and building context.

---

## 3. Delete Floor

**Endpoint:** `DELETE /api/v1/floors/:floorId`

**Description:** Deletes a floor and all its local rooms (cascade delete).

**What Gets Deleted:**
- ✅ Floor document
- ✅ All LocalRooms in that floor
- ✅ Cache invalidation (if rooms had Loxone mappings)

**Important Notes:**
- Loxone Rooms and Sensors are NOT deleted (they're shared across buildings)
- Measurements will no longer be stored for sensors in deleted LocalRooms
- Cache is invalidated to reflect the deletion

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 3.1: Delete Floor (Success)
```bash
curl -X DELETE http://localhost:3000/api/v1/floors/<floorId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Floor deleted successfully",
  "data": {
    "floorId": "...",
    "floorName": "Ground Floor",
    "buildingId": "...",
    "buildingName": "Building Name",
    "deletedItems": {
      "localRooms": 5
    }
  }
}
```

**Activity Log:** Records deletion with summary of deleted items.

#### Test 3.2: Read-Only User Attempt (Should Fail)
```bash
curl -X DELETE http://localhost:3000/api/v1/floors/<floorId> \
  -H "Authorization: Bearer <read-only-user-token>"
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "Read-Only users cannot perform this action"
}
```

---

## 4. Add Room to Floor

**Endpoint:** `POST /api/v1/floors/:floorId/rooms`

**Description:** Adds a local room to an existing floor.

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 4.1: Add Room to Floor (Success)
```bash
curl -X POST http://localhost:3000/api/v1/floors/<floorId>/rooms \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Room 103",
    "color": "#3357FF",
    "loxone_room_id": "loxone-room-id-here"
  }'
```

**Expected Response:** 201 Created
```json
{
  "success": true,
  "message": "Room added successfully",
  "data": {
    "_id": "...",
    "name": "Room 103",
    "color": "#3357FF",
    "loxone_room_id": "...",
    "floor_id": "...",
    ...
  }
}
```

**Activity Log:** Records room creation with Loxone mapping status.

**Cache:** Invalidates sensor IDs cache if `loxone_room_id` is provided.

---

## 5. Update Local Room

**Endpoint:** `PATCH /api/v1/floors/rooms/:roomId`

**Description:** Updates a local room (name, color, loxone_room_id).

**Allowed Fields:**
- `name` - Room name
- `color` - Room color (hex code)
- `loxone_room_id` - Reference to Loxone Room

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 5.1: Update Local Room (Success)
```bash
curl -X PATCH http://localhost:3000/api/v1/floors/rooms/<roomId> \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Room Name",
    "color": "#FF0000",
    "loxone_room_id": "new-loxone-room-id"
  }'
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Room updated successfully",
  "data": {
    "_id": "...",
    "name": "Updated Room Name",
    "color": "#FF0000",
    "loxone_room_id": "...",
    ...
  }
}
```

**Activity Log:** Records updated fields and whether Loxone mapping changed.

**Cache:** Invalidates sensor IDs cache if `loxone_room_id` changed.

#### Test 5.2: Update Loxone Mapping (Cache Invalidation)
When updating `loxone_room_id`, the sensor IDs cache is invalidated to ensure measurements are filtered correctly.

---

## 6. Delete Local Room

**Endpoint:** `DELETE /api/v1/floors/rooms/:roomId`

**Description:** Deletes a local room.

**What Happens:**
- ✅ LocalRoom document is deleted
- ✅ Cache is invalidated (if room had Loxone mapping)
- ❌ Loxone Room and Sensors are NOT deleted (shared resources)
- ⚠️ Measurements for sensors in that room will no longer be stored

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 6.1: Delete Local Room (Success)
```bash
curl -X DELETE http://localhost:3000/api/v1/floors/rooms/<roomId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Room deleted successfully",
  "data": {
    "roomId": "...",
    "roomName": "Room 101",
    "floorId": "...",
    "buildingId": "...",
    "buildingName": "Building Name",
    "hadLoxoneMapping": true
  }
}
```

**Activity Log:** Records deletion with building/floor context.

**Cache:** Invalidates sensor IDs cache if room had Loxone mapping.

#### Test 6.2: Delete Room with Loxone Mapping
When deleting a room that has a Loxone mapping:
- The LocalRoom is deleted
- Cache is invalidated
- Future measurements for sensors in that Loxone Room will be filtered out
- Existing measurements remain in the database

---

## 7. Get Floors by Building

**Endpoint:** `GET /api/v1/floors/building/:buildingId`

**Description:** Retrieves all floors for a building with their local rooms.

**No Role Restrictions:** All authenticated users can view floors.

### Test Case

#### Test 7.1: Get Floors by Building (Success)
```bash
curl -X GET http://localhost:3000/api/v1/floors/building/<buildingId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "data": [
    {
      "_id": "...",
      "name": "Ground Floor",
      "building_id": "...",
      "rooms": [
        {
          "_id": "...",
          "name": "Room 101",
          "color": "#FF5733",
          ...
        },
        ...
      ]
    },
    ...
  ]
}
```

---

## 8. Get Floor by ID

**Endpoint:** `GET /api/v1/floors/:floorId`

**Description:** Retrieves a single floor by ID with its local rooms.

**No Role Restrictions:** All authenticated users can view floors.

### Test Case

#### Test 8.1: Get Floor by ID (Success)
```bash
curl -X GET http://localhost:3000/api/v1/floors/<floorId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "data": {
    "_id": "...",
    "name": "Ground Floor",
    "building_id": "...",
    "rooms": [...]
  }
}
```

---

## Understanding Deletion Impact

### When Deleting a LocalRoom:

1. **LocalRoom Document**: ✅ Deleted
2. **Loxone Room**: ❌ NOT deleted (shared across buildings using same server)
3. **Sensors**: ❌ NOT deleted (linked to Loxone Room, shared resource)
4. **Measurements**: ⚠️ Future measurements will be filtered out (cache invalidated)
5. **Existing Measurements**: ✅ Remain in database (historical data preserved)

### When Deleting a Floor:

1. **All LocalRooms in Floor**: ✅ Deleted (cascade)
2. **Floor Document**: ✅ Deleted
3. **Loxone Rooms**: ❌ NOT deleted (shared)
4. **Sensors**: ❌ NOT deleted (shared)
5. **Cache**: ✅ Invalidated if any rooms had Loxone mappings

### Measurement Filtering Logic:

- Measurements are only stored for sensors in Loxone Rooms that are mapped to LocalRooms
- When a LocalRoom is deleted, the mapping is removed
- The cache (`allowedSensorIdsCache`) is invalidated
- Future measurements for sensors in that Loxone Room will be filtered out
- This ensures measurements are only stored for rooms that are actively configured in the system

---

## Testing Checklist

### Role-Based Access Control
- [ ] Read-Only user cannot create floor
- [ ] Read-Only user cannot update floor
- [ ] Read-Only user cannot delete floor
- [ ] Read-Only user cannot add room
- [ ] Read-Only user cannot update room
- [ ] Read-Only user cannot delete room
- [ ] User without `manage_buildings` permission cannot modify floors/rooms

### Create Operations
- [ ] Can create floor with rooms
- [ ] Activity log created for floor
- [ ] Activity log created for each room
- [ ] Cache invalidated when room has Loxone mapping

### Update Operations
- [ ] Can update floor name and floor_plan_link
- [ ] Can update room name, color, loxone_room_id
- [ ] Activity log records updated fields
- [ ] Cache invalidated when Loxone mapping changes

### Delete Operations
- [ ] Delete floor deletes all local rooms (cascade)
- [ ] Delete room removes LocalRoom only
- [ ] Loxone Rooms and Sensors are NOT deleted
- [ ] Cache invalidated appropriately
- [ ] Activity log records deletion with context
- [ ] Deletion summary includes deleted items count

### Cache Invalidation
- [ ] Cache invalidated when creating room with Loxone mapping
- [ ] Cache invalidated when updating room Loxone mapping
- [ ] Cache invalidated when deleting room with Loxone mapping
- [ ] Cache invalidated when deleting floor with mapped rooms

---

## Error Codes Reference

| Status Code | Error Type | Description |
|------------|------------|-------------|
| 400 | ValidationError | Missing required fields, invalid input |
| 403 | AuthorizationError | Read-Only user, missing permissions |
| 404 | NotFoundError | Floor/Room/Building not found |

---

## Notes

1. **Shared Resources**: Loxone Rooms and Sensors are scoped to `miniserver_serial`, not building. They are shared across buildings using the same Loxone server.

2. **Cache Invalidation**: The `allowedSensorIdsCache` is invalidated whenever LocalRoom mappings change. This ensures measurements are only stored for actively configured rooms.

3. **Measurement Filtering**: After deleting a LocalRoom, measurements for sensors in that room's Loxone Room will no longer be stored. Historical data remains.

4. **Cascade Deletion**: Deleting a floor automatically deletes all LocalRooms in that floor.

5. **Activity Logging**: All operations are logged with full context (building, floor, room names, etc.) for audit purposes.
