const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * Authentication middleware
 * Verifies JWT token and attaches user to request
 */
exports.requireAuth = async (req, res, next) => {
  try {
    if (!process.env.JWT_SECRET) {
      return res.status(500).json({ 
        success: false,
        message: 'Server configuration error: JWT_SECRET is not set' 
      });
    }

    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    
    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ 
        success: false,
        message: 'Unauthorized - No token provided' 
      });
    }

    const payload = jwt.verify(token, process.env.JWT_SECRET);
   
    const user = await User.findById(payload.id || payload.userId);
    
    if (!user) {
      return res.status(401).json({ 
        success: false,
        message: 'Unauthorized - User not found' 
      });
    }

    if (user.is_active === false) {
      return res.status(401).json({ 
        success: false,
        message: 'Unauthorized - Account is inactive' 
      });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ 
      success: false,
      message: 'Unauthorized - Invalid token' 
    });
  }
};

// Alias for requireAuth to maintain compatibility
exports.protect = exports.requireAuth;

