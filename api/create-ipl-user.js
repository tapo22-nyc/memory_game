const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests are allowed.' });
  }

  try {
    const { user_name } = req.body;

    if (!user_name || user_name.trim().length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters.' });
    }

    const cleanName = user_name.trim().toLowerCase();

    const users = await sql`
      INSERT INTO ipl_users (user_name, total_points)
      VALUES (${cleanName}, 100)
      ON CONFLICT (user_name)
      DO UPDATE SET user_name = EXCLUDED.user_name
      RETURNING id, user_name, total_points;
    `;

    res.status(200).json({ user: users[0] });
  } catch (error) {
    console.error('create-ipl-user error:', error);
    res.status(500).json({ error: error.message || 'Could not create IPL user.' });
  }
};
