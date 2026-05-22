const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests are allowed.' });
  }

  try {
    const { user_name, email } = req.body;

    if (!user_name || user_name.trim().length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters.' });
    }

    const cleanName = user_name.trim().toLowerCase();

    if (!email || !email.trim()) {
      return res.status(400).json({ error: 'Email address is required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    const users = await sql`
      INSERT INTO ipl_users (user_name, email, total_points)
      VALUES (${cleanName}, ${cleanEmail}, 100)
      ON CONFLICT (user_name)
      DO UPDATE SET email = EXCLUDED.email
      RETURNING id, user_name, email, total_points;
    `;

    res.status(200).json({ user: users[0] });
  } catch (error) {
    console.error('create-ipl-user error:', error);
    if (error.code === '23505' && error.constraint && error.constraint.includes('email')) {
      return res.status(400).json({ error: 'This email is already associated with another account.' });
    }
    res.status(500).json({ error: error.message || 'Could not create user.' });
  }
};
