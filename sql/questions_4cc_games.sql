-- ============================================================
-- FILE: sql/questions_4cc_games.sql
-- PURPOSE: Replace questions for the 4 upcoming Closest Call
--          games with a simplified 6-question pre-match set.
--
-- TARGET MATCHES (already in closest_call_matches):
--   W1: SL-W vs IRE-W       — WT20 WC 2026   (June 23, 13:30 UTC)
--   W2: AUS-W vs PAK-W      — WT20 WC 2026   (June 23, 17:30 UTC)
--   M1: SF Unicorns vs TSK  — MLC 2026        (June 25, 01:30 UTC)
--   M2: Wash Freedom vs SEO — MLC 2026        (June 26, 01:30 UTC)
--
-- NEW QUESTION SET PER GAME (6 total, all pre_match):
--   1. What will be Team A's final score?      → team_final_score / TEAM_FINAL_SCORE
--   2. What will be Team B's final score?      → team_final_score / TEAM_FINAL_SCORE
--   3. What will be Team A's powerplay score?  → team_score_6    / TEAM_PHASE_SCORE
--   4. What will be Team B's powerplay score?  → team_score_6    / TEAM_PHASE_SCORE
--   5. How many sixes will Team A hit?         → total_sixes     / TOTAL_SIXES
--   6. How many sixes will Team B hit?         → total_sixes     / TOTAL_SIXES
--
-- SIXES QUESTION TYPE RATIONALE:
--   The existing schema supports question_type='total_sixes' with
--   scoring_rule_code='TOTAL_SIXES' (a LEGACY_RULE in update-closest-
--   call-actuals.js that reads from closest_call_scoring_rules DB table).
--   Per-team sixes are distinguished by setting team_code — the scoring
--   UPDATE in score_4cc_games.sql uses IS NOT DISTINCT FROM on team_code,
--   so 'SL-W' and 'IRE-W' sixes questions score independently.
--   No new question_type is invented; total_sixes + team_code is used.
--
-- APPROACH: Delete-and-reinsert (idempotent for this set of matches).
--   Step 1: Delete existing predictions for these 4 matches (FK safety)
--   Step 2: Delete existing questions for these 4 matches
--   Step 3: Insert 6 fresh pre-match questions per match
--   Only the 4 specific match titles are affected — all other matches
--   and their questions/predictions are untouched.
-- ============================================================


-- ============================================================
-- STEP 1: Remove existing predictions for these 4 matches
--         (must happen before deleting questions — FK constraint)
-- ============================================================
DELETE FROM closest_call_predictions
WHERE  closest_call_match_id IN (
  SELECT id FROM closest_call_matches
  WHERE  match_title IN (
    'SL-W vs IRE-W — WT20 WC 2026',
    'AUS-W vs PAK-W — WT20 WC 2026',
    'SF Unicorns vs Texas Super Kings — MLC 2026',
    'Washington Freedom vs Seattle Orcas — MLC 2026'
  )
);


-- ============================================================
-- STEP 2: Remove existing questions for these 4 matches
-- ============================================================
DELETE FROM closest_call_questions
WHERE  closest_call_match_id IN (
  SELECT id FROM closest_call_matches
  WHERE  match_title IN (
    'SL-W vs IRE-W — WT20 WC 2026',
    'AUS-W vs PAK-W — WT20 WC 2026',
    'SF Unicorns vs Texas Super Kings — MLC 2026',
    'Washington Freedom vs Seattle Orcas — MLC 2026'
  )
);


-- ============================================================
-- STEP 3A: Insert 6 pre-match questions — W1 (SL-W vs IRE-W)
-- ============================================================
WITH m AS (
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026'
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  m.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-23 13:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m
CROSS JOIN (VALUES
  ('What will be SL-W''s final score?',      'team_final_score', 'SL-W',  'TEAM_FINAL_SCORE'),
  ('What will be IRE-W''s final score?',     'team_final_score', 'IRE-W', 'TEAM_FINAL_SCORE'),
  ('What will be SL-W''s powerplay score?',  'team_score_6',     'SL-W',  'TEAM_PHASE_SCORE'),
  ('What will be IRE-W''s powerplay score?', 'team_score_6',     'IRE-W', 'TEAM_PHASE_SCORE'),
  ('How many sixes will SL-W hit?',          'total_sixes',      'SL-W',  'TOTAL_SIXES'),
  ('How many sixes will IRE-W hit?',         'total_sixes',      'IRE-W', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code);


-- ============================================================
-- STEP 3B: Insert 6 pre-match questions — W2 (AUS-W vs PAK-W)
-- ============================================================
WITH m AS (
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  m.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m
CROSS JOIN (VALUES
  ('What will be AUS-W''s final score?',      'team_final_score', 'AUS-W', 'TEAM_FINAL_SCORE'),
  ('What will be PAK-W''s final score?',      'team_final_score', 'PAK-W', 'TEAM_FINAL_SCORE'),
  ('What will be AUS-W''s powerplay score?',  'team_score_6',     'AUS-W', 'TEAM_PHASE_SCORE'),
  ('What will be PAK-W''s powerplay score?',  'team_score_6',     'PAK-W', 'TEAM_PHASE_SCORE'),
  ('How many sixes will AUS-W hit?',          'total_sixes',      'AUS-W', 'TOTAL_SIXES'),
  ('How many sixes will PAK-W hit?',          'total_sixes',      'PAK-W', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code);


-- ============================================================
-- STEP 3C: Insert 6 pre-match questions — M1 (SF Unicorns vs TSK)
-- ============================================================
WITH m AS (
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  m.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-25 01:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m
CROSS JOIN (VALUES
  ('What will be SF Unicorns'' final score?',      'team_final_score', 'SFU', 'TEAM_FINAL_SCORE'),
  ('What will be Texas Super Kings'' final score?', 'team_final_score', 'TSK', 'TEAM_FINAL_SCORE'),
  ('What will be SF Unicorns'' powerplay score?',  'team_score_6',     'SFU', 'TEAM_PHASE_SCORE'),
  ('What will be Texas Super Kings'' powerplay score?', 'team_score_6', 'TSK', 'TEAM_PHASE_SCORE'),
  ('How many sixes will SF Unicorns hit?',         'total_sixes',      'SFU', 'TOTAL_SIXES'),
  ('How many sixes will Texas Super Kings hit?',   'total_sixes',      'TSK', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code);


-- ============================================================
-- STEP 3D: Insert 6 pre-match questions — M2 (Wash Freedom vs SEO)
-- ============================================================
WITH m AS (
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  m.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m
CROSS JOIN (VALUES
  ('What will be Washington Freedom''s final score?', 'team_final_score', 'WF',  'TEAM_FINAL_SCORE'),
  ('What will be Seattle Orcas'' final score?',       'team_final_score', 'SEO', 'TEAM_FINAL_SCORE'),
  ('What will be Washington Freedom''s powerplay score?', 'team_score_6', 'WF',  'TEAM_PHASE_SCORE'),
  ('What will be Seattle Orcas'' powerplay score?',   'team_score_6',     'SEO', 'TEAM_PHASE_SCORE'),
  ('How many sixes will Washington Freedom hit?',     'total_sixes',      'WF',  'TOTAL_SIXES'),
  ('How many sixes will Seattle Orcas hit?',          'total_sixes',      'SEO', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code);


-- ============================================================
-- VERIFICATION — expect 6 questions per match, all pre_match
-- ============================================================
SELECT
  ccm.match_title,
  COUNT(ccq.id)                                              AS total_questions,
  SUM(CASE WHEN ccq.phase = 'pre_match'         THEN 1 END) AS pre_match,
  SUM(CASE WHEN ccq.question_type = 'team_final_score' THEN 1 END) AS final_score_qs,
  SUM(CASE WHEN ccq.question_type = 'team_score_6'     THEN 1 END) AS powerplay_qs,
  SUM(CASE WHEN ccq.question_type = 'total_sixes'      THEN 1 END) AS sixes_qs
FROM  closest_call_matches ccm
LEFT  JOIN closest_call_questions ccq ON ccq.closest_call_match_id = ccm.id
WHERE ccm.match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
)
GROUP BY ccm.match_title
ORDER BY ccm.match_title;
