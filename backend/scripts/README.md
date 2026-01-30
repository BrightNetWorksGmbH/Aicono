# Aggregation Migration Script

## Overview

The `aggregateExistingData.js` script aggregates existing unaggregated data in the MongoDB `measurements` collection. This is useful for:
- Migrating existing raw data to aggregated format
- Reducing database size by aggregating old data
- Optimizing query performance

## What It Does

The script processes data in three phases:

1. **Phase 1: Raw Data → 15-minute Aggregates**
   - Finds all raw data (resolution_minutes: 0)
   - Aggregates to 15-minute buckets
   - Deletes raw data after successful aggregation

2. **Phase 2: 15-minute → Hourly Aggregates**
   - Finds all 15-minute data older than 1 hour
   - Aggregates to hourly buckets
   - Deletes 15-minute data after successful aggregation

3. **Phase 3: Hourly → Daily Aggregates**
   - Finds all hourly data older than 1 week
   - Aggregates to daily buckets
   - Deletes hourly data after successful aggregation

## Prerequisites

1. **Environment Setup**
   - Ensure `.env` file exists in the backend root directory
   - `MONGODB_URI` must be set in `.env`

2. **Database Connection**
   - MongoDB must be accessible
   - User must have read/write permissions

## Usage

### Run the Script

```bash
cd Aicono/backend
node scripts/aggregateExistingData.js
```

### What to Expect

The script will:
- Connect to MongoDB
- Process data in time windows (to avoid memory issues)
- Log progress for each window
- Provide a summary at the end

### Example Output

```
========================================
[MIGRATION] Starting data aggregation migration...
========================================

✅ Connected to MongoDB

[MIGRATION] Phase 1: Aggregating raw data to 15-minute...
  Found raw data from 2020-01-01T00:00:00.000Z to 2024-01-15T12:00:00.000Z
  Processing 123456 raw data points from 2020-01-01T00:00:00.000Z to 2020-01-02T00:00:00.000Z
  ✓ Window 1: Created 4321 aggregates, deleted 123456 raw data points
  ...

[MIGRATION] Phase 1 complete: 1234567 raw → 43210 15-minute aggregates

[MIGRATION] Phase 2: Aggregating 15-minute data (older than 1 hour) to hourly...
  ...

[MIGRATION] Migration complete! Summary:
========================================
Phase 1 (Raw → 15-minute):
  - Raw data processed: 1,234,567
  - 15-minute aggregates created: 43,210
  - Raw data deleted: 1,234,567
...
Total time: 45m 30s
========================================
```

## Important Notes

1. **Data Deletion**: The script deletes source data after successful aggregation. This is intentional and matches the normal aggregation process.

2. **Time Windows**: Data is processed in time windows to avoid:
   - Memory exhaustion
   - Query timeouts
   - Database lock issues

3. **Error Handling**: If a window fails, the script logs the error and continues with the next window.

4. **Resumable**: If the script is interrupted, you can run it again. It will skip already-aggregated data (since source data is deleted).

5. **Time Series Collections**: The script automatically detects if the `measurements` collection is a Time Series collection and uses the appropriate insertion method.

## Safety Recommendations

Before running on production:

1. **Backup Database**: Always backup your database before running migration scripts
2. **Test on Staging**: Test the script on a staging environment first
3. **Monitor Progress**: Watch the logs to ensure processing is working correctly
4. **Check Disk Space**: Ensure you have enough disk space (aggregation reduces size but needs temporary space)

## Troubleshooting

### Connection Errors
- Verify `MONGODB_URI` is correct in `.env`
- Check MongoDB is running and accessible
- Verify network connectivity

### Timeout Errors
- The script processes data in windows to avoid timeouts
- If timeouts occur, the script will log the error and continue
- Consider reducing window size if issues persist

### Memory Issues
- The script processes data in time windows to minimize memory usage
- If memory issues occur, consider processing smaller time windows

## Related Files

- `services/measurementAggregationService.js` - Core aggregation logic
- `services/aggregationScheduler.js` - Scheduled aggregation jobs
- `db/connection.js` - Database connection setup
