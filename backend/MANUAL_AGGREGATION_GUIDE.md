# Manual Aggregation Trigger Guide

## Fixed Issues

✅ **Controller Error Fixed**: The `req.body` destructuring error has been fixed. You can now trigger aggregation without a body.

## How to Manually Trigger Aggregation

### Option 1: Without Building ID (All Buildings)

```bash
POST http://localhost:3000/api/v1/loxone/aggregation/trigger/15min
Headers: {
  "Authorization": "Bearer YOUR_TOKEN",
  "Content-Type": "application/json"
}
Body: {}  # Empty body is now OK
```

Or using curl:
```bash
curl -X POST http://localhost:3000/api/v1/loxone/aggregation/trigger/15min \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Option 2: With Building ID (Specific Building)

```bash
POST http://localhost:3000/api/v1/loxone/aggregation/trigger/15min
Headers: {
  "Authorization": "Bearer YOUR_TOKEN",
  "Content-Type": "application/json"
}
Body: {
  "buildingId": "6948dcd113537bff98eb7338"
}
```

## Expected Response

### Success Response:
```json
{
  "success": true,
  "message": "15-minute aggregation triggered",
  "data": {
    "success": true,
    "count": 100,
    "deleted": 25000,
    "aggregationWindow": {
      "start": "2025-12-23T08:00:00.000Z",
      "end": "2025-12-23T08:15:00.000Z"
    },
    "buildingId": null
  }
}
```

### If No Data Available:
```json
{
  "success": true,
  "message": "15-minute aggregation triggered",
  "data": {
    "success": true,
    "count": 0,
    "deleted": 0,
    "skipped": true,
    "reason": "No data in time range"
  }
}
```

## Check Server Logs

After triggering, check your server console for:

### Success:
```
[SCHEDULER] Manually triggering 15-minute aggregation...
[AGGREGATION] [15-min] Found 25000 raw data points to aggregate
[AGGREGATION] [15-min] Created 100 aggregates for all buildings
[AGGREGATION] [15-min] Deleted 25000 raw data points
```

### No Data:
```
[SCHEDULER] Manually triggering 15-minute aggregation...
[AGGREGATION] [15-min] Found 0 raw data points to aggregate
[AGGREGATION] [15-min] No raw data found in time range, skipping aggregation
```

### Skipped (Data Too Recent):
```
[AGGREGATION] [15-min] Skipping: Not enough data for complete 15-minute window
```

## Verify in MongoDB

### Check if Aggregates Were Created:
```json
{
  "resolution_minutes": 15
}
```

### Check Raw Data Count:
```json
{
  "resolution_minutes": 0
}
```

## Troubleshooting

### Issue: "No data in time range"

**Possible Causes:**
1. Data is too recent (less than 15 minutes old)
2. Data timestamps are in the future
3. No data exists for the time range

**Solution:**
- Wait a bit longer (ensure data is at least 15 minutes old)
- Check data timestamps in MongoDB:
  ```javascript
  db.measurements.find({ resolution_minutes: 0 })
    .sort({ timestamp: -1 })
    .limit(5)
  ```

### Issue: "Skipping: Not enough data for complete 15-minute window"

**Cause:** The aggregation requires at least one complete 15-minute window of data that is at least 15 minutes old.

**Solution:**
- Wait until you have data that is at least 15 minutes old
- Check the oldest data:
  ```javascript
  db.measurements.find({ resolution_minutes: 0 })
    .sort({ timestamp: 1 })
    .limit(1)
  ```

### Issue: Cron Job Not Running

**Check:**
1. Is the scheduler started? Look for this in server logs:
   ```
   [SCHEDULER] ✓ Aggregation scheduler started successfully
   ```

2. Check scheduler status:
   ```bash
   GET http://localhost:3000/api/v1/loxone/aggregation/status
   ```

3. Cron schedule: Runs every 15 minutes at `:00`, `:15`, `:30`, `:45`

## Testing Steps

1. **Check if you have raw data:**
   ```javascript
   // In MongoDB Compass
   db.measurements.countDocuments({ resolution_minutes: 0 })
   ```

2. **Check oldest data timestamp:**
   ```javascript
   db.measurements.findOne(
     { resolution_minutes: 0 },
     { timestamp: 1 }
   ).sort({ timestamp: 1 })
   ```

3. **Manually trigger aggregation:**
   ```bash
   POST /api/v1/loxone/aggregation/trigger/15min
   ```

4. **Check logs** for detailed information

5. **Verify aggregates created:**
   ```javascript
   db.measurements.countDocuments({ resolution_minutes: 15 })
   ```

## Other Manual Triggers

### Hourly Aggregation:
```bash
POST http://localhost:3000/api/v1/loxone/aggregation/trigger/hourly
Body: {}  # Optional: { "buildingId": "..." }
```

### Daily Aggregation:
```bash
POST http://localhost:3000/api/v1/loxone/aggregation/trigger/daily
Body: {}  # Optional: { "buildingId": "..." }
```

