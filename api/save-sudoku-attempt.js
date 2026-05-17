const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const {
      user_id,
      puzzle_id,
      difficulty,
      puzzle_number,
      attempts_count,
      time_taken_seconds,
      completed_correctly
    } = req.body || {};

    if (!user_id) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    if (!difficulty || !['easy', 'medium', 'hard'].includes(String(difficulty).toLowerCase())) {
      return res.status(400).json({ error: 'difficulty must be easy, medium, or hard' });
    }

    if (!puzzle_number || puzzle_number < 1 || puzzle_number > 3) {
      return res.status(400).json({ error: 'puzzle_number must be 1, 2, or 3' });
    }

    const result = await sql`
      INSERT INTO sudoku_attempts
        (user_id, puzzle_id, difficulty, puzzle_number, attempts_count, time_taken_seconds, completed_correctly, started_at, completed_at)
      VALUES
        (
          ${Number(user_id)},
          ${puzzle_id ? Number(puzzle_id) : null},
          ${String(difficulty).toLowerCase()},
          ${Number(puzzle_number)},
          ${Number(attempts_count) || 0},
          ${completed_correctly && time_taken_seconds != null ? Number(time_taken_seconds) : null},
          ${Boolean(completed_correctly)},
          NOW() - INTERVAL '1 second' * ${Number(time_taken_seconds) || 0},
          ${completed_correctly ? sql`NOW()` : null}
        )
      RETURNING id, created_at
    `;

    return res.status(200).json({ success: true, attempt_id: result[0]?.id });
  } catch (error) {
    console.error('save-sudoku-attempt error:', error);
    return res.status(500).json({ error: error.message });
  }
};
