import { neon } from '@neondatabase/serverless';
import { Resend } from 'resend';
import crypto from 'crypto';

const sql = neon(process.env.DATABASE_URL);
const resend = new Resend(process.env.RESEND_API_KEY);

function hashOtp(otp) {
  return crypto.createHash('sha256').update(otp).digest('hex');
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const { user_name, email } = req.body;

    if (!user_name || !email) {
      return res.status(400).json({
        success: false,
        error: 'Username and email are required'
      });
    }

    const cleanUsername = user_name.trim();
    const cleanEmail = email.trim().toLowerCase();

    if (!cleanEmail.includes('@')) {
      return res.status(400).json({
        success: false,
        error: 'Please enter a valid email'
      });
    }

    const existingByUsername = await sql`
      SELECT id, user_name, email
      FROM ipl_users
      WHERE LOWER(user_name) = LOWER(${cleanUsername})
      LIMIT 1
    `;

    const existingByEmail = await sql`
      SELECT id, user_name, email
      FROM ipl_users
      WHERE LOWER(email) = LOWER(${cleanEmail})
      LIMIT 1
    `;

    let user;

    if (existingByUsername.length > 0) {
      user = existingByUsername[0];

      if (user.email && user.email.toLowerCase() !== cleanEmail) {
        return res.status(409).json({
          success: false,
          error: 'This username is already linked to another email.'
        });
      }

      if (!user.email) {
        await sql`
          UPDATE ipl_users
          SET email = ${cleanEmail}, updated_at = NOW()
          WHERE id = ${user.id}
        `;
      }
    } else if (existingByEmail.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'This email is already linked to another username.'
      });
    } else {
      const newUsers = await sql`
        INSERT INTO ipl_users (user_name, email, email_verified, created_at, updated_at)
        VALUES (${cleanUsername}, ${cleanEmail}, FALSE, NOW(), NOW())
        RETURNING id, user_name, email
      `;

      user = newUsers[0];
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const hashedOtp = hashOtp(otp);

    await sql`
      INSERT INTO user_login_otps (user_id, email, otp_code, expires_at)
      VALUES (${user.id}, ${cleanEmail}, ${hashedOtp}, NOW() + INTERVAL '10 minutes')
    `;

    await resend.emails.send({
      from: 'MT Games <login@playmtgames.com>',
      to: cleanEmail,
      subject: 'Your MT Games login code',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto;">
          <h2>Your MT Games login code</h2>
          <p>Use this code to verify your email:</p>
          <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; margin: 24px 0;">
            ${otp}
          </div>
          <p>This code expires in 10 minutes.</p>
          <p>If you did not request this, you can ignore this email.</p>
        </div>
      `
    });

    return res.status(200).json({
      success: true,
      message: 'OTP sent successfully'
    });

  } catch (error) {
    console.error('auth-start error:', error);

    return res.status(500).json({
      success: false,
      error: 'Something went wrong while sending OTP'
    });
  }
}
