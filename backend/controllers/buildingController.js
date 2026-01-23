const buildingService = require('../services/buildingService');
const buildingContactService = require('../services/buildingContactService');
const { asyncHandler } = require('../middleware/errorHandler');

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
  console.log('updateBuilding', req.body);
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
  // Can be array of objects or array of string IDs
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
        // Validate object structure
        if (recipient.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient.email)) {
          return res.status(400).json({
            success: false,
            error: 'Invalid email format in reportingRecipients'
          });
        }
      } else {
        return res.status(400).json({
          success: false,
          error: 'Each item in reportingRecipients must be either a string ID or an object with name, email, and optional phone'
        });
      }
    }
  }

  // Validate reportConfigs if provided
  if (filteredData.reportConfigs !== undefined) {
    if (!Array.isArray(filteredData.reportConfigs)) {
      return res.status(400).json({
        success: false,
        error: 'reportConfigs must be an array'
      });
    }

    // Validate each config
    const validIntervals = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
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
    
    for (const config of filteredData.reportConfigs) {
      if (typeof config !== 'object' || config === null) {
        return res.status(400).json({
          success: false,
          error: 'Each item in reportConfigs must be an object with name, interval, and optional reportContents'
        });
      }

      if (!config.name || typeof config.name !== 'string') {
        return res.status(400).json({
          success: false,
          error: 'Each reportConfig must have a name (string)'
        });
      }

      if (!config.interval || !validIntervals.includes(config.interval)) {
        return res.status(400).json({
          success: false,
          error: `Each reportConfig must have a valid interval. Must be one of: ${validIntervals.join(', ')}`
        });
      }

      // Validate reportContents if provided
      if (config.reportContents !== undefined) {
        if (!Array.isArray(config.reportContents)) {
          return res.status(400).json({
            success: false,
            error: 'reportContents must be an array'
          });
        }

        // Validate each content type
        for (const content of config.reportContents) {
          if (!validReportContents.includes(content)) {
            return res.status(400).json({
              success: false,
              error: `Invalid reportContent: ${content}. Must be one of: ${validReportContents.join(', ')}`
            });
          }
        }
      }
    }

    // Validate that reportingRecipients and reportConfigs are provided together and have same length
    if (filteredData.reportingRecipients === undefined) {
      return res.status(400).json({
        success: false,
        error: 'reportingRecipients must be provided when reportConfigs is provided'
      });
    }

    if (filteredData.reportingRecipients.length !== filteredData.reportConfigs.length) {
      return res.status(400).json({
        success: false,
        error: 'reportingRecipients and reportConfigs arrays must have the same length'
      });
    }
  }

  // Validate that if reportingRecipients is provided, reportConfigs must also be provided
  if (filteredData.reportingRecipients !== undefined && filteredData.reportConfigs === undefined) {
    return res.status(400).json({
      success: false,
      error: 'reportConfigs must be provided when reportingRecipients is provided'
    });
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
