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

    const cleanName = user_name.trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
    if (cleanName.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 letters, numbers, or underscores.' });
    }

    if (!email || !email.trim()) {
      return res.status(400).json({ error: 'Email address is required.' });
    }

    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    // Check if username already exists
    const existing = await sql`
      SELECT id, user_name, email FROM ipl_users WHERE user_name = ${cleanName} LIMIT 1
    `;

    if (existing.length > 0) {
      const existingEmail = existing[0].email;
      // Username taken by someone with a different email
      if (existingEmail && existingEmail !== cleanEmail) {
        return res.status(400).json({ error: 'This user name has already been taken.' });
      }
      // Same email (or no email stored) → returning user, update/set email
      const updated = await sql`
        UPDATE ipl_users SET email = ${cleanEmail}
        WHERE user_name = ${cleanName}
        RETURNING id, user_name, email, total_points
      `;
      return res.status(200).json({ user: updated[0] });
    }

    // New user — create account
    const users = await sql`
      INSERT INTO ipl_users (user_name, email, total_points)
      VALUES (${cleanName}, ${cleanEmail}, 100)
      RETURNING id, user_name, email, total_points
    `;
    return res.status(200).json({ user: users[0] });

  } catch (error) {
    console.error('create-ipl-user error:', error);
    if (error.code === '23505' && error.constraint && error.constraint.includes('email')) {
      return res.status(400).json({ error: 'This email is already associated with another account.' });
    }
    res.status(500).json({ error: error.message || 'Could not create user.' });
  }
};
