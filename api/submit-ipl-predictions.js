const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests are allowed.' });
  }

  try {
    const { user_id, match_id } = req.body;

    // Accept both 'predictions' and 'picks' from frontend
    const predictions = req.body.predictions || req.body.picks;

    if (!user_id || !match_id || !Array.isArray(predictions) || predictions.length === 0) {
      return res.status(400).json({
        error: 'user_id, match_id, and predictions/picks are required.'
      });
    }

    for (const pick of predictions) {
      if (!pick.question_id || !pick.selected_option_id) {
        return res.status(400).json({
          error: 'Each prediction needs question_id and selected_option_id.'
        });
      }

      await sql`
        INSERT INTO ipl_predictions
          (user_id, match_id, question_id, selected_option_id, points_spent)
        VALUES
          (
            ${Number(user_id)},
            ${Number(match_id)},
            ${Number(pick.question_id)},
            ${Number(pick.selected_option_id)},
            5
          )
        ON CONFLICT (user_id, question_id)
        DO UPDATE SET
          selected_option_id = EXCLUDED.selected_option_id,
          points_spent = EXCLUDED.points_spent,
          points_won = 0,
          is_correct = NULL,
          created_at = CURRENT_TIMESTAMP
      `;
    }

    res.status(200).json({
      success: true,
      message: 'Predictions saved successfully.',
      saved_count: predictions.length
    });

  } catch (error) {
    console.error('submit-ipl-predictions error:', error);
    res.status(500).json({
      error: error.message || 'Could not save predictions.'
    });
  }
};
