const Site = require('../models/Site');
const Building = require('../models/Building');
const BuildingReportingAssignment = require('../models/BuildingReportingAssignment');
const Reporting = require('../models/Reporting');
const ReportingRecipient = require('../models/ReportingRecipient');
const UserRole = require('../models/UserRole');
const User = require('../models/User');
const dashboardDiscoveryService = require('./dashboardDiscoveryService');

/**
 * Dashboard Reports Service
 * 
 * Provides hierarchical data retrieval for the "Your Reports" dashboard section:
 * Sites → Buildings → Reports
 */
class DashboardReportsService {
  /**
   * Get all sites with reports for a user
   * @param {String} userId - User ID
   * @param {String} bryteswitchId - Optional BryteSwitch ID to filter by
   * @returns {Promise<Array>} Sites array with building/report counts
   */
  async getSitesWithReports(userId, bryteswitchId = null) {
    // Get user's accessible sites (reuse existing logic from dashboardDiscoveryService)
    const sites = await dashboardDiscoveryService.getSites(userId, bryteswitchId);
    
    // Get building counts and report counts for each site
    const siteIds = sites.map(s => s._id);
    
    // Get all buildings for these sites
    const buildings = await Building.find({ site_id: { $in: siteIds } })
      .select('_id site_id name')
      .lean();
    
    // Get all assignments for these buildings
    const buildingIds = buildings.map(b => b._id);
    const assignments = await BuildingReportingAssignment.find({
      building_id: { $in: buildingIds }
    })
      .select('building_id reporting_id')
      .lean();
    
    // Count reports per site
    const siteReportCounts = new Map();
    const siteBuildingCounts = new Map();
    
    buildings.forEach(building => {
      const siteId = building.site_id.toString();
      siteBuildingCounts.set(siteId, (siteBuildingCounts.get(siteId) || 0) + 1);
    });
    
    assignments.forEach(assignment => {
      const buildingId = assignment.building_id.toString();
      const building = buildings.find(b => b._id.toString() === buildingId);
      if (building) {
        const siteId = building.site_id.toString();
        siteReportCounts.set(siteId, (siteReportCounts.get(siteId) || 0) + 1);
      }
    });
    
    // Add counts to sites
    return sites.map(site => ({
      _id: site._id,
      name: site.name,
      address: site.address,
      resource_type: site.resource_type,
      bryteswitch_id: site.bryteswitch_id,
      building_count: siteBuildingCounts.get(site._id.toString()) || 0,
      report_count: siteReportCounts.get(site._id.toString()) || 0,
      created_at: site.created_at,
      updated_at: site.updated_at
    }));
  }

  /**
   * Get buildings in a site with their reports
   * @param {String} siteId - Site ID
   * @param {String} userId - User ID (for access verification)
   * @returns {Promise<Array>} Buildings array with report counts
   */
  async getBuildingsWithReports(siteId, userId) {
    // Verify access
    const site = await Site.findById(siteId).populate('bryteswitch_id', 'organization_name');
    if (!site) {
      throw new Error('Site not found');
    }
    
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: site.bryteswitch_id._id || site.bryteswitch_id
    });
    
    if (!userRole) {
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        throw new Error('You do not have access to this site');
      }
    }
    
    // Get buildings in this site
    const buildings = await Building.find({ site_id: siteId })
      .select('_id name site_id')
      .sort({ name: 1 })
      .lean();
    
    const buildingIds = buildings.map(b => b._id);
    
    // Get assignments for these buildings
    const assignments = await BuildingReportingAssignment.find({
      building_id: { $in: buildingIds }
    })
      .select('building_id reporting_id')
      .lean();
    
    // Count reports per building
    const buildingReportCounts = new Map();
    assignments.forEach(assignment => {
      const buildingId = assignment.building_id.toString();
      buildingReportCounts.set(buildingId, (buildingReportCounts.get(buildingId) || 0) + 1);
    });
    
    // Add counts to buildings
    return buildings.map(building => ({
      _id: building._id,
      name: building.name,
      siteId: building.site_id,
      report_count: buildingReportCounts.get(building._id.toString()) || 0,
    }));
  }

  /**
   * Get all reports for a building, grouped by report name with recipients
   * @param {String} buildingId - Building ID
   * @param {String} userId - User ID (for access verification)
   * @returns {Promise<Array>} Reports array grouped by reporting_id
   */
  async getBuildingReports(buildingId, userId) {
    // Verify access
    const building = await Building.findById(buildingId).populate('site_id');
    if (!building) {
      throw new Error('Building not found');
    }
    
    const site = await Site.findById(building.site_id._id || building.site_id);
    if (!site) {
      throw new Error('Site not found');
    }
    
    const userRole = await UserRole.findOne({
      user_id: userId,
      bryteswitch_id: site.bryteswitch_id
    });
    
    if (!userRole) {
      const user = await User.findById(userId);
      if (!user || !user.is_superadmin) {
        throw new Error('You do not have access to this building');
      }
    }
    
    // Get all assignments for this building
    const assignments = await BuildingReportingAssignment.find({ building_id: buildingId })
      .populate('reporting_id', 'name interval reportContents')
      .populate('recipient_id', 'name email')
      .lean();
    
    // Group assignments by reporting_id
    const reportMap = new Map();
    
    assignments.forEach(assignment => {
      const reportingId = assignment.reporting_id._id.toString();
      
      if (!reportMap.has(reportingId)) {
        reportMap.set(reportingId, {
          reportId: reportingId,
          reportName: assignment.reporting_id.name,
          interval: assignment.reporting_id.interval,
          buildingId: buildingId,
          buildingName: building.name,
          recipients: []
        });
      }
      
      const report = reportMap.get(reportingId);
      report.recipients.push({
        recipientId: assignment.recipient_id._id.toString(),
        recipientName: assignment.recipient_id.name || assignment.recipient_id.email.split('@')[0],
        recipientEmail: assignment.recipient_id.email
      });
    });
    
    // Convert map to array and sort by report name
    return Array.from(reportMap.values()).sort((a, b) => 
      a.reportName.localeCompare(b.reportName)
    );
  }
}

module.exports = new DashboardReportsService();
