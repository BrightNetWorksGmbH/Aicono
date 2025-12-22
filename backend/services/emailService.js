const Mailjet = require("node-mailjet");

// Mailjet configuration
const MAILJET_API_KEY = process.env.MJ_API_KEY;
const MAILJET_SECRET_KEY = process.env.MJ_SECRET_KEY;
const FROM_EMAIL = process.env.MJ_FROM_EMAIL;
const FROM_NAME = process.env.FROM_NAME || "AICONO EMS";

// Initialize Mailjet client (same pattern as bnw backend)
const mailjet = new Mailjet({
  apiKey: MAILJET_API_KEY,
  apiSecret: MAILJET_SECRET_KEY,
});

const AICONO_LOGO_URL = process.env.AICONO_LOGO_URL || "";

/**
 * Build email template for Aicono
 */
function buildEmailTemplate({
  heading = "AICONO EMS",
  subheading,
  contentHtml = "",
  buttonText,
  buttonUrl,
  fallbackLabel = "If the button doesn't work, copy and paste this link into your browser:",
  footerLines = ["This email was sent from AICONO EMS."],
  includeLogo = true,
  postButtonHtml = "",
  gradientStart = "#214A59",
  gradientEnd = "#171C23",
  accentColor = "#214A59",
}) {
  const buttonSection = buttonText && buttonUrl
    ? `
          <div style="text-align: center;">
            <a href="${buttonUrl}" class="button">${buttonText}</a>
          </div>
          <p>${fallbackLabel}</p>
          <div class="link-fallback">${buttonUrl}</div>
        `
    : "";

  const footerSection = footerLines
    .map(line => `<p>${line}</p>`)
    .join("\n");

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${subheading ? `${subheading} - ` : ""}${heading}</title>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f4f4f4; }
        .container { max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, ${gradientStart} 0%, ${gradientEnd} 100%); border-radius: 16px; overflow: hidden; box-shadow: 0 15px 45px rgba(0,0,0,0.18); padding: 2px; }
        .card { background: #ffffff; border-radius: 14px; overflow: hidden; }
        .header { background: linear-gradient(135deg, ${gradientStart} 0%, ${gradientEnd} 100%); color: white; padding: 30px 20px; text-align: center; position: relative; }
        .header::before { content: ""; position: absolute; inset: 0; background: linear-gradient(135deg, rgba(255,255,255,0.18), rgba(255,255,255,0)); }
        .logo { position: relative; z-index: 1; margin-bottom: 16px; }
        .logo img { max-width: 160px; }
        .header h1, .header h2 { position: relative; z-index: 1; margin: 0; }
        .header h2 { margin-top: 10px; font-size: 20px; font-weight: normal; letter-spacing: 0.5px; }
        .content { padding: 30px 30px 36px; }
        .button { display: inline-block; background: linear-gradient(135deg, ${gradientStart} 0%, ${gradientEnd} 100%); color: #ffffff !important; padding: 15px 30px; text-decoration: none !important; border-radius: 6px; font-weight: bold; }
        .button:hover { filter: brightness(0.9); color: #ffffff !important; }
        a.button { color: #ffffff !important; text-decoration: none !important; }
        a.button:visited { color: #ffffff !important; }
        a.button:active { color: #ffffff !important; }
        .link-fallback { word-break: break-all; background: #f8f9fa; padding: 10px; border-radius: 4px; font-family: monospace; font-size: 12px; margin-top: 10px; }
        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; font-size: 14px; }
        .notice { background: #fff3cd; padding: 15px; border-radius: 6px; margin: 20px 0; border-left: 4px solid #ffc107; }
        .notice ul { margin: 8px 0 0 18px; padding: 0; }
        .notice li { margin-bottom: 6px; }
        .info-box { background: rgba(255, 255, 255, 0.65); padding: 15px; border-radius: 6px; margin: 20px 0; border-left: 4px solid ${accentColor}; }
        .info-box strong { color: ${accentColor}; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="card">
          <div class="header">
            ${includeLogo && AICONO_LOGO_URL ? `<div class="logo"><img src="${AICONO_LOGO_URL}" alt="Aicono" style="max-width: 160px; height: auto; display: block; margin: 0 auto;" border="0" /></div>` : ""}
            <h1>${heading}</h1>
            ${subheading ? `<h2>${subheading}</h2>` : ""}
          </div>
          <div class="content">
            ${contentHtml}
            ${buttonSection}
            ${postButtonHtml}
          </div>
          <div class="footer">
            ${footerSection}
          </div>
        </div>
      </div>
    </body>
    </html>
  `;
}

/**
 * Build password reset link
 */
function buildPasswordResetLink({ token, baseUrl }) {
  const url = new URL(baseUrl);
  url.pathname = "/reset-password";
  url.searchParams.set("token", token);
  return url.toString();
}

/**
 * Send password reset email using Mailjet
 * @param {object} params - Email parameters
 * @param {string} params.to - Recipient email address
 * @param {string} params.resetToken - Password reset token
 * @param {string} params.firstName - User's first name (optional)
 * @returns {Promise<object>} Result object with ok status and messageId or error
 */
async function sendPasswordResetEmail({ to, resetToken, firstName }) {
  try {
    const baseUrl = process.env.FRONTEND_URL || "http://localhost:3000";
    const resetLink = buildPasswordResetLink({ token: resetToken, baseUrl });
    const subject = "Password Reset Request - AICONO EMS";

    const greeting = firstName ? ` ${firstName}` : '';

    const htmlContent = buildEmailTemplate({
      heading: "AICONO EMS",
      subheading: "Password Reset Request",
      contentHtml: `
            <p>Hello${greeting},</p>
            <p>We received a request to reset your password for your AICONO EMS account.</p>
            <p>Please use the button below to choose a new password.</p>
      `,
      buttonText: "Reset Password",
      buttonUrl: resetLink,
      postButtonHtml: `
            <div class="notice">
              <strong>⚠️ Important:</strong>
              <ul>
                <li>This link will expire in <strong>10 minutes</strong>.</li>
                <li>If you didn't request this reset, please ignore this email.</li>
                <li>Your password will not change until you create a new one.</li>
              </ul>
            </div>
            <p>If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.</p>
            <p>For security reasons, we recommend choosing a strong password that you don't use for other accounts.</p>
            <p>Best regards,<br>The AICONO EMS Team</p>
      `,
      footerLines: [
        "This email was sent from AICONO EMS.",
        "If you have any questions, please contact our support team.",
      ],
    });

    const textContent = `
AICONO EMS - Password Reset Request

Hello${greeting},

We received a request to reset your password for your AICONO EMS account.

Please click the link below to reset your password:
${resetLink}

⚠️ Important:
- This link will expire in 10 minutes
- If you didn't request this reset, please ignore this email
- Your password will not change until you create a new one

If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.

Best regards,
The AICONO EMS Team

---
This email was sent from AICONO EMS. If you have any questions, please contact our support team.
    `.trim();

    // Check if Mailjet is configured
    if (!MAILJET_API_KEY || !MAILJET_SECRET_KEY || !FROM_EMAIL) {
      console.warn('Mailjet not configured. Skipping password reset email.');
      return {
        ok: false,
        error: 'Mailjet not configured. Please set MJ_API_KEY, MJ_SECRET_KEY, and MJ_FROM_EMAIL in .env',
        statusCode: 500,
      };
    }

    // Send email using Mailjet v3.1 API
    const request = mailjet.post("send", { version: "v3.1" }).request({
      Messages: [
        {
          From: {
            Email: FROM_EMAIL,
            Name: FROM_NAME,
          },
          To: [
            {
              Email: to,
              Name: firstName || to.split("@")[0],
            },
          ],
          Subject: subject,
          TextPart: textContent,
          HTMLPart: htmlContent,
        },
      ],
    });

    const result = await request;

    return {
      ok: true,
      messageId: result.body.Messages[0].To[0].MessageID,
      status: result.body.Messages[0].Status,
    };
  } catch (error) {
    console.error(
      "Failed to send password reset email:",
      error.statusCode || error.message
    );

    if (error.response && error.response.body) {
      console.error(
        "Mailjet API Error Details:",
        JSON.stringify(error.response.body, null, 2)
      );
    }

    return {
      ok: false,
      error:
        error.response?.body?.ErrorMessage || error.message || "Unknown error",
      statusCode: error.statusCode,
    };
  }
}

/**
 * Build invitation link
 */
function buildInvitationLink({ token, baseUrl }) {
  const url = new URL(baseUrl);
  url.pathname = "/invitation-validation";
  url.searchParams.set("token", token);
  return url.toString();
}

/**
 * Send invitation email using Mailjet
 * @param {object} params - Email parameters
 * @param {string} params.to - Recipient email address
 * @param {string} params.organizationName - BryteSwitch organization name
 * @param {string} params.roleName - Role name (e.g., "Owner")
 * @param {string} params.token - Invitation token
 * @param {string} params.subdomain - Subdomain (optional)
 * @param {string} params.firstName - Recipient first name (optional)
 * @param {string} params.lastName - Recipient last name (optional)
 * @returns {Promise<object>} Result object with ok status and messageId or error
 */
async function sendInvitationEmail({ to, organizationName, roleName, token, subdomain, firstName, lastName }) {
  try {
    // Check if Mailjet is configured
    if (!MAILJET_API_KEY || !MAILJET_SECRET_KEY || !FROM_EMAIL) {
      console.warn('Mailjet not configured. Skipping email send.');
      console.warn('Missing configuration:', {
        hasApiKey: !!MAILJET_API_KEY,
        hasSecretKey: !!MAILJET_SECRET_KEY,
        hasFromEmail: !!FROM_EMAIL
      });
      return {
        ok: false,
        error: 'Mailjet not configured. Please set MJ_API_KEY, MJ_SECRET_KEY, and MJ_FROM_EMAIL in .env',
        statusCode: 500,
      };
    }

    // Debug: Verify credentials are loaded (masked for security)
    if (MAILJET_SECRET_KEY === 'aicono-secret-key' || MAILJET_SECRET_KEY?.includes('secret-key')) {
      console.error('❌ ERROR: Mailjet secret key appears to be a placeholder!');
      console.error('Please update MJ_SECRET_KEY in your .env file with the actual secret key from Mailjet.');
      return {
        ok: false,
        error: 'Invalid Mailjet secret key. Please check your .env file.',
        statusCode: 500,
      };
    }

    const baseUrl = process.env.FRONTEND_URL || "http://localhost:3000";
    const inviteLink = buildInvitationLink({ token, baseUrl });
    const subject = `Invitation to join ${organizationName || "BryteSwitch"} as ${roleName || "member"}`;

    const greeting = firstName ? ` ${firstName}` : '';
    const fullName = firstName && lastName ? `${firstName} ${lastName}` : firstName || lastName || '';

    const organizationInfoHtml = subdomain
      ? `
            <div class="info-box">
              <strong>Organization Details</strong><br />
              Subdomain: ${subdomain}
            </div>
      `
      : "";

    const htmlContent = buildEmailTemplate({
      heading: "AICONO EMS",
      subheading: "You're Invited!",
      contentHtml: `
            <p>Hello${greeting},</p>
            <p>You have been invited to join <strong>${organizationName || "BryteSwitch"}</strong> as <strong>${roleName || "member"}</strong>.</p>
            ${organizationInfoHtml}
            <p>Please click the button below to accept your invitation and set up your account:</p>
      `,
      buttonText: "Accept Invitation",
      buttonUrl: inviteLink,
      postButtonHtml: `
            <div class="notice">
              <strong>⚠️ Important:</strong>
              <ul>
                <li>This invitation will expire in <strong>7 days</strong>.</li>
                <li>If you didn't expect this invitation, please ignore this email.</li>
                <li>You will be able to set your password after accepting the invitation.</li>
              </ul>
            </div>
            <p>If you have any questions, please don't hesitate to reach out.</p>
            <p>Welcome to AICONO EMS!</p>
      `,
      footerLines: [
        "This invitation was sent from AICONO EMS.",
        "If you didn't expect this email, please ignore it.",
      ],
    });

    const textContent = `
AICONO EMS - You're Invited!

Hello${greeting},

You have been invited to join ${organizationName || "BryteSwitch"} as ${roleName || "member"}.

${subdomain ? `Organization Details:\nSubdomain: ${subdomain}\n\n` : ""}

Please click the link below to accept your invitation and set up your account:
${inviteLink}

⚠️ Important:
- This invitation will expire in 7 days
- If you didn't expect this invitation, please ignore this email
- You will be able to set your password after accepting the invitation

If you have any questions, please don't hesitate to reach out.

Welcome to AICONO EMS!

---
This invitation was sent from AICONO EMS. If you didn't expect this email, please ignore it.
    `.trim();

    // Send email using Mailjet v3.1 API
    const request = mailjet.post("send", { version: "v3.1" }).request({
      Messages: [
        {
          From: {
            Email: FROM_EMAIL,
            Name: FROM_NAME,
          },
          To: [
            {
              Email: to,
              Name: fullName || to.split("@")[0],
            },
          ],
          Subject: subject,
          TextPart: textContent,
          HTMLPart: htmlContent,
        },
      ],
    });

    const result = await request;

    return {
      ok: true,
      messageId: result.body.Messages[0].To[0].MessageID,
      status: result.body.Messages[0].Status,
    };
  } catch (error) {
    console.error(
      "Failed to send invitation email:",
      error.statusCode || error.message
    );

    const statusCode = error.statusCode || error.response?.status || 500;
    const errorMessage = error.response?.body?.ErrorMessage || error.message || "Unknown error";
    
    // Log detailed error information
    if (error.response && error.response.body) {
      console.error("Mailjet API Error Details:", JSON.stringify(error.response.body, null, 2));
      
      // Check for authentication errors
      if (statusCode === 401) {
        console.error("❌ Mailjet Authentication Failed (401)");
        console.error("Please verify in your .env file:");
        console.error("  - MJ_API_KEY is set and correct");
        console.error("  - MJ_SECRET_KEY is set and correct");
        console.error("  - Both keys are valid and active in your Mailjet account");
        console.error("  - Keys are not expired or revoked");
        console.error("\nTo get your Mailjet keys:");
        console.error("  1. Go to https://app.mailjet.com/account/apikeys");
        console.error("  2. Copy your API Key and Secret Key");
        console.error("  3. Add them to your .env file");
      }
    } else {
      // Log the full error for debugging
      console.error("Full error object:", error);
    }

    return {
      ok: false,
      error: errorMessage,
      statusCode: statusCode,
    };
  }
}

module.exports = {
  sendPasswordResetEmail,
  sendInvitationEmail,
  buildEmailTemplate,
  buildInvitationLink,
};

