-- ============================================================
-- FILE: sql/test_nzw_saw_game_01_create_game_questions.sql
-- PURPOSE: Create a TEST Closest Call match (NZ-W vs SA-W) with
--          8 questions covering all v2 scoring rule codes:
--            TEAM_SCORE_50, POWERPLAY_SCORE_30, BATTER_SCORE_20, TEAM_SIXES_10
--
-- TEST MATCH: [TEST] NZ-W vs SA-W — WT20 WC 2026
-- DATE:       2026-07-01 14:00:00 UTC (placeholder)
--
-- DATABASE: Neon PostgreSQL (MT Games)
-- SAFE TO RE-RUN: WHERE NOT EXISTS guard on match insert +
--   question insert guard prevent duplicates.
--
-- RUN ORDER:
--   01 → this file (create match + questions)
--   02 → insert test predictions
--   03 → enter actual values and score
--   04 → verify scores
--   05 → cleanup
-- ============================================================


WITH m AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    '[TEST] NZ-W vs SA-W — WT20 WC 2026',
    'NZ-W',
    'SA-W',
    '2026-06-23 22:20:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
  )
  RETURNING id
),
m_id AS (
  SELECT id FROM m
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m)
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
FROM m_id mi
CROSS JOIN (VALUES

  -- ── Pre-match questions: open now, lock at match start 14:00 UTC ──

  -- Q3: Sophie Devine batter runs  [BATTER_SCORE_20 — max 20]
  ('How many runs will Sophie Devine score?',
   'batter_runs',      'pre_match',   'NZ-W',     'Sophie Devine',   1,
   20,  'BATTER_SCORE_20',
   NULL::TIMESTAMPTZ, '2026-06-23 22:20:00+00'::TIMESTAMPTZ),

  -- Q4: NZ Women sixes  [TEAM_SIXES_10 — max 10]
  ('How many sixes will NZ Women hit in the match?',
   'total_sixes',      'pre_match',   'NZ-W',     NULL::TEXT,        NULL::INT,
   10,  'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-23 22:20:00+00'::TIMESTAMPTZ),

  -- Q7: Nadine de Klerk batter runs  [BATTER_SCORE_20 — max 20]
  ('How many runs will Nadine de Klerk score?',
   'batter_runs',      'pre_match',   'SA-W',     'Nadine de Klerk', 2,
   20,  'BATTER_SCORE_20',
   NULL::TIMESTAMPTZ, '2026-06-23 22:20:00+00'::TIMESTAMPTZ),

  -- Q8: SA Women sixes  [TEAM_SIXES_10 — max 10]
  ('How many sixes will SA Women hit in the match?',
   'total_sixes',      'pre_match',   'SA-W',     NULL::TEXT,        NULL::INT,
   10,  'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-23 22:20:00+00'::TIMESTAMPTZ),

  -- ── Innings 1: NZ Women bat ──

  -- Q2: NZ Women powerplay  [POWERPLAY_SCORE_30 — max 30]
  -- open at match start, lock after 6 overs (~40 min)
  ('What will NZ Women score after 6 overs (Innings 1)?',
   'team_score_6',     'powerplay',   'NZ-W',     NULL::TEXT,        1,
   30,  'POWERPLAY_SCORE_30',
   '2026-06-23 22:20:00+00'::TIMESTAMPTZ, '2026-07-01 14:40:00+00'::TIMESTAMPTZ),

  -- Q1: NZ Women final innings total  [TEAM_SCORE_50 — max 50]
  -- open after powerplay, lock as innings ends (~15:40)
  ('What will NZ Women final innings total be?',
   'team_final_score', 'final',       'NZ-W',     NULL::TEXT,        1,
   50,  'TEAM_SCORE_50',
   '2026-07-01 14:40:00+00'::TIMESTAMPTZ, '2026-07-01 15:40:00+00'::TIMESTAMPTZ),

  -- ── Innings 2: SA Women bat ──

  -- Q6: SA Women powerplay  [POWERPLAY_SCORE_30 — max 30]
  -- open as innings 2 starts (~15:50), lock after 6 overs
  ('What will SA Women score after 6 overs (Innings 2)?',
   'team_score_6',     'powerplay',   'SA-W',     NULL::TEXT,        2,
   30,  'POWERPLAY_SCORE_30',
   '2026-07-01 15:50:00+00'::TIMESTAMPTZ, '2026-07-01 16:30:00+00'::TIMESTAMPTZ),

  -- Q5: SA Women final innings total  [TEAM_SCORE_50 — max 50]
  -- open after SA powerplay locks, lock as innings ends
  ('What will SA Women final innings total be?',
   'team_final_score', 'final',       'SA-W',     NULL::TEXT,        2,
   50,  'TEAM_SCORE_50',
   '2026-07-01 16:30:00+00'::TIMESTAMPTZ, '2026-07-01 17:30:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ── Verify creation ───────────────────────────────────────────────────────────

SELECT
  ccm.id              AS match_id,
  ccm.match_title,
  ccm.status          AS match_status,
  COUNT(ccq.id)       AS total_questions,
  SUM(ccq.max_points) AS max_possible_pts
FROM   closest_call_matches   ccm
LEFT   JOIN closest_call_questions ccq ON ccq.closest_call_match_id = ccm.id
WHERE  ccm.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
GROUP  BY ccm.id, ccm.match_title, ccm.status;

-- Expected: 8 questions, 220 max possible points


SELECT
  ccq.id,
  ccq.question_type,
  ccq.phase,
  ccq.team_code,
  ccq.player_name,
  ccq.scoring_rule_code,
  ccq.max_points,
  ccq.status
FROM   closest_call_questions ccq
JOIN   closest_call_matches   ccm ON ccm.id = ccq.closest_call_match_id
WHERE  ccm.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
ORDER  BY ccq.id;
