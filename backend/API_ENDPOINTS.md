# Aicono EMS API Endpoints

## Authentication Endpoints

### POST /api/v1/auth/login
Login user and get JWT token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "user": {
      "_id": "user_id",
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "position": "Engineer",
      "profile_picture_url": "https://..."
    },
    "token": "jwt_token_here",
    "roles": [
      {
        "role_id": "role_id",
        "role_name": "Admin",
        "permissions": {},
        "bryteswitch_id": "bryteswitch_id",
        "organization_name": "Organization Name",
        "sub_domain": "subdomain"
      }
    ],
    "is_setup_complete": false
  }
}
```

**Error Responses:**
- `400` - Missing email or password
- `401` - Invalid credentials or inactive account
- `500` - Server error

---

### POST /api/v1/auth/forgot-password
Request password reset email.

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "If an account with that email exists, a password reset link has been sent"
}
```

**Error Responses:**
- `400` - Missing email
- `403` - Account is inactive
- `500` - Server error

---

### POST /api/v1/auth/reset-password
Reset password using token from email.

**Request Body:**
```json
{
  "token": "reset_token_from_email",
  "new_password": "newpassword123",
  "confirm_password": "newpassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password has been reset successfully. You can now log in with your new password."
}
```

**Error Responses:**
- `400` - Missing fields, passwords don't match, weak password, or invalid/expired token
- `403` - Account is inactive
- `500` - Server error

---

## Invitation Endpoints

### POST /api/v1/invitations/accept-password
Accept invitation and set password for new user.

**Request Body:**
```json
{
  "invitation_token": "invitation_token_from_link",
  "new_password": "password123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password set successfully and invitation accepted",
  "data": {
    "user": {
      "_id": "user_id",
      "email": "user@example.com",
      "first_name": "",
      "last_name": ""
    }
  }
}
```

**Error Responses:**
- `400` - Missing fields, weak password, invitation already accepted, expired, or invalid status
- `404` - Invalid invitation token
- `500` - Server error

---

## Environment Variables Required

Add these to your `.env` file:

```env
# Server
PORT=3000
NODE_ENV=development

# Database
MONGODB_URI=mongodb+srv://...

# JWT
JWT_SECRET=your-secret-key-change-in-production

# Mailjet (for email sending)
MJ_API_KEY=your_mailjet_api_key
MJ_SECRET_KEY=your_mailjet_secret_key
MJ_FROM_EMAIL=noreply@aicono.com
FROM_NAME=AICONO EMS

# Frontend URL (for password reset links)
FRONTEND_URL=http://localhost:3000

# Optional: Logo URL for emails
AICONO_LOGO_URL=https://your-logo-url.com/logo.png
```

---

## Authentication Flow

1. **User Registration via Invitation:**
   - User receives invitation email with token
   - User clicks link and is taken to password setup page
   - User calls `POST /api/v1/invitations/accept-password` with token and password
   - System creates/updates user, creates UserRole, marks invitation as accepted

2. **User Login:**
   - User calls `POST /api/v1/auth/login` with email and password
   - System verifies credentials and returns JWT token with user info and setup status

3. **Password Reset:**
   - User calls `POST /api/v1/auth/forgot-password` with email
   - System sends password reset email with token
   - User clicks link and calls `POST /api/v1/auth/reset-password` with token and new password
   - System updates password and clears reset token

---

## Security Features

- Passwords are hashed using bcrypt (10 rounds)
- JWT tokens expire after 7 days
- Password reset tokens expire after 10 minutes
- All tokens are hashed before storage
- Email validation and password strength requirements
- Activity logging for security auditing

