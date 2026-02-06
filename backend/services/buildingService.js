const Building = require('../models/Building');
const buildingContactService = require('./buildingContactService');
const reportingService = require('./reportingService');
const { NotFoundError, ValidationError, ConflictError } = require('../utils/errors');

class BuildingService {
  /**
   * Create multiple buildings for a site
   * @param {String} siteId - Site ID
   * @param {Array<String>} buildingNames - Array of building names
   * @returns {Promise<Array>} Created buildings
   */
  async createBuildings(siteId, buildingNames) {
    if (!buildingNames || !Array.isArray(buildingNames) || buildingNames.length === 0) {
      throw new ValidationError('Building names array is required');
    }

    // Check for duplicate names within the request
    const uniqueNames = [...new Set(buildingNames)];
    if (uniqueNames.length !== buildingNames.length) {
      throw new ValidationError('Duplicate building names are not allowed');
    }

    // Check for existing buildings with same names in this site
    const existingBuildings = await Building.find({
      site_id: siteId,
      name: { $in: buildingNames }
    });

    if (existingBuildings.length > 0) {
      const existingNames = existingBuildings.map(b => b.name);
      throw new ConflictError(`Buildings with these names already exist: ${existingNames.join(', ')}`);
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
      throw new NotFoundError('Building');
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
    // console.log("updateBuilding's updateData is ", updateData);
    const building = await Building.findById(buildingId);
    if (!building) {
      throw new NotFoundError('Building');
    }

    // If name is being updated, check for duplicates
    if (updateData.name && updateData.name !== building.name) {
      const existing = await Building.findOne({
        site_id: building.site_id,
        name: updateData.name,
        _id: { $ne: buildingId }
      });
      if (existing) {
        throw new ConflictError(`A building with the name "${updateData.name}" already exists in this site`);
      }
    }

    // Handle buildingContact separately
    let buildingContactId = null;
    if (updateData.buildingContact !== undefined) {
      buildingContactId = await buildingContactService.resolveContact(updateData.buildingContact);
      delete updateData.buildingContact; // Remove from updateData as we'll set buildingContact_id
      updateData.buildingContact_id = buildingContactId;
    }

    // Handle reportingRecipients and reportConfigs
    // New format:
    // - Each recipient can have an optional reportConfig array (recipient-specific)
    // - reportConfigs at root level applies to ALL recipients (general templates)
    if (updateData.reportingRecipients !== undefined || updateData.reportConfigs !== undefined) {
      const { reportingRecipients, reportConfigs } = updateData;
      
      // Validate reportingRecipients if provided
      if (reportingRecipients !== undefined) {
        if (!Array.isArray(reportingRecipients)) {
          throw new ValidationError('reportingRecipients must be an array');
        }
      }
      
      // Validate reportConfigs if provided (general templates)
      if (reportConfigs !== undefined) {
        if (!Array.isArray(reportConfigs)) {
          throw new ValidationError('reportConfigs must be an array');
        }
      }

      // Process recipients if provided
      if (reportingRecipients && Array.isArray(reportingRecipients)) {
        for (const recipientInput of reportingRecipients) {
          // Resolve recipient (create or get existing)
          // Extract reportConfig from recipient if it exists
          let recipientReportConfigs = [];
          let recipientData = recipientInput;
          
          if (typeof recipientInput === 'object' && recipientInput !== null) {
            // Check if it's an object with id field (existing recipient with optional config)
            if (recipientInput.id !== undefined) {
              // Extract reportConfig if provided
              if (recipientInput.reportConfig) {
                recipientReportConfigs = recipientInput.reportConfig;
              }
              // Use the id string directly for resolving recipient
              recipientData = recipientInput.id;
            } else if (recipientInput.reportConfig !== undefined) {
              // It's a full recipient object with reportConfig
              // Extract reportConfig from recipient object
              recipientReportConfigs = recipientInput.reportConfig;
              // Create a copy without reportConfig for resolving recipient
              recipientData = { ...recipientInput };
              delete recipientData.reportConfig;
            } else {
              // It's a full recipient object without reportConfig
              recipientData = recipientInput;
            }
          }
          // If recipientInput is a string, recipientData is already set to that string
          
          const recipientId = await reportingService.resolveRecipient(recipientData);

          // Process recipient-specific report configs (if any)
          if (Array.isArray(recipientReportConfigs) && recipientReportConfigs.length > 0) {
            for (const config of recipientReportConfigs) {
              // Create reporting config
              const reporting = await reportingService.createReporting(config);

              // Create assignment for this recipient with this specific config
              await reportingService.createOrUpdateAssignment(
                buildingId,
                recipientId,
                reporting._id.toString()
              );
            }
          }

          // Process general report configs (apply to all recipients)
          if (Array.isArray(reportConfigs) && reportConfigs.length > 0) {
            for (const config of reportConfigs) {
              // Create reporting config
              const reporting = await reportingService.createReporting(config);

              // Create assignment for this recipient with general config
              await reportingService.createOrUpdateAssignment(
                buildingId,
                recipientId,
                reporting._id.toString()
              );
            }
          }
        }
      }

      // Remove from updateData as they're handled separately
      delete updateData.reportingRecipients;
      delete updateData.reportConfigs;
    }

    // console.log("updateBuilding's updateData before assigning is ", updateData);

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

