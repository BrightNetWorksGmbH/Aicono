# Quick MongoDB Setup Guide

## The Problem

You're getting these errors:
1. `Cast to ObjectId failed for value "Building1"` - BUILDING_ID must be a valid MongoDB ObjectId
2. `Cannot access 'path' before initialization` - Fixed in code

## Solution: Create Building Document

### Option 1: Use the Setup Script (Recommended)

```bash
cd /Users/sami/Downloads/vscode-download/Aicono/testLoxoneConnection
node setupMongoDB.js
```

This script will:
- Connect to MongoDB
- Check if Building already exists for your Miniserver
- Create Site and Building if needed
- Output the correct BUILDING_ID to use

### Option 2: Create Manually via MongoDB Shell

```javascript
// Connect to MongoDB
use aicono

// 1. Create or find BryteSwitchSettings (required for Site)
db.bryteswitchsettings.findOne() 
// If none exists, create one:
db.bryteswitchsettings.insertOne({
  organization_name: "Default Organization",
  sub_domain: "default",
  is_setup_complete: false
})
// Copy the _id

// 2. Create or find Site
db.sites.findOne()
// If none exists:
db.sites.insertOne({
  name: "Default Site",
  address: "",
  resource_type: "Building",
  bryteswitch_id: ObjectId("...") // From step 1
})
// Copy the _id

// 3. Create Building
db.buildings.insertOne({
  site_id: ObjectId("..."), // From step 2
  name: "ECO-Detect Building",
  miniserver_ip: "192.168.178.201",
  miniserver_serial: "504F94D107EE",
  miniserver_auth_token: "",
  type_of_use: "Commercial"
})
// Copy the _id - THIS IS YOUR BUILDING_ID
```

### Option 3: Create via Your Backend API

Use your existing backend API to create:
1. Site (if doesn't exist)
2. Building with miniserver details

Then get the Building `_id` and use it as `BUILDING_ID`.

---

## Update .env File

After creating the Building, update your `.env`:

```env
# Remove the old incorrect value
# BUILDING_ID=Building1  ❌ WRONG

# Add the correct ObjectId
BUILDING_ID=507f1f77bcf86cd799439011  ✅ CORRECT (use your actual ObjectId)
```

**Important**: BUILDING_ID must be:
- 24 hexadecimal characters
- A valid MongoDB ObjectId
- The `_id` of an existing Building document

---

## Collections That Need to Exist

### Required Collections (will be created automatically):

1. **measurements** (Time Series) - Created automatically by `mongodbStorage.js`
2. **buildings** - You need to create Building document
3. **sites** - You need to create Site document (or use existing)
4. **sensors** - Will be created when you import structure
5. **rooms** - Will be created when you import structure
6. **floors** - Will be created when you import structure

### Collections Created by Setup Script:

- `bryteswitchsettings` (if needed for Site)
- `sites` (if doesn't exist)
- `buildings` (for your Miniserver)

---

## Step-by-Step Setup

### Step 1: Run Setup Script

```bash
cd /Users/sami/Downloads/vscode-download/Aicono/testLoxoneConnection
node setupMongoDB.js
```

### Step 2: Copy Building ID

The script will output:
```
[SETUP] ⚠️  IMPORTANT: Add this to your .env file:
BUILDING_ID=507f1f77bcf86cd799439011
```

### Step 3: Update .env

```bash
# Edit .env file
nano .env
# or
code .env
```

Replace `BUILDING_ID=Building1` with the correct ObjectId.

### Step 4: Verify Collections

The Time Series collection `measurements` will be created automatically when you run the connection.

### Step 5: Test Connection

```bash
npm start
```

You should now see:
```
[MONGODB] Connected successfully
[MONGODB] Created Time Series collection: measurements
[MONGODB] Loaded models from backend
[MONGODB] Loaded X UUID mappings for building ...
```

---

## What Collections Are Created Automatically?

✅ **measurements** (Time Series) - Created by `mongodbStorage.js` when connection starts
✅ Indexes - Created automatically

❌ **buildings** - You must create Building document first
❌ **sites** - You must create Site document first (or use existing)
❌ **sensors** - Created when you import LoxAPP3.json structure
❌ **rooms** - Created when you import LoxAPP3.json structure

---

## Troubleshooting

### Error: "Cast to ObjectId failed for value 'Building1'"

**Solution**: BUILDING_ID must be a valid MongoDB ObjectId (24 hex characters), not a string like "Building1".

### Error: "Building not found"

**Solution**: 
1. Create Building document first (use setup script)
2. Use the correct ObjectId in BUILDING_ID

### Error: "Site not found" or "bryteswitch_id required"

**Solution**: 
1. Create BryteSwitchSettings first
2. Create Site with bryteswitch_id
3. Then create Building

### Error: "Cannot access 'path' before initialization"

**Solution**: Fixed in code - path is now imported at the top of the file.

---

## Next Steps After Setup

1. ✅ Create Building document
2. ✅ Set BUILDING_ID in .env
3. ⏭️ Import Rooms and Sensors from LoxAPP3.json (via your backend API)
4. ⏭️ Run connection - measurements will store automatically
5. ⏭️ Verify measurements are being stored in MongoDB

---

Run `node setupMongoDB.js` to get started!

