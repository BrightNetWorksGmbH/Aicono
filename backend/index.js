require('dotenv').config();
const express = require('express');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 3000;

// Import DB connection
const { connectToDatabase } = require('./db/connection');

// Import error handling middleware
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// Import routes
const indexRouter = require('./routes');
const authRouter = require('./routes/auth');
const invitationRouter = require('./routes/invitation');
const bryteswitchRouter = require('./routes/bryteswitch');
const siteRouter = require('./routes/sites');
const buildingRouter = require('./routes/buildings');
const loxoneRouter = require('./routes/loxone');
const floorRouter = require('./routes/floors');
const dashboardRouter = require('./routes/dashboard');
const uploadRouter = require('./routes/upload');
const sensorRouter = require('./routes/sensors');
const reportingRouter = require('./routes/reporting');
const reportsRouter = require('./routes/reports');

// CORS configuration
const corsOptions = {
  origin: true, // Allow ALL origins
  credentials: true, // Allow cookies and authorization headers
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization'],
  exposedHeaders: ['Authorization'],
  optionsSuccessStatus: 200
};

// Apply CORS middleware
app.use(cors(corsOptions));

// Rate limiting middleware - protect against resource exhaustion
const rateLimit = require('express-rate-limit');

// General API rate limiter (100 requests per 15 minutes per IP)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX || '100', 10), // Limit each IP to 100 requests per windowMs
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

// Stricter rate limiter for write operations (POST, PUT, PATCH, DELETE)
const writeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_WRITE_MAX || '30', 10), // Limit write operations more strictly
  message: {
    success: false,
    message: 'Too many write requests from this IP, please try again later.',
    code: 'RATE_LIMIT_WRITE_EXCEEDED'
  },
  skip: (req) => {
    // Skip rate limiting for GET, HEAD, OPTIONS requests
    return ['GET', 'HEAD', 'OPTIONS'].includes(req.method);
  }
});

// Apply general rate limiting to all API routes
app.use('/api/', apiLimiter);

// Apply stricter rate limiting to write operations
app.use('/api/', writeLimiter);

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Priority system: Track API requests for measurement queue throttling
const measurementQueueService = require('./services/measurementQueueService');
app.use((req, res, next) => {
  // Increment API request counter
  measurementQueueService.incrementApiRequests();
  
  // Decrement when response finishes
  res.on('finish', () => {
    measurementQueueService.decrementApiRequests();
  });
  
  next();
});

// Request timeout middleware - prevents requests from hanging indefinitely
const requestTimeout = parseInt(process.env.REQUEST_TIMEOUT_MS || '30000', 10); // Default 30 seconds
app.use((req, res, next) => {
  // Set timeout for this request
  req.setTimeout(requestTimeout, () => {
    if (!res.headersSent) {
      res.status(504).json({
        success: false,
        message: 'Request timeout - the server took too long to respond',
        code: 'REQUEST_TIMEOUT',
        timeout: requestTimeout
      });
    }
  });
  
  // Also set a timer to log timeout occurrences
  const timeoutId = setTimeout(() => {
    if (!res.headersSent) {
      console.warn(`[TIMEOUT] Request ${req.method} ${req.path} exceeded ${requestTimeout}ms timeout`);
    }
  }, requestTimeout);
  
  // Clear timeout when response is sent
  const originalEnd = res.end;
  res.end = function(...args) {
    clearTimeout(timeoutId);
    originalEnd.apply(this, args);
  };
  
  next();
});

// Routes
app.use('/', indexRouter);
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/invitations', invitationRouter);
app.use('/api/v1/bryteswitch', bryteswitchRouter);
app.use('/api/v1/sites', siteRouter);
app.use('/api/v1/buildings', buildingRouter);
app.use('/api/v1/loxone', loxoneRouter);
app.use('/api/v1/floors', floorRouter);
app.use('/api/v1/dashboard', dashboardRouter);
app.use('/api/v1/upload', uploadRouter);
app.use('/api/v1/sensors', sensorRouter);
app.use('/api/v1/reporting', reportingRouter);
app.use('/api/v1/reports', reportsRouter);

// Handle 404 - Not Found routes
app.use(notFoundHandler);

// Global error handling middleware (must be last)
app.use(errorHandler);

// Import aggregation scheduler
const aggregationScheduler = require('./services/aggregationScheduler');
// Import reporting scheduler
const reportingScheduler = require('./services/reportingScheduler');
// Import Loxone connection manager
const loxoneConnectionManager = require('./services/loxoneConnectionManager');

// Start server after DB is connected
connectToDatabase()
  .then(async () => {
    // Initialize measurement collections once at startup (before restoring connections)
    // This prevents redundant initialization checks during connection restoration
    try {
      const measurementCollectionService = require('./services/measurementCollectionService');
      await measurementCollectionService.ensureCollectionsExist();
      console.log('[STARTUP] ✓ Measurement collections initialized');
    } catch (error) {
      console.error('[STARTUP] ❌ Failed to initialize measurement collections:', error.message);
      // Don't fail server startup, but log the error clearly
    }
    
    // Start aggregation scheduler after DB connection
    try {
      aggregationScheduler.start();
      console.log('[STARTUP] ✓ Aggregation scheduler started successfully');
    } catch (error) {
      console.error('[STARTUP] ❌ Failed to start aggregation scheduler:', error.message);
      console.error('[STARTUP] Stack trace:', error.stack);
      // Don't fail server startup, but log the error clearly
    }
    
    // Start reporting scheduler after aggregation scheduler (to ensure clean data)
    try {
      reportingScheduler.start();
      console.log('[STARTUP] ✓ Reporting scheduler started successfully');
    } catch (error) {
      console.error('[STARTUP] ❌ Failed to start reporting scheduler:', error.message);
      console.error('[STARTUP] Stack trace:', error.stack);
      // Don't fail server startup, but log the error clearly
    }
    
    // Restore Loxone connections from database (non-blocking)
    // This ensures connections persist across server restarts/deployments
    // Collections are already initialized above, so no redundant checks during restoration
    loxoneConnectionManager.restoreConnections()
      .then((result) => {
        if (result.restored > 0 || result.failed > 0) {
          console.log(`[LOXONE] Connection restoration: ${result.restored} restored, ${result.failed} failed`);
        }
      })
      .catch((error) => {
        console.error('[LOXONE] Failed to restore connections:', error.message);
        // Don't fail server startup if connection restoration fails
      });
    
    app.listen(port, () => {
      console.log(`Aicono EMS Server running at http://localhost:${port}`);
    });
  })
  .catch((error) => {
    console.error('Failed to start server due to DB connection error:', error.message);
    process.exit(1);
  });

