const ReportingRecipient = require('../models/ReportingRecipient');
const Reporting = require('../models/Reporting');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
const Building = require('../models/Building');
const mongoose = require('mongoose');

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

      const validReportContents = [
        'TotalConsumption',
        'ConsumptionByRoom',
        'PeakLoads',
        'MeasurementTypeBreakdown',
        'EUI',
        'PerCapitaConsumption',
        'BenchmarkComparison',
        'InefficientUsage',
        'Anomalies',
        'PeriodComparison',
        'TimeBasedAnalysis',
        'BuildingComparison',
        'TemperatureAnalysis',
        'DataQualityReport'
      ];
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
    // Validate all entities in parallel (optimized)
    const [building, recipient, reporting] = await Promise.all([
      Building.findById(buildingId),
      ReportingRecipient.findById(recipientId),
      Reporting.findById(reportingId),
    ]);

    if (!building) {
      throw new Error(`Building with ID ${buildingId} not found`);
    }
    if (!recipient) {
      throw new Error(`ReportingRecipient with ID ${recipientId} not found`);
    }
    if (!reporting) {
      throw new Error(`Reporting with ID ${reportingId} not found`);
    }

    // Use findOneAndUpdate with upsert for atomic operation (optimized)
    // This avoids race conditions and reduces database round-trips
    const assignment = await BuildingReportingAssignment.findOneAndUpdate(
      {
        building_id: buildingId,
        recipient_id: recipientId,
        reporting_id: reportingId,
      },
      {
        building_id: buildingId,
        recipient_id: recipientId,
        reporting_id: reportingId,
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    );

    return assignment;
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

  /**
   * Get all reporting recipients with optional filtering
   * @param {Object} filters - Filter options
   * @param {String} filters.site_id - Optional site ID to filter by
   * @param {String} filters.building_id - Optional building ID to filter by
   * @returns {Promise<Array>} Array of recipient documents
   */
  async getRecipients(filters = {}) {
    const { site_id, building_id } = filters;

    // If no filters, return all active recipients by default
    if (!site_id && !building_id) {
      return await ReportingRecipient.find({ is_active: true })
        .sort({ email: 1 })
        .lean();
    }

    // Build query to find relevant buildings
    const buildingQuery = {};
    
    if (building_id) {
      if (!mongoose.Types.ObjectId.isValid(building_id)) {
        throw new Error(`Invalid building_id: ${building_id}`);
      }
      buildingQuery._id = new mongoose.Types.ObjectId(building_id);
    }
    
    if (site_id) {
      if (!mongoose.Types.ObjectId.isValid(site_id)) {
        throw new Error(`Invalid site_id: ${site_id}`);
      }
      buildingQuery.site_id = new mongoose.Types.ObjectId(site_id);
    }

    // Find buildings matching the criteria
    const buildings = await Building.find(buildingQuery)
      .select('_id')
      .lean();

    const buildingIds = buildings.map(b => b._id);

    // If no buildings found, return empty array
    if (buildingIds.length === 0) {
      return [];
    }

    // Find assignments for these buildings
    const assignments = await BuildingReportingAssignment.find({
      building_id: { $in: buildingIds }
    })
      .select('recipient_id')
      .lean();

    // Extract unique recipient IDs
    const recipientIds = [...new Set(
      assignments
        .map(a => a.recipient_id)
        .filter(id => id !== null && id !== undefined)
    )];

    // If no recipients found, return empty array
    if (recipientIds.length === 0) {
      return [];
    }

    // Return recipients matching the IDs (only active ones)
    return await ReportingRecipient.find({
      _id: { $in: recipientIds },
      is_active: true
    }).sort({ email: 1 }).lean();
  }
}

module.exports = new ReportingService();
