const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

const VALID_DIFFICULTIES = ['easy', 'medium', 'hard'];

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { difficulty } = req.query || {};

    if (!difficulty || !VALID_DIFFICULTIES.includes(difficulty)) {
      return res.status(400).json({ error: 'difficulty must be easy, medium, or hard' });
    }

    const rows = await sql`
      SELECT
        r.id,
        r.puzzle_id,
        COALESCE(r.puzzle_number, p.puzzle_number) AS puzzle_number,
        r.difficulty,
        r.player_name,
        r.words_found,
        r.total_words,
        r.time_taken_seconds,
        r.completed_at
      FROM spelling_bee_results r
      JOIN spelling_bee_puzzles p ON r.puzzle_id = p.id
      WHERE r.difficulty = ${difficulty}
      ORDER BY r.words_found DESC, r.time_taken_seconds ASC
      LIMIT 50
    `;

    return res.status(200).json({ rows });
  } catch (error) {
    console.error('get-spelling-bee-leaderboard error:', error);
    return res.status(500).json({ error: error.message });
  }
};
