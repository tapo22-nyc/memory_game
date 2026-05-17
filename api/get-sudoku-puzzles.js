const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { difficulty, puzzle_number } = req.query;

    let query;
    if (difficulty && puzzle_number) {
      query = sql`
        SELECT id, difficulty, puzzle_number, puzzle_grid, solution_grid, is_active, created_at
        FROM sudoku_puzzles
        WHERE is_active = true
          AND difficulty     = ${String(difficulty).toLowerCase()}
          AND puzzle_number  = ${Number(puzzle_number)}
        ORDER BY id ASC
        LIMIT 1
      `;
    } else if (difficulty) {
      query = sql`
        SELECT id, difficulty, puzzle_number, puzzle_grid, solution_grid, is_active, created_at
        FROM sudoku_puzzles
        WHERE is_active = true
          AND difficulty = ${String(difficulty).toLowerCase()}
        ORDER BY puzzle_number ASC
      `;
    } else {
      query = sql`
        SELECT id, difficulty, puzzle_number, puzzle_grid, solution_grid, is_active, created_at
        FROM sudoku_puzzles
        WHERE is_active = true
        ORDER BY difficulty ASC, puzzle_number ASC
      `;
    }

    const puzzles = await query;
    return res.status(200).json({ puzzles });
  } catch (error) {
    console.error('get-sudoku-puzzles error:', error);
    return res.status(500).json({ error: error.message });
  }
};
