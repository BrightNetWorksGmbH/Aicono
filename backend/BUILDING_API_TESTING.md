# Building API Testing Guide

This document provides comprehensive testing instructions for the Building API endpoints, including role-based access control, Loxone configuration updates, and building deletion.

## Base URL
```
http://localhost:3000/api/v1/buildings
```

## Authentication
All endpoints require authentication. Include the Bearer token in the Authorization header:
```
Authorization: Bearer <your-token>
```

---

## 1. Update Building (Regular Update)

**Endpoint:** `PATCH /api/v1/buildings/:buildingId`

**Description:** Updates building details (name, size, floors, contact, reporting, etc.). Does NOT allow Loxone configuration updates.

**Allowed Fields:**
- `name` - Building name
- `building_size` - Building size in square meters
- `num_floors` - Number of floors
- `year_of_construction` - Year of construction
- `heated_building_area` - Heated building area
- `type_of_use` - Type of use
- `num_students_employees` - Number of students/employees
- `buildingContact` - Building contact (ID string or object)
- `reportingRecipients` - Array of reporting recipients
- `reportConfigs` - Array of report configurations

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

### Test Cases

#### Test 1.1: Update Building Name (Success)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Building Name",
    "building_size": 5000,
    "num_floors": 3
  }'
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Building updated successfully",
  "data": {
    "_id": "...",
    "name": "Updated Building Name",
    "building_size": 5000,
    "num_floors": 3,
    ...
  }
}
```

#### Test 1.2: Try to Update Loxone Config (Should Fail)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "miniserver_serial": "12345678-1234-1234-1234-123456789012"
  }'
```

**Expected Response:** 400 Bad Request
```json
{
  "success": false,
  "error": "Loxone configuration cannot be updated through this endpoint. Use /api/v1/buildings/:buildingId/loxone-config instead."
}
```

#### Test 1.3: Try to Update site_id (Should Fail)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "site_id": "some-other-site-id"
  }'
```

**Expected Response:** 400 Bad Request
```json
{
  "success": false,
  "error": "Cannot update site_id"
}
```

#### Test 1.4: Read-Only User Attempt (Should Fail)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <read-only-user-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name"
  }'
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "Read-Only users cannot edit buildings"
}
```

#### Test 1.5: User Without manage_buildings Permission (Should Fail)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <user-without-permission-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name"
  }'
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "You do not have permission to update buildings"
}
```

---

## 2. Update Loxone Configuration

**Endpoint:** `PATCH /api/v1/buildings/:buildingId/loxone-config`

**Description:** Updates Loxone connection configuration. Handles disconnect/reconnect and structure file management.

**Allowed Fields:**
- `ip` or `miniserver_ip` - Loxone server IP
- `port` or `miniserver_port` - Loxone server port
- `protocol` or `miniserver_protocol` - Protocol (ws/wss)
- `user` or `miniserver_user` - Username
- `pass` or `miniserver_pass` - Password
- `externalAddress` or `miniserver_external_address` - External address
- `serialNumber` or `miniserver_serial` - Server serial number

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

**Important Notes:**
- If serial number changes, the old connection is disconnected first
- New connection is established automatically after config update
- Structure file is managed based on server serial number

### Test Cases

#### Test 2.1: Update Loxone Config (Success)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId>/loxone-config \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "192.168.1.100",
    "port": "8080",
    "protocol": "ws",
    "user": "admin",
    "pass": "password123",
    "serialNumber": "12345678-1234-1234-1234-123456789012"
  }'
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Loxone configuration updated and reconnected successfully",
  "data": {
    "building": {
      "_id": "...",
      "miniserver_ip": "192.168.1.100",
      "miniserver_port": "8080",
      "miniserver_serial": "12345678-1234-1234-1234-123456789012",
      ...
    },
    "connectionResult": {
      "success": true,
      "message": "Connection started"
    }
  }
}
```

#### Test 2.2: Update Loxone Config - Change Serial Number
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId>/loxone-config \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "serialNumber": "NEW-SERIAL-1234-5678-9012"
  }'
```

**Expected Behavior:**
- Old connection is disconnected
- Building config is updated with new serial
- New connection is attempted (may fail if credentials are invalid)

#### Test 2.3: Read-Only User Attempt (Should Fail)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId>/loxone-config \
  -H "Authorization: Bearer <read-only-user-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "192.168.1.100"
  }'
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "Read-Only users cannot update Loxone configuration"
}
```

#### Test 2.4: Update with Invalid Credentials (Config Updated, Reconnect Failed)
```bash
curl -X PATCH http://localhost:3000/api/v1/buildings/<buildingId>/loxone-config \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "ip": "192.168.1.100",
    "user": "wrong",
    "pass": "wrong"
  }'
```

**Expected Response:** 200 OK (with warning)
```json
{
  "success": true,
  "message": "Loxone configuration updated, but reconnection failed",
  "warning": "Building config updated but reconnection failed: ...",
  "data": {
    "building": {...},
    "connectionResult": {
      "success": false,
      "message": "..."
    }
  }
}
```

---

## 3. Delete Building

**Endpoint:** `DELETE /api/v1/buildings/:buildingId`

**Description:** Hard deletes a building and all related data (cascade deletion).

**What Gets Deleted:**
- ✅ Building document
- ✅ All Floors for the building
- ✅ All LocalRooms for those floors
- ✅ Sensors linked to those rooms (if no other buildings use the same Loxone server)
- ✅ Loxone connection (disconnected)
- ✅ Structure file (if only this building uses that server)
- ✅ Reporting assignments
- ✅ Building contact references

**Role Requirements:**
- ❌ Read-Only users: **BLOCKED**
- ✅ All other roles with `manage_buildings` permission: **ALLOWED**

**Important Notes:**
- This is a **hard delete** - data cannot be recovered
- If multiple buildings share a Loxone server, sensors/rooms are NOT deleted
- Structure file is only deleted if this is the only building using that server

### Test Cases

#### Test 3.1: Delete Building (Success)
```bash
curl -X DELETE http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Building deleted successfully",
  "data": {
    "buildingId": "...",
    "buildingName": "Building Name",
    "deletedItems": {
      "loxoneConnection": "disconnected",
      "floors": 3,
      "localRooms": 15,
      "sensors": 45,
      "reportingAssignments": 5,
      "structureFile": "deleted"
    }
  }
}
```

#### Test 3.2: Delete Building - Shared Loxone Server
If the building shares a Loxone server with other buildings:

**Expected Response:** 200 OK
```json
{
  "success": true,
  "message": "Building deleted successfully",
  "data": {
    "buildingId": "...",
    "buildingName": "Building Name",
    "deletedItems": {
      "loxoneConnection": "disconnected",
      "floors": 3,
      "localRooms": 15,
      "sensors": 0,
      "reportingAssignments": 5,
      "note": "Sensors not deleted - other buildings may use the same Loxone server"
    }
  }
}
```

#### Test 3.3: Read-Only User Attempt (Should Fail)
```bash
curl -X DELETE http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <read-only-user-token>"
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "Read-Only users cannot delete buildings"
}
```

#### Test 3.4: User Without manage_buildings Permission (Should Fail)
```bash
curl -X DELETE http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <user-without-permission-token>"
```

**Expected Response:** 403 Forbidden
```json
{
  "success": false,
  "error": "You do not have permission to delete buildings"
}
```

#### Test 3.5: Delete Non-Existent Building (Should Fail)
```bash
curl -X DELETE http://localhost:3000/api/v1/buildings/invalid-id \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 404 Not Found
```json
{
  "success": false,
  "error": "Building not found"
}
```

---

## 4. Get Building by ID

**Endpoint:** `GET /api/v1/buildings/:buildingId`

**Description:** Retrieves a single building by ID.

**No Role Restrictions:** All authenticated users can view buildings (if they have access to the BryteSwitch).

### Test Case

#### Test 4.1: Get Building (Success)
```bash
curl -X GET http://localhost:3000/api/v1/buildings/<buildingId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "data": {
    "_id": "...",
    "name": "Building Name",
    "site_id": "...",
    "building_size": 5000,
    ...
  }
}
```

---

## 5. Get Buildings by Site

**Endpoint:** `GET /api/v1/buildings/site/:siteId`

**Description:** Retrieves all buildings for a site.

**No Role Restrictions:** All authenticated users can view buildings.

### Test Case

#### Test 5.1: Get Buildings by Site (Success)
```bash
curl -X GET http://localhost:3000/api/v1/buildings/site/<siteId> \
  -H "Authorization: Bearer <your-token>"
```

**Expected Response:** 200 OK
```json
{
  "success": true,
  "data": [
    {
      "_id": "...",
      "name": "Building 1",
      ...
    },
    {
      "_id": "...",
      "name": "Building 2",
      ...
    }
  ]
}
```

---

## Testing Checklist

### Role-Based Access Control
- [ ] Read-Only user cannot update building
- [ ] Read-Only user cannot update Loxone config
- [ ] Read-Only user cannot delete building
- [ ] User without `manage_buildings` permission cannot update/delete
- [ ] User with `manage_buildings` permission can update/delete

### Update Building
- [ ] Can update name, size, floors, etc.
- [ ] Cannot update Loxone config through regular endpoint
- [ ] Cannot update site_id
- [ ] Duplicate name check works

### Update Loxone Config
- [ ] Can update Loxone configuration
- [ ] Old connection is disconnected when serial changes
- [ ] New connection is established after update
- [ ] Handles invalid credentials gracefully

### Delete Building
- [ ] Deletes building document
- [ ] Deletes all floors
- [ ] Deletes all local rooms
- [ ] Deletes sensors (if no shared server)
- [ ] Disconnects Loxone connection
- [ ] Deletes structure file (if only building using server)
- [ ] Deletes reporting assignments
- [ ] Returns detailed deletion summary

---

## Error Codes Reference

| Status Code | Error Type | Description |
|------------|------------|-------------|
| 400 | ValidationError | Invalid input, Loxone config in wrong endpoint, etc. |
| 403 | AuthorizationError | Read-Only user, missing permissions, etc. |
| 404 | NotFoundError | Building not found |
| 409 | ConflictError | Duplicate building name, etc. |

---

## Notes

1. **Hard Delete**: Building deletion is permanent. Ensure you have backups if needed.

2. **Shared Loxone Servers**: If multiple buildings use the same Loxone server, sensors and rooms are NOT deleted when deleting one building.

3. **Structure Files**: Structure files are only deleted if the deleted building was the only one using that Loxone server.

4. **Loxone Config Updates**: Always use the dedicated `/loxone-config` endpoint for Loxone-related updates to ensure proper disconnect/reconnect handling.

5. **Role Hierarchy**: 
   - Owner: Full access
   - Admin: Full access
   - Expert: Limited (no building management)
   - Read-Only: View only
