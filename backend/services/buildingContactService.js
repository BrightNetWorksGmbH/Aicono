const BuildingContact = require('../models/BuildingContact');

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
}

module.exports = new BuildingContactService();
