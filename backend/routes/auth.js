const express = require('express');
const router = express.Router();
const {
  registerUser,
  loginUser,
  forgotPassword,
  resetPassword,
  getUserByEmail,
} = require('../controllers/authController');
const { body } = require('express-validator');
const { validationErrorHandler } = require('../middleware/errorHandler');

// Validation rules
const loginValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
  body('password')
    .notEmpty()
    .withMessage('Password is required'),
];

const forgotPasswordValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
];

const resetPasswordValidation = [
  body('token')
    .notEmpty()
    .withMessage('Reset token is required'),
  body('new_password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters long'),
  body('confirm_password')
    .notEmpty()
    .withMessage('Password confirmation is required'),
];

const registerValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters long'),
  body('invitation_token')
    .optional()
    .isString()
    .withMessage('Invitation token must be a string'),
  body('first_name')
    .optional()
    .isString()
    .trim()
    .withMessage('First name must be a string'),
  body('last_name')
    .optional()
    .isString()
    .trim()
    .withMessage('Last name must be a string'),
  body('position')
    .optional()
    .isString()
    .trim()
    .withMessage('Position must be a string'),
  body('profile_picture_url')
    .optional()
    .isURL()
    .withMessage('Profile picture URL must be a valid URL'),
  body('is_superadmin')
    .optional()
    .isBoolean()
    .withMessage('is_superadmin must be a boolean'),
];

/**
 * @route   POST /api/v1/auth/register
 * @desc    Register new user (with optional invitation token)
 * @access  Public
 */
router.post('/register', registerValidation, validationErrorHandler, registerUser);

/**
 * @route   POST /api/v1/auth/login
 * @desc    Login user
 * @access  Public
 */
router.post('/login', loginValidation, validationErrorHandler, loginUser);

/**
 * @route   POST /api/v1/auth/forgot-password
 * @desc    Request password reset
 * @access  Public
 */
router.post('/forgot-password', forgotPasswordValidation, validationErrorHandler, forgotPassword);

/**
 * @route   POST /api/v1/auth/reset-password
 * @desc    Reset password using token
 * @access  Public
 */
router.post('/reset-password', resetPasswordValidation, validationErrorHandler, resetPassword);

/**
 * @route   GET /api/v1/auth/user/email/:email
 * @desc    Get user by email
 * @access  Public
 */
router.get('/user/email/:email', getUserByEmail);

module.exports = router;

