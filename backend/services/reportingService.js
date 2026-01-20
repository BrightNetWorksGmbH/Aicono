const ReportingRecipient = require('../models/ReportingRecipient');
const Reporting = require('../models/Reporting');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
const Building = require('../models/Building');

class ReportingService {
  /**
   * Resolve recipient input - either create new recipient or return existing ID
   * @param {Object|String} input - Recipient object {name, email, phone?} or recipient ID string
   * @returns {Promise<String>} ReportingRecipient ID
   */
  async resolveRecipient(input) {
    if (!input) {
      return null;
    }

    // If input is a string, treat it as an ID
    if (typeof input === 'string') {
      const recipient = await ReportingRecipient.findById(input);
      if (!recipient) {
        throw new Error(`ReportingRecipient with ID ${input} not found`);
      }
      return recipient._id.toString();
    }

    // If input is an object, validate and create/find recipient
    if (typeof input !== 'object' || input === null) {
      throw new Error('Recipient must be either a string ID or an object with name, email, and optional phone');
    }

    const { name, email, phone } = input;

    if (!email) {
      throw new Error('Email is required for recipient');
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error('Invalid email format in recipient');
    }

    // Try to find existing recipient by email
    let recipient = await ReportingRecipient.findOne({ email: email.toLowerCase().trim() });

    if (recipient) {
      // Update recipient if new data provided
      if (name !== undefined) recipient.name = name;
      if (phone !== undefined) recipient.phone = phone;
      await recipient.save();
      return recipient._id.toString();
    }

    // Create new recipient
    try {
      recipient = await ReportingRecipient.create({
        name,
        email: email.toLowerCase().trim(),
        phone,
      });
      return recipient._id.toString();
    } catch (error) {
      if (error.code === 11000) {
        // Duplicate key error - email already exists
        recipient = await ReportingRecipient.findOne({ email: email.toLowerCase().trim() });
        if (recipient) {
          // Update existing recipient
          if (name !== undefined) recipient.name = name;
          if (phone !== undefined) recipient.phone = phone;
          await recipient.save();
          return recipient._id.toString();
        }
      }
      throw error;
    }
  }

  /**
   * Create a reporting configuration
   * @param {Object} config - Reporting config {name, interval, reportContents?}
   * @returns {Promise<Object>} Created Reporting document
   */
  async createReporting(config) {
    const { name, interval, reportContents } = config;

    if (!name) {
      throw new Error('Reporting name is required');
    }

    if (!interval) {
      throw new Error('Reporting interval is required');
    }

    // Validate interval
    const validIntervals = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
    if (!validIntervals.includes(interval)) {
      throw new Error(`Invalid interval. Must be one of: ${validIntervals.join(', ')}`);
    }

    // Validate reportContents if provided
    if (reportContents !== undefined) {
      if (!Array.isArray(reportContents)) {
        throw new Error('reportContents must be an array');
      }

      const validReportContents = ['TotalConsumption', 'ConsumptionByRoom', 'PeakLoads', 'Anomalies', 'InefficientUsage'];
      for (const content of reportContents) {
        if (!validReportContents.includes(content)) {
          throw new Error(`Invalid reportContent: ${content}. Must be one of: ${validReportContents.join(', ')}`);
        }
      }
    }

    const reporting = await Reporting.create({
      name,
      interval,
      reportContents: reportContents || [],
    });

    return reporting;
  }

  /**
   * Create or update a building reporting assignment
   * @param {String} buildingId - Building ID
   * @param {String} recipientId - ReportingRecipient ID
   * @param {String} reportingId - Reporting ID
   * @returns {Promise<Object>} Assignment document
   */
  async createOrUpdateAssignment(buildingId, recipientId, reportingId) {
    // Validate building exists
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }

    // Validate recipient exists
    const recipient = await ReportingRecipient.findById(recipientId);
    if (!recipient) {
      throw new Error(`ReportingRecipient with ID ${recipientId} not found`);
    }

    // Validate reporting exists
    const reporting = await Reporting.findById(reportingId);
    if (!reporting) {
      throw new Error(`Reporting with ID ${reportingId} not found`);
    }

    // Try to find existing assignment
    let assignment = await BuildingReportingAssignment.findOne({
      building_id: buildingId,
      recipient_id: recipientId,
      reporting_id: reportingId,
    });

    if (assignment) {
      // Assignment already exists, return it
      return assignment;
    }

    // Create new assignment
    try {
      assignment = await BuildingReportingAssignment.create({
        building_id: buildingId,
        recipient_id: recipientId,
        reporting_id: reportingId,
      });
      return assignment;
    } catch (error) {
      if (error.code === 11000) {
        // Duplicate key error - assignment already exists
        assignment = await BuildingReportingAssignment.findOne({
          building_id: buildingId,
          recipient_id: recipientId,
          reporting_id: reportingId,
        });
        return assignment;
      }
      throw error;
    }
  }

  /**
   * Get assignments for a building
   * @param {String} buildingId - Building ID
   * @returns {Promise<Array>} Array of assignment documents with populated references
   */
  async getBuildingAssignments(buildingId) {
    return await BuildingReportingAssignment.find({ building_id: buildingId })
      .populate('recipient_id')
      .populate('reporting_id')
      .exec();
  }

  /**
   * Get assignments for a recipient
   * @param {String} recipientId - ReportingRecipient ID
   * @returns {Promise<Array>} Array of assignment documents with populated references
   */
  async getRecipientAssignments(recipientId) {
    return await BuildingReportingAssignment.find({ recipient_id: recipientId })
      .populate('building_id')
      .populate('reporting_id')
      .exec();
  }
}

module.exports = new ReportingService();
