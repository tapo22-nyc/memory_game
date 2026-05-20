const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

const VALID_DIFFICULTIES = ['easy', 'medium', 'hard'];

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { difficulty } = req.query || {};
    const diff = VALID_DIFFICULTIES.includes(difficulty) ? difficulty : 'easy';

    const puzzles = await sql`
      SELECT
        p.id,
        p.puzzle_number,
        p.puzzle_date,
        p.difficulty,
        p.center_letter,
        p.outer_letters,
        p.pangram_word,
        COUNT(w.id) AS total_words
      FROM spelling_bee_puzzles p
      LEFT JOIN spelling_bee_words w ON w.puzzle_id = p.id
      WHERE p.is_active = true
        AND p.difficulty = ${diff}
      GROUP BY p.id, p.puzzle_number, p.puzzle_date, p.difficulty,
               p.center_letter, p.outer_letters, p.pangram_word
      ORDER BY p.puzzle_number ASC
      LIMIT 4
    `;

    return res.status(200).json({ puzzles });
  } catch (error) {
    console.error('get-spelling-bee-puzzles error:', error);
    return res.status(500).json({ error: error.message });
  }
};
