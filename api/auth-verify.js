import { neon } from '@neondatabase/serverless';
import crypto from 'crypto';

const sql = neon(process.env.DATABASE_URL);

function hashOtp(otp) {
  return crypto.createHash('sha256').update(otp).digest('hex');
}

function createSessionToken() {
  return crypto.randomBytes(48).toString('hex');
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const { email, otp_code } = req.body;

    if (!email || !otp_code) {
      return res.status(400).json({
        success: false,
        error: 'Email and OTP are required'
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanOtp = otp_code.trim();
    const hashedOtp = hashOtp(cleanOtp);

    const otpRows = await sql`
      SELECT id, user_id, email, otp_code, expires_at, used_at
      FROM user_login_otps
      WHERE LOWER(email) = LOWER(${cleanEmail})
        AND used_at IS NULL
      ORDER BY created_at DESC
      LIMIT 1
    `;

    if (otpRows.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Invalid or expired OTP'
      });
    }

    const otpRow = otpRows[0];

    if (new Date(otpRow.expires_at) < new Date()) {
      return res.status(400).json({
        success: false,
        error: 'OTP has expired'
      });
    }

    if (otpRow.otp_code !== hashedOtp) {
      return res.status(400).json({
        success: false,
        error: 'Incorrect OTP'
      });
    }

    await sql`
      UPDATE user_login_otps
      SET used_at = NOW()
      WHERE id = ${otpRow.id}
    `;

    const users = await sql`
      UPDATE ipl_users
      SET email_verified = TRUE,
          last_login_at = NOW(),
          updated_at = NOW()
      WHERE id = ${otpRow.user_id}
      RETURNING id, user_name, email, email_verified
    `;

    const user = users[0];
    const sessionToken = createSessionToken();

    await sql`
      INSERT INTO user_sessions (user_id, session_token, expires_at)
      VALUES (${user.id}, ${sessionToken}, NOW() + INTERVAL '90 days')
    `;

    return res.status(200).json({
      success: true,
      user_id: user.id,
      user_name: user.user_name,
      email: user.email,
      email_verified: user.email_verified,
      session_token: sessionToken
    });

  } catch (error) {
    console.error('auth-verify error:', error);

    return res.status(500).json({
      success: false,
      error: 'Something went wrong while verifying OTP'
    });
  }
}
