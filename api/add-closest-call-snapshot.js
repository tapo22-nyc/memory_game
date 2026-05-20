const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

// Maps snapshot phase → question_type(s) to update
const PHASE_TO_QUESTION_TYPE = {
  six_overs:    ['team_score_6'],
  twelve_overs: ['team_score_12'],
  final:        ['team_final_score'],
};

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

  const {
    closest_call_match_id,
    innings_number,
    batting_team,
    phase,
    overs,
    runs,
    wickets,
    fantasy_match_id,
  } = req.body || {};

  if (!closest_call_match_id || !innings_number || !batting_team || !phase || runs === undefined) {
    return res.status(400).json({
      error: 'closest_call_match_id, innings_number, batting_team, phase, and runs are required.',
    });
  }

  const matchId = Number(closest_call_match_id);
  const inningsNum = Number(innings_number);
  const runsVal = Number(runs);
  const wicketsVal = wickets !== undefined ? Number(wickets) : null;
  const oversVal = overs !== undefined ? Number(overs) : null;
  const fantasyMatchId = fantasy_match_id ? Number(fantasy_match_id) : null;

  try {
    // Upsert snapshot
    const snapRows = await sql`
      INSERT INTO closest_call_score_snapshots
        (closest_call_match_id, fantasy_match_id, innings_number, batting_team,
         phase, overs, runs, wickets, source, updated_at)
      VALUES
        (${matchId}, ${fantasyMatchId}, ${inningsNum}, ${batting_team},
         ${phase}, ${oversVal}, ${runsVal}, ${wicketsVal}, 'manual', NOW())
      ON CONFLICT (closest_call_match_id, innings_number, phase) DO UPDATE SET
        runs         = EXCLUDED.runs,
        wickets      = EXCLUDED.wickets,
        overs        = EXCLUDED.overs,
        updated_at   = NOW()
      RETURNING *
    `;
    const snapshot = snapRows[0];

    // Find matching question types for this phase
    const questionTypes = PHASE_TO_QUESTION_TYPE[phase] || [];
    if (!questionTypes.length) {
      return res.status(200).json({
        success: true,
        snapshot,
        scored_questions: 0,
        message: `Snapshot saved. No question types mapped to phase '${phase}'.`,
      });
    }

    // Find related questions for this match, team, innings, and question type
    const questions = await sql`
      SELECT * FROM closest_call_questions
      WHERE closest_call_match_id = ${matchId}
        AND team_code = ${batting_team}
        AND innings_number = ${inningsNum}
        AND question_type = ANY(${questionTypes})
        AND status NOT IN ('void')
    `;

    let scoredCount = 0;

    for (const q of questions) {
      // Update question actual value and mark scored
      await sql`
        UPDATE closest_call_questions
        SET actual_value = ${runsVal},
            status       = 'scored',
            updated_at   = NOW()
        WHERE id = ${q.id}
      `;

      // Score all predictions for this question
      const preds = await sql`
        SELECT id, predicted_value FROM closest_call_predictions
        WHERE question_id = ${q.id}
      `;

      for (const pred of preds) {
        const difference = Math.abs(pred.predicted_value - runsVal);
        const points     = await getPoints(q.scoring_rule_code, difference);

        await sql`
          UPDATE closest_call_predictions
          SET actual_value   = ${runsVal},
              difference     = ${difference},
              points_awarded = ${points},
              updated_at     = NOW()
          WHERE id = ${pred.id}
        `;
      }

      scoredCount++;
    }

    return res.status(200).json({
      success: true,
      snapshot,
      scored_questions: scoredCount,
    });

  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
};
