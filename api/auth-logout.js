import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

function getToken(req) {
  const authHeader = req.headers.authorization || '';
  return authHeader.replace('Bearer ', '').trim();
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method not allowed' });
  }

  try {
    const token = getToken(req);

    if (!token) {
      return res.status(200).json({
        success: true,
        message: 'Already logged out'
      });
    }

    await sql`
      DELETE FROM user_sessions
      WHERE session_token = ${token}
    `;

    return res.status(200).json({
      success: true,
      message: 'Logged out successfully'
    });

  } catch (error) {
    console.error('auth-logout error:', error);

    return res.status(500).json({
      success: false,
      error: 'Something went wrong while logging out'
    });
  }
}
