const express = require('express');
const router = express.Router();
const { getMyProfile, updateMyProfile, changeMyPassword } = require('../controllers/userController');
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

// Validation rules for password change
const changePasswordValidation = [
  body('current_password')
    .notEmpty()
    .withMessage('Current password is required'),
  body('new_password')
    .isLength({ min: 8 })
    .withMessage('New password must be at least 8 characters long'),
  body('confirm_password')
    .notEmpty()
    .withMessage('Password confirmation is required'),
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

/**
 * @route   PUT /api/v1/users/me/password
 * @desc    Change current user password
 * @access  Private
 */
router.put('/me/password', requireAuth, changePasswordValidation, validationErrorHandler, changeMyPassword);

module.exports = router;
