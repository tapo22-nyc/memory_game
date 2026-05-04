const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const { user_id, match_id } = req.query;

    if (!user_id || !match_id) {
      return res.status(400).json({ error: 'user_id and match_id are required' });
    }

    const predictions = await sql`
      SELECT
        question_id,
        selected_option_id
      FROM ipl_predictions
      WHERE user_id = ${Number(user_id)}
        AND match_id = ${Number(match_id)}
      ORDER BY question_id ASC
    `;

    res.status(200).json({ predictions });
  } catch (error) {
    console.error('get-ipl-user-predictions error:', error);
    res.status(500).json({ error: error.message || 'Could not load predictions.' });
  }
};
