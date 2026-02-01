const mongoose = require('mongoose');

let isConnected = false;
let connectionHandlersAttached = false;

// Connection priority system
const PRIORITY = {
    HIGH: 1,    // API requests, real-time data storage
    MEDIUM: 2,  // Aggregation operations
    LOW: 3      // Deletion operations
};

const priorityEnabled = process.env.MONGODB_PRIORITY_SYSTEM_ENABLED !== 'false';
const highPriorityReserved = parseInt(process.env.MONGODB_HIGH_PRIORITY_RESERVED || '20', 10);

// Logging throttling to prevent spam
let lastLoggedUsage = {
    percent: 0,
    timestamp: 0,
    level: null // 'warning' or 'error'
};
const LOG_THROTTLE_MS = 10000; // Only log once per 10 seconds
const LOG_CHANGE_THRESHOLD = 5; // Only log if usage changes by 5% or more

/**
 * Attach connection event handlers for monitoring and recovery
 * This is idempotent - handlers are only attached once
 */
function attachConnectionHandlers() {
  if (connectionHandlersAttached) {
    return;
  }

  mongoose.connection.on('error', (err) => {
    console.error('[MONGODB] Connection error:', err.message);
    isConnected = false;
  });

  mongoose.connection.on('disconnected', () => {
    console.warn('[MONGODB] Disconnected from MongoDB');
    isConnected = false;
  });

  mongoose.connection.on('reconnected', () => {
    console.log('[MONGODB] Reconnected to MongoDB');
    isConnected = true;
  });

  mongoose.connection.on('connecting', () => {
    console.log('[MONGODB] Connecting to MongoDB...');
  });

  mongoose.connection.on('connected', () => {
    console.log('[MONGODB] Connected to MongoDB');
    isConnected = true;
  });

  connectionHandlersAttached = true;
}

/**
 * Check if MongoDB connection is healthy
 * @returns {boolean} True if connection is ready
 */
function isConnectionHealthy() {
  return (
    isConnected &&
    mongoose.connection.readyState === 1 // 1 = connected
  );
}

/**
 * Connect to MongoDB with improved configuration and error handling
 * @returns {Promise<mongoose.Connection>} Mongoose connection instance
 */
async function connectToDatabase() {
  // Check if already connected and healthy
  if (isConnectionHealthy()) {
    return mongoose.connection;
  }

  const { MONGODB_URI } = process.env;
  if (!MONGODB_URI) {
    throw new Error('MONGODB_URI is not set in environment variables');
  }

  // Attach event handlers before connecting
  attachConnectionHandlers();

  try {
    // Improved connection options for better reliability
    // Connection pool size is configurable via env var, default to 100 for high-throughput scenarios
    // With 10 buildings processing in parallel + aggregation + API requests, we need more connections
    const maxPoolSize = parseInt(process.env.MONGODB_MAX_POOL_SIZE || '100', 10);
    const minPoolSize = parseInt(process.env.MONGODB_MIN_POOL_SIZE || '10', 10);
    
    await mongoose.connect(MONGODB_URI, {
      autoIndex: true,
      serverSelectionTimeoutMS: 60000, // Increased from 30s to 60s for better reliability
      socketTimeoutMS: 120000, // Increased from 60s to 120s for long-running aggregation queries
      maxPoolSize: maxPoolSize,
      minPoolSize: minPoolSize, // Keep minimum connections alive
      maxIdleTimeMS: 60000, // Close idle connections after 60s (increased from 30s)
      retryWrites: true,
      retryReads: true,
      // Connection pool options
      heartbeatFrequencyMS: 10000, // Check connection health every 10s
    });
    
    console.log(`[MONGODB] Connection pool configured: min=${minPoolSize}, max=${maxPoolSize}`);

    // Verify connection is actually ready
    await mongoose.connection.db.admin().ping();
    
    isConnected = true;
    console.log('[MONGODB] ✓ MongoDB connected successfully');
    return mongoose.connection;
  } catch (error) {
    console.error('[MONGODB] ✗ Connection error:', error.message);
    isConnected = false;
    throw error;
  }
}

/**
 * Get current connection status
 * @returns {Object} Connection status information
 */
function getConnectionStatus() {
  return {
    isConnected: isConnectionHealthy(),
    readyState: mongoose.connection.readyState,
    readyStateName: ['disconnected', 'connected', 'connecting', 'disconnecting'][mongoose.connection.readyState] || 'unknown',
    host: mongoose.connection.host,
    port: mongoose.connection.port,
    name: mongoose.connection.name,
  };
}

/**
 * Get connection pool statistics
 * @param {number} priority - Priority level (PRIORITY.HIGH, PRIORITY.MEDIUM, PRIORITY.LOW)
 * @returns {Object} Pool statistics
 */
async function getPoolStatistics(priority = PRIORITY.MEDIUM) {
  try {
    // Fix: Correct operator precedence - should be !== not !...==
    if (mongoose.connection.readyState !== 1) {
      return {
        available: false,
        message: 'Database not connected'
      };
    }

    const db = mongoose.connection.db;
    // Add null check before accessing admin()
    if (!db) {
      return {
        available: false,
        message: 'Database not available'
      };
    }
    
    const admin = db.admin();
    
    // Get server status (includes connection info)
    const serverStatus = await admin.serverStatus();
    
    // Get connection pool info from mongoose
    const pool = mongoose.connection.getClient().topology?.s?.connectionPool;
    
    let poolStats = {
      available: true,
      maxPoolSize: parseInt(process.env.MONGODB_MAX_POOL_SIZE || '100', 10),
      minPoolSize: parseInt(process.env.MONGODB_MIN_POOL_SIZE || '10', 10),
      priorityEnabled: priorityEnabled,
      highPriorityReserved: highPriorityReserved
    };

    if (pool) {
      poolStats.currentConnections = pool.totalConnectionCount || 0;
      poolStats.availableConnections = pool.availableConnectionCount || 0;
      poolStats.inUseConnections = poolStats.currentConnections - poolStats.availableConnections;
      poolStats.usagePercent = poolStats.maxPoolSize > 0 
        ? Math.round((poolStats.inUseConnections / poolStats.maxPoolSize) * 100) 
        : 0;
    } else {
      // Fallback: estimate from server status
      poolStats.currentConnections = serverStatus.connections?.current || 0;
      poolStats.availableConnections = poolStats.maxPoolSize - poolStats.currentConnections;
      poolStats.inUseConnections = poolStats.currentConnections;
      poolStats.usagePercent = poolStats.maxPoolSize > 0 
        ? Math.round((poolStats.currentConnections / poolStats.maxPoolSize) * 100) 
        : 0;
    }

    // Calculate effective available connections based on priority
    if (priorityEnabled) {
      const reservedForHigh = Math.min(highPriorityReserved, poolStats.maxPoolSize);
      const effectiveMaxForPriority = priority === PRIORITY.HIGH 
        ? poolStats.maxPoolSize  // High priority gets full pool
        : poolStats.maxPoolSize - reservedForHigh; // Others get reduced pool
      
      poolStats.effectiveMaxPoolSize = effectiveMaxForPriority;
      poolStats.effectiveUsagePercent = effectiveMaxForPriority > 0
        ? Math.round((poolStats.inUseConnections / effectiveMaxForPriority) * 100)
        : 0;
      poolStats.effectiveAvailableConnections = Math.max(0, effectiveMaxForPriority - poolStats.inUseConnections);
    } else {
      poolStats.effectiveMaxPoolSize = poolStats.maxPoolSize;
      poolStats.effectiveUsagePercent = poolStats.usagePercent;
      poolStats.effectiveAvailableConnections = poolStats.availableConnections;
    }

    // Log warning if usage is high (80%+) or critical (95%+)
    // Throttle logging to prevent spam - only log on significant changes or after throttle period
    const usageToCheck = priorityEnabled ? poolStats.effectiveUsagePercent : poolStats.usagePercent;
    const now = Date.now();
    const timeSinceLastLog = now - lastLoggedUsage.timestamp;
    const usageChange = Math.abs(usageToCheck - lastLoggedUsage.percent);
    
    const shouldLog = 
      timeSinceLastLog >= LOG_THROTTLE_MS || // Enough time has passed
      usageChange >= LOG_CHANGE_THRESHOLD || // Significant change
      (usageToCheck >= 95 && lastLoggedUsage.level !== 'error') || // Critical level changed
      (usageToCheck >= 80 && usageToCheck < 95 && lastLoggedUsage.level !== 'warning') || // Warning level changed
      (usageToCheck < 80 && lastLoggedUsage.level !== null && timeSinceLastLog >= LOG_THROTTLE_MS); // Only log normalized if enough time passed
    
    if (shouldLog) {
      if (usageToCheck >= 95) {
        // Show both actual and effective usage for clarity
        const actualUsage = poolStats.usagePercent;
        const effectiveUsage = poolStats.effectiveUsagePercent;
        if (priorityEnabled && priority !== PRIORITY.HIGH) {
          const priorityName = priority === PRIORITY.MEDIUM ? 'MEDIUM' : 'LOW';
          console.error(`[MONGODB] 🔴 Connection pool usage is CRITICAL for ${priorityName} priority: ${effectiveUsage}% effective (${poolStats.inUseConnections}/${poolStats.effectiveMaxPoolSize} of available), ${actualUsage}% actual (${poolStats.inUseConnections}/${poolStats.maxPoolSize} total, ${highPriorityReserved} reserved for HIGH priority)`);
        } else {
          console.error(`[MONGODB] 🔴 Connection pool usage is CRITICAL: ${usageToCheck}% (${poolStats.inUseConnections}/${poolStats.maxPoolSize} connections in use, priority: ${priority})`);
        }
        lastLoggedUsage = { percent: usageToCheck, timestamp: now, level: 'error' };
      } else if (usageToCheck >= 80) {
        const actualUsage = poolStats.usagePercent;
        const effectiveUsage = poolStats.effectiveUsagePercent;
        if (priorityEnabled && priority !== PRIORITY.HIGH) {
          const priorityName = priority === PRIORITY.MEDIUM ? 'MEDIUM' : 'LOW';
          console.warn(`[MONGODB] ⚠️  Connection pool usage is high for ${priorityName} priority: ${effectiveUsage}% effective (${poolStats.inUseConnections}/${poolStats.effectiveMaxPoolSize} of available), ${actualUsage}% actual (${poolStats.inUseConnections}/${poolStats.maxPoolSize} total)`);
        } else {
          console.warn(`[MONGODB] ⚠️  Connection pool usage is high: ${usageToCheck}% (${poolStats.inUseConnections}/${poolStats.maxPoolSize} connections in use, priority: ${priority})`);
        }
        lastLoggedUsage = { percent: usageToCheck, timestamp: now, level: 'warning' };
      } else if (lastLoggedUsage.level !== null && timeSinceLastLog >= LOG_THROTTLE_MS) {
        // Usage dropped below threshold - log recovery (only if enough time passed to prevent spam)
        console.log(`[MONGODB] ✓ Connection pool usage normalized: ${usageToCheck}% (${poolStats.inUseConnections}/${poolStats.maxPoolSize} connections in use)`);
        lastLoggedUsage = { percent: usageToCheck, timestamp: now, level: null };
      }
    }

    return poolStats;
  } catch (error) {
    console.error('[MONGODB] Error getting pool statistics:', error.message);
    return {
      available: false,
      error: error.message
    };
  }
}

/**
 * Check if a connection can be acquired for the given priority
 * @param {number} priority - Priority level
 * @returns {Promise<boolean>} True if connection can be acquired
 */
async function canAcquireConnection(priority = PRIORITY.MEDIUM) {
  if (!priorityEnabled) {
    return true; // Priority system disabled, allow all
  }

  const poolStats = await getPoolStatistics(priority);
  if (!poolStats.available) {
    return false;
  }

  // High priority can always acquire (up to max pool size)
  if (priority === PRIORITY.HIGH) {
    return poolStats.usagePercent < 95; // Allow up to 95% for high priority
  }

  // Medium and low priority check against effective pool size
  return poolStats.effectiveUsagePercent < 85; // Allow up to 85% for lower priorities
}

/**
 * Wait for connection availability
 * @param {number} priority - Priority level
 * @param {number} maxWaitMs - Maximum time to wait in milliseconds
 * @returns {Promise<boolean>} True if connection became available
 */
async function waitForConnection(priority = PRIORITY.MEDIUM, maxWaitMs = 10000) {
  const startTime = Date.now();
  const checkInterval = 500; // Check every 500ms

  while (Date.now() - startTime < maxWaitMs) {
    if (await canAcquireConnection(priority)) {
      return true;
    }
    await new Promise(resolve => setTimeout(resolve, checkInterval));
  }

  return false;
}

module.exports = {
  connectToDatabase,
  isConnectionHealthy,
  getConnectionStatus,
  getPoolStatistics,
  canAcquireConnection,
  waitForConnection,
  PRIORITY,
};

