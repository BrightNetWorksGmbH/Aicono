const express = require('express');
const router = express.Router();
const { getMyProfile, updateMyProfile } = require('../controllers/userController');
const { body } = require('express-validator');
const { validationErrorHandler } = require('../middleware/errorHandler');
const { requireAuth } = require('../middleware/auth');

// Validation rules for profile update
const updateProfileValidation = [
  body('first_name')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1 })
    .withMessage('First name must be a non-empty string'),
  body('last_name')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1 })
    .withMessage('Last name must be a non-empty string'),
  body('email')
    .optional()
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
  body('phone_number')
    .optional()
    .isString()
    .trim()
    .withMessage('Phone number must be a string'),
  body('position')
    .optional()
    .isString()
    .trim()
    .withMessage('Position must be a string'),
  body('profile_picture_url')
    .optional()
    .isURL()
    .withMessage('Profile picture URL must be a valid URL'),
];

/**
 * @route   GET /api/v1/users/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/me', requireAuth, getMyProfile);

/**
 * @route   PUT /api/v1/users/me
 * @desc    Update current user profile
 * @access  Private
 */
router.put('/me', requireAuth, updateProfileValidation, validationErrorHandler, updateMyProfile);

module.exports = router;
