const { neon } = require('@neondatabase/serverless');

const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests are allowed.' });
  }

  try {
    const { user_id, match_id } = req.body;
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
            0
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

    const answerCheck = await sql`
      SELECT 
        COUNT(*) AS total_questions,
        COUNT(correct_option_id) AS answered_questions
      FROM ipl_questions
      WHERE match_id = ${Number(match_id)}
    `;

    const totalQuestions = Number(answerCheck[0].total_questions);
    const answeredQuestions = Number(answerCheck[0].answered_questions);

    if (totalQuestions > 0 && totalQuestions === answeredQuestions) {
      await sql`
        UPDATE ipl_predictions p
        SET is_correct = CASE 
          WHEN p.selected_option_id = q.correct_option_id THEN TRUE
          ELSE FALSE
        END
        FROM ipl_questions q
        WHERE p.question_id = q.id
          AND p.match_id = ${Number(match_id)}
      `;

      await sql`
        UPDATE ipl_predictions
        SET points_won = 20
        WHERE match_id = ${Number(match_id)}
          AND is_correct = TRUE
      `;

      await sql`
        UPDATE ipl_predictions
        SET points_won = 0
        WHERE match_id = ${Number(match_id)}
          AND is_correct = FALSE
      `;

      await sql`
        INSERT INTO ipl_user_match_scores
          (user_id, match_id, total_entry_points, total_points_won, net_points, correct_answers)
        SELECT
          user_id,
          match_id,
          SUM(points_spent) AS total_entry_points,
          SUM(points_won) AS total_points_won,
          SUM(points_won) - SUM(points_spent) AS net_points,
          COUNT(*) FILTER (WHERE is_correct = TRUE) AS correct_answers
        FROM ipl_predictions
        WHERE match_id = ${Number(match_id)}
        GROUP BY user_id, match_id
        ON CONFLICT (user_id, match_id)
        DO UPDATE SET
          total_entry_points = EXCLUDED.total_entry_points,
          total_points_won = EXCLUDED.total_points_won,
          net_points = EXCLUDED.net_points,
          correct_answers = EXCLUDED.correct_answers,
          calculated_at = CURRENT_TIMESTAMP
      `;
    }

    res.status(200).json({
      success: true,
      message: totalQuestions === answeredQuestions
        ? 'Predictions saved and scores recalculated.'
        : 'Predictions saved. Scores will calculate after correct answers are entered.',
      scores_calculated: totalQuestions === answeredQuestions,
      saved_count: predictions.length
    });

  } catch (error) {
    console.error('submit-ipl-predictions error:', error);
    res.status(500).json({
      error: error.message || 'Could not save predictions.'
    });
  }
};
