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
      hints_used_so_far,
      hinted_row,
      hinted_col,
      hinted_value
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

    if (hinted_row == null || hinted_col == null || hinted_value == null) {
      return res.status(400).json({ error: 'hinted_row, hinted_col, and hinted_value are required' });
    }

    await sql`
      INSERT INTO sudoku_hints
        (user_id, puzzle_id, difficulty, puzzle_number, hints_used_so_far, hinted_row, hinted_col, hinted_value)
      VALUES
        (
          ${Number(user_id)},
          ${puzzle_id != null ? Number(puzzle_id) : null},
          ${String(difficulty).toLowerCase()},
          ${Number(puzzle_number)},
          ${Number(hints_used_so_far) || 1},
          ${Number(hinted_row)},
          ${Number(hinted_col)},
          ${Number(hinted_value)}
        )
    `;

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('save-sudoku-hint error:', error);
    return res.status(500).json({ error: error.message });
  }
};
