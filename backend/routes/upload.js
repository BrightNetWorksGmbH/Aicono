const express = require('express');
const router = express.Router();
const uploadController = require('../controllers/uploadController');
const { requireAuth } = require('../middleware/auth');

/**
 * File Upload API Routes
 * 
 * All routes require authentication.
 * Files are uploaded to DigitalOcean Spaces under the "aicono/" directory.
 * 
 * Supported file types:
 * - Images: JPEG, PNG, GIF, WebP
 * - Documents: PDF, DOC, DOCX, XLS, XLSX, TXT
 * - Media: MP4, MP3, WAV
 * 
 * Max file size: 50MB per file
 * Max files per request: 10 (for multiple upload)
 */

// Upload single file
router.post('/single', 
  requireAuth,
  uploadController.uploadMiddleware.single('file'),
  uploadController.uploadSingle
);

// Upload multiple files
router.post('/multiple', 
  requireAuth,
  uploadController.uploadMiddleware.array('files', 10), // Max 10 files
  uploadController.uploadMultiple
);

// Delete file
router.delete('/delete', 
  requireAuth,
  uploadController.deleteFile
);

// List files
router.get('/list', 
  requireAuth,
  uploadController.listFiles
);

module.exports = router;

