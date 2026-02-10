const buildingService = require('../services/buildingService');
const buildingContactService = require('../services/buildingContactService');
const ActivityLog = require('../models/ActivityLog');
const Building = require('../models/Building');
const Site = require('../models/Site');
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
  const userId = req.user._id;

  if (!buildingNames || !Array.isArray(buildingNames)) {
    return res.status(400).json({
      success: false,
      error: 'buildingNames array is required'
    });
  }

  const result = await buildingService.createBuildings(siteId, buildingNames, userId);

  // Log activity for each building created
  try {
    for (const building of result.buildings) {
      await ActivityLog.create({
        bryteswitch_id: result.site.bryteswitch_id,
        user_id: userId,
        action: 'create',
        resource_type: 'building',
        resource_id: building._id,
        timestamp: new Date(),
        details: {
          building_name: building.name,
          site_id: siteId,
          site_name: result.site.name,
          action: 'building_created'
        },
        severity: 'low',
      });
    }
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.status(201).json({
    success: true,
    message: `Created ${result.buildings.length} building(s)`,
    data: result.buildings
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
  // Can be array of:
  // 1. String IDs: "696f21f9d8e3e4af1f137463"
  // 2. Objects with id field: { id: "696f21f9d8e3e4af1f137463", reportConfig: [...] }
  // 3. Full recipient objects: { name, email, phone?, reportConfig? }
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
        // Valid - it's an ID reference (existing recipient without config)
      } else if (typeof recipient === 'object' && recipient !== null) {
        // Check if it's an object with id field (existing recipient with optional config)
        if (recipient.id !== undefined) {
          // Validate id is a string
          if (typeof recipient.id !== 'string') {
            return res.status(400).json({
              success: false,
              error: 'id field in reportingRecipients must be a string'
            });
          }
          
          // Validate reportConfig if provided
          if (recipient.reportConfig !== undefined) {
            const error = validateReportConfigsArray(recipient.reportConfig, 'reportConfig in reportingRecipients');
            if (error) {
              return res.status(400).json(error);
            }
          }
        } else if (recipient.email !== undefined) {
          // It's a full recipient object (new recipient)
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
            error: 'Each item in reportingRecipients must be either a string ID, an object with id field (and optional reportConfig), or an object with name, email, optional phone, and optional reportConfig array'
          });
        }
      } else {
        return res.status(400).json({
          success: false,
          error: 'Each item in reportingRecipients must be either a string ID, an object with id field (and optional reportConfig), or an object with name, email, optional phone, and optional reportConfig array'
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

  const userId = req.user._id;
  const building = await buildingService.updateBuilding(buildingId, filteredData, userId);

  // Get site for activity log
  const site = await Site.findById(building.site_id);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'update',
      resource_type: 'building',
      resource_id: buildingId,
      timestamp: new Date(),
      details: {
        building_name: building.name,
        updated_fields: Object.keys(filteredData),
        action: 'building_updated'
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Building updated successfully',
    data: building
  });
});

/**
 * PATCH /api/v1/buildings/:buildingId/loxone-config
 * Update Loxone configuration for a building
 * This endpoint handles disconnect/reconnect and structure file management
 */
exports.updateLoxoneConfig = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const loxoneConfig = req.body;
  const userId = req.user._id;

  // Validate required fields for Loxone config
  const loxoneFields = ['ip', 'port', 'user', 'pass', 'serialNumber'];
  const providedFields = Object.keys(loxoneConfig);
  const hasRequiredFields = loxoneFields.some(field => 
    loxoneConfig[field] !== undefined || 
    loxoneConfig[`miniserver_${field === 'serialNumber' ? 'serial' : field}`] !== undefined
  );

  if (!hasRequiredFields) {
    return res.status(400).json({
      success: false,
      error: 'At least one Loxone configuration field is required (ip, port, user, pass, or serialNumber)'
    });
  }

  const result = await buildingService.updateLoxoneConfig(buildingId, loxoneConfig, userId);

  // Get site for activity log
  const site = await Site.findById(result.building.site_id);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'update',
      resource_type: 'building',
      resource_id: buildingId,
      timestamp: new Date(),
      details: {
        building_name: result.building.name,
        action: 'loxone_config_updated',
        loxone_fields_updated: Object.keys(loxoneConfig),
        connection_success: result.connectionResult ? result.connectionResult.success : false,
        serial_changed: loxoneConfig.serialNumber !== undefined || loxoneConfig.miniserver_serial !== undefined
      },
      severity: 'medium',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  if (result.connectionResult && result.connectionResult.success === false) {
    // Config updated but reconnection failed
    return res.status(200).json({
      success: true,
      message: 'Loxone configuration updated, but reconnection failed',
      warning: result.connectionResult.message,
      data: {
        building: result.building,
        connectionResult: result.connectionResult
      }
    });
  }

  res.json({
    success: true,
    message: 'Loxone configuration updated and reconnected successfully',
    data: {
      building: result.building,
      connectionResult: result.connectionResult
    }
  });
});

/**
 * DELETE /api/v1/buildings/:buildingId
 * Delete a building and all related data (hard delete with cascade)
 */
exports.deleteBuilding = asyncHandler(async (req, res) => {
  const { buildingId } = req.params;
  const userId = req.user._id;

  // Get building info before deletion for activity log
  const building = await Building.findById(buildingId).populate('site_id');
  
  if (!building) {
    return res.status(404).json({
      success: false,
      error: 'Building not found'
    });
  }

  const deletionSummary = await buildingService.deleteBuilding(buildingId, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: building.site_id.bryteswitch_id,
      user_id: userId,
      action: 'delete',
      resource_type: 'building',
      resource_id: buildingId,
      timestamp: new Date(),
      details: {
        building_name: deletionSummary.buildingName,
        site_id: building.site_id._id,
        site_name: building.site_id.name,
        action: 'building_deleted',
        deleted_items: deletionSummary.deletedItems
      },
      severity: 'medium',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
    // Don't fail the request if logging fails
  }

  res.json({
    success: true,
    message: 'Building deleted successfully',
    data: deletionSummary
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
