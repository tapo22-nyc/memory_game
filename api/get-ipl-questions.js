const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const { match_id } = req.query;

    if (!match_id) {
      return res.status(400).json({ error: 'match_id is required' });
    }

    const questions = await sql`
      SELECT 
        q.id AS question_id,
        q.question_text,
        q.entry_fee,
        q.reward_pool,
        o.id AS option_id,
        o.option_text,
        o.option_order
      FROM ipl_questions q
      JOIN ipl_options o
        ON q.id = o.question_id
      WHERE q.match_id = ${match_id}
      ORDER BY q.id, o.option_order
    `;

    res.status(200).json({ questions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};
