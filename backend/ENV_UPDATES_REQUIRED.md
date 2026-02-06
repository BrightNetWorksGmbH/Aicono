# Environment Variables to Update

After applying the connection pool optimization fixes, please update your `.env` file with the following settings:

## Required MongoDB Pool Settings

Add or update these lines in your `.env` file:

```bash
# MongoDB Connection Pool - OPTIMIZED for 20+ buildings
MONGODB_MAX_POOL_SIZE=150
MONGODB_MIN_POOL_SIZE=10
MONGODB_HIGH_PRIORITY_RESERVED=30

# Aggregation Scheduler - Longer delays between buildings
AGGREGATION_BUILDING_DELAY_MS=5000
```

## What These Settings Do

| Setting | Default | Recommended | Purpose |
|---------|---------|-------------|---------|
| `MONGODB_MAX_POOL_SIZE` | 100 | 150 | Increases total connection pool for 20+ buildings |
| `MONGODB_MIN_POOL_SIZE` | 10 | 10 | Keeps minimum connections ready |
| `MONGODB_HIGH_PRIORITY_RESERVED` | 20 | 30 | Reserves more connections for real-time data |
| `AGGREGATION_BUILDING_DELAY_MS` | 2000 | 5000 | Longer delay between building aggregations |

## How to Apply

1. Open your `.env` file:
   ```bash
   nano /Users/sami/Downloads/vscode-download/Aicono/backend/.env
   ```

2. Add the settings above to the file

3. Restart your application:
   ```bash
   npm run dev
   ```

## Verification

After restarting, monitor the logs for:
- Pool usage should drop from 90-101% to 40-60%
- Structure files should load only once per building on startup
- Deletion queue should start running (previously blocked)

## Optional: Reduce Reserved Pool if API Traffic is Low

If your API traffic is light (few dashboard users), you can reduce the reserved pool to give more connections to real-time data:

```bash
# Alternative setting if API traffic is low
MONGODB_HIGH_PRIORITY_RESERVED=20  # Down from 30
```

This gives 130 connections available for real-time data (vs 120 with the default).

---
*This file was created by the connection pool optimization fix.*
*You can delete this file after updating your .env*
