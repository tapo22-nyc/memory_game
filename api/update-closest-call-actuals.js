const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

async function getPoints(ruleCode, difference) {
  const rules = await sql`
    SELECT points FROM closest_call_scoring_rules
    WHERE rule_code = ${ruleCode}
      AND min_diff <= ${difference}
      AND (max_diff IS NULL OR max_diff >= ${difference})
    ORDER BY min_diff DESC
    LIMIT 1
  `;
  return rules.length ? Number(rules[0].points) : 0;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests allowed.' });
  }

  const { closest_call_match_id, question_updates } = req.body || {};

  if (!closest_call_match_id) {
    return res.status(400).json({ error: 'closest_call_match_id is required.' });
  }
  if (!Array.isArray(question_updates) || question_updates.length === 0) {
    return res.status(400).json({ error: 'question_updates array is required.' });
  }

  const matchId = Number(closest_call_match_id);

  try {
    let updatedCount = 0;

    for (const update of question_updates) {
      const questionId  = Number(update.question_id);
      const actualValue = parseInt(update.actual_value, 10);

      if (isNaN(questionId) || isNaN(actualValue)) continue;

      // Update the question with actual value and mark as scored
      const qRows = await sql`
        UPDATE closest_call_questions
        SET actual_value = ${actualValue},
            status       = 'scored',
            updated_at   = NOW()
        WHERE id = ${questionId} AND closest_call_match_id = ${matchId}
        RETURNING id, scoring_rule_code
      `;
      if (!qRows.length) continue;

      const ruleCode = qRows[0].scoring_rule_code;

      // Update all predictions for this question
      const predictions = await sql`
        SELECT id, predicted_value
        FROM closest_call_predictions
        WHERE question_id = ${questionId}
      `;

      for (const pred of predictions) {
        const difference = Math.abs(pred.predicted_value - actualValue);
        const points     = await getPoints(ruleCode, difference);

        await sql`
          UPDATE closest_call_predictions
          SET actual_value   = ${actualValue},
              difference     = ${difference},
              points_awarded = ${points},
              updated_at     = NOW()
          WHERE id = ${pred.id}
        `;
      }

      updatedCount++;
    }

    return res.status(200).json({
      success: true,
      updated_questions: updatedCount,
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
