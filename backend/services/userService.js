const User = require('../models/User');
const { NotFoundError, ValidationError, ConflictError } = require('../utils/errors');

class UserService {
  /**
   * Get user profile by ID
   * @param {String} userId - User ID
   * @returns {Promise<Object>} User profile
   */
  async getUserProfile(userId) {
    const user = await User.findById(userId)
      .populate('joined_switch', 'organization_name sub_domain')
      .select('-password_hash -resetPasswordToken -resetPasswordExpire');

    if (!user) {
      throw new NotFoundError('User');
    }

    return user;
  }

  /**
   * Update user profile
   * @param {String} userId - User ID
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated user profile
   */
  async updateUserProfile(userId, updateData) {
    const user = await User.findById(userId);
    if (!user) {
      throw new NotFoundError('User');
    }

    // Track changes for activity log
    const changes = {};

    // Update first_name
    if (updateData.first_name !== undefined && updateData.first_name !== user.first_name) {
      if (!updateData.first_name.trim()) {
        throw new ValidationError('First name cannot be empty');
      }
      changes.first_name = { old: user.first_name, new: updateData.first_name.trim() };
      user.first_name = updateData.first_name.trim();
    }

    // Update last_name
    if (updateData.last_name !== undefined && updateData.last_name !== user.last_name) {
      if (!updateData.last_name.trim()) {
        throw new ValidationError('Last name cannot be empty');
      }
      changes.last_name = { old: user.last_name, new: updateData.last_name.trim() };
      user.last_name = updateData.last_name.trim();
    }

    // Update email (with uniqueness check)
    if (updateData.email !== undefined && updateData.email.toLowerCase() !== user.email.toLowerCase()) {
      const email = updateData.email.toLowerCase().trim();
      
      // Validate email format
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(email)) {
        throw new ValidationError('Invalid email format');
      }

      // Check if email is already taken by another user
      const existingUser = await User.findOne({ email });
      if (existingUser && existingUser._id.toString() !== userId.toString()) {
        throw new ConflictError('Email is already in use');
      }

      changes.email = { old: user.email, new: email };
      user.email = email;
    }

    // Update phone_number
    if (updateData.phone_number !== undefined) {
      const phoneNumber = updateData.phone_number ? updateData.phone_number.trim() : null;
      if (phoneNumber !== user.phone_number) {
        changes.phone_number = { old: user.phone_number || null, new: phoneNumber };
        user.phone_number = phoneNumber;
      }
    }

    // Update position
    if (updateData.position !== undefined) {
      const position = updateData.position ? updateData.position.trim() : null;
      if (position !== user.position) {
        changes.position = { old: user.position || null, new: position };
        user.position = position;
      }
    }

    // Update profile_picture_url
    if (updateData.profile_picture_url !== undefined) {
      const profilePictureUrl = updateData.profile_picture_url ? updateData.profile_picture_url.trim() : null;
      
      // Validate URL format if provided
      if (profilePictureUrl) {
        try {
          new URL(profilePictureUrl);
        } catch (e) {
          throw new ValidationError('Profile picture URL must be a valid URL');
        }
      }

      if (profilePictureUrl !== user.profile_picture_url) {
        changes.profile_picture_url = { old: user.profile_picture_url || null, new: profilePictureUrl };
        user.profile_picture_url = profilePictureUrl;
      }
    }

    // Save updated user
    await user.save();

    return {
      user,
      changes: Object.keys(changes).length > 0 ? changes : null
    };
  }

  /**
   * Delete old profile picture from S3 if it exists
   * @param {String} profilePictureUrl - URL of the profile picture to delete
   * @returns {Promise<void>}
   */
  async deleteOldProfilePicture(profilePictureUrl) {
    if (!profilePictureUrl) {
      return;
    }

    try {
      const AWS = require('aws-sdk');
      const s3 = new AWS.S3({
        endpoint: process.env.DO_SPACES_ENDPOINT,
        accessKeyId: process.env.DO_SPACES_ACCESS_KEY,
        secretAccessKey: process.env.DO_SPACES_SECRET_KEY,
        region: process.env.DO_SPACES_REGION,
        s3ForcePathStyle: false
      });

      let oldKey = null;

      // Handle DigitalOcean Spaces direct URL
      // Example: https://fra1.digitaloceanspaces.com/bucket-name/aicono/avatars/userId/filename.jpg
      if (profilePictureUrl.includes('digitaloceanspaces.com')) {
        const urlParts = profilePictureUrl.split('/');
        const bucketIndex = urlParts.findIndex(part => part.includes('digitaloceanspaces.com'));
        
        if (bucketIndex !== -1 && bucketIndex + 2 < urlParts.length) {
          // Get everything after the bucket name
          oldKey = urlParts.slice(bucketIndex + 2).join('/');
        }
      }
      // Handle CDN URL
      // Example: https://cdn.example.com/aicono/avatars/userId/filename.jpg
      else if (process.env.DO_SPACES_CDN_ENDPOINT && profilePictureUrl.includes(process.env.DO_SPACES_CDN_ENDPOINT)) {
        // Extract path after CDN endpoint
        const cdnBase = process.env.DO_SPACES_CDN_ENDPOINT.replace(/^https?:\/\//, '').replace(/\/$/, '');
        const urlParts = profilePictureUrl.split(cdnBase);
        if (urlParts.length > 1) {
          oldKey = urlParts[1].replace(/^\//, ''); // Remove leading slash
        }
      }
      // Try to extract path from any URL structure
      else {
        try {
          const url = new URL(profilePictureUrl);
          // Get pathname and remove leading slash
          oldKey = url.pathname.replace(/^\//, '');
        } catch (e) {
          console.warn('Could not parse profile picture URL:', profilePictureUrl);
          return;
        }
      }

      // Validate that the path starts with "aicono/" for security (like deleteFile does)
      if (!oldKey || !oldKey.startsWith('aicono/')) {
        console.warn('Invalid profile picture path - must start with "aicono/":', oldKey);
        return;
      }

      // Decode URL-encoded characters in the path
      oldKey = decodeURIComponent(oldKey);

      const deleteParams = {
        Bucket: process.env.DO_SPACES_BUCKET_NAME,
        Key: oldKey
      };
      
      await s3.deleteObject(deleteParams).promise();
      console.log('Old profile picture deleted from S3:', oldKey);
    } catch (deleteError) {
      console.warn('Failed to delete old profile picture:', deleteError.message);
      // Don't throw - continue even if deletion fails
    }
  }
}

module.exports = new UserService();
