-- ============================================================
-- FILE: sql/score_4cc_games.sql
-- PURPOSE: Score all 4 upcoming Closest Call games using
--          simulated actuals, replicating the logic in
--          api/update-closest-call-actuals.js.
--
-- PREREQUISITE: Run questions_4cc_games.sql and
--   testusers_4cc_games.sql first.
--
-- WHAT THIS DOES (2 steps per game + 1 final step):
--   Step A — Writes actual_value onto each question and marks
--             it as 'scored'.
--   Step B — Computes ABS difference and looks up points_awarded
--             from closest_call_scoring_rules for every prediction
--             with a non-NULL predicted_value.
--   Step 5 — Sets all 4 match statuses to 'closed'.
--
-- SCORING RULES (all LEGACY_RULES — use DB table):
--   TEAM_FINAL_SCORE  → closest_call_scoring_rules WHERE rule_code='TEAM_FINAL_SCORE'
--   TEAM_PHASE_SCORE  → closest_call_scoring_rules WHERE rule_code='TEAM_PHASE_SCORE'
--   TOTAL_SIXES       → closest_call_scoring_rules WHERE rule_code='TOTAL_SIXES'
--
-- SIXES SCORING: total_sixes questions are now per-team (team_code
--   is set). The IS NOT DISTINCT FROM match on team_code in Step A
--   correctly assigns each actual to the right team's question.
--   The scoring subquery in Step B uses the same TOTAL_SIXES rule
--   regardless of whether the question is total-match or per-team.
--
-- SIMULATED ACTUALS:
--   W1  SL-W   final=138, powerplay=48, sixes=4
--       IRE-W  final=112, powerplay=38, sixes=3
--   W2  AUS-W  final=152, powerplay=52, sixes=6
--       PAK-W  final=118, powerplay=40, sixes=3
--   M1  SFU    final=162, powerplay=54, sixes=8
--       TSK    final=158, powerplay=50, sixes=7
--   M2  WF     final=168, powerplay=58, sixes=9
--       SEO    final=145, powerplay=48, sixes=6
--
-- IDEMPOTENT: Re-running will re-score already-scored predictions
--   (overwriting difference / points_awarded with the same values).
--   No status column is touched on closest_call_predictions.
-- ============================================================


-- ============================================================
-- STEP 1A: Set actuals + mark scored — W1 (SL-W vs IRE-W)
-- ============================================================
UPDATE closest_call_questions q
SET    actual_value = v.actual,
       status       = 'scored',
       updated_at   = NOW()
FROM (VALUES
  ('team_final_score'::TEXT, NULL::TEXT, 'SL-W'::TEXT,  138::INT),
  ('team_score_6',           NULL::TEXT, 'SL-W',          48),
  ('total_sixes',            NULL::TEXT, 'SL-W',           4),
  ('team_final_score',       NULL::TEXT, 'IRE-W',         112),
  ('team_score_6',           NULL::TEXT, 'IRE-W',          38),
  ('total_sixes',            NULL::TEXT, 'IRE-W',           3)
) AS v(question_type, player_name, team_code, actual)
WHERE  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026')
  AND  q.question_type IS NOT DISTINCT FROM v.question_type
  AND  q.player_name   IS NOT DISTINCT FROM v.player_name
  AND  q.team_code     IS NOT DISTINCT FROM v.team_code;


-- ============================================================
-- STEP 1B: Score predictions — W1
-- ============================================================
UPDATE closest_call_predictions p
SET    actual_value   = q.actual_value,
       difference     = ABS(p.predicted_value - q.actual_value),
       points_awarded = COALESCE((
         SELECT sr.points
         FROM   closest_call_scoring_rules sr
         WHERE  sr.rule_code = q.scoring_rule_code
           AND  sr.min_diff <= ABS(p.predicted_value - q.actual_value)
           AND  (sr.max_diff IS NULL OR sr.max_diff >= ABS(p.predicted_value - q.actual_value))
         ORDER  BY sr.min_diff DESC
         LIMIT  1
       ), 0),
       updated_at = NOW()
FROM   closest_call_questions q
WHERE  p.question_id           = q.id
  AND  q.status                = 'scored'
  AND  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026')
  AND  p.predicted_value IS NOT NULL;


-- ============================================================
-- STEP 2A: Set actuals + mark scored — W2 (AUS-W vs PAK-W)
-- ============================================================
UPDATE closest_call_questions q
SET    actual_value = v.actual,
       status       = 'scored',
       updated_at   = NOW()
FROM (VALUES
  ('team_final_score'::TEXT, NULL::TEXT, 'AUS-W'::TEXT, 152::INT),
  ('team_score_6',           NULL::TEXT, 'AUS-W',         52),
  ('total_sixes',            NULL::TEXT, 'AUS-W',          6),
  ('team_final_score',       NULL::TEXT, 'PAK-W',         118),
  ('team_score_6',           NULL::TEXT, 'PAK-W',          40),
  ('total_sixes',            NULL::TEXT, 'PAK-W',           3)
) AS v(question_type, player_name, team_code, actual)
WHERE  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'AUS-W vs PAK-W — WT20 WC 2026')
  AND  q.question_type IS NOT DISTINCT FROM v.question_type
  AND  q.player_name   IS NOT DISTINCT FROM v.player_name
  AND  q.team_code     IS NOT DISTINCT FROM v.team_code;


-- ============================================================
-- STEP 2B: Score predictions — W2
-- ============================================================
UPDATE closest_call_predictions p
SET    actual_value   = q.actual_value,
       difference     = ABS(p.predicted_value - q.actual_value),
       points_awarded = COALESCE((
         SELECT sr.points
         FROM   closest_call_scoring_rules sr
         WHERE  sr.rule_code = q.scoring_rule_code
           AND  sr.min_diff <= ABS(p.predicted_value - q.actual_value)
           AND  (sr.max_diff IS NULL OR sr.max_diff >= ABS(p.predicted_value - q.actual_value))
         ORDER  BY sr.min_diff DESC
         LIMIT  1
       ), 0),
       updated_at = NOW()
FROM   closest_call_questions q
WHERE  p.question_id           = q.id
  AND  q.status                = 'scored'
  AND  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'AUS-W vs PAK-W — WT20 WC 2026')
  AND  p.predicted_value IS NOT NULL;


-- ============================================================
-- STEP 3A: Set actuals + mark scored — M1 (SFU vs TSK)
-- ============================================================
UPDATE closest_call_questions q
SET    actual_value = v.actual,
       status       = 'scored',
       updated_at   = NOW()
FROM (VALUES
  ('team_final_score'::TEXT, NULL::TEXT, 'SFU'::TEXT, 162::INT),
  ('team_score_6',           NULL::TEXT, 'SFU',         54),
  ('total_sixes',            NULL::TEXT, 'SFU',          8),
  ('team_final_score',       NULL::TEXT, 'TSK',         158),
  ('team_score_6',           NULL::TEXT, 'TSK',          50),
  ('total_sixes',            NULL::TEXT, 'TSK',           7)
) AS v(question_type, player_name, team_code, actual)
WHERE  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026')
  AND  q.question_type IS NOT DISTINCT FROM v.question_type
  AND  q.player_name   IS NOT DISTINCT FROM v.player_name
  AND  q.team_code     IS NOT DISTINCT FROM v.team_code;


-- ============================================================
-- STEP 3B: Score predictions — M1
-- ============================================================
UPDATE closest_call_predictions p
SET    actual_value   = q.actual_value,
       difference     = ABS(p.predicted_value - q.actual_value),
       points_awarded = COALESCE((
         SELECT sr.points
         FROM   closest_call_scoring_rules sr
         WHERE  sr.rule_code = q.scoring_rule_code
           AND  sr.min_diff <= ABS(p.predicted_value - q.actual_value)
           AND  (sr.max_diff IS NULL OR sr.max_diff >= ABS(p.predicted_value - q.actual_value))
         ORDER  BY sr.min_diff DESC
         LIMIT  1
       ), 0),
       updated_at = NOW()
FROM   closest_call_questions q
WHERE  p.question_id           = q.id
  AND  q.status                = 'scored'
  AND  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026')
  AND  p.predicted_value IS NOT NULL;


-- ============================================================
-- STEP 4A: Set actuals + mark scored — M2 (WF vs SEO)
-- ============================================================
UPDATE closest_call_questions q
SET    actual_value = v.actual,
       status       = 'scored',
       updated_at   = NOW()
FROM (VALUES
  ('team_final_score'::TEXT, NULL::TEXT, 'WF'::TEXT,  168::INT),
  ('team_score_6',           NULL::TEXT, 'WF',          58),
  ('total_sixes',            NULL::TEXT, 'WF',           9),
  ('team_final_score',       NULL::TEXT, 'SEO',         145),
  ('team_score_6',           NULL::TEXT, 'SEO',          48),
  ('total_sixes',            NULL::TEXT, 'SEO',           6)
) AS v(question_type, player_name, team_code, actual)
WHERE  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026')
  AND  q.question_type IS NOT DISTINCT FROM v.question_type
  AND  q.player_name   IS NOT DISTINCT FROM v.player_name
  AND  q.team_code     IS NOT DISTINCT FROM v.team_code;


-- ============================================================
-- STEP 4B: Score predictions — M2
-- ============================================================
UPDATE closest_call_predictions p
SET    actual_value   = q.actual_value,
       difference     = ABS(p.predicted_value - q.actual_value),
       points_awarded = COALESCE((
         SELECT sr.points
         FROM   closest_call_scoring_rules sr
         WHERE  sr.rule_code = q.scoring_rule_code
           AND  sr.min_diff <= ABS(p.predicted_value - q.actual_value)
           AND  (sr.max_diff IS NULL OR sr.max_diff >= ABS(p.predicted_value - q.actual_value))
         ORDER  BY sr.min_diff DESC
         LIMIT  1
       ), 0),
       updated_at = NOW()
FROM   closest_call_questions q
WHERE  p.question_id           = q.id
  AND  q.status                = 'scored'
  AND  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026')
  AND  p.predicted_value IS NOT NULL;


-- ============================================================
-- STEP 5: Close all 4 matches
-- ============================================================
UPDATE closest_call_matches
SET    status     = 'closed',
       updated_at = NOW()
WHERE  match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
);


-- ============================================================
-- VERIFICATION
-- ============================================================

-- 1. Confirm all 4 matches are now closed
SELECT match_title, status, updated_at
FROM   closest_call_matches
WHERE  match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
)
ORDER  BY match_title;

-- 2. Confirm all questions for these matches are scored
SELECT
  ccm.match_title,
  COUNT(ccq.id)                                              AS total_questions,
  SUM(CASE WHEN ccq.status = 'scored'    THEN 1 END)        AS scored,
  SUM(CASE WHEN ccq.actual_value IS NULL THEN 1 END)        AS missing_actual
FROM  closest_call_matches ccm
JOIN  closest_call_questions ccq ON ccq.closest_call_match_id = ccm.id
WHERE ccm.match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
)
GROUP BY ccm.match_title
ORDER BY ccm.match_title;

-- 3. Leaderboard snapshot — points per user per match
SELECT
  ccm.match_title,
  u.user_name,
  SUM(p.points_awarded)                         AS total_points,
  COUNT(CASE WHEN p.difference = 0 THEN 1 END)  AS exact_calls,
  COUNT(p.id)                                   AS predictions_scored
FROM   closest_call_predictions p
JOIN   ipl_users             u   ON u.id   = p.user_id
JOIN   closest_call_questions q  ON q.id   = p.question_id
JOIN   closest_call_matches   ccm ON ccm.id = p.closest_call_match_id
WHERE  u.user_name IN ('ami_kolkata','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  ccm.match_title IN (
         'SL-W vs IRE-W — WT20 WC 2026',
         'AUS-W vs PAK-W — WT20 WC 2026',
         'SF Unicorns vs Texas Super Kings — MLC 2026',
         'Washington Freedom vs Seattle Orcas — MLC 2026'
       )
  AND  q.status = 'scored'
GROUP  BY ccm.match_title, u.user_name
ORDER  BY ccm.match_title, total_points DESC;

-- 4. Grand total points per user across all 4 games
SELECT
  u.user_name,
  SUM(p.points_awarded) AS grand_total_points
FROM   closest_call_predictions p
JOIN   ipl_users             u   ON u.id   = p.user_id
JOIN   closest_call_questions q  ON q.id   = p.question_id
JOIN   closest_call_matches   ccm ON ccm.id = p.closest_call_match_id
WHERE  u.user_name IN ('ami_kolkata','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  ccm.match_title IN (
         'SL-W vs IRE-W — WT20 WC 2026',
         'AUS-W vs PAK-W — WT20 WC 2026',
         'SF Unicorns vs Texas Super Kings — MLC 2026',
         'Washington Freedom vs Seattle Orcas — MLC 2026'
       )
  AND  q.status = 'scored'
GROUP  BY u.user_name
ORDER  BY grand_total_points DESC;
