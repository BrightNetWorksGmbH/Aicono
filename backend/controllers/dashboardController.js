const dashboardDiscoveryService = require('../services/dashboardDiscoveryService');
const { asyncHandler } = require('../middleware/errorHandler');

/**
 * Get all sites for the authenticated user
 * GET /api/v1/dashboard/sites
 * 
 * Query parameters:
 * - bryteswitch_id (optional): Filter by bryteswitch ID
 */
exports.getSites = asyncHandler(async (req, res) => {
    const userId = req.user._id;
    const { bryteswitch_id } = req.query;
    
    const sites = await dashboardDiscoveryService.getSites(userId, bryteswitch_id || null);
    
    res.json({
        success: true,
        data: sites,
        count: sites.length
    });
});

/**
 * Get site details with full hierarchy
 * GET /api/v1/dashboard/sites/:siteId
 * 
 * Query parameters:
 * - startDate (optional): Start date for time range (ISO 8601 format)
 * - endDate (optional): End date for time range (ISO 8601 format)
 * - days (optional): Number of days to look back (default: 7)
 * - resolution (optional): Override automatic resolution (0, 15, 60, 1440, 10080, 43200)
 * - measurementType (optional): Filter by measurement type (e.g., 'Energy', 'Temperature')
 * - includeMeasurements (optional): Include measurement data (default: true)
 * - limit (optional): Limit number of measurements (default: 1000)
 */
exports.getSiteDetails = asyncHandler(async (req, res) => {
    const { siteId } = req.params;
    const userId = req.user._id;
    const {
        startDate,
        endDate,
        days,
        resolution,
        measurementType,
        includeMeasurements,
        limit
    } = req.query;
    
    const options = {
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        days: days ? parseInt(days, 10) : undefined,
        resolution: resolution ? parseInt(resolution, 10) : undefined,
        measurementType: measurementType || undefined,
        includeMeasurements: includeMeasurements !== 'false',
        limit: limit ? parseInt(limit, 10) : undefined
    };
    
    const siteDetails = await dashboardDiscoveryService.getSiteDetails(siteId, userId, options);
    
    res.json({
        success: true,
        data: siteDetails
    });
});

/**
 * Get building details with nested data
 * GET /api/v1/dashboard/buildings/:buildingId
 * 
 * Query parameters:
 * - startDate (optional): Start date for time range (ISO 8601 format)
 * - endDate (optional): End date for time range (ISO 8601 format)
 * - days (optional): Number of days to look back (default: 7)
 * - resolution (optional): Override automatic resolution (0, 15, 60, 1440, 10080, 43200)
 * - measurementType (optional): Filter by measurement type
 * - includeMeasurements (optional): Include measurement data (default: true)
 * - limit (optional): Limit number of measurements
 */
exports.getBuildingDetails = asyncHandler(async (req, res) => {
    const { buildingId } = req.params;
    const userId = req.user._id;
    const {
        startDate,
        endDate,
        days,
        resolution,
        measurementType,
        includeMeasurements,
        limit
    } = req.query;
    
    const options = {
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        days: days ? parseInt(days, 10) : undefined,
        resolution: resolution ? parseInt(resolution, 10) : undefined,
        measurementType: measurementType || undefined,
        includeMeasurements: includeMeasurements !== 'false',
        limit: limit ? parseInt(limit, 10) : undefined
    };
    
    const buildingDetails = await dashboardDiscoveryService.getBuildingDetails(
        buildingId,
        userId,
        options
    );
    
    res.json({
        success: true,
        data: buildingDetails
    });
});

/**
 * Get floor details with nested data
 * GET /api/v1/dashboard/floors/:floorId
 * 
 * Query parameters:
 * - startDate (optional): Start date for time range (ISO 8601 format)
 * - endDate (optional): End date for time range (ISO 8601 format)
 * - days (optional): Number of days to look back (default: 7)
 * - resolution (optional): Override automatic resolution
 * - measurementType (optional): Filter by measurement type
 * - includeMeasurements (optional): Include measurement data (default: true)
 * - limit (optional): Limit number of measurements
 */
exports.getFloorDetails = asyncHandler(async (req, res) => {
    const { floorId } = req.params;
    const userId = req.user._id;
    const {
        startDate,
        endDate,
        days,
        resolution,
        measurementType,
        includeMeasurements,
        limit
    } = req.query;
    
    const options = {
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        days: days ? parseInt(days, 10) : undefined,
        resolution: resolution ? parseInt(resolution, 10) : undefined,
        measurementType: measurementType || undefined,
        includeMeasurements: includeMeasurements !== 'false',
        limit: limit ? parseInt(limit, 10) : undefined
    };
    
    const floorDetails = await dashboardDiscoveryService.getFloorDetails(
        floorId,
        userId,
        options
    );
    
    res.json({
        success: true,
        data: floorDetails
    });
});

/**
 * Get room details with nested data
 * GET /api/v1/dashboard/rooms/:roomId
 * 
 * Query parameters:
 * - startDate (optional): Start date for time range (ISO 8601 format)
 * - endDate (optional): End date for time range (ISO 8601 format)
 * - days (optional): Number of days to look back (default: 7)
 * - resolution (optional): Override automatic resolution
 * - measurementType (optional): Filter by measurement type
 * - includeMeasurements (optional): Include measurement data (default: true)
 * - limit (optional): Limit number of measurements
 */
exports.getRoomDetails = asyncHandler(async (req, res) => {
    const { roomId } = req.params;
    const userId = req.user._id;
    const {
        startDate,
        endDate,
        days,
        resolution,
        measurementType,
        includeMeasurements,
        limit
    } = req.query;
    
    const options = {
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        days: days ? parseInt(days, 10) : undefined,
        resolution: resolution ? parseInt(resolution, 10) : undefined,
        measurementType: measurementType || undefined,
        includeMeasurements: includeMeasurements !== 'false',
        limit: limit ? parseInt(limit, 10) : undefined
    };
    
    const roomDetails = await dashboardDiscoveryService.getRoomDetails(
        roomId,
        userId,
        options
    );
    
    res.json({
        success: true,
        data: roomDetails
    });
});

/**
 * Get sensor details with measurement data
 * GET /api/v1/dashboard/sensors/:sensorId
 * 
 * Query parameters:
 * - startDate (optional): Start date for time range (ISO 8601 format)
 * - endDate (optional): End date for time range (ISO 8601 format)
 * - days (optional): Number of days to look back (default: 7)
 * - resolution (optional): Override automatic resolution
 * - measurementType (optional): Filter by measurement type
 * - includeMeasurements (optional): Include measurement data (default: true)
 * - limit (optional): Limit number of measurements (default: 1000)
 * - skip (optional): Skip number of measurements (for pagination)
 */
exports.getSensorDetails = asyncHandler(async (req, res) => {
    const { sensorId } = req.params;
    const userId = req.user._id;
    const {
        startDate,
        endDate,
        days,
        resolution,
        measurementType,
        includeMeasurements,
        limit,
        skip
    } = req.query;
    
    const options = {
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        days: days ? parseInt(days, 10) : undefined,
        resolution: resolution ? parseInt(resolution, 10) : undefined,
        measurementType: measurementType || undefined,
        includeMeasurements: includeMeasurements !== 'false',
        limit: limit ? parseInt(limit, 10) : undefined,
        skip: skip ? parseInt(skip, 10) : undefined
    };
    
    const sensorDetails = await dashboardDiscoveryService.getSensorDetails(
        sensorId,
        userId,
        options
    );
    
    res.json({
        success: true,
        data: sensorDetails
    });
});

