-- ============================================================
-- FILE: sql/insert_closest_call_upcoming_games.sql
-- PURPOSE: Insert Closest Call matches and questions for the
--          next four upcoming live games:
--
--   W1: SL-W vs IRE-W       — June 23, 2026  9:30 AM ET  (13:30 UTC)
--   W2: AUS-W vs PAK-W      — June 23, 2026  1:30 PM ET  (17:30 UTC)
--   M1: SF Unicorns vs TSK   — June 24, 2026  9:30 PM ET  (June 25 01:30 UTC)
--   M2: Wash Freedom vs SEO  — June 25, 2026  9:30 PM ET  (June 26 01:30 UTC)
--
-- DATABASE: Neon PostgreSQL (MT Games)
-- SAFE TO RE-RUN: Each block uses WHERE NOT EXISTS guards on
--   both the match insert and the question insert, so re-running
--   this file will not create duplicate rows.
--
-- TIMING LOGIC (all times UTC, June = EDT = UTC-4):
--   Pre-match questions  → open now,   lock = match_date (kickoff)
--   Innings 1 Powerplay  → open at kickoff,    lock = kickoff + 40 min
--   Innings 1 Mid        → open at +40 min,    lock = +70 min
--   Innings 1 Final      → open at +70 min,    lock = +100 min
--   Innings 2 Powerplay  → open at +105 min,   lock = +145 min
--   Innings 2 Mid        → open at +145 min,   lock = +175 min
--   Innings 2 Final      → open at +175 min,   lock = +205 min
--
-- SCORING RULES USED (from closest_call_scoring_rules / update-closest-call-actuals.js):
--   TEAM_PHASE_SCORE  — powerplay / mid-innings score (legacy DB rule)
--   TEAM_FINAL_SCORE  — innings total (legacy DB rule)
--   BATTER_RUNS       — batter runs (legacy DB rule)
--   BOWLER_WICKETS    — bowler wickets (legacy DB rule)
--   TOTAL_SIXES       — total match sixes (legacy DB rule)
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
  q.question_text, q.question_type, q.phase,
  q.team_code, q.player_name, q.innings_number,
  q.max_points, q.scoring_rule_code, q.open_time, q.lock_time,
  'open'
FROM m_slw_irew_id mi
CROSS JOIN (VALUES
  -- ── Pre-match questions (open now → lock at kickoff 13:30 UTC) ──
  ('How many runs will Chamari Athapaththu score?',
   'batter_runs',      'pre_match',   'SL-W',   'Chamari Athapaththu',  1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-23 13:30:00+00'::TIMESTAMPTZ),

  ('How many runs will Gaby Lewis score?',
   'batter_runs',      'pre_match',   'IRE-W',  'Gaby Lewis',           2, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-23 13:30:00+00'::TIMESTAMPTZ),

  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',   NULL::TEXT, NULL::TEXT,         NULL::INT, 100, 'TOTAL_SIXES',
   NULL::TIMESTAMPTZ, '2026-06-23 13:30:00+00'::TIMESTAMPTZ),

  -- ── Innings 1 — Sri Lanka Women bat ──
  -- Powerplay:  open 13:30, lock 14:10
  ('What will SL-W score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'SL-W',   NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 13:30:00+00'::TIMESTAMPTZ, '2026-06-23 14:10:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 14:10, lock 14:40
  ('What will SL-W score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings', 'SL-W',   NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 14:10:00+00'::TIMESTAMPTZ, '2026-06-23 14:40:00+00'::TIMESTAMPTZ),

  -- Final:       open 14:40, lock 15:10
  ('What will SL-W final innings total be?',
   'team_final_score', 'final',       'SL-W',   NULL::TEXT,             1, 100, 'TEAM_FINAL_SCORE',
   '2026-06-23 14:40:00+00'::TIMESTAMPTZ, '2026-06-23 15:10:00+00'::TIMESTAMPTZ),

  -- ── Innings 2 — Ireland Women bat ──
  -- Innings 2 starts ≈ 105 min after kickoff (15:15 UTC)
  -- Powerplay:  open 15:15, lock 15:55
  ('What will IRE-W score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'IRE-W',  NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 15:15:00+00'::TIMESTAMPTZ, '2026-06-23 15:55:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 15:55, lock 16:25
  ('What will IRE-W score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings', 'IRE-W',  NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 15:55:00+00'::TIMESTAMPTZ, '2026-06-23 16:25:00+00'::TIMESTAMPTZ),

  -- Final:       open 16:25, lock 16:55
  ('What will IRE-W final innings total be?',
   'team_final_score', 'final',       'IRE-W',  NULL::TEXT,             2, 100, 'TEAM_FINAL_SCORE',
   '2026-06-23 16:25:00+00'::TIMESTAMPTZ, '2026-06-23 16:55:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
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
  q.question_text, q.question_type, q.phase,
  q.team_code, q.player_name, q.innings_number,
  q.max_points, q.scoring_rule_code, q.open_time, q.lock_time,
  'open'
FROM m_ausw_pakw_id mi
CROSS JOIN (VALUES
  -- ── Pre-match questions (open now → lock at kickoff 17:30 UTC) ──
  ('How many runs will Alyssa Healy score?',
   'batter_runs',      'pre_match',   'AUS-W',  'Alyssa Healy',         1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ),

  ('How many runs will Beth Mooney score?',
   'batter_runs',      'pre_match',   'AUS-W',  'Beth Mooney',          1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ),

  ('How many runs will Bismah Maroof score?',
   'batter_runs',      'pre_match',   'PAK-W',  'Bismah Maroof',        2, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ),

  ('How many wickets will Megan Schutt take?',
   'bowler_wickets',   'pre_match',   'AUS-W',  'Megan Schutt',         1, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ),

  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',   NULL::TEXT, NULL::TEXT,         NULL::INT, 100, 'TOTAL_SIXES',
   NULL::TIMESTAMPTZ, '2026-06-23 17:30:00+00'::TIMESTAMPTZ),

  -- ── Innings 1 — Australia Women bat ──
  -- Powerplay:  open 17:30, lock 18:10
  ('What will AUS-W score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'AUS-W',  NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 17:30:00+00'::TIMESTAMPTZ, '2026-06-23 18:10:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 18:10, lock 18:40
  ('What will AUS-W score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings', 'AUS-W',  NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 18:10:00+00'::TIMESTAMPTZ, '2026-06-23 18:40:00+00'::TIMESTAMPTZ),

  -- Final:       open 18:40, lock 19:10
  ('What will AUS-W final innings total be?',
   'team_final_score', 'final',       'AUS-W',  NULL::TEXT,             1, 100, 'TEAM_FINAL_SCORE',
   '2026-06-23 18:40:00+00'::TIMESTAMPTZ, '2026-06-23 19:10:00+00'::TIMESTAMPTZ),

  -- ── Innings 2 — Pakistan Women bat ──
  -- Innings 2 starts ≈ 105 min after kickoff (19:15 UTC)
  -- Powerplay:  open 19:15, lock 19:55
  ('What will PAK-W score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'PAK-W',  NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 19:15:00+00'::TIMESTAMPTZ, '2026-06-23 19:55:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 19:55, lock 20:25
  ('What will PAK-W score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings', 'PAK-W',  NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-23 19:55:00+00'::TIMESTAMPTZ, '2026-06-23 20:25:00+00'::TIMESTAMPTZ),

  -- Final:       open 20:25, lock 20:55
  ('What will PAK-W final innings total be?',
   'team_final_score', 'final',       'PAK-W',  NULL::TEXT,             2, 100, 'TEAM_FINAL_SCORE',
   '2026-06-23 20:25:00+00'::TIMESTAMPTZ, '2026-06-23 20:55:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
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
  q.question_text, q.question_type, q.phase,
  q.team_code, q.player_name, q.innings_number,
  q.max_points, q.scoring_rule_code, q.open_time, q.lock_time,
  'open'
FROM m_sfu_tsk_id mi
CROSS JOIN (VALUES
  -- ── Pre-match questions (open now → lock at kickoff 01:30 UTC June 25) ──
  ('How many runs will Finn Allen score?',
   'batter_runs',      'pre_match',   'SFU',    'Finn Allen',           1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-25 01:30:00+00'::TIMESTAMPTZ),

  ('How many runs will Devon Conway score?',
   'batter_runs',      'pre_match',   'TSK',    'Devon Conway',         2, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-25 01:30:00+00'::TIMESTAMPTZ),

  ('How many wickets will Saurabh Netravalkar take?',
   'bowler_wickets',   'pre_match',   'SFU',    'Saurabh Netravalkar',  1, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-25 01:30:00+00'::TIMESTAMPTZ),

  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',   NULL::TEXT, NULL::TEXT,         NULL::INT, 100, 'TOTAL_SIXES',
   NULL::TIMESTAMPTZ, '2026-06-25 01:30:00+00'::TIMESTAMPTZ),

  -- ── Innings 1 — SF Unicorns bat ──
  -- Powerplay:  open 01:30, lock 02:10
  ('What will SF Unicorns score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'SFU',    NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-25 01:30:00+00'::TIMESTAMPTZ, '2026-06-25 02:10:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 02:10, lock 02:40
  ('What will SF Unicorns score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings', 'SFU',    NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-25 02:10:00+00'::TIMESTAMPTZ, '2026-06-25 02:40:00+00'::TIMESTAMPTZ),

  -- Final:       open 02:40, lock 03:10
  ('What will SF Unicorns final innings total be?',
   'team_final_score', 'final',       'SFU',    NULL::TEXT,             1, 100, 'TEAM_FINAL_SCORE',
   '2026-06-25 02:40:00+00'::TIMESTAMPTZ, '2026-06-25 03:10:00+00'::TIMESTAMPTZ),

  -- ── Innings 2 — Texas Super Kings bat ──
  -- Innings 2 starts ≈ 105 min after kickoff (03:15 UTC)
  -- Powerplay:  open 03:15, lock 03:55
  ('What will Texas Super Kings score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'TSK',    NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-25 03:15:00+00'::TIMESTAMPTZ, '2026-06-25 03:55:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 03:55, lock 04:25
  ('What will Texas Super Kings score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings', 'TSK',    NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-25 03:55:00+00'::TIMESTAMPTZ, '2026-06-25 04:25:00+00'::TIMESTAMPTZ),

  -- Final:       open 04:25, lock 04:55
  ('What will Texas Super Kings final innings total be?',
   'team_final_score', 'final',       'TSK',    NULL::TEXT,             2, 100, 'TEAM_FINAL_SCORE',
   '2026-06-25 04:25:00+00'::TIMESTAMPTZ, '2026-06-25 04:55:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
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
  q.question_text, q.question_type, q.phase,
  q.team_code, q.player_name, q.innings_number,
  q.max_points, q.scoring_rule_code, q.open_time, q.lock_time,
  'open'
FROM m_wf_seo_id mi
CROSS JOIN (VALUES
  -- ── Pre-match questions (open now → lock at kickoff 01:30 UTC June 26) ──
  ('How many runs will Glenn Maxwell score?',
   'batter_runs',      'pre_match',   'WF',     'Glenn Maxwell',        1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ),

  ('How many runs will Alex Hales score?',
   'batter_runs',      'pre_match',   'WF',     'Alex Hales',           1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ),

  ('How many wickets will Adil Rashid take?',
   'bowler_wickets',   'pre_match',   'SEO',    'Adil Rashid',          2, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ),

  ('How many wickets will Trent Boult take?',
   'bowler_wickets',   'pre_match',   'SEO',    'Trent Boult',          2, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ),

  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',   NULL::TEXT, NULL::TEXT,         NULL::INT, 100, 'TOTAL_SIXES',
   NULL::TIMESTAMPTZ, '2026-06-26 01:30:00+00'::TIMESTAMPTZ),

  -- ── Innings 1 — Washington Freedom bat ──
  -- Powerplay:  open 01:30, lock 02:10
  ('What will Washington Freedom score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'WF',     NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-26 01:30:00+00'::TIMESTAMPTZ, '2026-06-26 02:10:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 02:10, lock 02:40
  ('What will Washington Freedom score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings', 'WF',     NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-26 02:10:00+00'::TIMESTAMPTZ, '2026-06-26 02:40:00+00'::TIMESTAMPTZ),

  -- Final:       open 02:40, lock 03:10
  ('What will Washington Freedom final innings total be?',
   'team_final_score', 'final',       'WF',     NULL::TEXT,             1, 100, 'TEAM_FINAL_SCORE',
   '2026-06-26 02:40:00+00'::TIMESTAMPTZ, '2026-06-26 03:10:00+00'::TIMESTAMPTZ),

  -- ── Innings 2 — Seattle Orcas bat ──
  -- Innings 2 starts ≈ 105 min after kickoff (03:15 UTC)
  -- Powerplay:  open 03:15, lock 03:55
  ('What will Seattle Orcas score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'SEO',    NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-26 03:15:00+00'::TIMESTAMPTZ, '2026-06-26 03:55:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 03:55, lock 04:25
  ('What will Seattle Orcas score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings', 'SEO',    NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-26 03:55:00+00'::TIMESTAMPTZ, '2026-06-26 04:25:00+00'::TIMESTAMPTZ),

  -- Final:       open 04:25, lock 04:55
  ('What will Seattle Orcas final innings total be?',
   'team_final_score', 'final',       'SEO',    NULL::TEXT,             2, 100, 'TEAM_FINAL_SCORE',
   '2026-06-26 04:25:00+00'::TIMESTAMPTZ, '2026-06-26 04:55:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- VERIFICATION QUERIES
-- Run after the inserts above.
-- ============================================================

-- 1. Confirm all four matches were created (or already existed):
SELECT id, match_title, team_1, team_2, status, match_date
FROM   closest_call_matches
WHERE  match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
)
ORDER  BY match_date;

-- 2. Confirm question counts (expect 9–11 per match):
SELECT
  ccm.match_title,
  COUNT(ccq.id) AS question_count,
  SUM(CASE WHEN ccq.phase = 'pre_match'   THEN 1 ELSE 0 END) AS pre_match,
  SUM(CASE WHEN ccq.phase = 'powerplay'   THEN 1 ELSE 0 END) AS powerplay,
  SUM(CASE WHEN ccq.phase = 'mid_innings' THEN 1 ELSE 0 END) AS mid_innings,
  SUM(CASE WHEN ccq.phase = 'final'       THEN 1 ELSE 0 END) AS final
FROM   closest_call_matches ccm
LEFT   JOIN closest_call_questions ccq ON ccq.closest_call_match_id = ccm.id
WHERE  ccm.match_title IN (
  'SL-W vs IRE-W — WT20 WC 2026',
  'AUS-W vs PAK-W — WT20 WC 2026',
  'SF Unicorns vs Texas Super Kings — MLC 2026',
  'Washington Freedom vs Seattle Orcas — MLC 2026'
)
GROUP  BY ccm.match_title
ORDER  BY ccm.match_title;

-- 3. Inspect timing windows for one match (replace title as needed):
/*
SELECT
  ccq.phase,
  ccq.question_type,
  ccq.question_text,
  ccq.open_time  AT TIME ZONE 'America/New_York' AS open_et,
  ccq.lock_time  AT TIME ZONE 'America/New_York' AS lock_et
FROM   closest_call_questions ccq
JOIN   closest_call_matches   ccm ON ccm.id = ccq.closest_call_match_id
WHERE  ccm.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
ORDER  BY ccq.innings_number NULLS FIRST, ccq.id;
*/
