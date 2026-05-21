import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

function getToken(req) {
  const authHeader = req.headers.authorization || '';
  return authHeader.replace('Bearer ', '').trim();
}

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const token = getToken(req);

    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'Missing session token'
      });
    }

    const rows = await sql`
      SELECT 
        s.id AS session_id,
        s.expires_at,
        u.id AS user_id,
        u.user_name,
        u.email,
        u.email_verified
      FROM user_sessions s
      JOIN ipl_users u ON u.id = s.user_id
      WHERE s.session_token = ${token}
      LIMIT 1
    `;

    if (rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Invalid session'
      });
    }

    const session = rows[0];

    if (new Date(session.expires_at) < new Date()) {
      return res.status(401).json({
        success: false,
        error: 'Session expired'
      });
    }

    await sql`
      UPDATE user_sessions
      SET last_seen_at = NOW()
      WHERE id = ${session.session_id}
    `;

    return res.status(200).json({
      success: true,
      user_id: session.user_id,
      user_name: session.user_name,
      email: session.email,
      email_verified: session.email_verified
    });

  } catch (error) {
    console.error('auth-me error:', error);

    return res.status(500).json({
      success: false,
      error: 'Something went wrong while checking session'
    });
  }
}
