const express = require('express');
const router = express.Router();

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

module.exports = router;

