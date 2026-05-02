import { neon } from '@neondatabase/serverless';

const sql = neon(process.env.DATABASE_URL);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { user_id, goal } = req.body;
    const cleanGoal = goal?.trim();

    if (!user_id || !cleanGoal || cleanGoal.length < 5) {
      return res.status(400).json({ error: 'User and goal are required.' });
    }

    const saved = await sql`
      INSERT INTO manifestation_goals (user_id, goal)
      VALUES (${user_id}, ${cleanGoal})
      RETURNING id, user_id, goal, created_at
    `;

    return res.status(201).json({ goal: saved[0] });
  } catch (error) {
    return res.status(500).json({ error: 'Could not save goal.' });
  }
}
