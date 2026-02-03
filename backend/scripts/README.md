# Database Scripts

This directory contains various utility scripts for database operations.

## Scripts Overview

### 1. `copyDatabaseToTest.js` - Copy Database to Test Environment

Copies all collections from the `aicono` database to `aicono-test` database. Useful for creating a test environment that mirrors production data.

### 2. `aggregateExistingData.js` - Aggregate Existing Data

Aggregates existing unaggregated data in the MongoDB `measurements` collection. This is useful for:
- Migrating existing raw data to aggregated format
- Reducing database size by aggregating old data
- Optimizing query performance

---

## copyDatabaseToTest.js

### Overview

The `copyDatabaseToTest.js` script copies all collections (including data and indexes) from the `aicono` database to `aicono-test` database. This is useful when you need a separate test database that mirrors your production data structure.

### What It Does

- Connects to MongoDB using `MONGODB_URI` from `.env`
- Lists all collections in the source database (`aicono`)
- Copies all documents from each collection to the target database (`aicono-test`)
- Copies all indexes from each collection
- Verifies the copy operation was successful
- Provides a detailed summary of the operation

### Prerequisites

1. **Environment Setup**
   - Ensure `.env` file exists in the backend root directory
   - `MONGODB_URI` must be set in `.env` (pointing to your MongoDB cluster)
   - Target database (`aicono-test`) should exist (can be empty)

2. **Database Connection**
   - MongoDB must be accessible
   - User must have read permissions on source database
   - User must have write permissions on target database

### Usage

#### Basic Usage

```bash
cd Aicono/backend
node scripts/copyDatabaseToTest.js
```

#### With Options

```bash
# Use custom batch size (default: 10000)
node scripts/copyDatabaseToTest.js --batch-size=5000

# Skip copying indexes (faster, but indexes won't be copied)
node scripts/copyDatabaseToTest.js --skip-indexes
```

### Options

- `--batch-size=N`: Number of documents to copy at a time (default: 10000). Use smaller values if you encounter memory issues.
- `--skip-indexes`: Skip copying indexes. Use this if you want faster copying and will recreate indexes manually later.

### What to Expect

The script will:
- Connect to MongoDB
- List all collections in the source database
- Copy each collection's data in batches
- Copy indexes for each collection
- Verify the copy was successful
- Provide a detailed summary

### Example Output

```
========================================
[COPY DB] Starting database copy operation...
[COPY DB] Source: aicono
[COPY DB] Target: aicono-test
========================================

[COPY DB] Connecting to MongoDB...
[COPY DB] ✓ Connected to MongoDB

[COPY DB] ✓ Source database 'aicono' found
[COPY DB] ✓ Target database 'aicono-test' ready

[COPY DB] Found 15 collection(s) to copy:

  1. buildings
  2. measurements
  3. sensors
  ...

[COPY DB] Processing collection: buildings
  [COPY DB]   Found 10 document(s)
  [COPY DB]   ✓ Copied 10 document(s)
  [COPY DB]   Copying indexes...
  [COPY DB]   ✓ Copied 3 index(es)
  [COPY DB]   ✅ Verification passed: 10 documents in target
  [COPY DB]   ✓ Collection 'buildings' copied successfully

...

========================================
[COPY DB] Copy operation complete!
========================================
Collections processed: 15/15
Total documents copied: 1,234,567
Total time: 120.45s

Collection Summary:
----------------------------------------
✅ buildings: 10 documents
✅ measurements: 1,200,000 documents
✅ sensors: 500 documents
...

========================================

[COPY DB] ✅ All collections copied successfully!
[COPY DB] You can now use 'aicono-test' database in your .env file
[COPY DB] Update MONGODB_URI to use 'aicono-test' instead of 'aicono'
```

### Important Notes

1. **Target Collection Clearing**: The script will clear existing data in target collections before copying. This ensures a clean copy.

2. **Batch Processing**: Large collections are processed in batches to avoid memory issues and timeouts.

3. **Index Copying**: Indexes are copied with their original settings (unique, sparse, TTL, etc.). The `_id` index is automatically created by MongoDB, so it's skipped.

4. **Error Handling**: If a collection fails to copy, the script logs the error and continues with the next collection.

5. **Verification**: After copying each collection, the script verifies that the document count matches between source and target.

### Safety Recommendations

Before running:

1. **Backup**: Always backup your databases before running this script
2. **Test Connection**: Verify you can connect to both databases
3. **Check Permissions**: Ensure your MongoDB user has necessary permissions
4. **Monitor Progress**: Watch the logs to ensure copying is working correctly
5. **Verify Results**: Check the summary to ensure all collections were copied successfully

### Troubleshooting

#### Connection Errors
- Verify `MONGODB_URI` is correct in `.env`
- Check MongoDB is running and accessible
- Verify network connectivity
- Ensure the connection string format is correct

#### Permission Errors
- Verify your MongoDB user has read permissions on source database
- Verify your MongoDB user has write permissions on target database
- Check if your user has access to list databases

#### Memory Issues
- Use a smaller `--batch-size` value (e.g., `--batch-size=1000`)
- Process collections one at a time if needed

#### Timeout Errors
- Increase MongoDB connection timeout settings
- Use smaller batch sizes
- Check network latency

### After Running

Once the script completes successfully:

1. Update your `.env` file to use the test database:
   ```
   MONGODB_URI=mongodb+srv://{username}:{password}@db-mongodb-fra1-38814-2d181fd3.mongo.ondigitalocean.com/aicono-test?authSource=admin&replicaSet=db-mongodb-fra1-38814&tls=true
   ```

2. Test your application with the new database

3. Keep the production database (`aicono`) unchanged for your deployed version

---

## aggregateExistingData.js

### Overview

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
