const AWS = require('aws-sdk');
const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const { asyncHandler } = require('../middleware/errorHandler');

// Configure DigitalOcean Spaces (S3-compatible)
const s3 = new AWS.S3({
  endpoint: process.env.DO_SPACES_ENDPOINT,
  accessKeyId: process.env.DO_SPACES_ACCESS_KEY,
  secretAccessKey: process.env.DO_SPACES_SECRET_KEY,
  region: process.env.DO_SPACES_REGION,
  s3ForcePathStyle: false
});

const BUCKET_NAME = process.env.DO_SPACES_BUCKET_NAME;

/**
 * Helper function to sanitize metadata values for S3
 * S3 metadata values must be ASCII strings without newlines
 */
const sanitizeMetadata = (value) => {
  if (!value) return '';
  return value
    .toString()
    .replace(/[^\x20-\x7E]/g, '') // Remove non-ASCII characters
    .replace(/[\r\n\t]/g, ' ') // Replace newlines and tabs with spaces
    .trim()
    .substring(0, 1024); // Limit length for metadata
};

/**
 * Generate file path for Aicono uploads
 * Base path is always "aicono" with optional folder_path
 */
const generateFilePath = (fileName, folderPath = '') => {
  const basePath = 'aicono';
  if (folderPath) {
    // Ensure folder_path doesn't start/end with slashes
    const cleanFolderPath = folderPath.replace(/^\/+|\/+$/g, '');
    return `${basePath}/${cleanFolderPath}/${fileName}`;
  }
  return `${basePath}/${fileName}`;
};

/**
 * Configure multer for memory storage
 * Files are stored in memory before uploading to S3
 */
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
  fileFilter: (req, file, cb) => {
    // Allow common file types
    const allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'text/plain',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'video/mp4',
      'audio/mpeg',
      'audio/wav'
    ];

    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only images, documents, videos, and audio files are allowed.'), false);
    }
  }
});

/**
 * Upload single file
 * @route   POST /api/v1/upload/single
 * @access  Private
 * @body    {file} file - File to upload
 * @body    {string} folder_path - Optional folder path within aicono/
 */
exports.uploadSingle = asyncHandler(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ 
      success: false,
      message: 'No file uploaded' 
    });
  }

  const file = req.file;
  const { folder_path = '' } = req.body;
  const userId = req.user._id;

  // Generate unique filename
  const fileExtension = path.extname(file.originalname);
  const fileName = `${uuidv4()}${fileExtension}`;
  
  // Create file path with aicono base path
  const filePath = generateFilePath(fileName, folder_path);

  // Upload to DigitalOcean Spaces
  const uploadParams = {
    Bucket: BUCKET_NAME,
    Key: filePath,
    Body: file.buffer,
    ContentType: file.mimetype,
    ACL: 'public-read', // Make file publicly accessible
    Metadata: {
      originalName: sanitizeMetadata(file.originalname),
      uploadedBy: sanitizeMetadata(userId.toString()),
      uploadedAt: sanitizeMetadata(new Date().toISOString()),
      folderPath: sanitizeMetadata(folder_path || 'root')
    }
  };

  const result = await s3.upload(uploadParams).promise();

  // Return file information
  const fileInfo = {
    id: uuidv4(),
    originalName: file.originalname,
    fileName: fileName,
    filePath: filePath,
    url: result.Location,
    cdnUrl: `${process.env.DO_SPACES_CDN_ENDPOINT}/${filePath}`,
    size: file.size,
    mimeType: file.mimetype,
    uploaded_by: userId,
    uploaded_at: new Date(),
    folder_path: folder_path || null
  };

  res.status(200).json({
    success: true,
    message: 'File uploaded successfully',
    data: fileInfo
  });
});

/**
 * Upload multiple files
 * @route   POST /api/v1/upload/multiple
 * @access  Private
 * @body    {file[]} files - Array of files to upload (max 10)
 * @body    {string} folder_path - Optional folder path within aicono/
 */
exports.uploadMultiple = asyncHandler(async (req, res) => {
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ 
      success: false,
      message: 'No files uploaded' 
    });
  }

  const files = req.files;
  const { folder_path = '' } = req.body;
  const userId = req.user._id;

  const uploadPromises = files.map(async (file) => {
    // Generate unique filename
    const fileExtension = path.extname(file.originalname);
    const fileName = `${uuidv4()}${fileExtension}`;
    
    // Create file path with aicono base path
    const filePath = generateFilePath(fileName, folder_path);

    // Upload to DigitalOcean Spaces
    const uploadParams = {
      Bucket: BUCKET_NAME,
      Key: filePath,
      Body: file.buffer,
      ContentType: file.mimetype,
      ACL: 'public-read',
      Metadata: {
        originalName: sanitizeMetadata(file.originalname),
        uploadedBy: sanitizeMetadata(userId.toString()),
        uploadedAt: sanitizeMetadata(new Date().toISOString()),
        folderPath: sanitizeMetadata(folder_path || 'root')
      }
    };

    const result = await s3.upload(uploadParams).promise();

    return {
      id: uuidv4(),
      originalName: file.originalname,
      fileName: fileName,
      filePath: filePath,
      url: result.Location,
      cdnUrl: `${process.env.DO_SPACES_CDN_ENDPOINT}/${filePath}`,
      size: file.size,
      mimeType: file.mimetype,
      uploaded_by: userId,
      uploaded_at: new Date(),
      folder_path: folder_path || null
    };
  });

  const uploadedFiles = await Promise.all(uploadPromises);

  res.status(200).json({
    success: true,
    message: `${uploadedFiles.length} files uploaded successfully`,
    data: {
      files: uploadedFiles,
      count: uploadedFiles.length
    }
  });
});

/**
 * Delete file
 * @route   DELETE /api/v1/upload/delete
 * @access  Private
 * @query   {string} filePath - Full file path to delete
 */
exports.deleteFile = asyncHandler(async (req, res) => {
  // Get the file path from query parameter
  const { filePath } = req.query;
  const userId = req.user._id;

  if (!filePath) {
    return res.status(400).json({ 
      success: false,
      message: 'File path is required' 
    });
  }

  // Decode the file path (in case it's URL encoded)
  const decodedFilePath = decodeURIComponent(filePath);

  // Verify the file path starts with "aicono/" for security
  if (!decodedFilePath.startsWith('aicono/')) {
    return res.status(400).json({ 
      success: false,
      message: 'Invalid file path. Files must be within the aicono directory.' 
    });
  }

  // Delete from DigitalOcean Spaces
  const deleteParams = {
    Bucket: BUCKET_NAME,
    Key: decodedFilePath
  };

  await s3.deleteObject(deleteParams).promise();

  res.status(200).json({
    success: true,
    message: 'File deleted successfully',
    data: {
      filePath: decodedFilePath
    }
  });
});

/**
 * List files
 * @route   GET /api/v1/upload/list
 * @access  Private
 * @query   {string} folder_path - Optional folder path within aicono/
 * @query   {string} prefix - Optional prefix to filter files
 */
exports.listFiles = asyncHandler(async (req, res) => {
  const { folder_path = '', prefix = '' } = req.query;
  const userId = req.user._id;

  // Build the prefix for listing (always starts with "aicono/")
  let listPrefix = 'aicono/';
  if (folder_path) {
    // Ensure folder_path doesn't start/end with slashes
    const cleanFolderPath = folder_path.replace(/^\/+|\/+$/g, '');
    listPrefix += `${cleanFolderPath}/`;
  }

  if (prefix) {
    listPrefix += prefix;
  }

  const listParams = {
    Bucket: BUCKET_NAME,
    Prefix: listPrefix,
    MaxKeys: 100 // Limit results
  };

  const result = await s3.listObjectsV2(listParams).promise();

  const files = result.Contents.map(item => ({
    key: item.Key,
    fileName: item.Key.split('/').pop(),
    size: item.Size,
    lastModified: item.LastModified,
    url: `${process.env.DO_SPACES_ENDPOINT}/${item.Key}`,
    cdnUrl: `${process.env.DO_SPACES_CDN_ENDPOINT}/${item.Key}`
  }));

  res.status(200).json({
    success: true,
    message: 'Files retrieved successfully',
    data: {
      files: files,
      count: files.length,
      prefix: listPrefix
    }
  });
});

// Export multer middleware for use in routes
exports.uploadMiddleware = upload;

