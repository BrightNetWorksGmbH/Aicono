const jwt = require('jsonwebtoken');

/**
 * Report Token Service
 * 
 * Generates and verifies JWT tokens for report viewing links in emails
 * Uses separate secret from authentication JWT for security isolation
 */
class ReportTokenService {
  /**
   * Get the report secret from environment
   * Falls back to JWT_SECRET if REPORT_SECRET not set (for backward compatibility)
   * @returns {String} Secret key
   */
  getSecret() {
    return process.env.REPORT_SECRET;
  }

  /**
   * Generate JWT token for report viewing
   * @param {String} recipientId - ReportingRecipient ID
   * @param {String} buildingId - Building ID
   * @param {String} reportingId - Reporting ID
   * @param {Object} timeRange - { startDate, endDate }
   * @param {String} interval - Report interval (Daily, Weekly, Monthly, Yearly)
   * @returns {String} JWT token
   */
  generateReportToken(recipientId, buildingId, reportingId, timeRange, interval) {
    const secret = this.getSecret();
    console.log("secret for generating token", secret);
    if (!secret) {
      throw new Error('REPORT_SECRET or JWT_SECRET must be configured in environment variables');
    }

    const payload = {
      recipientId: recipientId.toString(),
      buildingId: buildingId.toString(),
      reportingId: reportingId.toString(),
      startDate: timeRange.startDate.toISOString(),
      endDate: timeRange.endDate.toISOString(),
      generatedAt: new Date().toISOString(),
      interval: interval,
    };

    // Token expires in 30 days (reports should be accessible for a reasonable time)
    return jwt.sign(payload, secret, { expiresIn: '30d' });
  }

  /**
   * Verify and decode report token
   * @param {String} token - JWT token
   * @returns {Object} Decoded token payload
   * @throws {Error} If token is invalid or expired
   */
  verifyReportToken(token) {
    const secret = this.getSecret();
    console.log("secret for verifying token", secret);
    
    if (!secret) {
      throw new Error('REPORT_SECRET or JWT_SECRET must be configured in environment variables');
    }

    try {
      const decoded = jwt.verify(token, secret);
      return decoded;
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw new Error('Report link has expired. Please request a new report.');
      } else if (error.name === 'JsonWebTokenError') {
        throw new Error('Invalid report link. Please check the URL.');
      } else {
        throw new Error(`Token verification failed: ${error.message}`);
      }
    }
  }

  /**
   * Extract report information from token
   * @param {String} token - JWT token
   * @returns {Object} Report metadata
   */
  extractReportInfo(token) {
    const decoded = this.verifyReportToken(token);
    console.log("decoded", decoded);
    
    return {
      recipientId: decoded.recipientId,
      buildingId: decoded.buildingId,
      reportingId: decoded.reportingId,
      timeRange: {
        startDate: new Date(decoded.startDate),
        endDate: new Date(decoded.endDate),
      },
      generatedAt: new Date(decoded.generatedAt),
      interval: decoded.interval,
    };
  }
}

module.exports = new ReportTokenService();
