-- ============================================================
-- FILE: sql/score_closest_call_test_games.sql
-- PURPOSE: Score both test matches using simulated actuals
--          defined in insert_closest_call_test_predictions.sql.
--
-- TEST GAME 1: [TEST] IND-W vs PAK-W — WT20 WC
-- TEST GAME 2: [TEST] TSK vs MI New York — MLC 2026
--
-- PREREQUISITES:
--   1. insert_closest_call_test_games.sql must have been run
--   2. insert_closest_call_test_predictions.sql must have been run
--
-- WHAT THIS DOES:
--   Step 1 & 3 — Writes actual values onto each question and
--                marks them as 'scored'
--   Step 2 & 4 — Computes difference and looks up points_awarded
--                from closest_call_scoring_rules for every
--                prediction, replicating the logic in
--                api/update-closest-call-actuals.js
--   Step 5     — Sets both match statuses to 'closed'
-- ============================================================


-- ============================================================
-- STEP 1: Set actuals + mark scored — Game 1 (IND-W vs PAK-W)
-- ============================================================
UPDATE closest_call_questions q
SET    actual_value = v.actual,
       status       = 'scored',
       updated_at   = NOW()
FROM (VALUES
  ('batter_runs'::TEXT,      'Smriti Mandhana'::TEXT, 'IND-W'::TEXT,    42::INT),
  ('batter_runs',            'Shafali Verma',          'IND-W',           28),
  ('batter_runs',            'Bismah Maroof',           'PAK-W',           15),
  ('bowler_wickets',         'Deepti Sharma',           'IND-W',            2),
  ('total_sixes',            NULL::TEXT,                NULL::TEXT,         8),
  ('team_score_6',           NULL::TEXT,                'IND-W',           52),
  ('team_score_12',          NULL::TEXT,                'IND-W',           98),
  ('team_final_score',       NULL::TEXT,                'IND-W',          147),
  ('team_score_6',           NULL::TEXT,                'PAK-W',           35),
  ('team_score_12',          NULL::TEXT,                'PAK-W',           72),
  ('team_final_score',       NULL::TEXT,                'PAK-W',          112)
) AS v(question_type, player_name, team_code, actual)
WHERE  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = '[TEST] IND-W vs PAK-W — WT20 WC')
  AND  q.question_type IS NOT DISTINCT FROM v.question_type
  AND  q.player_name   IS NOT DISTINCT FROM v.player_name
  AND  q.team_code     IS NOT DISTINCT FROM v.team_code;


-- ============================================================
-- STEP 2: Score predictions — Game 1
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
         WHERE  match_title = '[TEST] IND-W vs PAK-W — WT20 WC')
  AND  p.predicted_value IS NOT NULL;


-- ============================================================
-- STEP 3: Set actuals + mark scored — Game 2 (TSK vs MI New York)
-- ============================================================
UPDATE closest_call_questions q
SET    actual_value = v.actual,
       status       = 'scored',
       updated_at   = NOW()
FROM (VALUES
  ('batter_runs'::TEXT,      'Devon Conway'::TEXT,     'TSK'::TEXT,       38::INT),
  ('batter_runs',            'Tim David',               'MINY',             55),
  ('batter_runs',            'Romario Shepherd',         'MINY',             22),
  ('bowler_wickets',         'Mitchell Santner',         'TSK',               1),
  ('bowler_wickets',         'Rashid Khan',              'MINY',              3),
  ('total_sixes',            NULL::TEXT,                 NULL::TEXT,         14),
  ('team_score_6',           NULL::TEXT,                 'TSK',              48),
  ('team_score_12',          NULL::TEXT,                 'TSK',              92),
  ('team_final_score',       NULL::TEXT,                 'TSK',             158),
  ('team_score_6',           NULL::TEXT,                 'MINY',             54),
  ('team_score_12',          NULL::TEXT,                 'MINY',            105),
  ('team_final_score',       NULL::TEXT,                 'MINY',            162)
) AS v(question_type, player_name, team_code, actual)
WHERE  q.closest_call_match_id = (
         SELECT id FROM closest_call_matches
         WHERE  match_title = '[TEST] TSK vs MI New York — MLC 2026')
  AND  q.question_type IS NOT DISTINCT FROM v.question_type
  AND  q.player_name   IS NOT DISTINCT FROM v.player_name
  AND  q.team_code     IS NOT DISTINCT FROM v.team_code;


-- ============================================================
-- STEP 4: Score predictions — Game 2
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
         WHERE  match_title = '[TEST] TSK vs MI New York — MLC 2026')
  AND  p.predicted_value IS NOT NULL;


-- ============================================================
-- STEP 5: Close both test matches
-- ============================================================
UPDATE closest_call_matches
SET    status     = 'closed',
       updated_at = NOW()
WHERE  match_title IN (
  '[TEST] IND-W vs PAK-W — WT20 WC',
  '[TEST] TSK vs MI New York — MLC 2026'
);
