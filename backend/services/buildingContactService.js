const BuildingContact = require('../models/BuildingContact');
const Building = require('../models/Building');
const mongoose = require('mongoose');

class BuildingContactService {
  /**
   * Resolve contact input - either create new contact or return existing ID
   * @param {Object|String} input - Contact object {name, email, phone?} or contact ID string
   * @returns {Promise<String>} BuildingContact ID
   */
  async resolveContact(input) {
    if (!input) {
      return null;
    }

    // If input is a string, treat it as an ID
    if (typeof input === 'string') {
      const contact = await BuildingContact.findById(input);
      if (!contact) {
        throw new Error(`BuildingContact with ID ${input} not found`);
      }
      return contact._id.toString();
    }

    // If input is an object, validate and create/find contact
    if (typeof input !== 'object' || input === null) {
      throw new Error('buildingContact must be either a string ID or an object with name, email, and optional phone');
    }

    const { name, email, phone } = input;

    if (!email) {
      throw new Error('Email is required for buildingContact');
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new Error('Invalid email format in buildingContact');
    }

    // Try to find existing contact by email
    let contact = await BuildingContact.findOne({ email: email.toLowerCase().trim() });

    if (contact) {
      // Update contact if new data provided
      if (name !== undefined) contact.name = name;
      if (phone !== undefined) contact.phone = phone;
      await contact.save();
      return contact._id.toString();
    }

    // Create new contact
    try {
      contact = await BuildingContact.create({
        name,
        email: email.toLowerCase().trim(),
        phone,
      });
      return contact._id.toString();
    } catch (error) {
      if (error.code === 11000) {
        // Duplicate key error - email already exists
        contact = await BuildingContact.findOne({ email: email.toLowerCase().trim() });
        if (contact) {
          // Update existing contact
          if (name !== undefined) contact.name = name;
          if (phone !== undefined) contact.phone = phone;
          await contact.save();
          return contact._id.toString();
        }
      }
      throw error;
    }
  }

  /**
   * Get contact by ID
   * @param {String} contactId - Contact ID
   * @returns {Promise<Object>} Contact document
   */
  async getContactById(contactId) {
    const contact = await BuildingContact.findById(contactId);
    if (!contact) {
      throw new Error('BuildingContact not found');
    }
    return contact;
  }

  /**
   * Get all building contacts with optional filtering
   * @param {Object} filters - Filter options
   * @param {String} filters.site_id - Optional site ID to filter by
   * @param {String} filters.building_id - Optional building ID to filter by
   * @returns {Promise<Array>} Array of contact documents
   */
  async getContacts(filters = {}) {
    const { site_id, building_id } = filters;

    // If no filters, return all contacts
    if (!site_id && !building_id) {
      return await BuildingContact.find({}).sort({ email: 1 }).lean();
    }

    // Build query to find relevant building contact IDs
    const buildingQuery = {};
    
    if (building_id) {
      if (!mongoose.Types.ObjectId.isValid(building_id)) {
        throw new Error(`Invalid building_id: ${building_id}`);
      }
      buildingQuery._id = new mongoose.Types.ObjectId(building_id);
    }
    
    if (site_id) {
      if (!mongoose.Types.ObjectId.isValid(site_id)) {
        throw new Error(`Invalid site_id: ${site_id}`);
      }
      buildingQuery.site_id = new mongoose.Types.ObjectId(site_id);
    }

    // Find buildings matching the criteria
    const buildings = await Building.find(buildingQuery)
      .select('buildingContact_id')
      .lean();

    // Extract unique contact IDs (filter out null/undefined)
    const contactIds = [...new Set(
      buildings
        .map(b => b.buildingContact_id)
        .filter(id => id !== null && id !== undefined)
    )];

    // If no contacts found, return empty array
    if (contactIds.length === 0) {
      return [];
    }

    // Return contacts matching the IDs
    return await BuildingContact.find({
      _id: { $in: contactIds }
    }).sort({ email: 1 }).lean();
  }
}

module.exports = new BuildingContactService();
