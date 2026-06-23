const { neon } = require('@neondatabase/serverless');
const sql = neon(process.env.DATABASE_URL);

// DB-based scoring for legacy rules
async function getPointsFromDB(ruleCode, difference) {
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

// Legacy rules that use the DB table
const LEGACY_RULES = new Set([
  'TEAM_PHASE_SCORE',
  'TEAM_FINAL_SCORE',
  'BATTER_RUNS',
  'BOWLER_WICKETS',
  'TOTAL_SIXES',
]);

// Rules that require dual runs+wickets input (kept for historical scored questions only)
const DUAL_INPUT_RULES = new Set([
  'TEAM_SCORE_SPLIT_75_25',
  'TEAM_SCORE_INNINGS',
]);

// Score the wickets component for dual-input team score rules (historical)
function computeWicketsPoints(ruleCode, wicketsDiff) {
  if (ruleCode === 'TEAM_SCORE_INNINGS') {
    if (wicketsDiff === 0) return 25;
    if (wicketsDiff === 1) return 20;
    if (wicketsDiff === 2) return 10;
    return 0;
  }
  // TEAM_SCORE_SPLIT_75_25 (historical)
  if (wicketsDiff === 0) return 25;
  if (wicketsDiff === 1) return 20;
  if (wicketsDiff === 2) return 10;
  if (wicketsDiff === 3) return 5;
  return 0;
}

// Score the runs component for dual-input team score rules (historical)
function computeRunsPoints(ruleCode, runsDiff) {
  if (ruleCode === 'TEAM_SCORE_INNINGS') {
    return runsDiff >= 40 ? 0 : Math.max(75 - runsDiff, 0);
  }
  // TEAM_SCORE_SPLIT_75_25 (historical)
  return Math.max(75 - runsDiff, 0);
}

// Code-based scoring for single-value rules
function computePointsCode(ruleCode, diff) {
  // ── Active rules (MLC 2026 / WWC 2026 and future tournaments) ──────────
  if (ruleCode === 'TEAM_SCORE_50') {
    // Team final innings score: max 50, -1 pt per run, 0 if diff > 40
    return diff > 40 ? 0 : 50 - diff;
  }
  if (ruleCode === 'POWERPLAY_SCORE_30') {
    // Powerplay (6-over) score: max 30, -1 pt per run, 0 if diff > 20
    return diff > 20 ? 0 : 30 - diff;
  }
  if (ruleCode === 'BATTER_SCORE_20') {
    // Individual batter runs: max 20, -1 pt per run, 0 if diff > 20
    return diff > 20 ? 0 : 20 - diff;
  }
  if (ruleCode === 'TEAM_SIXES_10') {
    // Total team sixes in match: max 10, -1 pt per six, 0 if diff > 5
    return diff > 5 ? 0 : 10 - diff;
  }
  if (ruleCode === 'BOWLER_WICKETS_10') {
    // Bowler wickets: max 10, 0 if diff >= 3
    if (diff === 0) return 10;
    if (diff === 1) return 9;
    if (diff === 2) return 8;
    return 0;
  }
  // ── Categorical ─────────────────────────────────────────────────────────
  if (ruleCode === 'CATEGORICAL_EXACT') {
    return diff === 0 ? 100 : 0;
  }
  // ── Historical rules (no longer assigned to new questions) ──────────────
  if (ruleCode === 'BATSMAN_RUNS_INNINGS') {
    return diff >= 30 ? 0 : Math.max(50 - diff, 0);
  }
  if (ruleCode === 'BATSMAN_SIXES_INNINGS') {
    if (diff <= 1) return 20;
    if (diff === 2) return 10;
    return 0;
  }
  if (ruleCode === 'BOWLER_WICKETS_INNINGS' || ruleCode === 'BOWLER_WICKETS_30') {
    if (diff === 0) return 30;
    if (diff === 1) return 20;
    if (diff === 2) return 10;
    return 0;
  }
  if (ruleCode === 'DEATH_OVERS_RUNS') {
    return diff >= 20 ? 0 : Math.max(40 - diff, 0);
  }
  if (ruleCode === 'DEATH_OVERS_WICKETS') {
    if (diff === 0) return 15;
    if (diff === 1) return 10;
    if (diff === 2) return 5;
    return 0;
  }
  if (ruleCode === 'DEATH_OVERS_SIXES' || ruleCode === 'DEATH_OVERS_DOT_BALLS') {
    return diff >= 4 ? 0 : Math.max(10 - diff, 0);
  }
  if (ruleCode === 'BATTER_RUNS_50') {
    return Math.max(50 - diff, 0);
  }
  if (ruleCode === 'BATTER_SIXES_20') {
    if (diff === 0) return 20;
    if (diff === 1) return 15;
    if (diff === 2) return 10;
    return 0;
  }
  if (ruleCode === 'IPL_SIXES_TOTAL_100') {
    return Math.max(100 - Math.floor(diff / 5) * 5, 0);
  }
  // TEAM_SCORE_SPLIT_75_25 / TEAM_SCORE_INNINGS handled separately (dual input)
  return null; // unknown rule — fall back to DB
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
      const questionId = Number(update.question_id);
      if (isNaN(questionId)) continue;

      const ruleCodeRaw = String(update.scoring_rule_code || '').trim() || null;

      // ── Dual-input team score rules ─────────────────────────────────────
      if (
        DUAL_INPUT_RULES.has(ruleCodeRaw) ||
        update.actual_runs !== undefined ||
        update.actual_wickets !== undefined
      ) {
        const actualRuns    = parseInt(update.actual_runs,    10);
        const actualWickets = parseInt(update.actual_wickets, 10);
        if (isNaN(actualRuns) || isNaN(actualWickets)) continue;

        // Update question with actual_runs and actual_wickets
        const qRows = await sql`
          UPDATE closest_call_questions
          SET actual_value   = ${actualRuns},
              actual_runs    = ${actualRuns},
              actual_wickets = ${actualWickets},
              status         = 'scored',
              updated_at     = NOW()
          WHERE id = ${questionId} AND closest_call_match_id = ${matchId}
          RETURNING id, scoring_rule_code
        `;
        if (!qRows.length) continue;

        const ruleCode = qRows[0].scoring_rule_code;

        // Score each prediction
        const predictions = await sql`
          SELECT id, predicted_runs, predicted_wickets, predicted_value
          FROM closest_call_predictions
          WHERE question_id = ${questionId}
        `;

        for (const pred of predictions) {
          const predRuns    = pred.predicted_runs    !== null ? Number(pred.predicted_runs)    : Number(pred.predicted_value);
          const predWickets = pred.predicted_wickets !== null ? Number(pred.predicted_wickets) : 0;

          const runsDiff    = Math.abs(predRuns    - actualRuns);
          const wicketsDiff = Math.abs(predWickets - actualWickets);

          const runsPts    = computeRunsPoints(ruleCode, runsDiff);
          const wicketsPts = computeWicketsPoints(ruleCode, wicketsDiff);

          const totalPts = runsPts + wicketsPts;
          const displayDiff = runsDiff; // runs difference for display

          await sql`
            UPDATE closest_call_predictions
            SET actual_value      = ${actualRuns},
                difference        = ${displayDiff},
                points_awarded    = ${totalPts},
                predicted_runs    = COALESCE(predicted_runs, ${predRuns}),
                predicted_wickets = COALESCE(predicted_wickets, ${predWickets}),
                updated_at        = NOW()
            WHERE id = ${pred.id}
          `;
        }

        updatedCount++;
        continue;
      }

      // ── Standard numeric / categorical ──────────────────────────────────
      const actualValue = parseInt(update.actual_value, 10);
      if (isNaN(actualValue)) continue;

      // Update question
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
        SELECT id, predicted_value, predicted_choice
        FROM closest_call_predictions
        WHERE question_id = ${questionId}
      `;

      for (const pred of predictions) {
        let difference = 0;
        let points     = 0;

        if (ruleCode === 'CATEGORICAL_EXACT') {
          // Compare predicted_choice against actual_value string
          const choice = pred.predicted_choice !== null ? String(pred.predicted_choice) : null;
          const actual = String(update.actual_value);
          difference = (choice === actual) ? 0 : 1;
          points     = difference === 0 ? 100 : 0;
        } else {
          difference = Math.abs(Number(pred.predicted_value) - actualValue);

          if (LEGACY_RULES.has(ruleCode)) {
            points = await getPointsFromDB(ruleCode, difference);
          } else {
            const coded = computePointsCode(ruleCode, difference);
            if (coded !== null) {
              points = coded;
            } else {
              // Unknown rule — fall back to DB
              points = await getPointsFromDB(ruleCode, difference);
            }
          }
        }

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
