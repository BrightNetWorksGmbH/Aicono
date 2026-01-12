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

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

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

// Handle 404 - Not Found routes
app.use(notFoundHandler);

// Global error handling middleware (must be last)
app.use(errorHandler);

// Import aggregation scheduler
const aggregationScheduler = require('./services/aggregationScheduler');
// Import Loxone connection manager
const loxoneConnectionManager = require('./services/loxoneConnectionManager');

// Start server after DB is connected
connectToDatabase()
  .then(async () => {
    // Start aggregation scheduler after DB connection
    aggregationScheduler.start();
    
    // Restore Loxone connections from database (non-blocking)
    // This ensures connections persist across server restarts/deployments
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

