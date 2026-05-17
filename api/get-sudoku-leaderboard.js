const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const rows = await sql`
      SELECT
        u.user_name,
        sa.difficulty,
        sa.time_taken_seconds
      FROM (
        SELECT user_id, difficulty, time_taken_seconds, completed_at
        FROM sudoku_attempts
        WHERE completed_correctly = true
        ORDER BY completed_at DESC
        LIMIT 10
      ) sa
      JOIN ipl_users u ON u.id = sa.user_id
      ORDER BY sa.time_taken_seconds DESC
    `;

    return res.status(200).json({ rows });
  } catch (error) {
    console.error('get-sudoku-leaderboard error:', error);
    return res.status(500).json({ error: error.message });
  }
};
