const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  try {
    const { user_id, match_id } = req.query;

    if (!user_id || !match_id) {
      return res.status(400).json({ error: 'user_id and match_id are required' });
    }

    const results = await sql`
      SELECT
        q.id AS question_id,
        q.question_text,

        selected_o.id AS selected_option_id,
        selected_o.option_text AS selected_answer,

        correct_o.id AS correct_option_id,
        correct_o.option_text AS correct_answer,

        p.is_correct,
        p.points_spent,
        p.points_won
      FROM ipl_questions q
      LEFT JOIN ipl_predictions p
        ON q.id = p.question_id
        AND p.user_id = ${Number(user_id)}
        AND p.match_id = ${Number(match_id)}
      LEFT JOIN ipl_options selected_o
        ON p.selected_option_id = selected_o.id
      LEFT JOIN ipl_options correct_o
        ON q.correct_option_id = correct_o.id
      WHERE q.match_id = ${Number(match_id)}
      ORDER BY q.id ASC
    `;

    res.status(200).json({ results });
  } catch (error) {
    console.error('get-ipl-user-results error:', error);
    res.status(500).json({ error: error.message || 'Could not load results.' });
  }
};
