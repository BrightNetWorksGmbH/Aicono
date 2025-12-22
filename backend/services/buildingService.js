const Building = require('../models/Building');

class BuildingService {
  /**
   * Create multiple buildings for a site
   * @param {String} siteId - Site ID
   * @param {Array<String>} buildingNames - Array of building names
   * @returns {Promise<Array>} Created buildings
   */
  async createBuildings(siteId, buildingNames) {
    if (!buildingNames || !Array.isArray(buildingNames) || buildingNames.length === 0) {
      throw new Error('Building names array is required');
    }

    // Check for duplicate names within the request
    const uniqueNames = [...new Set(buildingNames)];
    if (uniqueNames.length !== buildingNames.length) {
      throw new Error('Duplicate building names are not allowed');
    }

    // Check for existing buildings with same names in this site
    const existingBuildings = await Building.find({
      site_id: siteId,
      name: { $in: buildingNames }
    });

    if (existingBuildings.length > 0) {
      const existingNames = existingBuildings.map(b => b.name);
      throw new Error(`Buildings with these names already exist: ${existingNames.join(', ')}`);
    }

    // Create buildings
    const buildingsToCreate = buildingNames.map(name => ({
      site_id: siteId,
      name: name.trim(),
    }));

    const createdBuildings = await Building.insertMany(buildingsToCreate);
    return createdBuildings;
  }

  /**
   * Get all buildings for a site
   * @param {String} siteId - Site ID
   * @returns {Promise<Array>} Buildings
   */
  async getBuildingsBySite(siteId) {
    return await Building.find({ site_id: siteId }).sort({ name: 1 });
  }

  /**
   * Get a building by ID
   * @param {String} buildingId - Building ID
   * @returns {Promise<Object>} Building
   */
  async getBuildingById(buildingId) {
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error('Building not found');
    }
    return building;
  }

  /**
   * Update building details
   * @param {String} buildingId - Building ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated building
   */
  async updateBuilding(buildingId, updateData) {
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new Error('Building not found');
    }

    // If name is being updated, check for duplicates
    if (updateData.name && updateData.name !== building.name) {
      const existing = await Building.findOne({
        site_id: building.site_id,
        name: updateData.name,
        _id: { $ne: buildingId }
      });
      if (existing) {
        throw new Error(`A building with the name "${updateData.name}" already exists in this site`);
      }
    }

    // Update building
    Object.assign(building, updateData);
    await building.save();
    return building;
  }

  /**
   * Update Loxone connection info
   * @param {String} buildingId - Building ID
   * @param {Object} loxoneConfig - Loxone configuration
   * @returns {Promise<Object>} Updated building
   */
  async updateLoxoneConfig(buildingId, loxoneConfig) {
    const updateData = {
      miniserver_ip: loxoneConfig.ip,
      miniserver_port: loxoneConfig.port,
      miniserver_protocol: loxoneConfig.protocol || 'wss',
      miniserver_user: loxoneConfig.user,
      miniserver_pass: loxoneConfig.pass,
      miniserver_external_address: loxoneConfig.externalAddress,
      miniserver_serial: loxoneConfig.serialNumber,
    };

    return await this.updateBuilding(buildingId, updateData);
  }
}

module.exports = new BuildingService();

