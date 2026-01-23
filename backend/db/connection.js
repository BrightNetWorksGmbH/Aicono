const mongoose = require('mongoose');

let isConnected = false;
let connectionHandlersAttached = false;

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
      serverSelectionTimeoutMS: 30000, // Increased from 10s to 30s
      socketTimeoutMS: 60000, // Increased from 45s to 60s
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
 * @returns {Object} Pool statistics
 */
async function getPoolStatistics() {
  try {
    if (!mongoose.connection.readyState === 1) {
      return {
        available: false,
        message: 'Database not connected'
      };
    }

    const db = mongoose.connection.db;
    const admin = db.admin();
    
    // Get server status (includes connection info)
    const serverStatus = await admin.serverStatus();
    
    // Get connection pool info from mongoose
    const pool = mongoose.connection.getClient().topology?.s?.connectionPool;
    
    let poolStats = {
      available: true,
      maxPoolSize: parseInt(process.env.MONGODB_MAX_POOL_SIZE || '100', 10),
      minPoolSize: parseInt(process.env.MONGODB_MIN_POOL_SIZE || '10', 10),
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

    // Log warning if usage is high (80%+) or critical (95%+)
    if (poolStats.usagePercent >= 95) {
      console.error(`[MONGODB] 🔴 Connection pool usage is CRITICAL: ${poolStats.usagePercent}% (${poolStats.inUseConnections}/${poolStats.maxPoolSize} connections in use)`);
    } else if (poolStats.usagePercent >= 80) {
      console.warn(`[MONGODB] ⚠️  Connection pool usage is high: ${poolStats.usagePercent}% (${poolStats.inUseConnections}/${poolStats.maxPoolSize} connections in use)`);
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

module.exports = {
  connectToDatabase,
  isConnectionHealthy,
  getConnectionStatus,
  getPoolStatistics,
};

