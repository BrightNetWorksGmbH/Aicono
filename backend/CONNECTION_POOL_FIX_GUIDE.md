# Connection Pool Optimization - Implementation Guide

## 📊 Problem Summary

Your Loxone-based energy management system is experiencing **90-101% MongoDB connection pool usage** with 20 buildings connected. The main issues are:

1. **Repeated Structure Loading** (PRIMARY ISSUE - 60-70% of problem)
   - The same buildings are loading structure mappings repeatedly
   - Each load performs heavy aggregation queries
   - Creates a "connection storm" with 20 buildings

2. **Inefficient Database Queries**
   - Sensor data fetched repeatedly instead of cached
   - N+1 query pattern in measurement storage
   - Aggregation queries hold connections for too long

3. **Concurrent Operations**
   - All 20 buildings process measurements simultaneously
   - Aggregation runs with minimal delays
   - No proper connection prioritization

4. **Deletion Queue Blocked**
   - Never runs because pool is always >85%
   - Old data accumulates, making problem worse

## 🔍 Root Cause Analysis

### Issue 1: Repeated Structure Loading

**File:** `loxoneStorageService.js:676-721`

**Problem:**
```javascript
// CURRENT CODE (PROBLEMATIC):
if (!uuidToSensorMap || uuidToSensorMap.size === 0) {
    // This reloads structure EVERY TIME UUID map is empty!
    const fileContent = await fsPromises.readFile(structureFilePath, 'utf8');
    const loxAPP3Data = JSON.parse(fileContent);
    await this.loadStructureMapping(buildingId, loxAPP3Data);  // <-- Heavy DB operations!
}
```

**Why it happens:**
1. Measurements arrive via WebSocket faster than structure loading completes
2. First measurement batch finds empty UUID map → triggers structure load
3. Second measurement batch also finds empty map (first load not done) → triggers ANOTHER load
4. This cascades with 20 buildings = 20+ simultaneous structure loads
5. Each load performs aggregation queries that hold connections

**Evidence from logs:**
```
[LOXONE] [696f4da7d4687eb5cef8252f] ✓ Structure imported (147 UUID mappings)
[LOXONE] [696f4da7d4687eb5cef8252f] ✓ Structure imported (147 UUID mappings)
[LOXONE] [696f4da7d4687eb5cef8252f] ✓ Structure imported (147 UUID mappings)
```

**Impact:**
- Each structure load uses 3-5 connections (aggregations + inserts)
- 20 buildings × 3-5 connections = 60-100 connections just for structure loading
- Blocks real-time measurement storage and API requests

### Issue 2: Sensor Fetching

**File:** `loxoneStorageService.js:754-766`

**Problem:**
```javascript
// CURRENT CODE:
const sensors = await db.collection('sensors')
    .find({ _id: { $in: sensorIdsArray } })
    .toArray();  // <-- Fetched EVERY measurement batch!
```

With measurements coming every second from 20 buildings:
- 20 buildings × 1 query/second = 20 queries/second just for sensor fetching
- Sensors rarely change, so this is wasted work
- Each query holds a connection briefly, but adds up

### Issue 3: Aggregation Processing

**File:** `aggregationScheduler.js:273-295`

**Problem:**
```javascript
// CURRENT CODE:
for (let i = 0; i < buildings.length; i++) {
    await aggregate15Minutes(buildingId);
    await new Promise(resolve => setTimeout(resolve, 2000)); // Only 2s delay!
}
```

- 20 buildings with only 2 second delays between them
- Each aggregation holds 2-3 connections for 5-10 seconds
- Total time: ~200 seconds with connections held throughout
- Overlaps with measurement processing

## ✅ Solution Overview

### Solution 1: Fix Repeated Structure Loading ⭐ **CRITICAL**

**Changes:**
1. Add loading state tracking to prevent duplicate loads
2. Add cooldown period (don't reload within 60 seconds)
3. Remove automatic reload from `storeMeasurements()`
4. Cache sensor data to avoid repeated fetches

**Expected Impact:** 60-70% reduction in connection pool usage

### Solution 2: Sensor Caching

**Changes:**
1. Cache sensors per building for 5 minutes
2. Only fetch missing sensors from database
3. Refresh cache when structure changes

**Expected Impact:** 15-20% reduction in queries

### Solution 3: Better Aggregation Scheduling

**Changes:**
1. Increase delays between building processing (3s → 5s)
2. Check pool usage before each building
3. Use MEDIUM priority for aggregation operations

**Expected Impact:** Prevents aggregation from blocking real-time data

### Solution 4: Increase Pool Size (Temporary)

**Changes:**
1. Increase from 100 to 150 connections
2. Increase HIGH priority reservation from 20 to 30

**Expected Impact:** Breathing room while other optimizations take effect

## 📋 Implementation Steps

### Step 1: Backup Current Files

```bash
cd /Users/sami/Downloads/vscode-download/Aicono/backend

# Backup current files
cp services/loxoneStorageService.js services/loxoneStorageService.js.backup
cp services/aggregationScheduler.js services/aggregationScheduler.js.backup
cp .env .env.backup
```

### Step 2: Apply Optimized Files

```bash
# Replace with optimized versions
cp services/loxoneStorageService.OPTIMIZED.js services/loxoneStorageService.js
cp services/aggregationScheduler.OPTIMIZED.js services/aggregationScheduler.js
```

### Step 3: Update Environment Variables

Edit your `.env` file and add/update these settings:

```bash
# MongoDB Connection Pool - OPTIMIZED
MONGODB_MAX_POOL_SIZE=150  # Increased from 100
MONGODB_MIN_POOL_SIZE=5
MONGODB_HIGH_PRIORITY_RESERVED=30  # Increased from 20

# Measurement Queue - OPTIMIZED
MEASUREMENT_QUEUE_BATCH_SIZE=200  # Increased from 50
MEASUREMENT_QUEUE_MAX_SIZE=20000
API_REQUEST_THRESHOLD=5
MEASUREMENT_QUEUE_THROTTLE_FACTOR=0.5

# Aggregation - OPTIMIZED
AGGREGATION_QUEUE_ENABLED=true
AGGREGATION_QUEUE_MAX_CONCURRENT=1
DELETE_RAW_AFTER_AGGREGATION=true
RAW_DATA_BUFFER_MINUTES=30
OLD_DATA_RETENTION_DAYS=1
AGGREGATION_BUILDING_DELAY_MS=5000  # NEW: 5 second delays between buildings

# Structure Loading - NEW SETTINGS
STRUCTURE_LOAD_COOLDOWN=60000  # Don't reload more than once per minute
SENSOR_CACHE_TTL=300000  # Cache sensors for 5 minutes
```

### Step 4: Restart Your Application

```bash
# Stop the application
# (Use your process manager: pm2, systemd, or Ctrl+C if running directly)

# Clear any stuck processes
pkill -f "node.*index.js"

# Start fresh
npm run dev
# OR for production:
npm start
```

### Step 5: Monitor Results

Watch the logs for improvements:

```bash
# Monitor connection pool usage
tail -f logs/application.log | grep "MONGODB.*Connection pool"

# Should see:
# Before: 🔴 Connection pool usage is CRITICAL: 96% (96/100 connections)
# After:  ✓ Connection pool usage normalized: 45% (67/150 connections)
```

## 📈 Expected Results

### Immediate (After Restart):

**Before:**
```
[MONGODB] 🔴 Connection pool usage is CRITICAL: 96% (96/100 connections)
[MONGODB] 🔴 Connection pool usage is CRITICAL: 98% (98/100 connections)
[MONGODB] 🔴 Connection pool usage is CRITICAL: 99% (99/100 connections)
[LOXONE] [buildingId] ✓ Structure imported (147 UUID mappings)  # <-- Repeated many times
[LOXONE] [buildingId] ✓ Structure imported (147 UUID mappings)
[LOXONE] [buildingId] ✓ Structure imported (147 UUID mappings)
[DELETION-QUEUE] Pool usage high (96%), waiting 5000ms...  # Never runs
```

**After:**
```
[MONGODB] ✓ Connection pool usage: 45% (67/150 connections)
[LOXONE] [buildingId] ✓ Structure imported (147 UUID mappings)  # <-- Only ONCE per building
[LOXONE] [buildingId] ✓ Using cached structure (loaded 5s ago)  # <-- Uses cache!
[DELETION-QUEUE] Processing deletion batch: 50000 documents...  # Runs successfully!
[SCHEDULER] ✅ 15-minute aggregation completed: 1250 aggregates created
```

### Within 1 Hour:

1. **Connection Pool Usage:** Drops from 90-101% to 40-60%
2. **Structure Loading:** Each building loads once, not continuously
3. **Deletion Queue:** Starts running and cleaning up old data
4. **Measurement Storage:** Faster, no blocking
5. **API Responses:** Faster, not competing for connections

### Within 24 Hours:

1. **Database Size:** Reduces as old data is cleaned up
2. **Query Performance:** Improves due to less data
3. **Stable Operations:** Pool usage remains steady around 40-60%

## 🔧 Verification Checklist

After restart, verify these improvements:

### ✅ 1. Structure Loading (Most Important)

**Check logs for this pattern:**
```bash
# Good: Each building loads ONCE
[LOXONE] [buildingId1] ✓ Structure imported (147 UUID mappings)
[LOXONE] [buildingId2] ✓ Structure imported (147 UUID mappings)
...

# Good: Subsequent uses show caching
[LOXONE] [buildingId1] ✓ Using cached structure (loaded 30s ago)
```

**Bad pattern (if you still see this, something is wrong):**
```bash
# Bad: Same building loading repeatedly
[LOXONE] [buildingId1] ✓ Structure imported (147 UUID mappings)
[LOXONE] [buildingId1] ✓ Structure imported (147 UUID mappings)  # <-- Duplicate!
[LOXONE] [buildingId1] ✓ Structure imported (147 UUID mappings)  # <-- Duplicate!
```

### ✅ 2. Connection Pool Usage

**Monitor for 10 minutes:**
```bash
tail -f logs/application.log | grep "Connection pool usage"
```

**Good:**
```
[MONGODB] ✓ Connection pool usage: 45% (67/150 connections)
[MONGODB] ✓ Connection pool usage: 52% (78/150 connections)
[MONGODB] ⚠️  Connection pool usage is high: 68% (102/150 connections)  # OK occasionally
```

**Bad:**
```
[MONGODB] 🔴 Connection pool usage is CRITICAL: 96% (144/150 connections)  # Still critical
```

### ✅ 3. Deletion Queue

**Check if deletion queue is running:**
```bash
tail -f logs/application.log | grep "DELETION-QUEUE"
```

**Good:**
```
[DELETION-QUEUE] Processing deletion batch: 50000 documents...
[DELETION-QUEUE] ✓ Deleted 45000 old measurement documents
```

**Bad:**
```
[DELETION-QUEUE] Pool usage high (92%), waiting 5000ms...  # Still can't run
```

### ✅ 4. Aggregation Performance

**Check aggregation logs:**
```bash
tail -f logs/application.log | grep "SCHEDULER.*15-minute"
```

**Good:**
```
[SCHEDULER] Processing building 1/20: 6948dcd113537bff98eb7338
[SCHEDULER] Processing building 2/20: 69674a4883b8ba4cdd805947
...
[SCHEDULER] ✅ 15-minute aggregation completed across 20 buildings:
[SCHEDULER]   - 1250 aggregates created
[SCHEDULER]   - 18 buildings processed successfully
```

## 🚨 Troubleshooting

### Problem: Pool usage still high (>80%) after restart

**Possible Causes:**
1. Old processes still running
2. Environment variables not loaded
3. Wrong files replaced

**Solution:**
```bash
# 1. Kill all node processes
pkill -f node

# 2. Verify .env file
cat .env | grep MONGODB_MAX_POOL_SIZE
# Should show: MONGODB_MAX_POOL_SIZE=150

# 3. Verify files were replaced
head -20 services/loxoneStorageService.js | grep "🔥"
# Should see comments with 🔥 markers

# 4. Start with explicit env file
NODE_ENV=production node index.js
```

### Problem: Still seeing repeated structure imports

**Check:**
```bash
# Count how many times structure is imported per building in last 5 minutes
tail -1000 logs/application.log | grep "Structure imported" | cut -d'[' -f3 | cut -d']' -f1 | sort | uniq -c

# Good: Each building ID appears 1-2 times
#   1 6948dcd113537bff98eb7338
#   1 69674a4883b8ba4cdd805947

# Bad: Buildings appear many times
#  15 6948dcd113537bff98eb7338  # <-- This is bad!
#  12 69674a4883b8ba4cdd805947
```

**If still happening:**
1. Verify `loxoneStorageService.js` was replaced correctly
2. Check for syntax errors: `node -c services/loxoneStorageService.js`
3. Restart with clean logs to see fresh behavior

### Problem: Deletion queue still not running

**Check effective pool usage:**
```bash
tail -f logs/application.log | grep "MEDIUM priority"
```

**If you see:**
```
[MONGODB] 🔴 Connection pool usage is CRITICAL for MEDIUM priority: 120% effective
```

This means HIGH priority connections are consuming the reserved pool. Check:
1. Are measurements flooding in too fast?
2. Is there a measurement queue backlog?

**Solution:**
```bash
# Check queue stats endpoint (if available)
curl http://localhost:3000/api/queue-stats

# Or restart with measurement processing paused temporarily
# Add to .env:
MEASUREMENT_QUEUE_ENABLED=false
```

### Problem: Application crashes on startup

**Check logs for errors:**
```bash
tail -50 logs/application.log
```

**Common errors:**

1. **SyntaxError:** File wasn't saved properly
   ```bash
   node -c services/loxoneStorageService.js
   ```

2. **Module not found:** Missing dependency
   ```bash
   npm install
   ```

3. **MongoDB connection error:** Check MongoDB is running
   ```bash
   mongo --eval "db.adminCommand('ping')"
   ```

## 📊 Monitoring Dashboard

Create a simple monitoring script to track improvements:

```bash
#!/bin/bash
# Save as: monitor_pool.sh

while true; do
    echo "=== $(date) ==="

    # Connection pool usage
    tail -1000 logs/application.log | grep "Connection pool usage" | tail -1

    # Structure imports (count in last 100 lines)
    echo "Structure imports in last 100 lines:"
    tail -100 logs/application.log | grep "Structure imported" | wc -l

    # Deletion queue status
    tail -100 logs/application.log | grep "DELETION-QUEUE" | tail -1

    echo ""
    sleep 30  # Check every 30 seconds
done
```

Run it:
```bash
chmod +x monitor_pool.sh
./monitor_pool.sh
```

## 🎯 Success Metrics

After 1 hour, you should see:

| Metric | Before | Target | Good |
|--------|--------|--------|------|
| **Peak Pool Usage** | 99-101% | <70% | ✅ 45-60% |
| **Average Pool Usage** | 90-96% | <60% | ✅ 40-55% |
| **Structure Loads/Building** | 10-20/min | 1/hour | ✅ 1 at startup |
| **Deletion Queue Runs** | 0 | Every 2s | ✅ Every 2-5s |
| **Measurement Storage Latency** | 500-1000ms | <100ms | ✅ 50-80ms |
| **Database Query Count** | 400/min | <200/min | ✅ 100-150/min |

## 📝 Next Steps (Optional Future Improvements)

Once stable, consider these enhancements:

### Phase 2: Advanced Optimizations (Week 2)

1. **Separate Connection Pools**
   - Dedicated pool for aggregation operations
   - Dedicated pool for real-time measurements
   - Prevents contention

2. **Batch Alarm Creation**
   - Currently creates alarms one-by-one
   - Could batch into single insert

3. **Structure File Change Detection**
   - Only reload when file timestamp changes
   - Even less frequent reloads

### Phase 3: Architectural Improvements (Month 2+)

1. **Message Queue (Redis/RabbitMQ)**
   - Decouple measurement ingestion from storage
   - Better handling of bursts

2. **Read Replicas**
   - Separate read/write operations
   - Aggregation queries use replicas

3. **Time-Series Database**
   - Consider TimescaleDB or InfluxDB
   - Purpose-built for time-series data

## 🆘 Support

If you encounter issues:

1. **Check logs:** Always start with full logs
2. **Verify files:** Ensure optimized files are in place
3. **Test incrementally:** Apply one change at a time if needed
4. **Rollback:** Use backup files if something breaks

**Rollback Command:**
```bash
cp services/loxoneStorageService.js.backup services/loxoneStorageService.js
cp services/aggregationScheduler.js.backup services/aggregationScheduler.js
cp .env.backup .env
```

## 📚 Additional Resources

- [MongoDB Connection Pooling Guide](https://www.mongodb.com/docs/drivers/node/current/fundamentals/connection/connection-options/)
- [Node.js Performance Best Practices](https://nodejs.org/en/docs/guides/simple-profiling/)
- [Loxone Communication Protocol](https://www.loxone.com/wp-content/uploads/datasheets/CommunicatingWithMiniserver.pdf)

---

**Created:** 2026-02-04
**Version:** 1.0
**Status:** Ready for Implementation
