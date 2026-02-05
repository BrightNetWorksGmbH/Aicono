# Connection Pool Optimization Plan

## Critical Issues Identified

### 1. Repeated Structure Loading (PRIMARY ISSUE)
**Location:** `loxoneStorageService.js:676-721`
**Problem:** Every time UUID map is empty, the entire structure file is reloaded and `loadStructureMapping()` is called, which performs heavy database operations:
- Aggregation to count sensors (lines 501-512)
- Aggregation with $lookup to load sensors (lines 526-537)
- Building UUID mappings (lines 551-621)

With 20 buildings receiving measurements constantly, this creates a connection storm.

**Root Cause:** The UUID map becomes empty because:
1. Structure might not be fully loaded when measurements start arriving
2. The `loadStructureMapping()` function is called multiple times unnecessarily
3. No caching mechanism to prevent redundant database queries

### 2. Inefficient Sensor Fetching in storeMeasurements()
**Location:** `loxoneStorageService.js:751-766`
**Problem:** For every measurement batch, sensors are fetched from database even though they rarely change.

### 3. Concurrent Operations Overwhelming Pool
- 20 WebSocket connections processing measurements in parallel
- Measurement queue processes all buildings simultaneously
- Aggregation runs with minimal delays between buildings
- Each operation holds connections for extended periods

### 4. Deletion Queue Never Runs
Pool usage always >85%, so deletions are blocked, causing data accumulation.

## Optimization Strategy

### Phase 1: Fix Repeated Structure Loading (CRITICAL - Immediate)

#### 1.1 Add Structure Loading State Tracking
Prevent multiple simultaneous structure loads for the same building.

#### 1.2 Cache Sensor Data
Cache sensor information to avoid repeated database queries during measurement storage.

#### 1.3 Remove Redundant Structure Reloading
Don't reload structure file on every UUID map check - only reload when explicitly needed.

### Phase 2: Optimize Database Queries (High Priority)

#### 2.1 Optimize loadStructureMapping()
- Remove redundant aggregation queries
- Use direct queries with proper indexes
- Cache results in memory

#### 2.2 Batch Sensor Fetching
- Fetch all sensors for a building once and cache
- Only refresh when structure changes

#### 2.3 Optimize Plausibility Checks
- Make plausibility checks async/non-blocking
- Batch alarm creation

### Phase 3: Connection Pool Management (Medium Priority)

#### 3.1 Increase Pool Size Temporarily
Increase from 100 to 150-200 to handle load while other optimizations are implemented.

#### 3.2 Stagger Operations
- Add delays between building processing in aggregation
- Throttle measurement queue more aggressively when pool is high

#### 3.3 Connection Priority Enforcement
- Ensure deletion queue runs at LOW priority
- Prioritize real-time data storage

### Phase 4: Long-term Improvements (Low Priority)

#### 4.1 Structure File Change Detection
- Use file timestamps to detect changes
- Only reload when file actually changes

#### 4.2 Measurement Buffering
- Buffer measurements more aggressively before database insert
- Larger batch sizes during high load

#### 4.3 Separate Database Connections
- Consider separate connection pool for aggregation
- Read replicas for reporting queries

## Implementation Order

1. **IMMEDIATE (Fix Repeated Loading)**
   - Add loading state flags to prevent duplicate structure loads
   - Cache sensor data in memory
   - Remove automatic structure reload on empty UUID map

2. **Within 24 Hours (Optimize Queries)**
   - Optimize loadStructureMapping() query structure
   - Add sensor caching
   - Batch alarm creation

3. **Within Week (Pool Management)**
   - Increase pool size
   - Better operation staggering
   - Connection priority enforcement

4. **Future (Long-term)**
   - File change detection
   - Advanced buffering
   - Database architecture improvements

## Expected Impact

### After Phase 1 (Immediate):
- **60-70% reduction** in connection pool usage
- Structure loading happens once per building instead of continuously
- Real-time measurement storage becomes non-blocking

### After Phase 2 (24 hours):
- **Additional 15-20% reduction** in connection usage
- Faster measurement processing
- Reduced query load on database

### After Phase 3 (Week):
- **Deletion queue starts running** (cleans up old data)
- **Stable pool usage** around 40-60%
- Better handling of traffic spikes

## Monitoring

Track these metrics before and after each phase:
1. Connection pool usage % (target: <60%)
2. Structure loading frequency per building (target: 1 time per connection)
3. Measurement storage latency (target: <100ms per batch)
4. Deletion queue processing (target: running regularly)
5. Database query count (target: 50% reduction)
