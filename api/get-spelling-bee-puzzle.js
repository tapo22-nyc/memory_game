const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

const VALID_DIFFICULTIES = ['easy', 'medium', 'hard'];

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { user_id, user_name, difficulty } = req.query || {};

    const diff = VALID_DIFFICULTIES.includes(difficulty) ? difficulty : 'easy';

    const puzzles = await sql`
      SELECT id, puzzle_number, puzzle_date, center_letter, outer_letters, pangram_word, difficulty
      FROM spelling_bee_puzzles
      WHERE is_active = true
        AND difficulty = ${diff}
      ORDER BY created_at DESC
      LIMIT 1
    `;

    if (puzzles.length === 0) {
      return res.status(404).json({ error: 'No active puzzle found for difficulty: ' + diff });
    }

    const puzzle = puzzles[0];

    const wordCountResult = await sql`
      SELECT COUNT(*) AS total_words
      FROM spelling_bee_words
      WHERE puzzle_id = ${puzzle.id}
    `;
    const totalWords = Number(wordCountResult[0]?.total_words || 0);

    let userGuesses = [];
    if (user_id) {
      const rows = await sql`
        SELECT guessed_word
        FROM spelling_bee_user_guesses
        WHERE puzzle_id = ${puzzle.id}
          AND user_id = ${Number(user_id)}
          AND is_correct = true
        ORDER BY created_at ASC
      `;
      userGuesses = rows.map(r => r.guessed_word);
    } else if (user_name) {
      const rows = await sql`
        SELECT guessed_word
        FROM spelling_bee_user_guesses
        WHERE puzzle_id = ${puzzle.id}
          AND user_name = ${String(user_name)}
          AND is_correct = true
        ORDER BY created_at ASC
      `;
      userGuesses = rows.map(r => r.guessed_word);
    }

    return res.status(200).json({
      puzzle_id:     puzzle.id,
      puzzle_number: puzzle.puzzle_number,
      difficulty:    puzzle.difficulty,
      center_letter: puzzle.center_letter,
      outer_letters: puzzle.outer_letters,
      total_words:   totalWords,
      user_guesses:  userGuesses
    });
  } catch (error) {
    console.error('get-spelling-bee-puzzle error:', error);
    return res.status(500).json({ error: error.message });
  }
};
