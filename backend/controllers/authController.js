const jwt = require("jsonwebtoken");
const User = require("../models/User");
const UserRole = require("../models/UserRole");
const Invitation = require("../models/Invitation");
const BryteSwitchSettings = require("../models/BryteSwitchSettings");
const ActivityLog = require("../models/ActivityLog");
const { sendPasswordResetEmail } = require("../services/emailService");
const { asyncHandler } = require("../middleware/errorHandler");

// Generate JWT
const generateToken = (id) => {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is not configured. Please set JWT_SECRET in your .env file.");
  }
  return jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: "7d" });
};

/**
 * @desc    Login user
 * @route   POST /api/v1/auth/login
 * @access  Public
 * @body    {string} email - User email
 * @body    {string} password - User password
 */
const loginUser = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  // Validate input
  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: "Please provide email and password",
    });
  }

  try {
    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Check if user is active
    if (!user.is_active) {
      return res.status(401).json({
        success: false,
        message: "Account is inactive. Please contact support.",
      });
    }

    // Check if user has a password set
    if (!user.password_hash) {
      return res.status(401).json({
        success: false,
        message: "Please set your password first. Check your email for an invitation link.",
      });
    }

    // Verify password
    const isPasswordValid = await user.matchPassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password",
      });
    }

    // Get user's roles
    const userRoles = await UserRole.find({
      user_id: user._id,
    })
      .populate("role_id", "name permissions_json")
      .populate("bryteswitch_id", "organization_name sub_domain is_setup_complete");

    // Get primary BryteSwitchSettings (first one or most relevant)
    const primaryBryteSwitch = userRoles.length > 0 
      ? userRoles[0].bryteswitch_id 
      : null;

    const is_setup_complete = primaryBryteSwitch 
      ? primaryBryteSwitch.is_setup_complete || false 
      : false;

    // Build user roles response
    const roles = userRoles.map((ur) => ({
      role_id: ur.role_id?._id,
      role_name: ur.role_id?.name,
      permissions: ur.role_id?.permissions_json,
      bryteswitch_id: ur.bryteswitch_id?._id,
      organization_name: ur.bryteswitch_id?.organization_name,
      sub_domain: ur.bryteswitch_id?.sub_domain,
    }));

    // Generate JWT token
    const token = generateToken(user._id);

    // Log activity
    if (primaryBryteSwitch) {
      try {
        await ActivityLog.create({
          bryteswitch_id: primaryBryteSwitch._id,
          user_id: user._id,
          action: "login",
          resource_type: "user",
          resource_id: user._id,
          timestamp: new Date(),
          details: {
            email: user.email,
            ip_address: req.ip || req.connection.remoteAddress,
          },
          ip_address: req.ip || req.connection.remoteAddress,
          severity: "low",
        });
      } catch (logError) {
        console.error("Failed to log login activity:", logError);
        // Don't fail the request if logging fails
      }
    }

    // Return response
    res.json({
      success: true,
      data: {
        user: {
          _id: user._id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          position: user.position,
          profile_picture_url: user.profile_picture_url,
        },
        token,
        roles,
        is_setup_complete,
      },
    });
  } catch (error) {
    console.error("Login error:", error);
    
    // Check if error is related to JWT_SECRET
    if (error.message && error.message.includes("JWT_SECRET")) {
      return res.status(500).json({
        success: false,
        message: "Server configuration error: JWT_SECRET is not set. Please contact the administrator.",
        error: process.env.NODE_ENV === "development" ? error.message : undefined,
      });
    }
    
    res.status(500).json({
      success: false,
      message: "An error occurred during login",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
});

/**
 * @desc    Request password reset
 * @route   POST /api/v1/auth/forgot-password
 * @access  Public
 * @body    {string} email - User email address
 */
const forgotPassword = asyncHandler(async (req, res) => {
  try {
    const { email } = req.body;

    // Validate email
    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Please provide an email address",
      });
    }

    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      // Don't reveal if user exists for security reasons
      return res.json({
        success: true,
        message: "If an account with that email exists, a password reset link has been sent",
      });
    }

    // Check if user is active
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: "This account is inactive. Please contact support.",
      });
    }

    // Generate reset token
    const resetToken = user.getResetPasswordToken();
    await user.save({ validateBeforeSave: false });

    // Send password reset email
    const emailResult = await sendPasswordResetEmail({
      to: user.email,
      resetToken,
      firstName: user.first_name,
    });

    if (!emailResult.ok) {
      // Rollback token if email fails
      user.resetPasswordToken = undefined;
      user.resetPasswordExpire = undefined;
      await user.save({ validateBeforeSave: false });

      console.error("Password reset email failed:", emailResult.error);
      return res.status(500).json({
        success: false,
        message: "Failed to send password reset email. Please try again later.",
      });
    }

    // Log activity for all BryteSwitch instances the user belongs to
    try {
      const userRoles = await UserRole.find({ user_id: user._id });
      const activityLogPromises = userRoles.map((ur) =>
        ActivityLog.create({
          bryteswitch_id: ur.bryteswitch_id,
          user_id: user._id,
          resource_type: "user",
          resource_id: user._id,
          action: "update",
          timestamp: new Date(),
          details: {
            context: "request_password_reset",
            email: user.email,
            ip_address: req.ip || req.connection.remoteAddress,
          },
          ip_address: req.ip || req.connection.remoteAddress,
          severity: "low",
        }).catch((err) => {
          console.error(`Failed to log password reset request:`, err.message);
          return null;
        })
      );

      await Promise.all(activityLogPromises);
    } catch (logError) {
      console.error("Error logging password reset request:", logError);
      // Don't fail if logging fails
    }

    res.json({
      success: true,
      message: "If an account with that email exists, a password reset link has been sent",
    });
  } catch (error) {
    console.error("Forgot password error:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred while processing your request",
    });
  }
});

/**
 * @desc    Reset password using token
 * @route   POST /api/v1/auth/reset-password
 * @access  Public
 * @body    {string} token - Password reset token
 * @body    {string} new_password - New password
 * @body    {string} confirm_password - Password confirmation
 */
const resetPassword = asyncHandler(async (req, res) => {
  try {
    const { token, new_password, confirm_password } = req.body;

    // Validate request
    if (!token || !new_password || !confirm_password) {
      return res.status(400).json({
        success: false,
        message: "Please provide reset token, new password, and confirmation",
      });
    }

    // Check if passwords match
    if (new_password !== confirm_password) {
      return res.status(400).json({
        success: false,
        message: "Passwords do not match",
      });
    }

    // Validate password strength
    if (new_password.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 8 characters long",
      });
    }

    // Hash the token to compare with database
    const crypto = require("crypto");
    const resetPasswordToken = crypto
      .createHash("sha256")
      .update(token)
      .digest("hex");

    // Find user with valid token
    const user = await User.findOne({
      resetPasswordToken,
      resetPasswordExpire: { $gt: Date.now() }, // Token not expired
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired reset token",
      });
    }

    // Check if user is active
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        message: "This account is inactive. Please contact support.",
      });
    }

    // Set new password (will be hashed by model method)
    await user.setPassword(new_password);

    // Clear reset token fields
    user.resetPasswordToken = undefined;
    user.resetPasswordExpire = undefined;

    await user.save();

    // Log activity for all BryteSwitch instances the user belongs to
    try {
      const userRoles = await UserRole.find({ user_id: user._id });
      const activityLogPromises = userRoles.map((ur) =>
        ActivityLog.create({
          bryteswitch_id: ur.bryteswitch_id,
          user_id: user._id,
          resource_type: "user",
          resource_id: user._id,
          action: "update",
          timestamp: new Date(),
          details: {
            context: "password_reset_completed",
            email: user.email,
            reset_method: "forgot_password_token",
          },
          ip_address: req.ip || req.connection.remoteAddress,
          severity: "low",
        }).catch((err) => {
          console.error(`Failed to log password reset:`, err.message);
          return null;
        })
      );

      await Promise.all(activityLogPromises);
    } catch (logError) {
      console.error("Error logging password reset:", logError);
      // Don't fail if logging fails
    }

    res.json({
      success: true,
      message: "Password has been reset successfully. You can now log in with your new password.",
    });
  } catch (error) {
    console.error("Reset password error:", error);
    res.status(500).json({
      success: false,
      message: "An error occurred while resetting your password",
    });
  }
});

/**
 * @desc    Register new user (with invitation token)
 * @route   POST /api/v1/auth/register
 * @access  Public
 * @body    {string} email - User email
 * @body    {string} password - User password
 * @body    {string} invitation_token - Invitation token (optional)
 */
const registerUser = asyncHandler(async (req, res) => {
  const { 
    email, 
    password, 
    invitation_token,
    first_name,
    last_name,
    position,
    profile_picture_url,
    is_superadmin
  } = req.body;

  // Validate input
  if (!email || !password) {
    return res.status(400).json({
      success: false,
      message: "Please provide email and password",
    });
  }

  // Validate password strength
  if (password.length < 8) {
    return res.status(400).json({
      success: false,
      message: "Password must be at least 8 characters long",
    });
  }

  try {
    // Check if user already exists
    const userExists = await User.findOne({ email: email.toLowerCase() });
    if (userExists) {
      return res.status(400).json({
        success: false,
        message: "User already exists",
      });
    }

    let userFirstName = '';
    let userLastName = '';
    let userPosition = '';
    let bryteswitch_id = null;
    let role_id = null;
    let is_setup_complete = false;
    let invitation = null;

    // If invitation token provided, get user details from invitation
    if (invitation_token) {
      invitation = await Invitation.findOne({ token: invitation_token })
        .populate('role_id')
        .populate('bryteswitch_id');

      if (!invitation) {
        return res.status(400).json({
          success: false,
          message: "Invalid invitation token",
        });
      }

      if (invitation.status === 'accepted') {
        return res.status(400).json({
          success: false,
          message: "Invitation already accepted",
        });
      }

      if (invitation.expires_at && invitation.expires_at < new Date()) {
        return res.status(400).json({
          success: false,
          message: "Invitation expired",
        });
      }

      if (invitation.status !== 'pending') {
        return res.status(400).json({
          success: false,
          message: "Invitation is not in a valid state",
        });
      }

      // Get user details from invitation
      userFirstName = invitation.first_name || '';
      userLastName = invitation.last_name || '';
      userPosition = invitation.position || '';
      bryteswitch_id = invitation.bryteswitch_id._id;
      role_id = invitation.role_id._id;

      // Check if this is a setup invitation (switch not yet complete)
      const bryteSwitch = invitation.bryteswitch_id;
      if (bryteSwitch && !bryteSwitch.is_setup_complete) {
        is_setup_complete = false;
      } else {
        is_setup_complete = true;
      }
    } else {
      // No invitation token - use values from request body
      // For direct registration (e.g., superadmin), allow first_name, last_name, etc. from body
      userFirstName = first_name || '';
      userLastName = last_name || '';
      userPosition = position || '';
    }

    // Create new user
    const user = new User({
      email: email.toLowerCase(),
      first_name: userFirstName,
      last_name: userLastName,
      position: userPosition,
      profile_picture_url: profile_picture_url || undefined,
      is_superadmin: is_superadmin === true || false, // Only allow if explicitly set to true
    });

    // Hash password
    await user.setPassword(password);
    await user.save();

    // Handle invitation scenarios
    if (invitation_token && invitation) {
      // Mark invitation as accepted
      invitation.status = 'accepted';
      await invitation.save();

      // Create UserRole entry
      const userRole = new UserRole({
        user_id: user._id,
        role_id: role_id,
        bryteswitch_id: bryteswitch_id,
        assigned_at: new Date(),
        assigned_by_user_id: invitation.invited_by_user_id,
      });

      await userRole.save();

      // Log the activity
      try {
        await ActivityLog.create({
          bryteswitch_id: bryteswitch_id,
          user_id: user._id,
          action: 'create',
          resource_type: 'user',
          resource_id: user._id,
          timestamp: new Date(),
          details: {
            action: is_setup_complete ? 'user_registered' : 'owner_registered_pending_setup',
            invitation_token: invitation_token,
            setup_complete: is_setup_complete,
            requires_action: !is_setup_complete,
          },
          severity: 'low',
        });
      } catch (logError) {
        console.error('Failed to log activity:', logError);
      }
    }

    // Generate JWT token
    const token = generateToken(user._id);

    // Get user roles for response
    const userRoles = await UserRole.find({
      user_id: user._id,
    })
      .populate("role_id", "name permissions_json")
      .populate("bryteswitch_id", "organization_name sub_domain is_setup_complete");

    const roles = userRoles.map((ur) => ({
      role_id: ur.role_id?._id,
      role_name: ur.role_id?.name,
      permissions: ur.role_id?.permissions_json,
      bryteswitch_id: ur.bryteswitch_id?._id,
      organization_name: ur.bryteswitch_id?.organization_name,
      sub_domain: ur.bryteswitch_id?.sub_domain,
    }));

    // Return response
    res.status(201).json({
      success: true,
      message: "User registered successfully",
      data: {
        user: {
          _id: user._id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          position: user.position,
          profile_picture_url: user.profile_picture_url,
        },
        token,
        roles,
        is_setup_complete: is_setup_complete && bryteswitch_id ? 
          (userRoles.find(ur => ur.bryteswitch_id?._id.toString() === bryteswitch_id.toString())?.bryteswitch_id?.is_setup_complete || false) : 
          true,
      },
    });
  } catch (error) {
    console.error("Registration error:", error);
    
    // Check if error is related to JWT_SECRET
    if (error.message && error.message.includes("JWT_SECRET")) {
      return res.status(500).json({
        success: false,
        message: "Server configuration error: JWT_SECRET is not set. Please contact the administrator.",
        error: process.env.NODE_ENV === "development" ? error.message : undefined,
      });
    }
    
    res.status(500).json({
      success: false,
      message: "An error occurred during registration",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
});

module.exports = {
  registerUser,
  loginUser,
  forgotPassword,
  resetPassword,
};

