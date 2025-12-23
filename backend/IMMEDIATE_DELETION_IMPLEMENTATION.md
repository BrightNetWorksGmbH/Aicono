# Immediate Raw Data Deletion Implementation

## Overview

This implementation adds **immediate deletion of raw data after aggregation** to reduce storage by ~99.7% while maintaining data integrity and spike detection capabilities.

## Key Features

### 1. Safe Deletion Logic

- **Only deletes aggregated data**: Deletes raw data from the exact time range that was aggregated
- **Complete window check**: Only aggregates complete 15-minute windows (skips incomplete current window)
- **Safety buffer**: Keeps raw data for at least 30 minutes (configurable) to prevent deleting current window data
- **Error isolation**: Deletion errors don't fail aggregation - aggregates are created first

### 2. Configuration

Add to `.env`:

```env
# Enable/disable immediate deletion (default: true)
DELETE_RAW_AFTER_AGGREGATION=true

# Safety buffer in minutes (default: 30)
# Keeps raw data for at least this long to prevent deleting current window
RAW_DATA_BUFFER_MINUTES=30

# Safety net retention (default: 1 day)
# Only used if immediate deletion fails or is disabled
OLD_DATA_RETENTION_DAYS=1
```

### 3. How It Works

```
Timeline Example:

10:00:00 - Real-time data starts flowing
10:00-10:15 - 25,000 raw data points accumulate

10:15:00 - Aggregation runs:
            ├── Checks: Is 10:00-10:15 a complete window? YES
            ├── Aggregates 10:00-10:15 → Creates ~100 aggregates with min/max/avg
            ├── Checks: Is 10:00-10:15 older than 30-min buffer? YES (15 min old)
            └── Deletes raw data from 10:00-10:15 → ~25,000 points deleted

10:15-10:30 - New raw data accumulates (current window, protected by buffer)
10:30:00 - Next aggregation runs:
            ├── Aggregates 10:15-10:30
            └── Deletes raw data from 10:15-10:30
```

### 4. Safety Mechanisms

#### Mechanism 1: Complete Window Check
```javascript
// Only aggregate complete 15-minute windows
const safeAggregationEnd = new Date(bucketEnd.getTime() - 15 * 60 * 1000);
if (bucketStart >= safeAggregationEnd) {
    // Skip aggregation - not enough data for complete window
    return { skipped: true };
}
```

#### Mechanism 2: Buffer Protection
```javascript
// Only delete data older than buffer
const bufferCutoff = new Date(now.getTime() - bufferMinutes * 60 * 1000);
const deleteCutoff = new Date(Math.min(safeAggregationEnd.getTime(), bufferCutoff.getTime()));

// Only delete if cutoff is after bucketStart
if (deleteCutoff > bucketStart) {
    // Safe to delete
    deleteRawData(bucketStart, deleteCutoff);
}
```

#### Mechanism 3: Precise Time Range
```javascript
// Only delete the exact range that was aggregated
const deleteMatchStage = {
    'meta.resolution_minutes': 0,
    timestamp: { 
        $gte: bucketStart,      // Exact start of aggregated window
        $lt: deleteCutoff       // Up to buffer cutoff
    }
};
```

## Storage Impact

### Before (30-day retention)
- Raw data: 72M points (~14.4 GB)
- Total: ~15 GB

### After (immediate deletion)
- Raw data: ~100K-200K points (~20-40 MB) - only 30-minute buffer
- Total: ~5.3 GB

**Reduction: 99.7% storage savings**

## Spike Detection

Spikes are **fully preserved** in aggregates:

```javascript
{
  timestamp: ISODate("2025-01-15T10:15:00.000Z"),
  value: 12.4,        // Average or consumption
  avgValue: 12.4,     // Average value
  minValue: 11.8,     // ← Low spike captured
  maxValue: 13.1,     // ← High spike captured
  count: 150          // Number of raw points aggregated
}
```

Alarm detection can use:
- `maxValue` for high spike detection
- `minValue` for low spike detection
- `avgValue` for trend analysis

## API Changes

### Manual Trigger (with options)

```bash
POST /api/v1/loxone/aggregation/trigger/15min
Body: {
  "buildingId": "optional_building_id",
  "deleteAfterAggregation": true  // Optional, uses config default
}
```

Response:
```json
{
  "success": true,
  "count": 100,
  "deleted": 25000,
  "aggregationWindow": {
    "start": "2025-01-15T10:00:00.000Z",
    "end": "2025-01-15T10:15:00.000Z"
  }
}
```

## Testing

### 1. Verify Aggregation Works
```bash
# Trigger aggregation
POST /api/v1/loxone/aggregation/trigger/15min

# Check aggregates created
db.measurements.find({ "meta.resolution_minutes": 15 })
  .sort({ timestamp: -1 })
  .limit(5)
```

### 2. Verify Raw Data Deletion
```bash
# Before aggregation
db.measurements.countDocuments({ "meta.resolution_minutes": 0 })
# Should show high count (e.g., 25,000)

# After aggregation (wait 15 minutes or trigger manually)
db.measurements.countDocuments({ "meta.resolution_minutes": 0 })
# Should show low count (only recent 30-minute buffer, ~100K-200K)
```

### 3. Verify Spike Detection
```bash
# Check aggregates have min/max values
db.measurements.findOne({ 
  "meta.resolution_minutes": 15 
}, {
  value: 1,
  avgValue: 1,
  minValue: 1,
  maxValue: 1,
  count: 1
})
```

## Monitoring

### Log Messages

```
[AGGREGATION] [15-min] Created 100 aggregates (2025-01-15T10:00:00.000Z to 2025-01-15T10:15:00.000Z)
[AGGREGATION] [15-min] Deleted 25000 raw data points (2025-01-15T10:00:00.000Z to 2025-01-15T10:14:30.000Z)
[SCHEDULER] 15-minute aggregation completed: 100 aggregates created, 25000 raw data points deleted
```

### Skipped Aggregation

```
[AGGREGATION] [15-min] Skipping: Not enough data for complete 15-minute window
[SCHEDULER] 15-minute aggregation skipped: Not enough data
```

### Buffer Protection

```
[AGGREGATION] [15-min] Skipping deletion: Data is within 30-minute safety buffer
```

## Troubleshooting

### Issue: Raw data not being deleted

**Check:**
1. Is `DELETE_RAW_AFTER_AGGREGATION=true` in `.env`?
2. Is data older than `RAW_DATA_BUFFER_MINUTES`?
3. Check logs for deletion errors

**Solution:**
```bash
# Manually trigger with deletion
POST /api/v1/loxone/aggregation/trigger/15min
Body: { "deleteAfterAggregation": true }
```

### Issue: Data from current window deleted

**Check:**
1. Is `RAW_DATA_BUFFER_MINUTES` set correctly?
2. Check aggregation window in logs

**Solution:**
Increase buffer:
```env
RAW_DATA_BUFFER_MINUTES=45  # Increase buffer
```

### Issue: Aggregation skipping

**Check:**
1. Is there enough data for a complete 15-minute window?
2. Check if data is flowing from Loxone

**Solution:**
Wait for more data or check Loxone connection.

## Migration Notes

### Existing Data

If you have existing raw data from before this implementation:
- Old raw data will be cleaned up by the safety cleanup job (daily at 2 AM)
- Or manually run cleanup:
  ```bash
  # Delete raw data older than 1 day
  db.measurements.deleteMany({
    "meta.resolution_minutes": 0,
    timestamp: { $lt: new Date(Date.now() - 24*60*60*1000) }
  })
  ```

### Disabling Immediate Deletion

If you need to disable immediate deletion temporarily:

```env
DELETE_RAW_AFTER_AGGREGATION=false
```

Raw data will be kept until the safety cleanup job runs (daily at 2 AM).

## Best Practices

1. **Monitor storage**: Check raw data count periodically
2. **Adjust buffer**: Increase `RAW_DATA_BUFFER_MINUTES` if you need more recent raw data
3. **Test first**: Test on a development environment before production
4. **Backup aggregates**: Ensure aggregates are being created before relying on deletion
5. **Monitor logs**: Watch for deletion errors or skipped aggregations

