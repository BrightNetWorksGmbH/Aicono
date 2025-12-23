# Aggregation Fix - Critical Bug Resolution

## Issues Found and Fixed

### 1. **Field Name Mismatch (CRITICAL BUG)**

**Problem:**
- Data is stored with `resolution_minutes` at the **root level** of the document
- But aggregation was looking for `meta.resolution_minutes` (inside meta object)
- This caused aggregation to find **zero documents** to aggregate

**Fix:**
Changed all queries from:
```javascript
'meta.resolution_minutes': 0  // ❌ WRONG
```

To:
```javascript
resolution_minutes: 0  // ✅ CORRECT
```

**Files Fixed:**
- `measurementAggregationService.js` - All aggregation methods
- `measurementQueryService.js` - All query methods

### 2. **Aggregation Logic Too Strict**

**Problem:**
- Original logic required 30 minutes of data before aggregating
- This meant it would keep skipping until enough data accumulated

**Fix:**
- Now aggregates data that is at least 15 minutes old
- This allows aggregation to run as soon as there's one complete 15-minute window

## How to Test

### 1. Restart Your Server

```bash
# Stop the current server (Ctrl+C)
# Then restart
npm run dev
```

You should see:
```
[SCHEDULER] ✓ Aggregation scheduler started successfully
[SCHEDULER] Jobs: 15-min (every 15m), Hourly (every hour), Daily (1 AM), Safety Cleanup (2 AM)
```

### 2. Wait for Next Cron Run (or Trigger Manually)

The cron job runs every 15 minutes at: `:00`, `:15`, `:30`, `:45`

Or trigger manually:
```bash
POST http://localhost:3000/api/v1/loxone/aggregation/trigger/15min
Headers: { "Authorization": "Bearer YOUR_TOKEN" }
Body: {}
```

### 3. Check Logs

You should now see:
```
[SCHEDULER] [timestamp] Running 15-minute aggregation...
[AGGREGATION] [15-min] Created X aggregates for all buildings (start to end)
[AGGREGATION] [15-min] Deleted Y raw data points
[SCHEDULER] [timestamp] 15-minute aggregation completed: X aggregates created, Y raw data points deleted
```

### 4. Verify in MongoDB Compass

**Check for aggregates:**
```json
{
  "resolution_minutes": 15
}
```

**Check raw data count:**
```json
{
  "resolution_minutes": 0
}
```

After aggregation, raw data count should decrease.

## Expected Behavior

### Before Fix:
- ❌ No aggregates created (field name mismatch)
- ❌ Raw data not deleted
- ❌ Aggregation kept skipping

### After Fix:
- ✅ Aggregates created every 15 minutes
- ✅ Raw data deleted after aggregation (with buffer)
- ✅ Aggregation runs on schedule

## Verification Queries

### Count Aggregates
```javascript
// In MongoDB Compass or shell
db.measurements.countDocuments({ resolution_minutes: 15 })
```

### Count Raw Data
```javascript
db.measurements.countDocuments({ resolution_minutes: 0 })
```

### View Sample Aggregate
```javascript
db.measurements.findOne({ resolution_minutes: 15 })
```

### View Latest Aggregates
```javascript
db.measurements.find({ resolution_minutes: 15 })
  .sort({ timestamp: -1 })
  .limit(10)
```

## Troubleshooting

### Still No Aggregates?

1. **Check if cron job is running:**
   ```bash
   GET http://localhost:3000/api/v1/loxone/aggregation/status
   ```

2. **Check server logs** for errors:
   - Look for `[AGGREGATION]` or `[SCHEDULER]` messages
   - Check for any error messages

3. **Manually trigger aggregation:**
   ```bash
   POST http://localhost:3000/api/v1/loxone/aggregation/trigger/15min
   ```

4. **Verify data exists:**
   ```javascript
   // Check if you have raw data
   db.measurements.countDocuments({ resolution_minutes: 0 })
   
   // Check if data is old enough (at least 15 minutes old)
   db.measurements.find({ 
     resolution_minutes: 0,
     timestamp: { $lt: new Date(Date.now() - 15*60*1000) }
   }).count()
   ```

### Aggregation Skipping?

If you see "Skipping: Not enough data", it means:
- Data is too recent (less than 15 minutes old)
- Wait a bit longer or check if data timestamps are correct

## Summary

The main issue was a **field name mismatch** - the code was looking for `meta.resolution_minutes` but the data is stored as `resolution_minutes` at the root level. This is now fixed in all aggregation and query methods.

