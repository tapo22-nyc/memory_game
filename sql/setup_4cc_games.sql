-- ============================================================
-- FILE: sql/setup_4cc_games.sql
-- PURPOSE: Create 4 upcoming Closest Call matches and insert
--          6 simplified pre-match questions per game.
--          Replaces insert_closest_call_upcoming_games.sql +
--          questions_4cc_games.sql — run this file instead.
--
-- TARGET MATCHES:
--   W1: SL-W vs IRE-W       — WT20 WC 2026   (June 23, 13:30 UTC)
--   W2: AUS-W vs PAK-W      — WT20 WC 2026   (June 23, 17:30 UTC)
--   M1: SF Unicorns vs TSK  — MLC 2026        (June 25, 01:30 UTC)
--   M2: Wash Freedom vs SEO — MLC 2026        (June 26, 01:30 UTC)
--
-- QUESTIONS PER GAME (6 total, all pre_match):
--   1. Team A final score      → team_final_score / TEAM_FINAL_SCORE
--   2. Team B final score      → team_final_score / TEAM_FINAL_SCORE
--   3. Team A powerplay score  → team_score_6    / TEAM_PHASE_SCORE
--   4. Team B powerplay score  → team_score_6    / TEAM_PHASE_SCORE
--   5. Team A sixes            → total_sixes     / TOTAL_SIXES
--   6. Team B sixes            → total_sixes     / TOTAL_SIXES
--
-- SAFE TO RE-RUN: WHERE NOT EXISTS guards on both match and
--   question inserts prevent duplicates on re-run.
-- ============================================================


-- ============================================================
-- MATCH W1: Sri Lanka Women vs Ireland Women
--           Women's T20 World Cup 2026
--           June 23, 2026  9:30 AM ET  →  13:30:00 UTC
-- ============================================================
WITH m_slw_irew AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'SL-W vs IRE-W — WT20 WC 2026',
    'SL-W',
    'IRE-W',
    '2026-06-23 13:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026'
  )
  RETURNING id
),
m_slw_irew_id AS (
  SELECT id FROM m_slw_irew
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_slw_irew)
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  mi.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-23 13:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m_slw_irew_id mi
CROSS JOIN (VALUES
  ('What will be SL-W''s final score?',      'team_final_score', 'SL-W',  'TEAM_FINAL_SCORE'),
  ('What will be IRE-W''s final score?',     'team_final_score', 'IRE-W', 'TEAM_FINAL_SCORE'),
  ('What will be SL-W''s powerplay score?',  'team_score_6',     'SL-W',  'TEAM_PHASE_SCORE'),
  ('What will be IRE-W''s powerplay score?', 'team_score_6',     'IRE-W', 'TEAM_PHASE_SCORE'),
  ('How many sixes will SL-W hit?',          'total_sixes',      'SL-W',  'TOTAL_SIXES'),
  ('How many sixes will IRE-W hit?',         'total_sixes',      'IRE-W', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- MATCH W2: Australia Women vs Pakistan Women
--           Women's T20 World Cup 2026
--           June 23, 2026  1:30 PM ET  →  17:30:00 UTC
-- ============================================================
WITH m_ausw_pakw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'AUS-W vs PAK-W — WT20 WC 2026',
    'AUS-W',
    'PAK-W',
    '2026-06-23 17:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
  )
  RETURNING id
),
m_ausw_pakw_id AS (
  SELECT id FROM m_ausw_pakw
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_ausw_pakw)
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  mi.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m_ausw_pakw_id mi
CROSS JOIN (VALUES
  ('What will be AUS-W''s final score?',      'team_final_score', 'AUS-W', 'TEAM_FINAL_SCORE'),
  ('What will be PAK-W''s final score?',      'team_final_score', 'PAK-W', 'TEAM_FINAL_SCORE'),
  ('What will be AUS-W''s powerplay score?',  'team_score_6',     'AUS-W', 'TEAM_PHASE_SCORE'),
  ('What will be PAK-W''s powerplay score?',  'team_score_6',     'PAK-W', 'TEAM_PHASE_SCORE'),
  ('How many sixes will AUS-W hit?',          'total_sixes',      'AUS-W', 'TOTAL_SIXES'),
  ('How many sixes will PAK-W hit?',          'total_sixes',      'PAK-W', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- MATCH M1: San Francisco Unicorns vs Texas Super Kings
--           Major League Cricket 2026
--           June 24, 2026  9:30 PM ET  →  June 25 01:30:00 UTC
-- ============================================================
WITH m_sfu_tsk AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'SF Unicorns vs Texas Super Kings — MLC 2026',
    'SFU',
    'TSK',
    '2026-06-25 01:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
  )
  RETURNING id
),
m_sfu_tsk_id AS (
  SELECT id FROM m_sfu_tsk
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_sfu_tsk)
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  mi.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-25 01:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m_sfu_tsk_id mi
CROSS JOIN (VALUES
  ('What will be SF Unicorns'' final score?',        'team_final_score', 'SFU', 'TEAM_FINAL_SCORE'),
  ('What will be Texas Super Kings'' final score?',  'team_final_score', 'TSK', 'TEAM_FINAL_SCORE'),
  ('What will be SF Unicorns'' powerplay score?',    'team_score_6',     'SFU', 'TEAM_PHASE_SCORE'),
  ('What will be Texas Super Kings'' powerplay score?', 'team_score_6',  'TSK', 'TEAM_PHASE_SCORE'),
  ('How many sixes will SF Unicorns hit?',           'total_sixes',      'SFU', 'TOTAL_SIXES'),
  ('How many sixes will Texas Super Kings hit?',     'total_sixes',      'TSK', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- MATCH M2: Washington Freedom vs Seattle Orcas
--           Major League Cricket 2026
--           June 25, 2026  9:30 PM ET  →  June 26 01:30:00 UTC
-- ============================================================
WITH m_wf_seo AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'Washington Freedom vs Seattle Orcas — MLC 2026',
    'WF',
    'SEO',
    '2026-06-26 01:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
  )
  RETURNING id
),
m_wf_seo_id AS (
  SELECT id FROM m_wf_seo
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_wf_seo)
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number,
   max_points, scoring_rule_code, open_time, lock_time, status)
SELECT
  mi.id,
  q.question_text, q.question_type, 'pre_match',
  q.team_code, NULL::TEXT, NULL::INT,
  100, q.scoring_rule_code,
  NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ,
  'open'
FROM m_wf_seo_id mi
CROSS JOIN (VALUES
  ('What will be Washington Freedom''s final score?',    'team_final_score', 'WF',  'TEAM_FINAL_SCORE'),
  ('What will be Seattle Orcas'' final score?',          'team_final_score', 'SEO', 'TEAM_FINAL_SCORE'),
  ('What will be Washington Freedom''s powerplay score?','team_score_6',     'WF',  'TEAM_PHASE_SCORE'),
  ('What will be Seattle Orcas'' powerplay score?',      'team_score_6',     'SEO', 'TEAM_PHASE_SCORE'),
  ('How many sixes will Washington Freedom hit?',        'total_sixes',      'WF',  'TOTAL_SIXES'),
  ('How many sixes will Seattle Orcas hit?',             'total_sixes',      'SEO', 'TOTAL_SIXES')
) AS q(question_text, question_type, team_code, scoring_rule_code)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- VERIFICATION — expect 4 matches, 6 questions each (all pre_match)
-- ============================================================

-- 1. Confirm all four matches exist
SELECT id, match_title, team_1, team_2, status, match_date
FROM   closest_call_matches
WHERE  match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
)
ORDER  BY match_date;

-- 2. Confirm question counts (expect 6 per match, all pre_match)
SELECT
  ccm.match_title,
  COUNT(ccq.id)                                                   AS total_questions,
  SUM(CASE WHEN ccq.phase = 'pre_match'              THEN 1 END) AS pre_match,
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
