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
    await mongoose.connect(MONGODB_URI, {
      autoIndex: true,
      serverSelectionTimeoutMS: 30000, // Increased from 10s to 30s
      socketTimeoutMS: 60000, // Increased from 45s to 60s
      maxPoolSize: 10,
      minPoolSize: 2, // Keep minimum connections alive
      maxIdleTimeMS: 30000, // Close idle connections after 30s
      retryWrites: true,
      retryReads: true,
      // Connection pool options
      heartbeatFrequencyMS: 10000, // Check connection health every 10s
    });

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

module.exports = {
  connectToDatabase,
  isConnectionHealthy,
  getConnectionStatus,
};

