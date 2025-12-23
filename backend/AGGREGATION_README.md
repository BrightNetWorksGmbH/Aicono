# Measurement Aggregation System

## Overview

The aggregation system automatically reduces storage requirements by ~99.7% while maintaining data integrity for reporting. It creates multi-tier aggregations with **immediate raw data deletion**:

- **Raw Data** (resolution_minutes: 0) - Kept for 30 minutes (configurable buffer)
- **15-Minute Aggregates** (resolution_minutes: 15) - Kept for 2 years
- **Hourly Aggregates** (resolution_minutes: 60) - Kept for 5 years
- **Daily Aggregates** (resolution_minutes: 1440) - Kept indefinitely

### Key Feature: Immediate Raw Data Deletion

Raw data is **automatically deleted immediately after aggregation** (within 15-30 minutes), keeping only a small safety buffer. This provides:
- **99.7% storage reduction** (from 72M to ~100K-200K raw points)
- **Spike detection preserved** via min/max values in aggregates
- **Recent data available** via 15-minute aggregates
- **Safe operation** with configurable buffer to prevent data loss

## Architecture

### Services

1. **measurementAggregationService.js** - Core aggregation logic
   - `aggregate15Minutes(buildingId)` - Aggregates raw data to 15-minute buckets
   - `aggregateHourly(buildingId)` - Aggregates 15-minute data to hourly buckets
   - `aggregateDaily(buildingId)` - Aggregates hourly data to daily buckets
   - `cleanupRawData(retentionDays, buildingId)` - Removes old raw data

2. **aggregationScheduler.js** - Cron job manager
   - Automatically runs aggregations on schedule
   - Provides manual trigger methods for testing

3. **measurementQueryService.js** - Optimized query service
   - Automatically selects appropriate resolution based on time range
   - Provides statistics and reporting methods

## Cron Schedule

- **Every 15 minutes**: 
  - Aggregate raw data → 15-minute buckets
  - **Delete raw data immediately after aggregation** (with safety buffer)
- **Every hour** (at :00): Aggregate 15-minute data → hourly buckets
- **Daily at 1:00 AM**: Aggregate hourly data → daily buckets
- **Daily at 2:00 AM**: Safety cleanup (removes any remaining raw data older than retention period)

## Configuration

Add these to your `.env` file:

```env
# Delete raw data immediately after aggregation (default: true)
DELETE_RAW_AFTER_AGGREGATION=true

# Safety buffer: keep raw data for at least N minutes (default: 30)
# This prevents deleting data from the current aggregation window
RAW_DATA_BUFFER_MINUTES=30

# Safety net: retention period for old data cleanup (default: 1 day)
# Only used as a safety net if immediate deletion fails
OLD_DATA_RETENTION_DAYS=1
```

## API Endpoints

### Aggregation Status
```
GET /api/v1/loxone/aggregation/status
```
Returns the status of all aggregation cron jobs.

### Manual Triggers (for testing)
```
POST /api/v1/loxone/aggregation/trigger/15min
POST /api/v1/loxone/aggregation/trigger/hourly
POST /api/v1/loxone/aggregation/trigger/daily
```
Body (optional):
```json
{
  "buildingId": "building_id_here"
}
```

### Query Measurements
```
GET /api/v1/loxone/measurements/:sensorId?startDate=2025-01-01&endDate=2025-01-02&resolution=15
GET /api/v1/loxone/measurements/building/:buildingId?startDate=2025-01-01&endDate=2025-01-02&measurementType=Energy
GET /api/v1/loxone/statistics/:buildingId?startDate=2025-01-01&endDate=2025-01-31&measurementType=Energy
```

## Testing

### 1. Start the Server
```bash
npm run dev
```

You should see:
```
[SCHEDULER] ✓ Aggregation scheduler started successfully
[SCHEDULER] Jobs: 15-min (every 15m), Hourly (every hour), Daily (1 AM), Cleanup (2 AM)
```

### 2. Connect a Building to Loxone
```bash
POST /api/v1/loxone/connect/:buildingId
```

### 3. Wait for Real-time Data
Let the system collect real-time measurements for at least 15 minutes.

### 4. Check Aggregation Status
```bash
GET /api/v1/loxone/aggregation/status
```

### 5. Manually Trigger 15-Minute Aggregation (for testing)
```bash
POST /api/v1/loxone/aggregation/trigger/15min
Body: { "buildingId": "your_building_id" }
```

### 6. Verify Aggregates Were Created
Check MongoDB:
```javascript
db.measurements.find({ "meta.resolution_minutes": 15 }).sort({ timestamp: -1 }).limit(10)
```

### 7. Query Measurements
```bash
GET /api/v1/loxone/measurements/building/:buildingId?startDate=2025-01-01T00:00:00Z&endDate=2025-01-02T00:00:00Z
```

## Automatic Resolution Selection

The query service automatically selects the best resolution:

- **< 1 day**: Raw data (resolution_minutes: 0)
- **1-7 days**: 15-minute aggregates (resolution_minutes: 15)
- **7-90 days**: Hourly aggregates (resolution_minutes: 60)
- **> 90 days**: Daily aggregates (resolution_minutes: 1440)

You can override this by specifying the `resolution` query parameter.

## Storage Savings

**Before Aggregation:**
- 5,000-7,000 data points/minute
- ~7.2M-10M data points/day
- ~2.6B-3.6B data points/year

**After Aggregation (with immediate deletion):**
- Raw data: ~100K-200K records (30-minute buffer only)
- 15-minute aggregates: ~20M records (2 years)
- Hourly aggregates: ~4.4M records (5 years)
- Daily aggregates: ~1.8M records/year

**Total: ~25M records vs. 2.5B+ without aggregation (~99% reduction)**

### Storage Breakdown

| Data Type | Retention | Records | Storage (approx) |
|-----------|-----------|---------|------------------|
| Raw Data | 30 minutes | ~100K-200K | ~20-40 MB |
| 15-min Aggregates | 2 years | ~20M | ~4 GB |
| Hourly Aggregates | 5 years | ~4.4M | ~880 MB |
| Daily Aggregates | Indefinite | ~1.8M/year | ~360 MB/year |

**Total: ~5.3 GB vs. ~500 GB without aggregation**

## MongoDB Requirements

This system requires MongoDB 5.0+ for the `$dateTrunc` operator used in aggregation pipelines.

## How Immediate Deletion Works

### Safety Mechanisms

1. **Complete Window Check**: Only aggregates complete 15-minute windows (not the current incomplete window)
2. **Buffer Protection**: Keeps raw data for at least 30 minutes (configurable) to prevent deleting current window data
3. **Precise Deletion**: Only deletes the exact time range that was aggregated
4. **Error Handling**: Deletion errors don't fail aggregation - aggregates are created first

### Example Timeline

```
10:00:00 - Real-time data starts flowing
10:00-10:15 - Raw data accumulates (25,000 points)
10:15:00 - Aggregation runs:
            ├── Aggregates 10:00-10:15 data → Creates ~100 aggregates
            ├── Checks: Is 10:00-10:15 complete? YES
            ├── Checks: Is it older than 30-min buffer? YES (it's 15 min old)
            └── Deletes raw data from 10:00-10:15 → ~25,000 points deleted

10:15-10:30 - New raw data accumulates (current window, NOT deleted)
10:30:00 - Next aggregation runs:
            ├── Aggregates 10:15-10:30 data
            └── Deletes raw data from 10:15-10:30
```

### Spike Detection

Spikes are **preserved** in aggregates via min/max values:
- High spikes → captured in `maxValue`
- Low spikes → captured in `minValue`
- Average trends → captured in `avgValue`

## Notes

- Aggregations run automatically in the background
- Raw data is deleted immediately after aggregation (with 30-minute safety buffer)
- Energy measurements use consumption calculation (last - first) for 15-minute buckets
- Other measurement types use average values
- All aggregations are stored in the same `measurements` collection with different `resolution_minutes` values
- Spike detection works via min/max values in aggregates
- Daily/weekly/monthly reports use aggregated data

