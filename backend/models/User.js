const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const userSchema = new mongoose.Schema({
  first_name: {
    type: String,
    required: true,
  },
  last_name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
  },
  password_hash: {
    type: String,
  },
  phone_number: {
    type: String,
  },
  position: {
    type: String,
  },
  profile_picture_url: {
    type: String,
  },
  is_active: {
    type: Boolean,
    default: true,
  },
  is_superadmin: {
    type: Boolean,
    default: false,
    index: true,
  },
  // Password reset fields
  resetPasswordToken: String,
  resetPasswordExpire: Date,
}, {
  timestamps: true,
});

// Indexes
userSchema.index({ email: 1 });
userSchema.index({ first_name: 1, last_name: 1 });
userSchema.index({ resetPasswordToken: 1 });

// Helper methods
userSchema.methods.setPassword = async function (plain) {
  this.password_hash = await bcrypt.hash(plain, 10);
};

userSchema.methods.matchPassword = async function (entered) {
  if (!this.password_hash) {
    return false;
  }
  return bcrypt.compare(entered, this.password_hash);
};

// Generate & hash reset token
userSchema.methods.getResetPasswordToken = function () {
  const resetToken = crypto.randomBytes(20).toString('hex');

  this.resetPasswordToken = crypto
    .createHash('sha256')
    .update(resetToken)
    .digest('hex');

  this.resetPasswordExpire = Date.now() + 10 * 60 * 1000; // 10 minutes

  return resetToken;
};

module.exports = mongoose.model('User', userSchema);

