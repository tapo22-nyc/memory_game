const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { puzzle_id, user_id, user_name, guessed_word } = req.body || {};

    if (!puzzle_id) {
      return res.status(400).json({ error: 'puzzle_id is required' });
    }
    if (!user_id && !user_name) {
      return res.status(400).json({ error: 'user_id or user_name is required' });
    }
    if (!guessed_word) {
      return res.status(400).json({ error: 'guessed_word is required' });
    }

    const word = String(guessed_word).toLowerCase().trim();

    if (word.length < 4) {
      return res.status(200).json({ result: 'invalid', message: 'Words must be at least 4 letters' });
    }

    const puzzles = await sql`
      SELECT center_letter, outer_letters
      FROM spelling_bee_puzzles
      WHERE id = ${Number(puzzle_id)}
    `;

    if (puzzles.length === 0) {
      return res.status(404).json({ error: 'Puzzle not found' });
    }

    const { center_letter, outer_letters } = puzzles[0];
    const centerLow = center_letter.toLowerCase();
    const allowedSet = new Set([centerLow, ...outer_letters.split(',').map(l => l.trim().toLowerCase())]);

    if (!word.includes(centerLow)) {
      await saveGuess(puzzle_id, user_id, user_name, word, false);
      return res.status(200).json({ result: 'invalid', message: `Word must contain the center letter "${center_letter.toUpperCase()}"` });
    }

    for (const ch of word) {
      if (!allowedSet.has(ch)) {
        await saveGuess(puzzle_id, user_id, user_name, word, false);
        return res.status(200).json({ result: 'invalid', message: 'Word uses letters not in the hive' });
      }
    }

    const validWords = await sql`
      SELECT id, is_pangram
      FROM spelling_bee_words
      WHERE puzzle_id = ${Number(puzzle_id)} AND word = ${word}
    `;

    if (validWords.length === 0) {
      await saveGuess(puzzle_id, user_id, user_name, word, false);
      return res.status(200).json({ result: 'invalid', message: 'Not in word list' });
    }

    const isPangram = validWords[0].is_pangram;

    let existingGuess;
    if (user_id) {
      existingGuess = await sql`
        SELECT id FROM spelling_bee_user_guesses
        WHERE puzzle_id = ${Number(puzzle_id)}
          AND user_id = ${Number(user_id)}
          AND guessed_word = ${word}
          AND is_correct = true
      `;
    } else {
      existingGuess = await sql`
        SELECT id FROM spelling_bee_user_guesses
        WHERE puzzle_id = ${Number(puzzle_id)}
          AND user_name = ${String(user_name)}
          AND guessed_word = ${word}
          AND is_correct = true
      `;
    }

    if (existingGuess.length > 0) {
      return res.status(200).json({ result: 'duplicate', message: 'Already found!' });
    }

    await saveGuess(puzzle_id, user_id, user_name, word, true);

    return res.status(200).json({
      result: 'correct',
      message: isPangram ? 'Pangram!' : 'Nice!',
      is_pangram: isPangram
    });
  } catch (error) {
    console.error('submit-spelling-bee-guess error:', error);
    return res.status(500).json({ error: error.message });
  }
};

async function saveGuess(puzzle_id, user_id, user_name, word, is_correct) {
  await sql`
    INSERT INTO spelling_bee_user_guesses
      (puzzle_id, user_id, user_name, guessed_word, is_correct, created_at)
    VALUES
      (
        ${Number(puzzle_id)},
        ${user_id ? Number(user_id) : null},
        ${user_name ? String(user_name) : null},
        ${word},
        ${Boolean(is_correct)},
        ${new Date().toISOString()}
      )
  `;
}
