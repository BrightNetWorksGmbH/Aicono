const buildingService = require('../services/buildingService');
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
    'num_students_employees'
  ];

  // Filter only allowed fields
  const filteredData = {};
  for (const field of allowedFields) {
    if (updateData[field] !== undefined) {
      filteredData[field] = updateData[field];
    }
  }

  const building = await buildingService.updateBuilding(buildingId, filteredData);

  res.json({
    success: true,
    message: 'Building updated successfully',
    data: building
  });
});

