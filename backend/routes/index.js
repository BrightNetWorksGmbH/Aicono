const express = require('express');
const router = express.Router();
const { getConnectionStatus, getPoolStatistics } = require('../db/connection');
const measurementQueueService = require('../services/measurementQueueService');

/**
 * @route   GET /
 * @desc    Health check endpoint
 * @access  Public
 */
router.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Aicono Energy Management System API',
    version: '1.0.0',
    status: 'running'
  });
});

/**
 * @route   GET /health
 * @desc    Health check endpoint
 * @access  Public
 */
router.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Server is healthy',
    timestamp: new Date().toISOString()
  });
});

/**
 * @route   GET /health/detailed
 * @desc    Detailed health check with connection pool and queue statistics
 * @access  Public
 */
router.get('/health/detailed', async (req, res) => {
  try {
    const connectionStatus = getConnectionStatus();
    const poolStats = await getPoolStatistics();
    const queueStats = measurementQueueService.getStats();
    
    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      database: connectionStatus,
      connectionPool: poolStats,
      measurementQueue: queueStats
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error getting health status',
      error: error.message
    });
  }
});

module.exports = router;

