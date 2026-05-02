import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { user_name } = req.body;
    const cleanName = user_name?.trim().toLowerCase();

    if (!cleanName || cleanName.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters.' });
    }

    const existing = await sql`
      SELECT id, user_name, created_at
      FROM users
      WHERE user_name = ${cleanName}
    `;

    if (existing.length > 0) {
      return res.status(200).json({ user: existing[0], existing: true });
    }

    const created = await sql`
      INSERT INTO users (user_name)
      VALUES (${cleanName})
      RETURNING id, user_name, created_at
    `;

    return res.status(201).json({ user: created[0], existing: false });
  } catch (error) {
    return res.status(500).json({ error: 'Could not create user.' });
  }
}
