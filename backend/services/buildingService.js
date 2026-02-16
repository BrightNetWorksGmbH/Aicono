const Building = require('../models/Building');
const Site = require('../models/Site');
const buildingContactService = require('./buildingContactService');
const reportingService = require('./reportingService');
const { NotFoundError, ValidationError, ConflictError } = require('../utils/errors');
const loxoneConnectionManager = require('./loxoneConnectionManager');
const Floor = require('../models/Floor');
const LocalRoom = require('../models/LocalRoom');
const Sensor = require('../models/Sensor');
const Room = require('../models/Room');
const fs = require('fs');
const { checkBuildingPermission } = require('../utils/buildingPermissions');
class BuildingService {
  /**
   * Create multiple buildings for a site
   * @param {String} siteId - Site ID
   * @param {Array<String>} buildingNames - Array of building names
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} Created buildings and site info
   */
  async createBuildings(siteId, buildingNames, userId) {
    if (!buildingNames || !Array.isArray(buildingNames) || buildingNames.length === 0) {
      throw new ValidationError('Building names array is required');
    }

    // Get site to check permissions
    const site = await Site.findById(siteId);
    if (!site) {
      throw new NotFoundError('Site');
    }

    // Check permissions
    await checkBuildingPermission(userId, site.bryteswitch_id);

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
    
    return {
      buildings: createdBuildings,
      site: site
    };
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
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} Updated building
   */
  async updateBuilding(buildingId, updateData, userId) {
    const building = await Building.findById(buildingId).populate('site_id');
    if (!building) {
      throw new NotFoundError('Building');
    }

    // Check permissions using utility function
    await checkBuildingPermission(userId, building.site_id.bryteswitch_id);

    // Prevent updating Loxone config through regular update
    const loxoneFields = [
      'miniserver_ip',
      'miniserver_port',
      'miniserver_protocol',
      'miniserver_user',
      'miniserver_pass',
      'miniserver_external_address',
      'miniserver_serial'
    ];
    const hasLoxoneUpdate = loxoneFields.some(field => updateData[field] !== undefined);

    if (hasLoxoneUpdate) {
      throw new ValidationError('Loxone configuration cannot be updated through this endpoint. Use /api/v1/buildings/:buildingId/loxone-config instead.');
    }

    // Prevent updating site_id
    if (updateData.site_id !== undefined) {
      throw new ValidationError('Cannot update site_id');
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

      // Invalidate alert notification cache so new contact person is picked up immediately
      try {
        const alertNotificationService = require('./alertNotificationService');
        alertNotificationService.invalidateBuildingContactCache();
      } catch (e) {
        // Non-critical - cache will expire naturally after 10 minutes
      }
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
   * Update Loxone connection info (separate method for complex Loxone updates)
   * This method handles disconnect/reconnect and structure file management
   * @param {String} buildingId - Building ID
   * @param {Object} loxoneConfig - Loxone configuration
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} Updated building and connection result
   */
  async updateLoxoneConfig(buildingId, loxoneConfig, userId) {
    const building = await Building.findById(buildingId).populate('site_id');
    if (!building) {
      throw new NotFoundError('Building');
    }

    // Check permissions using utility function
    await checkBuildingPermission(userId, building.site_id.bryteswitch_id);

    // Check if serial number is changing
    const oldSerial = building.miniserver_serial;
    const newSerial = loxoneConfig.serialNumber || loxoneConfig.miniserver_serial;
    const serialChanged = oldSerial && newSerial && oldSerial !== newSerial;

    // If serial changed, disconnect old connection first

    if (serialChanged && oldSerial) {
      try {
        await loxoneConnectionManager.disconnect(buildingId);
      } catch (error) {
        console.error('Error disconnecting old Loxone connection:', error);
        // Continue with update even if disconnect fails
      }
    }

    // Update building config
    const updateData = {
      miniserver_ip: loxoneConfig.ip || loxoneConfig.miniserver_ip,
      miniserver_port: loxoneConfig.port || loxoneConfig.miniserver_port,
      miniserver_protocol: loxoneConfig.protocol || loxoneConfig.miniserver_protocol || 'wss',
      miniserver_user: loxoneConfig.user || loxoneConfig.miniserver_user,
      miniserver_pass: loxoneConfig.pass || loxoneConfig.miniserver_pass,
      miniserver_external_address: loxoneConfig.externalAddress || loxoneConfig.miniserver_external_address,
      miniserver_serial: newSerial,
    };

    // Remove undefined values
    Object.keys(updateData).forEach(key => {
      if (updateData[key] === undefined) {
        delete updateData[key];
      }
    });

    // Update building document directly (bypass regular updateBuilding to avoid permission check loop)
    Object.assign(building, updateData);
    await building.save();

    // Reconnect with new config if credentials are provided
    let connectionResult = null;
    if (updateData.miniserver_serial && (updateData.miniserver_user || updateData.miniserver_pass)) {
      try {
        connectionResult = await loxoneConnectionManager.connect(buildingId, {
          ip: updateData.miniserver_ip,
          port: updateData.miniserver_port,
          protocol: updateData.miniserver_protocol,
          user: updateData.miniserver_user,
          pass: updateData.miniserver_pass,
          externalAddress: updateData.miniserver_external_address,
          serialNumber: updateData.miniserver_serial
        });
      } catch (error) {
        console.error('Error reconnecting Loxone after config update:', error);
        // Return building update even if reconnect fails
        connectionResult = {
          success: false,
          message: `Building config updated but reconnection failed: ${error.message}`
        };
      }
    }

    return {
      building: building,
      connectionResult: connectionResult
    };
  }

  /**
   * Delete building and all related data (hard delete with cascade)
   * @param {String} buildingId - Building ID
   * @param {String} userId - User ID (for permission check)
   * @returns {Promise<Object>} Deletion summary
   */
  async deleteBuilding(buildingId, userId) {
    const building = await Building.findById(buildingId).populate('site_id');
    if (!building) {
      throw new NotFoundError('Building');
    }

    // Check permissions using utility function
    await checkBuildingPermission(userId, building.site_id.bryteswitch_id);

    const deletionSummary = {
      buildingId: buildingId,
      buildingName: building.name,
      deletedItems: {}
    };

    // 1. Disconnect Loxone connection if active
    try {
      await loxoneConnectionManager.disconnect(buildingId);
      deletionSummary.deletedItems.loxoneConnection = 'disconnected';
    } catch (error) {
      console.error('Error disconnecting Loxone:', error);
      deletionSummary.deletedItems.loxoneConnection = 'disconnect_failed';
    }

    // 2. Delete floors and related data


    // Get all floors for this building
    const floors = await Floor.find({ building_id: buildingId });
    const floorIds = floors.map(f => f._id);
    deletionSummary.deletedItems.floors = floors.length;

    // Get all LocalRooms for these floors
    const localRooms = await LocalRoom.find({ floor_id: { $in: floorIds } });
    const localRoomIds = localRooms.map(r => r._id);
    deletionSummary.deletedItems.localRooms = localRooms.length;

    // Get Loxone room IDs that are mapped to these LocalRooms
    const loxoneRoomIds = localRooms
      .filter(r => r.loxone_room_id)
      .map(r => r.loxone_room_id);

    // Check if other buildings use the same Loxone server
    const otherBuildings = await Building.find({
      miniserver_serial: building.miniserver_serial,
      _id: { $ne: buildingId }
    });

    // If this is the only building using this server, we can clean up more aggressively
    // However, since rooms and sensors are scoped to miniserver_serial (not building),
    // we should be careful. For now, we'll only delete sensors that are exclusively
    // linked to LocalRooms from this building.
    if (otherBuildings.length === 0 && building.miniserver_serial && loxoneRoomIds.length > 0) {
      // Delete sensors for these rooms (only if no other buildings use the server)
      const sensorResult = await Sensor.deleteMany({ room_id: { $in: loxoneRoomIds } });
      deletionSummary.deletedItems.sensors = sensorResult.deletedCount;

      // Delete structure file if this is the only building using the server
      try {
        const structureFilePath = loxoneConnectionManager.getStructureFilePath(building.miniserver_serial);
        
        if (fs.existsSync(structureFilePath)) {
          fs.unlinkSync(structureFilePath);
          deletionSummary.deletedItems.structureFile = 'deleted';
        }
      } catch (error) {
        console.error('Error deleting structure file:', error);
        deletionSummary.deletedItems.structureFile = 'delete_failed';
      }
    } else {
      deletionSummary.deletedItems.sensors = 0;
      deletionSummary.deletedItems.note = 'Sensors not deleted - other buildings may use the same Loxone server';
    }

    // Delete LocalRooms
    await LocalRoom.deleteMany({ floor_id: { $in: floorIds } });

    // Delete Floors
    await Floor.deleteMany({ building_id: buildingId });

    // 3. Delete reporting assignments
    const assignmentResult = await reportingService.deleteBuildingAssignments(buildingId);
    deletionSummary.deletedItems.reportingAssignments = assignmentResult.deletedCount;

    // 4. Finally, delete the building
    await Building.findByIdAndDelete(buildingId);

    return deletionSummary;
  }
}

module.exports = new BuildingService();

