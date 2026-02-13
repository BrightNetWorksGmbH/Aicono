const reportingService = require('../services/reportingService');
const { asyncHandler } = require('../middleware/errorHandler');
const { checkReportingPermissionByRecipient } = require('../utils/buildingPermissions');

/**
 * DELETE /api/v1/reporting/recipients/:recipientId
 * Delete a recipient and all related assignments
 */
exports.deleteRecipient = asyncHandler(async (req, res) => {
  const { recipientId } = req.params;
  const userId = req.user._id;

  // Check permission - user must be Owner, Admin, or Expert (not Read-Only)
  // Check based on first building assignment for this recipient
  await checkReportingPermissionByRecipient(userId, recipientId);

  const result = await reportingService.deleteRecipient(recipientId);

  res.json({
    success: true,
    message: `Recipient "${result.recipientEmail}" deleted successfully`,
    data: result
  });
});

/**
 * PATCH /api/v1/reporting/recipients/:recipientId
 * Update a recipient (name, phone)
 * Body: { name?, phone? }
 * Note: Email is not editable
 */
exports.updateRecipient = asyncHandler(async (req, res) => {
  const { recipientId } = req.params;
  const userId = req.user._id;
  const updateData = req.body;

  // Validate that at least one field is provided
  if (!updateData || Object.keys(updateData).length === 0) {
    return res.status(400).json({
      success: false,
      error: 'At least one field (name or phone) must be provided for update'
    });
  }

  // Prevent email updates
  if (updateData.email !== undefined) {
    return res.status(400).json({
      success: false,
      error: 'Email cannot be updated. Please delete and create a new recipient with the new email.'
    });
  }

  // Check permission - user must be Owner, Admin, or Expert (not Read-Only)
  // Check based on first building assignment for this recipient
  await checkReportingPermissionByRecipient(userId, recipientId);

  const updatedRecipient = await reportingService.updateRecipient(recipientId, updateData);

  res.json({
    success: true,
    message: 'Recipient updated successfully',
    data: updatedRecipient
  });
});
