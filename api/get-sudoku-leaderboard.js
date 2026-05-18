const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const rows = await sql`
      WITH latest_attempts AS (
        SELECT
          sa.user_id,
          sa.difficulty,
          sa.time_taken_seconds,
          sa.completed_at,
          sa.created_at
        FROM sudoku_attempts sa
        WHERE sa.completed_correctly = true
        ORDER BY COALESCE(sa.completed_at, sa.created_at) DESC
        LIMIT 10
      )
      SELECT
        u.user_name,
        la.difficulty,
        la.time_taken_seconds,
        la.completed_at
      FROM latest_attempts la
      JOIN ipl_users u ON u.id = la.user_id
      ORDER BY la.time_taken_seconds ASC
    `;

    return res.status(200).json({ rows });
  } catch (error) {
    console.error('get-sudoku-leaderboard error:', error);
    return res.status(500).json({ error: error.message });
  }
};
