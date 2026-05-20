const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { puzzle_id } = req.query || {};

    if (!puzzle_id) {
      return res.status(400).json({ error: 'puzzle_id is required' });
    }

    const words = await sql`
      SELECT word, is_pangram
      FROM spelling_bee_words
      WHERE puzzle_id = ${Number(puzzle_id)}
      ORDER BY word ASC
    `;

    return res.status(200).json({ puzzle_id: Number(puzzle_id), words });
  } catch (error) {
    console.error('get-spelling-bee-answers error:', error);
    return res.status(500).json({ error: error.message });
  }
};
