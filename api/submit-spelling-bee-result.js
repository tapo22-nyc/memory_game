const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { puzzle_id, player_name, words_found, total_words, time_taken_seconds } = req.body || {};

    if (!puzzle_id || !player_name || words_found === undefined || words_found === null) {
      return res.status(400).json({ error: 'puzzle_id, player_name, and words_found are required' });
    }

    const puzzles = await sql`
      SELECT puzzle_number, difficulty
      FROM spelling_bee_puzzles
      WHERE id = ${Number(puzzle_id)}
    `;

    if (puzzles.length === 0) {
      return res.status(404).json({ error: 'Puzzle not found' });
    }

    const { puzzle_number, difficulty } = puzzles[0];

    await sql`
      INSERT INTO spelling_bee_results
        (puzzle_id, puzzle_number, difficulty, player_name, words_found, total_words, time_taken_seconds)
      VALUES (
        ${Number(puzzle_id)},
        ${puzzle_number},
        ${difficulty},
        ${String(player_name).trim()},
        ${Number(words_found)},
        ${total_words != null ? Number(total_words) : 0},
        ${time_taken_seconds != null ? Number(time_taken_seconds) : null}
      )
    `;

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('submit-spelling-bee-result error:', error);
    return res.status(500).json({ error: error.message });
  }
};
