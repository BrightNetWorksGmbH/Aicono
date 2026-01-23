const { isOperationalError } = require("../utils/errors");

/**
 * Global error handler middleware
 * Catches all errors and sends appropriate JSON responses
 *
 * Usage: Add as the last middleware in app.js:
 * app.use(errorHandler);
 */
const errorHandler = (err, req, res, next) => {
  // Handle timeout errors
  if (err.code === 'ETIMEDOUT' || err.message === 'Request timeout') {
    return res.status(504).json({
      success: false,
      message: 'Request timeout - the server took too long to respond',
      code: 'REQUEST_TIMEOUT'
    });
  }
  
  // Determine status code
  const statusCode = err.status || err.statusCode || 500;

  // Build error response
  const errorResponse = {
    success: false,
    message: err.message || "An unexpected error occurred",
  };

  // Add error code if available
  if (err.code) {
    errorResponse.code = err.code;
  }

  // Add additional error details in development mode
  if (process.env.NODE_ENV === "development") {
    errorResponse.stack = err.stack;

    // Add validation errors if present (from express-validator)
    if (err.errors) {
      errorResponse.errors = err.errors;
    }
  }

  // Handle operational vs programming errors
  if (!isOperationalError(err)) {
    // This is a programming error (bug) - log it prominently
    console.error("PROGRAMMING ERROR (BUG):", err);

    // In production, don't leak error details
    if (process.env.NODE_ENV === "production") {
      errorResponse.message = "An unexpected error occurred";
    }
  }

  // Send error response
  res.status(statusCode).json(errorResponse);
};

/**
 * Not Found (404) handler middleware
 * Catches requests to non-existent routes
 *
 * Usage: Add before the error handler in app.js:
 * app.use(notFoundHandler);
 * app.use(errorHandler);
 */
const notFoundHandler = (req, res, next) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.path}`,
    code: "ROUTE_NOT_FOUND",
  });
};

/**
 * Async error wrapper
 * Wraps async route handlers to catch errors automatically
 *
 * Usage:
 * router.get('/route', asyncHandler(async (req, res) => {
 *   // async code that might throw errors
 * }));
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Validation error handler
 * Processes express-validator errors
 *
 * Usage:
 * router.post('/route', [...validations], validationErrorHandler, async (req, res) => {
 *   // route logic
 * });
 */
const validationErrorHandler = (req, res, next) => {
  const { validationResult } = require("express-validator");
  const errors = validationResult(req);

  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: "Validation failed",
      code: "VALIDATION_ERROR",
      errors: errors.array(),
    });
  }

  next();
};

module.exports = {
  errorHandler,
  notFoundHandler,
  asyncHandler,
  validationErrorHandler,
};

