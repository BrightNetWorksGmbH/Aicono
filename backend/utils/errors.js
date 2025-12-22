/**
 * Base class for application errors
 * Extends Error with status code and error code properties
 */
class AppError extends Error {
  constructor(message, status = 500, code = "INTERNAL_ERROR") {
    super(message);
    this.name = this.constructor.name;
    this.status = status;
    this.code = code;
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    return {
      error: {
        name: this.name,
        message: this.message,
        code: this.code,
        status: this.status,
      },
    };
  }
}

/**
 * Validation Error (400)
 * Used for invalid input, malformed requests, validation failures
 */
class ValidationError extends AppError {
  constructor(message, code = "VALIDATION_ERROR") {
    super(message, 400, code);
  }
}

/**
 * Authentication Error (401)
 * Used when authentication is required but not provided or invalid
 */
class AuthenticationError extends AppError {
  constructor(message = "Authentication required", code = "AUTHENTICATION_ERROR") {
    super(message, 401, code);
  }
}

/**
 * Authorization Error (403)
 * Used when user is authenticated but doesn't have permission
 */
class AuthorizationError extends AppError {
  constructor(message = "Permission denied", code = "AUTHORIZATION_ERROR") {
    super(message, 403, code);
  }
}

/**
 * Not Found Error (404)
 * Used when a requested resource doesn't exist
 */
class NotFoundError extends AppError {
  constructor(resource = "Resource", code = "NOT_FOUND") {
    super(`${resource} not found`, 404, code);
    this.resource = resource;
  }
}

/**
 * Conflict Error (409)
 * Used for conflicts like duplicate entries, already exists, etc.
 */
class ConflictError extends AppError {
  constructor(message, code = "CONFLICT") {
    super(message, 409, code);
  }
}

/**
 * Unprocessable Entity Error (422)
 * Used when request is well-formed but semantically incorrect
 */
class UnprocessableEntityError extends AppError {
  constructor(message, code = "UNPROCESSABLE_ENTITY") {
    super(message, 422, code);
  }
}

/**
 * Rate Limit Error (429)
 * Used when too many requests are made
 */
class RateLimitError extends AppError {
  constructor(message = "Too many requests", code = "RATE_LIMIT_EXCEEDED") {
    super(message, 429, code);
  }
}

/**
 * Internal Server Error (500)
 * Used for unexpected server errors
 */
class InternalServerError extends AppError {
  constructor(message = "Internal server error", code = "INTERNAL_ERROR") {
    super(message, 500, code);
  }
}

/**
 * Service Unavailable Error (503)
 * Used when a service/database is temporarily unavailable
 */
class ServiceUnavailableError extends AppError {
  constructor(message = "Service temporarily unavailable", code = "SERVICE_UNAVAILABLE") {
    super(message, 503, code);
  }
}

/**
 * Helper function to create an error with custom status and code
 * Useful for backward compatibility with existing code
 * @param {string} message - Error message
 * @param {number} status - HTTP status code
 * @param {string} code - Error code
 * @returns {AppError}
 */
const createError = (message, status = 500, code = "ERROR") => {
  return new AppError(message, status, code);
};

/**
 * Checks if an error is an operational error (expected) vs programming error (bug)
 * @param {Error} error
 * @returns {boolean}
 */
const isOperationalError = (error) => {
  return error instanceof AppError;
};

module.exports = {
  AppError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  UnprocessableEntityError,
  RateLimitError,
  InternalServerError,
  ServiceUnavailableError,
  createError,
  isOperationalError,
};

