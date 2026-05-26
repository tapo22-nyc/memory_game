const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Only POST requests allowed.' });
  }

  const { user_name, closest_call_match_id, predictions } = req.body || {};

  if (!user_name) {
    return res.status(400).json({ error: 'user_name is required.' });
  }
  if (!closest_call_match_id) {
    return res.status(400).json({ error: 'closest_call_match_id is required.' });
  }
  if (!Array.isArray(predictions) || predictions.length === 0) {
    return res.status(400).json({ error: 'predictions array is required.' });
  }

  const matchId   = Number(closest_call_match_id);
  const cleanName = String(user_name).trim().toLowerCase().replace(/[^a-z0-9_]/g, '');
  if (cleanName.length < 3) {
    return res.status(400).json({ error: 'user_name must be at least 3 characters.' });
  }

  try {
    // Get or create user
    const users = await sql`
      INSERT INTO ipl_users (user_name, total_points)
      VALUES (${cleanName}, 100)
      ON CONFLICT (user_name)
      DO UPDATE SET user_name = EXCLUDED.user_name
      RETURNING id, user_name
    `;
    const user = users[0];

    // Get match
    const matches = await sql`
      SELECT * FROM closest_call_matches WHERE id = ${matchId} LIMIT 1
    `;
    if (!matches.length) {
      return res.status(404).json({ error: 'Match not found.' });
    }
    const match = matches[0];
    if (match.status === 'closed') {
      return res.status(400).json({ error: 'Match is closed. Predictions cannot be submitted.' });
    }
    if (match.status === 'locked') {
      // Pre-match predictions are frozen once the match starts.
      // Bonus (non-pre_match) questions may still be open — those are validated per-question below.
      const preMatchIds = predictions.map(p => Number(p.question_id));
      if (preMatchIds.length) {
        const preMatchQs = await sql`
          SELECT id FROM closest_call_questions
          WHERE id = ANY(${preMatchIds})
            AND closest_call_match_id = ${matchId}
            AND phase = 'pre_match'
        `;
        if (preMatchQs.length > 0) {
          return res.status(400).json({
            error: 'Match is in progress. Pre-match predictions are now locked.',
          });
        }
      }
    }

    const now = new Date();
    const saved = [];
    const errors = [];

    for (const pred of predictions) {
      const questionId = Number(pred.question_id);

      if (isNaN(questionId) || questionId <= 0) {
        errors.push({ question_id: pred.question_id, error: 'Invalid question_id.' });
        continue;
      }

      // Fetch question
      const questions = await sql`
        SELECT * FROM closest_call_questions
        WHERE id = ${questionId} AND closest_call_match_id = ${matchId}
        LIMIT 1
      `;
      if (!questions.length) {
        errors.push({ question_id: questionId, error: 'Question not found for this match.' });
        continue;
      }
      const q = questions[0];

      // Check editability
      if (q.status !== 'open') {
        errors.push({ question_id: questionId, error: `Question is ${q.status} and cannot be edited.` });
        continue;
      }
      const lockTime = q.lock_time ? new Date(q.lock_time) : null;
      if (lockTime && now >= lockTime) {
        errors.push({ question_id: questionId, error: 'Prediction window has closed for this question.' });
        continue;
      }
      const openTime = q.open_time ? new Date(q.open_time) : null;
      if (openTime && now < openTime) {
        errors.push({ question_id: questionId, error: 'This question is not yet open for predictions.' });
        continue;
      }

      const ruleCode = q.scoring_rule_code || '';

      // Determine prediction type based on scoring rule
      if (ruleCode === 'TEAM_SCORE_SPLIT_75_25' || ruleCode === 'TEAM_SCORE_INNINGS') {
        // Expects predicted_runs + predicted_wickets
        const pRuns    = parseInt(pred.predicted_runs,    10);
        const pWickets = parseInt(pred.predicted_wickets, 10);
        if (isNaN(pRuns) || pRuns < 0) {
          errors.push({ question_id: questionId, error: 'predicted_runs must be a non-negative integer for TEAM_SCORE_SPLIT_75_25.' });
          continue;
        }
        if (isNaN(pWickets) || pWickets < 0 || pWickets > 10) {
          errors.push({ question_id: questionId, error: 'predicted_wickets must be 0-10 for TEAM_SCORE_SPLIT_75_25.' });
          continue;
        }
        const result = await sql`
          INSERT INTO closest_call_predictions
            (user_id, closest_call_match_id, question_id, predicted_value,
             predicted_runs, predicted_wickets, submitted_at, updated_at)
          VALUES
            (${user.id}, ${matchId}, ${questionId}, ${pRuns},
             ${pRuns}, ${pWickets}, NOW(), NOW())
          ON CONFLICT (user_id, question_id)
          DO UPDATE SET
            predicted_value   = EXCLUDED.predicted_value,
            predicted_runs    = EXCLUDED.predicted_runs,
            predicted_wickets = EXCLUDED.predicted_wickets,
            updated_at        = NOW()
          RETURNING *
        `;
        saved.push(result[0]);

      } else if (ruleCode === 'CATEGORICAL_EXACT') {
        // Expects predicted_choice (string)
        const pChoice = String(pred.predicted_choice || '').trim();
        if (!pChoice) {
          errors.push({ question_id: questionId, error: 'predicted_choice is required for CATEGORICAL_EXACT questions.' });
          continue;
        }
        // Validate against question_options if set
        if (q.question_options && Array.isArray(q.question_options)) {
          if (!q.question_options.includes(pChoice)) {
            errors.push({ question_id: questionId, error: 'predicted_choice is not a valid option.' });
            continue;
          }
        }
        const result = await sql`
          INSERT INTO closest_call_predictions
            (user_id, closest_call_match_id, question_id, predicted_value,
             predicted_choice, submitted_at, updated_at)
          VALUES
            (${user.id}, ${matchId}, ${questionId}, 0,
             ${pChoice}, NOW(), NOW())
          ON CONFLICT (user_id, question_id)
          DO UPDATE SET
            predicted_value  = 0,
            predicted_choice = EXCLUDED.predicted_choice,
            updated_at       = NOW()
          RETURNING *
        `;
        saved.push(result[0]);

      } else {
        // Default: numeric predicted_value
        const predictedValue = parseInt(pred.predicted_value, 10);
        if (isNaN(predictedValue) || predictedValue < 0) {
          errors.push({ question_id: questionId, error: 'predicted_value must be a non-negative integer.' });
          continue;
        }
        const result = await sql`
          INSERT INTO closest_call_predictions
            (user_id, closest_call_match_id, question_id, predicted_value, submitted_at, updated_at)
          VALUES
            (${user.id}, ${matchId}, ${questionId}, ${predictedValue}, NOW(), NOW())
          ON CONFLICT (user_id, question_id)
          DO UPDATE SET
            predicted_value = EXCLUDED.predicted_value,
            updated_at      = NOW()
          RETURNING *
        `;
        saved.push(result[0]);
      }
    }

    return res.status(200).json({
      success: true,
      user,
      saved,
      errors: errors.length ? errors : undefined,
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
