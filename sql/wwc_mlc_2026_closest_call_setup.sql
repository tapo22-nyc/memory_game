-- ============================================================
-- FILE: sql/wwc_mlc_2026_closest_call_setup.sql
-- PURPOSE: Create Closest Call matches + questions for
--          Women's T20 World Cup 2026 and MLC 2026.
--
-- DATABASE: Neon PostgreSQL (MT Games)
-- SAFE TO RE-RUN: Uses ON CONFLICT DO NOTHING where possible.
--
-- HOW IT WORKS:
--   Each block uses a CTE (WITH ... AS) to insert one match
--   and immediately attach all its questions in a single query.
--   No manual ID copying needed.
--
-- BEFORE RUNNING:
--   1. Update the match_date values below to real match dates.
--   2. Run one block at a time and verify with the CHECK query
--      at the bottom before moving on.
--
-- MATCH STATUS OPTIONS:
--   'open'   → users can submit predictions
--   'locked' → no more predictions accepted
--   'closed' → results finalised, points awarded
-- ============================================================


-- ============================================================
-- ══ PART 1: WOMEN'S T20 WORLD CUP 2026 ══
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- MATCH W1: Sri Lanka Women vs Ireland Women
-- ────────────────────────────────────────────────────────────
-- ↓ UPDATE match_date before running
WITH m_slw_irew AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  VALUES (
    'SL-W vs IRE-W — WT20 WC 2026',
    'SL-W',
    'IRE-W',
    '2026-10-01 10:00:00+00',   -- ← replace with real date/time (UTC)
    'open'
  )
  RETURNING id
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number, max_points, scoring_rule_code, status)
SELECT
  m.id,
  q.question_text,
  q.question_type,
  q.phase,
  q.team_code,
  q.player_name,
  q.innings_number,
  q.max_points,
  q.scoring_rule_code,
  'open'
FROM m_slw_irew m
CROSS JOIN (VALUES
  -- Innings 1: Sri Lanka Women bat
  ('What will SL-W score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',    'SL-W',  NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will SL-W score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings',  'SL-W',  NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will SL-W final innings total be?',
   'team_final_score', 'final',        'SL-W',  NULL::TEXT,              1, 100, 'TEAM_FINAL_SCORE'),

  -- Innings 2: Ireland Women bat
  ('What will IRE-W score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',    'IRE-W', NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will IRE-W score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings',  'IRE-W', NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will IRE-W final innings total be?',
   'team_final_score', 'final',        'IRE-W', NULL::TEXT,              2, 100, 'TEAM_FINAL_SCORE'),

  -- Player predictions
  ('How many runs will Chamari Athapaththu score?',
   'batter_runs',      'pre_match',    'SL-W',  'Chamari Athapaththu',   1, 150, 'BATTER_RUNS'),
  ('How many runs will Gaby Lewis score?',
   'batter_runs',      'pre_match',    'IRE-W', 'Gaby Lewis',            2, 150, 'BATTER_RUNS'),
  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',    NULL,    NULL::TEXT,           NULL, 100, 'TOTAL_SIXES')

) AS q(question_text, question_type, phase, team_code, player_name,
       innings_number, max_points, scoring_rule_code);


-- ────────────────────────────────────────────────────────────
-- MATCH W2: Australia Women vs Pakistan Women
-- ────────────────────────────────────────────────────────────
-- ↓ UPDATE match_date before running
WITH m_ausw_pakw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  VALUES (
    'AUS-W vs PAK-W — WT20 WC 2026',
    'AUS-W',
    'PAK-W',
    '2026-10-03 10:00:00+00',   -- ← replace with real date/time (UTC)
    'open'
  )
  RETURNING id
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number, max_points, scoring_rule_code, status)
SELECT
  m.id,
  q.question_text,
  q.question_type,
  q.phase,
  q.team_code,
  q.player_name,
  q.innings_number,
  q.max_points,
  q.scoring_rule_code,
  'open'
FROM m_ausw_pakw m
CROSS JOIN (VALUES
  -- Innings 1: Australia Women bat
  ('What will AUS-W score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',    'AUS-W', NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will AUS-W score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings',  'AUS-W', NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will AUS-W final innings total be?',
   'team_final_score', 'final',        'AUS-W', NULL::TEXT,              1, 100, 'TEAM_FINAL_SCORE'),

  -- Innings 2: Pakistan Women bat
  ('What will PAK-W score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',    'PAK-W', NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will PAK-W score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings',  'PAK-W', NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will PAK-W final innings total be?',
   'team_final_score', 'final',        'PAK-W', NULL::TEXT,              2, 100, 'TEAM_FINAL_SCORE'),

  -- Player predictions
  ('How many runs will Alyssa Healy score?',
   'batter_runs',      'pre_match',    'AUS-W', 'Alyssa Healy',          1, 150, 'BATTER_RUNS'),
  ('How many runs will Beth Mooney score?',
   'batter_runs',      'pre_match',    'AUS-W', 'Beth Mooney',           1, 150, 'BATTER_RUNS'),
  ('How many runs will Bismah Maroof score?',
   'batter_runs',      'pre_match',    'PAK-W', 'Bismah Maroof',         2, 150, 'BATTER_RUNS'),
  ('How many wickets will Megan Schutt take?',
   'bowler_wickets',   'pre_match',    'AUS-W', 'Megan Schutt',          1, 100, 'BOWLER_WICKETS'),
  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',    NULL,    NULL::TEXT,           NULL, 100, 'TOTAL_SIXES')

) AS q(question_text, question_type, phase, team_code, player_name,
       innings_number, max_points, scoring_rule_code);


-- ────────────────────────────────────────────────────────────
-- MATCH W3: England Women vs West Indies Women
-- ────────────────────────────────────────────────────────────
-- ↓ UPDATE match_date before running
WITH m_engw_wiw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  VALUES (
    'ENG-W vs WI-W — WT20 WC 2026',
    'ENG-W',
    'WI-W',
    '2026-10-05 10:00:00+00',   -- ← replace with real date/time (UTC)
    'open'
  )
  RETURNING id
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number, max_points, scoring_rule_code, status)
SELECT
  m.id,
  q.question_text,
  q.question_type,
  q.phase,
  q.team_code,
  q.player_name,
  q.innings_number,
  q.max_points,
  q.scoring_rule_code,
  'open'
FROM m_engw_wiw m
CROSS JOIN (VALUES
  -- Innings 1: England Women bat
  ('What will ENG-W score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',    'ENG-W', NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will ENG-W score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings',  'ENG-W', NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will ENG-W final innings total be?',
   'team_final_score', 'final',        'ENG-W', NULL::TEXT,              1, 100, 'TEAM_FINAL_SCORE'),

  -- Innings 2: West Indies Women bat
  ('What will WI-W score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',    'WI-W',  NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will WI-W score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings',  'WI-W',  NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will WI-W final innings total be?',
   'team_final_score', 'final',        'WI-W',  NULL::TEXT,              2, 100, 'TEAM_FINAL_SCORE'),

  -- Player predictions
  ('How many runs will Natalie Sciver-Brunt score?',
   'batter_runs',      'pre_match',    'ENG-W', 'Natalie Sciver-Brunt',  1, 150, 'BATTER_RUNS'),
  ('How many runs will Danni Wyatt score?',
   'batter_runs',      'pre_match',    'ENG-W', 'Danni Wyatt',           1, 150, 'BATTER_RUNS'),
  ('How many runs will Hayley Matthews score?',
   'batter_runs',      'pre_match',    'WI-W',  'Hayley Matthews',       2, 150, 'BATTER_RUNS'),
  ('How many wickets will Sophie Ecclestone take?',
   'bowler_wickets',   'pre_match',    'ENG-W', 'Sophie Ecclestone',     1, 100, 'BOWLER_WICKETS'),
  ('How many wickets will Shamilia Connell take?',
   'bowler_wickets',   'pre_match',    'WI-W',  'Shamilia Connell',      2, 100, 'BOWLER_WICKETS'),
  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',    NULL,    NULL::TEXT,           NULL, 100, 'TOTAL_SIXES')

) AS q(question_text, question_type, phase, team_code, player_name,
       innings_number, max_points, scoring_rule_code);


-- ============================================================
-- ══ PART 2: MLC 2026 (MAJOR LEAGUE CRICKET) ══
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- MATCH M1: SF Unicorns vs Texas Super Kings
-- ────────────────────────────────────────────────────────────
-- ↓ UPDATE match_date before running
WITH m_sfu_tsk AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  VALUES (
    'SF Unicorns vs Texas Super Kings — MLC 2026',
    'SFU',
    'TSK',
    '2026-07-11 23:00:00+00',   -- ← replace with real date/time (UTC)
    'open'
  )
  RETURNING id
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number, max_points, scoring_rule_code, status)
SELECT
  m.id,
  q.question_text,
  q.question_type,
  q.phase,
  q.team_code,
  q.player_name,
  q.innings_number,
  q.max_points,
  q.scoring_rule_code,
  'open'
FROM m_sfu_tsk m
CROSS JOIN (VALUES
  -- Innings 1: SF Unicorns bat
  ('What will SF Unicorns score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',    'SFU',   NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will SF Unicorns score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings',  'SFU',   NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will SF Unicorns final innings total be?',
   'team_final_score', 'final',        'SFU',   NULL::TEXT,              1, 100, 'TEAM_FINAL_SCORE'),

  -- Innings 2: Texas Super Kings bat
  ('What will Texas Super Kings score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',    'TSK',   NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will Texas Super Kings score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings',  'TSK',   NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will Texas Super Kings final innings total be?',
   'team_final_score', 'final',        'TSK',   NULL::TEXT,              2, 100, 'TEAM_FINAL_SCORE'),

  -- Player predictions
  ('How many runs will Finn Allen score?',
   'batter_runs',      'pre_match',    'SFU',   'Finn Allen',            1, 150, 'BATTER_RUNS'),
  ('How many runs will Devon Conway score?',
   'batter_runs',      'pre_match',    'TSK',   'Devon Conway',          2, 150, 'BATTER_RUNS'),
  ('How many wickets will Saurabh Netravalkar take?',
   'bowler_wickets',   'pre_match',    'SFU',   'Saurabh Netravalkar',   1, 100, 'BOWLER_WICKETS'),
  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',    NULL,    NULL::TEXT,           NULL, 100, 'TOTAL_SIXES')

) AS q(question_text, question_type, phase, team_code, player_name,
       innings_number, max_points, scoring_rule_code);


-- ────────────────────────────────────────────────────────────
-- MATCH M2: Washington Freedom vs Seattle Orcas
-- ────────────────────────────────────────────────────────────
-- ↓ UPDATE match_date before running
WITH m_wf_seo AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  VALUES (
    'Washington Freedom vs Seattle Orcas — MLC 2026',
    'WF',
    'SEO',
    '2026-07-13 23:00:00+00',   -- ← replace with real date/time (UTC)
    'open'
  )
  RETURNING id
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number, max_points, scoring_rule_code, status)
SELECT
  m.id,
  q.question_text,
  q.question_type,
  q.phase,
  q.team_code,
  q.player_name,
  q.innings_number,
  q.max_points,
  q.scoring_rule_code,
  'open'
FROM m_wf_seo m
CROSS JOIN (VALUES
  -- Innings 1: Washington Freedom bat
  ('What will Washington Freedom score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',    'WF',    NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will Washington Freedom score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings',  'WF',    NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will Washington Freedom final innings total be?',
   'team_final_score', 'final',        'WF',    NULL::TEXT,              1, 100, 'TEAM_FINAL_SCORE'),

  -- Innings 2: Seattle Orcas bat
  ('What will Seattle Orcas score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',    'SEO',   NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will Seattle Orcas score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings',  'SEO',   NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will Seattle Orcas final innings total be?',
   'team_final_score', 'final',        'SEO',   NULL::TEXT,              2, 100, 'TEAM_FINAL_SCORE'),

  -- Player predictions
  ('How many runs will Glenn Maxwell score?',
   'batter_runs',      'pre_match',    'WF',    'Glenn Maxwell',         1, 150, 'BATTER_RUNS'),
  ('How many runs will Alex Hales score?',
   'batter_runs',      'pre_match',    'WF',    'Alex Hales',            1, 150, 'BATTER_RUNS'),
  ('How many wickets will Adil Rashid take?',
   'bowler_wickets',   'pre_match',    'SEO',   'Adil Rashid',           2, 100, 'BOWLER_WICKETS'),
  ('How many wickets will Trent Boult take?',
   'bowler_wickets',   'pre_match',    'SEO',   'Trent Boult',           2, 100, 'BOWLER_WICKETS'),
  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',    NULL,    NULL::TEXT,           NULL, 100, 'TOTAL_SIXES')

) AS q(question_text, question_type, phase, team_code, player_name,
       innings_number, max_points, scoring_rule_code);


-- ────────────────────────────────────────────────────────────
-- MATCH M3: MI New York vs Texas Super Kings
-- ────────────────────────────────────────────────────────────
-- ↓ UPDATE match_date before running
WITH m_miny_tsk AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  VALUES (
    'MI New York vs Texas Super Kings — MLC 2026',
    'MINY',
    'TSK',
    '2026-07-16 23:00:00+00',   -- ← replace with real date/time (UTC)
    'open'
  )
  RETURNING id
)
INSERT INTO closest_call_questions
  (closest_call_match_id, question_text, question_type, phase,
   team_code, player_name, innings_number, max_points, scoring_rule_code, status)
SELECT
  m.id,
  q.question_text,
  q.question_type,
  q.phase,
  q.team_code,
  q.player_name,
  q.innings_number,
  q.max_points,
  q.scoring_rule_code,
  'open'
FROM m_miny_tsk m
CROSS JOIN (VALUES
  -- Innings 1: MI New York bat
  ('What will MI New York score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',    'MINY',  NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will MI New York score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings',  'MINY',  NULL::TEXT,              1, 100, 'TEAM_PHASE_SCORE'),
  ('What will MI New York final innings total be?',
   'team_final_score', 'final',        'MINY',  NULL::TEXT,              1, 100, 'TEAM_FINAL_SCORE'),

  -- Innings 2: Texas Super Kings bat
  ('What will Texas Super Kings score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',    'TSK',   NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will Texas Super Kings score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings',  'TSK',   NULL::TEXT,              2, 100, 'TEAM_PHASE_SCORE'),
  ('What will Texas Super Kings final innings total be?',
   'team_final_score', 'final',        'TSK',   NULL::TEXT,              2, 100, 'TEAM_FINAL_SCORE'),

  -- Player predictions
  ('How many runs will Tim David score?',
   'batter_runs',      'pre_match',    'MINY',  'Tim David',             1, 150, 'BATTER_RUNS'),
  ('How many runs will Romario Shepherd score?',
   'batter_runs',      'pre_match',    'MINY',  'Romario Shepherd',      1, 150, 'BATTER_RUNS'),
  ('How many runs will Devon Conway score?',
   'batter_runs',      'pre_match',    'TSK',   'Devon Conway',          2, 150, 'BATTER_RUNS'),
  ('How many wickets will Rashid Khan take?',
   'bowler_wickets',   'pre_match',    'MINY',  'Rashid Khan',           1, 100, 'BOWLER_WICKETS'),
  ('How many wickets will Mitchell Santner take?',
   'bowler_wickets',   'pre_match',    'TSK',   'Mitchell Santner',      2, 100, 'BOWLER_WICKETS'),
  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',    NULL,    NULL::TEXT,           NULL, 100, 'TOTAL_SIXES')

) AS q(question_text, question_type, phase, team_code, player_name,
       innings_number, max_points, scoring_rule_code);


-- ============================================================
-- VERIFICATION QUERIES
-- Run each SELECT below after running the INSERTs above.
-- ============================================================

-- 1. Check all 6 matches were created:
SELECT id, match_title, team_1, team_2, status, match_date
FROM   closest_call_matches
WHERE  match_title LIKE '%WT20 WC 2026%'
   OR  match_title LIKE '%MLC 2026%'
ORDER  BY id;


-- 2. Check question counts per match (expect 9–12 per match):
SELECT
  ccm.match_title,
  COUNT(ccq.id) AS question_count
FROM   closest_call_matches ccm
LEFT   JOIN closest_call_questions ccq
       ON ccq.closest_call_match_id = ccm.id
WHERE  ccm.match_title LIKE '%WT20 WC 2026%'
   OR  ccm.match_title LIKE '%MLC 2026%'
GROUP  BY ccm.match_title
ORDER  BY ccm.match_title;


-- 3. Inspect all questions for a specific match (replace match title):
/*
SELECT
  ccq.id,
  ccq.question_text,
  ccq.question_type,
  ccq.phase,
  ccq.team_code,
  ccq.player_name,
  ccq.innings_number,
  ccq.max_points,
  ccq.scoring_rule_code,
  ccq.status
FROM   closest_call_questions ccq
JOIN   closest_call_matches   ccm ON ccm.id = ccq.closest_call_match_id
WHERE  ccm.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
ORDER  BY ccq.id;
*/


-- ============================================================
-- HOW TO UPDATE DATES (if you need to change them later)
-- ============================================================
/*
UPDATE closest_call_matches
SET    match_date = '2026-10-01 14:30:00+05:30'   -- IST example
WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026';
*/


-- ============================================================
-- HOW TO LOCK A MATCH (stop new predictions at toss time)
-- ============================================================
/*
UPDATE closest_call_matches
SET    status = 'locked'
WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026';

-- Also lock all questions for that match:
UPDATE closest_call_questions
SET    status = 'locked'
WHERE  closest_call_match_id = (
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026'
);
*/


-- ============================================================
-- HOW TO ENTER ACTUAL SCORES AND CLOSE A MATCH
-- ============================================================
/*
-- Step 1: Set actual values on each question
UPDATE closest_call_questions
SET    actual_value = 58             -- replace with real score
WHERE  closest_call_match_id = (SELECT id FROM closest_call_matches WHERE match_title = 'SL-W vs IRE-W — WT20 WC 2026')
  AND  question_type = 'team_score_6'
  AND  team_code     = 'SL-W';

-- Step 2: Close the match
UPDATE closest_call_matches
SET    status = 'closed'
WHERE  match_title = 'SL-W vs IRE-W — WT20 WC 2026';
*/
