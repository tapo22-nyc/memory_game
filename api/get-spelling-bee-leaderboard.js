const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const rows = await sql`
      SELECT
        p.puzzle_number,
        p.difficulty,
        COALESCE(g.user_name, u.user_name) AS user_name,
        COUNT(*) AS correct_words_count
      FROM spelling_bee_user_guesses g
      JOIN spelling_bee_puzzles p ON p.id = g.puzzle_id
      LEFT JOIN ipl_users u ON u.id = g.user_id
      WHERE g.is_correct = true
      GROUP BY p.puzzle_number, p.difficulty, COALESCE(g.user_name, u.user_name)
      ORDER BY correct_words_count DESC, p.puzzle_number DESC
      LIMIT 100
    `;

    return res.status(200).json({ rows });
  } catch (error) {
    console.error('get-spelling-bee-leaderboard error:', error);
    return res.status(500).json({ error: error.message });
  }
};
