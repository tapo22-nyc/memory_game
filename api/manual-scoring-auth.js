/**
 * POST /api/manual-scoring-auth
 *
 * Validates four admin credentials against the closest_call_manual_admins
 * DB table (plain-text comparison — no hashing required).
 * Returns a random session token on success, stored back in the DB row.
 *
 * No environment variables required beyond DATABASE_URL.
 */

const { neon } = require('@neondatabase/serverless');
const crypto   = require('crypto');

const sql = neon(process.env.DATABASE_URL);

const TOKEN_TTL_MS = 2 * 60 * 60 * 1000; // 2 hours

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  const { username, email, password, code } = req.body || {};

  if (!username || !email || !password || !code) {
    return res.status(400).json({ error: 'All four fields are required.' });
  }

  const cleanUsername = String(username).trim().toLowerCase();
  const cleanEmail    = String(email).trim().toLowerCase();
  const cleanPassword = String(password).trim();
  const cleanCode     = String(code).trim();

  const GENERIC_ERROR = 'Invalid manual scoring credentials.';

  try {
    const rows = await sql`
      SELECT id, username, email, scoring_password, scoring_code
      FROM   closest_call_manual_admins
      WHERE  username  = ${cleanUsername}
        AND  is_active = TRUE
      LIMIT 1
    `;

    if (!rows.length) {
      return res.status(401).json({ error: GENERIC_ERROR });
    }

    const admin = rows[0];

    if (admin.email            !== cleanEmail    ||
        admin.scoring_password !== cleanPassword ||
        admin.scoring_code     !== cleanCode) {
      return res.status(401).json({ error: GENERIC_ERROR });
    }

    // Generate a random session token — no secret needed
    const token     = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + TOKEN_TTL_MS);

    await sql`
      UPDATE closest_call_manual_admins
      SET    session_token      = ${token},
             session_expires_at = ${expiresAt.toISOString()},
             updated_at         = NOW()
      WHERE  id = ${admin.id}
    `;

    return res.status(200).json({ success: true, token, username: cleanUsername });

  } catch (error) {
    console.error('manual-scoring-auth error:', error);
    return res.status(500).json({ error: 'Authentication failed. Please try again.' });
  }
};
