const express = require('express');
const router = express.Router();
const {
  createInvitation,
  getInvitationByToken,
  getInvitationById,
  updateInvitation,
  deleteInvitation,
  getPendingInvitations,
} = require('../controllers/invitationController');
const { body } = require('express-validator');
const { validationErrorHandler } = require('../middleware/errorHandler');
const { requireAuth } = require('../middleware/auth');

// Validation rules
const createInvitationValidation = [
  body('bryteswitch_id')
    .notEmpty()
    .withMessage('BryteSwitch ID is required')
    .isMongoId()
    .withMessage('Invalid BryteSwitch ID'),
  body('role_id')
    .notEmpty()
    .withMessage('Role ID is required')
    .isMongoId()
    .withMessage('Invalid Role ID'),
  body('recipient_email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
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
  body('expires_in_days')
    .optional()
    .isInt({ min: 1, max: 365 })
    .withMessage('Expires in days must be between 1 and 365'),
];

const updateInvitationValidation = [
  body('recipient_email')
    .optional()
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email address'),
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
  body('role_id')
    .optional()
    .isMongoId()
    .withMessage('Invalid Role ID'),
  body('expires_at')
    .optional()
    .isISO8601()
    .withMessage('Expires at must be a valid date'),
];

/**
 * @route   POST /api/v1/invitations
 * @desc    Create invitation
 * @access  Private (Superadmin, Owner, Admin with invite_users permission)
 */
router.post(
  '/',
  requireAuth,
  createInvitationValidation,
  validationErrorHandler,
  createInvitation
);

/**
 * @route   GET /api/v1/invitations/token/:token
 * @desc    Get invitation by token
 * @access  Public
 */
router.get('/token/:token', getInvitationByToken);

/**
 * @route   GET /api/v1/invitations/:id
 * @desc    Get invitation by ID
 * @access  Private (Inviter, Superadmin, or member of the BryteSwitch)
 */
router.get('/:id', requireAuth, getInvitationById);

/**
 * @route   PUT /api/v1/invitations/:id
 * @desc    Update invitation
 * @access  Private (Inviter or Superadmin)
 */
router.put(
  '/:id',
  requireAuth,
  updateInvitationValidation,
  validationErrorHandler,
  updateInvitation
);

/**
 * @route   DELETE /api/v1/invitations/:id
 * @desc    Delete invitation
 * @access  Private (Inviter or Superadmin)
 */
router.delete('/:id', requireAuth, deleteInvitation);

/**
 * @route   GET /api/v1/invitations/bryteswitch/:bryteswitchId
 * @desc    Get pending invitations for a BryteSwitch
 * @access  Private (Superadmin, Owner, Admin with invite_users or manage_users permission)
 */
router.get('/bryteswitch/:bryteswitchId', requireAuth, getPendingInvitations);

module.exports = router;
