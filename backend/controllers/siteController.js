const siteService = require('../services/siteService');
const ActivityLog = require('../models/ActivityLog');
const { asyncHandler } = require('../middleware/errorHandler');
const { validationResult } = require('express-validator');

/**
 * Create a site for a BryteSwitch
 * POST /api/v1/sites/bryteswitch/:bryteswitchId
 */
exports.createSite = asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ 
      success: false,
      errors: errors.array() 
    });
  }

  const { bryteswitchId } = req.params;
  const { name, address, resource_type } = req.body;
  const userId = req.user._id;

  const site = await siteService.createSite(
    bryteswitchId,
    { name, address, resource_type },
    userId
  );

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: bryteswitchId,
      user_id: userId,
      action: 'create',
      resource_type: 'site',
      resource_id: site._id,
      timestamp: new Date(),
      details: {
        site_name: site.name,
        address: site.address,
        resource_type: site.resource_type,
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
  }

  res.status(201).json({
    success: true,
    message: 'Site created successfully',
    data: site
  });
});

/**
 * Get all sites for a BryteSwitch
 * GET /api/v1/sites/bryteswitch/:bryteswitchId
 */
exports.getSitesByBryteSwitch = asyncHandler(async (req, res) => {
  const { bryteswitchId } = req.params;
  const userId = req.user._id;

  const sites = await siteService.getSitesByBryteSwitch(bryteswitchId, userId);

  res.json({
    success: true,
    data: sites
  });
});

/**
 * Get site by ID
 * GET /api/v1/sites/:siteId
 */
exports.getSiteById = asyncHandler(async (req, res) => {
  const { siteId } = req.params;
  const userId = req.user._id;

  const site = await siteService.getSiteById(siteId, userId);

  res.json({
    success: true,
    data: site
  });
});

/**
 * Update site
 * PATCH /api/v1/sites/:siteId
 */
exports.updateSite = asyncHandler(async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ 
      success: false,
      errors: errors.array() 
    });
  }

  const { siteId } = req.params;
  const updateData = req.body;
  const userId = req.user._id;

  const site = await siteService.updateSite(siteId, updateData, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'update',
      resource_type: 'site',
      resource_id: site._id,
      timestamp: new Date(),
      details: {
        updated_fields: Object.keys(updateData),
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
  }

  res.json({
    success: true,
    message: 'Site updated successfully',
    data: site
  });
});

/**
 * Delete site
 * DELETE /api/v1/sites/:siteId
 */
exports.deleteSite = asyncHandler(async (req, res) => {
  const { siteId } = req.params;
  const userId = req.user._id;

  const site = await siteService.getSiteById(siteId, userId);
  
  await siteService.deleteSite(siteId, userId);

  // Log activity
  try {
    await ActivityLog.create({
      bryteswitch_id: site.bryteswitch_id,
      user_id: userId,
      action: 'delete',
      resource_type: 'site',
      resource_id: siteId,
      timestamp: new Date(),
      details: {
        site_name: site.name,
      },
      severity: 'low',
    });
  } catch (logError) {
    console.error('Failed to log activity:', logError);
  }

  res.json({
    success: true,
    message: 'Site deleted successfully'
  });
});

