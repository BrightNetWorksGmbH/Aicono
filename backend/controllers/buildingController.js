const buildingService = require('../services/buildingService');
const buildingContactService = require('../services/buildingContactService');
const { asyncHandler } = require('../middleware/errorHandler');

// Constants for report configuration validation
const VALID_INTERVALS = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
const VALID_REPORT_CONTENTS = [
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

/**
 * Validate a single report configuration object
 * @param {Object} config - Report configuration object
 * @param {String} context - Context for error messages (e.g., 'recipient reportConfig' or 'reportConfigs')
 * @returns {Object|null} Error object if validation fails, null if valid
 */
function validateReportConfig(config, context = 'reportConfig') {
  if (typeof config !== 'object' || config === null) {
    return {
      success: false,
      error: `Each item in ${context} must be an object with name, interval, and optional reportContents`
    };
  }

  if (!config.name || typeof config.name !== 'string') {
    return {
      success: false,
      error: 'Each reportConfig must have a name (string)'
    };
  }

  if (!config.interval || !VALID_INTERVALS.includes(config.interval)) {
    return {
      success: false,
      error: `Each reportConfig must have a valid interval. Must be one of: ${VALID_INTERVALS.join(', ')}`
    };
  }

  // Validate reportContents if provided
  if (config.reportContents !== undefined) {
    if (!Array.isArray(config.reportContents)) {
      return {
        success: false,
        error: 'reportContents must be an array'
      };
    }

    // Validate each content type
    for (const content of config.reportContents) {
      if (!VALID_REPORT_CONTENTS.includes(content)) {
        return {
          success: false,
          error: `Invalid reportContent: ${content}. Must be one of: ${VALID_REPORT_CONTENTS.join(', ')}`
        };
      }
    }
  }

  return null; // Valid
}

/**
 * Validate an array of report configurations
 * @param {Array} reportConfigs - Array of report configuration objects
 * @param {String} context - Context for error messages
 * @returns {Object|null} Error object if validation fails, null if valid
 */
function validateReportConfigsArray(reportConfigs, context = 'reportConfigs') {
  if (!Array.isArray(reportConfigs)) {
    return {
      success: false,
      error: `${context} must be an array`
    };
  }

  for (const config of reportConfigs) {
    const error = validateReportConfig(config, context);
    if (error) {
      return error;
    }
  }

  return null; // Valid
}

/**
 * POST /api/buildings/site/:siteId
 * Create multiple buildings for a site
 */
exports.createBuildings = asyncHandler(async (req, res) => {
  const { siteId } = req.params;
  const { buildingNames } = req.body;

  if (!buildingNames || !Array.isArray(buildingNames)) {
    return res.status(400).json({
      success: false,
      error: 'buildingNames array is required'
    });
  }

  const buildings = await buildingService.createBuildings(siteId, buildingNames);

  res.status(201).json({
    success: true,
    message: `Created ${buildings.length} building(s)`,
    data: buildings
  });
});

/**
 * GET /api/buildings/site/:siteId
 * Get all buildings for a site
 */
exports.getBuildingsBySite = asyncHandler(async (req, res) => {
  const { siteId } = req.params;
  const buildings = await buildingService.getBuildingsBySite(siteId);

  res.json({
    success: true,
    data: buildings
  });
});

/**
 * GET /api/buildings/:buildingId
 * Get a building by ID
 */
exports.getBuildingById = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const building = await buildingService.getBuildingById(buildingId);

  res.json({
    success: true,
    data: building
  });
});

/**
 * PATCH /api/buildings/:buildingId
 * Update building details
 */
exports.updateBuilding = asyncHandler(async (req, res) => {
  // console.log('updateBuilding', req.body);
  const { buildingId } = req.params;
  const updateData = req.body;

  // Allowed fields for update
  const allowedFields = [
    'name',
    'building_size',
    'num_floors',
    'year_of_construction',
    'heated_building_area',
    'type_of_use',
    'num_students_employees',
    'buildingContact',
    'reportingRecipients',
    'reportConfigs'
  ];

  // Filter only allowed fields
  const filteredData = {};
  for (const field of allowedFields) {
    if (updateData[field] !== undefined) {
      filteredData[field] = updateData[field];
    }
  }

  // Validate buildingContact structure if provided
  // Can be either a string ID or an object with name, email, and optional phone
  if (filteredData.buildingContact !== undefined) {
    const contact = filteredData.buildingContact;
    if (typeof contact === 'string') {
      // Valid - it's an ID reference
    } else if (typeof contact === 'object' && contact !== null) {
      // Validate object structure
      if (contact.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact.email)) {
        return res.status(400).json({
          success: false,
          error: 'Invalid email format in buildingContact'
        });
      }
    } else {
      return res.status(400).json({
        success: false,
        error: 'buildingContact must be either a string ID or an object with name, email, and optional phone'
      });
    }
  }

  // Validate reportingRecipients if provided
  // Can be array of objects (with optional reportConfig) or array of string IDs
  if (filteredData.reportingRecipients !== undefined) {
    if (!Array.isArray(filteredData.reportingRecipients)) {
      return res.status(400).json({
        success: false,
        error: 'reportingRecipients must be an array'
      });
    }
    
    // Validate each item in array
    for (const recipient of filteredData.reportingRecipients) {
      if (typeof recipient === 'string') {
        // Valid - it's an ID reference
      } else if (typeof recipient === 'object' && recipient !== null) {
        // Validate email format if provided
        if (recipient.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient.email)) {
          return res.status(400).json({
            success: false,
            error: 'Invalid email format in reportingRecipients'
          });
        }
        
        // Validate reportConfig if provided (recipient-specific configs)
        if (recipient.reportConfig !== undefined) {
          const error = validateReportConfigsArray(recipient.reportConfig, 'reportConfig in reportingRecipients');
          if (error) {
            return res.status(400).json(error);
          }
        }
      } else {
        return res.status(400).json({
          success: false,
          error: 'Each item in reportingRecipients must be either a string ID or an object with name, email, optional phone, and optional reportConfig array'
        });
      }
    }
  }

  // Validate reportConfigs if provided (general templates that apply to all recipients)
  if (filteredData.reportConfigs !== undefined) {
    const error = validateReportConfigsArray(filteredData.reportConfigs, 'reportConfigs');
    if (error) {
      return res.status(400).json(error);
    }
  }

  const building = await buildingService.updateBuilding(buildingId, filteredData);

  res.json({
    success: true,
    message: 'Building updated successfully',
    data: building
  });
});

/**
 * GET /api/v1/buildings/contacts
 * Get all building contacts with optional filtering
 * Query parameters:
 * - site_id (optional): Filter contacts by site ID
 * - building_id (optional): Filter contacts by building ID
 */
exports.getContacts = asyncHandler(async (req, res) => {
  const { site_id, building_id } = req.query;

  const filters = {};
  if (site_id) filters.site_id = site_id;
  if (building_id) filters.building_id = building_id;

  const contacts = await buildingContactService.getContacts(filters);

  res.json({
    success: true,
    data: contacts,
    count: contacts.length
  });
});
