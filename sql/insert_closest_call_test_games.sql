-- ============================================================
-- FILE: sql/insert_closest_call_test_games.sql
-- PURPOSE: Insert two clearly-labeled TEST matches for QA /
--          leaderboard testing.  These games are not real
--          upcoming fixtures — use them to exercise the full
--          prediction → scoring → leaderboard flow before going
--          live with real matches.
--
-- TEST GAME 1 (WWC):  IND-W vs PAK-W — WT20 WC TEST
-- TEST GAME 2 (MLC):  TSK vs MINY    — MLC TEST
--
-- Both matches are dated in the near future so the 'open'
-- status makes sense.  Adjust match_date if needed.
--
-- DATABASE: Neon PostgreSQL (MT Games)
-- SAFE TO RE-RUN: Both blocks guard on match_title using
--   WHERE NOT EXISTS, so re-running will not duplicate rows.
--
-- TO REMOVE TEST DATA AFTER QA:
--   DELETE FROM closest_call_questions
--     WHERE closest_call_match_id IN (
--       SELECT id FROM closest_call_matches
--       WHERE match_title LIKE '%TEST%'
--     );
--   DELETE FROM closest_call_predictions
--     WHERE closest_call_match_id IN (
--       SELECT id FROM closest_call_matches
--       WHERE match_title LIKE '%TEST%'
--     );
--   DELETE FROM closest_call_matches
--     WHERE match_title LIKE '%TEST%';
-- ============================================================


-- ============================================================
-- TEST GAME 1: India Women vs Pakistan Women
--              Women's T20 World Cup — TEST ONLY
--              Placeholder date: June 28, 2026  2:00 PM UTC
-- ============================================================
WITH m_indw_pakw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    '[TEST] IND-W vs PAK-W — WT20 WC',
    'IND-W',
    'PAK-W',
    '2026-06-28 14:00:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
  )
  RETURNING id
),
m_indw_pakw_id AS (
  SELECT id FROM m_indw_pakw
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
    AND  NOT EXISTS (SELECT 1 FROM m_indw_pakw)
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
FROM m_indw_pakw_id mi
CROSS JOIN (VALUES
  -- ── Pre-match questions (open now → lock at 14:00 UTC) ──
  ('How many runs will Smriti Mandhana score?',
   'batter_runs',      'pre_match',   'IND-W',  'Smriti Mandhana',      1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-28 14:00:00+00'::TIMESTAMPTZ),

  ('How many runs will Shafali Verma score?',
   'batter_runs',      'pre_match',   'IND-W',  'Shafali Verma',        1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-28 14:00:00+00'::TIMESTAMPTZ),

  ('How many runs will Bismah Maroof score?',
   'batter_runs',      'pre_match',   'PAK-W',  'Bismah Maroof',        2, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-28 14:00:00+00'::TIMESTAMPTZ),

  ('How many wickets will Deepti Sharma take?',
   'bowler_wickets',   'pre_match',   'IND-W',  'Deepti Sharma',        1, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-28 14:00:00+00'::TIMESTAMPTZ),

  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',   NULL::TEXT, NULL::TEXT,         NULL::INT, 100, 'TOTAL_SIXES',
   NULL::TIMESTAMPTZ, '2026-06-28 14:00:00+00'::TIMESTAMPTZ),

  -- ── Innings 1 — India Women bat ──
  -- Powerplay:  open 14:00, lock 14:40
  ('What will IND-W score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'IND-W',  NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 14:00:00+00'::TIMESTAMPTZ, '2026-06-28 14:40:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 14:40, lock 15:10
  ('What will IND-W score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings', 'IND-W',  NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 14:40:00+00'::TIMESTAMPTZ, '2026-06-28 15:10:00+00'::TIMESTAMPTZ),

  -- Final:       open 15:10, lock 15:40
  ('What will IND-W final innings total be?',
   'team_final_score', 'final',       'IND-W',  NULL::TEXT,             1, 100, 'TEAM_FINAL_SCORE',
   '2026-06-28 15:10:00+00'::TIMESTAMPTZ, '2026-06-28 15:40:00+00'::TIMESTAMPTZ),

  -- ── Innings 2 — Pakistan Women bat ──
  -- Innings 2 starts ≈ 105 min after kickoff (15:45 UTC)
  -- Powerplay:  open 15:45, lock 16:25
  ('What will PAK-W score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'PAK-W',  NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 15:45:00+00'::TIMESTAMPTZ, '2026-06-28 16:25:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 16:25, lock 16:55
  ('What will PAK-W score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings', 'PAK-W',  NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 16:25:00+00'::TIMESTAMPTZ, '2026-06-28 16:55:00+00'::TIMESTAMPTZ),

  -- Final:       open 16:55, lock 17:25
  ('What will PAK-W final innings total be?',
   'team_final_score', 'final',       'PAK-W',  NULL::TEXT,             2, 100, 'TEAM_FINAL_SCORE',
   '2026-06-28 16:55:00+00'::TIMESTAMPTZ, '2026-06-28 17:25:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- TEST GAME 2: Texas Super Kings vs MI New York
--              Major League Cricket 2026 — TEST ONLY
--              Placeholder date: June 28, 2026  9:00 PM UTC
-- ============================================================
WITH m_tsk_miny AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    '[TEST] TSK vs MI New York — MLC 2026',
    'TSK',
    'MINY',
    '2026-06-28 21:00:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = '[TEST] TSK vs MI New York — MLC 2026'
  )
  RETURNING id
),
m_tsk_miny_id AS (
  SELECT id FROM m_tsk_miny
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = '[TEST] TSK vs MI New York — MLC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_tsk_miny)
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
FROM m_tsk_miny_id mi
CROSS JOIN (VALUES
  -- ── Pre-match questions (open now → lock at 21:00 UTC) ──
  ('How many runs will Devon Conway score?',
   'batter_runs',      'pre_match',   'TSK',    'Devon Conway',         1, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-28 21:00:00+00'::TIMESTAMPTZ),

  ('How many runs will Tim David score?',
   'batter_runs',      'pre_match',   'MINY',   'Tim David',            2, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-28 21:00:00+00'::TIMESTAMPTZ),

  ('How many runs will Romario Shepherd score?',
   'batter_runs',      'pre_match',   'MINY',   'Romario Shepherd',     2, 150, 'BATTER_RUNS',
   NULL::TIMESTAMPTZ, '2026-06-28 21:00:00+00'::TIMESTAMPTZ),

  ('How many wickets will Mitchell Santner take?',
   'bowler_wickets',   'pre_match',   'TSK',    'Mitchell Santner',     1, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-28 21:00:00+00'::TIMESTAMPTZ),

  ('How many wickets will Rashid Khan take?',
   'bowler_wickets',   'pre_match',   'MINY',   'Rashid Khan',          2, 100, 'BOWLER_WICKETS',
   NULL::TIMESTAMPTZ, '2026-06-28 21:00:00+00'::TIMESTAMPTZ),

  ('How many total sixes will be hit in the match?',
   'total_sixes',      'pre_match',   NULL::TEXT, NULL::TEXT,         NULL::INT, 100, 'TOTAL_SIXES',
   NULL::TIMESTAMPTZ, '2026-06-28 21:00:00+00'::TIMESTAMPTZ),

  -- ── Innings 1 — Texas Super Kings bat ──
  -- Powerplay:  open 21:00, lock 21:40
  ('What will Texas Super Kings score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'TSK',    NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 21:00:00+00'::TIMESTAMPTZ, '2026-06-28 21:40:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 21:40, lock 22:10
  ('What will Texas Super Kings score after 12 overs (Innings 1)?',
   'team_score_12',    'mid_innings', 'TSK',    NULL::TEXT,             1, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 21:40:00+00'::TIMESTAMPTZ, '2026-06-28 22:10:00+00'::TIMESTAMPTZ),

  -- Final:       open 22:10, lock 22:40
  ('What will Texas Super Kings final innings total be?',
   'team_final_score', 'final',       'TSK',    NULL::TEXT,             1, 100, 'TEAM_FINAL_SCORE',
   '2026-06-28 22:10:00+00'::TIMESTAMPTZ, '2026-06-28 22:40:00+00'::TIMESTAMPTZ),

  -- ── Innings 2 — MI New York bat ──
  -- Innings 2 starts ≈ 105 min after kickoff (22:45 UTC)
  -- Powerplay:  open 22:45, lock 23:25
  ('What will MI New York score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'MINY',   NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 22:45:00+00'::TIMESTAMPTZ, '2026-06-28 23:25:00+00'::TIMESTAMPTZ),

  -- Mid-innings: open 23:25, lock 23:55
  ('What will MI New York score after 12 overs (Innings 2)?',
   'team_score_12',    'mid_innings', 'MINY',   NULL::TEXT,             2, 100, 'TEAM_PHASE_SCORE',
   '2026-06-28 23:25:00+00'::TIMESTAMPTZ, '2026-06-28 23:55:00+00'::TIMESTAMPTZ),

  -- Final:       open 23:55, lock 00:25 next day
  ('What will MI New York final innings total be?',
   'team_final_score', 'final',       'MINY',   NULL::TEXT,             2, 100, 'TEAM_FINAL_SCORE',
   '2026-06-28 23:55:00+00'::TIMESTAMPTZ, '2026-06-29 00:25:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- 1. Confirm test matches were created:
SELECT id, match_title, team_1, team_2, status, match_date
FROM   closest_call_matches
WHERE  match_title LIKE '[TEST]%'
ORDER  BY match_date;

-- 2. Confirm question counts (expect 11 per match):
SELECT
  ccm.match_title,
  COUNT(ccq.id)  AS total_questions,
  SUM(CASE WHEN ccq.phase = 'pre_match'   THEN 1 ELSE 0 END) AS pre_match,
  SUM(CASE WHEN ccq.phase = 'powerplay'   THEN 1 ELSE 0 END) AS powerplay,
  SUM(CASE WHEN ccq.phase = 'mid_innings' THEN 1 ELSE 0 END) AS mid_innings,
  SUM(CASE WHEN ccq.phase = 'final'       THEN 1 ELSE 0 END) AS final
FROM   closest_call_matches ccm
LEFT   JOIN closest_call_questions ccq ON ccq.closest_call_match_id = ccm.id
WHERE  ccm.match_title LIKE '[TEST]%'
GROUP  BY ccm.match_title
ORDER  BY ccm.match_title;
