-- ============================================================
-- FILE: sql/insert_wwc_2026_upcoming_games_questions_test_predictions.sql
-- PURPOSE: Insert 3 upcoming Women's T20 World Cup 2026 matches,
--          6 pre-match questions per game (v2 scoring rules),
--          and test predictions for 5 test users.
--
-- MATCHES:
--   W1: ENG-W vs WI-W   — 24 June 2026  1:30 PM EST  (17:30 UTC)
--   W2: IND-W vs BAN-W  — 25 June 2026  9:30 AM EST  (13:30 UTC)
--   W3: ENG-W vs NZ-W   — 27 June 2026  1:30 PM EST  (17:30 UTC)
--
-- QUESTIONS (6 per match, all pre_match, lock = match kickoff):
--   1. Team 1 Final Score   → TEAM_SCORE_50     (max 50 pts)
--   2. Team 2 Final Score   → TEAM_SCORE_50     (max 50 pts)
--   3. Team 1 Powerplay     → POWERPLAY_SCORE_30 (max 30 pts)
--   4. Team 2 Powerplay     → POWERPLAY_SCORE_30 (max 30 pts)
--   5. Team 1 Total Sixes   → TEAM_SIXES_10     (max 10 pts)
--   6. Team 2 Total Sixes   → TEAM_SIXES_10     (max 10 pts)
--
-- TEST USERS: kartik15 through knicksrulz_17
--
-- DATABASE: Neon PostgreSQL (MT Games)
-- SAFE TO RE-RUN: WHERE NOT EXISTS guards on match + question inserts.
--   Predictions use ON CONFLICT (user_id, question_id) DO NOTHING.
-- ============================================================


-- ============================================================
-- MATCH W1: England Women vs West Indies Women
--           Women's T20 World Cup 2026
--           24 June 2026  1:30 PM EST  →  17:30:00 UTC
-- ============================================================
WITH m_engw_wiw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'ENG-W vs WI-W — WT20 WC 2026',
    'ENG-W',
    'WI-W',
    '2026-06-24 17:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'ENG-W vs WI-W — WT20 WC 2026'
  )
  RETURNING id
),
m_engw_wiw_id AS (
  SELECT id FROM m_engw_wiw
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'ENG-W vs WI-W — WT20 WC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_engw_wiw)
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
FROM m_engw_wiw_id mi
CROSS JOIN (VALUES

  -- Q1: ENG-W Final Score  [TEAM_SCORE_50 — max 50 pts]
  ('What will ENG-W final innings total be?',
   'team_final_score', 'pre_match', 'ENG-W', NULL::TEXT, 1,
   50, 'TEAM_SCORE_50',
   NULL::TIMESTAMPTZ, '2026-06-24 17:30:00+00'::TIMESTAMPTZ),

  -- Q2: WI-W Final Score  [TEAM_SCORE_50 — max 50 pts]
  ('What will WI-W final innings total be?',
   'team_final_score', 'pre_match', 'WI-W', NULL::TEXT, 2,
   50, 'TEAM_SCORE_50',
   NULL::TIMESTAMPTZ, '2026-06-24 17:30:00+00'::TIMESTAMPTZ),

  -- Q3: ENG-W Powerplay  [POWERPLAY_SCORE_30 — max 30 pts]
  ('What will ENG-W score after 6 overs?',
   'team_score_6', 'pre_match', 'ENG-W', NULL::TEXT, 1,
   30, 'POWERPLAY_SCORE_30',
   NULL::TIMESTAMPTZ, '2026-06-24 17:30:00+00'::TIMESTAMPTZ),

  -- Q4: WI-W Powerplay  [POWERPLAY_SCORE_30 — max 30 pts]
  ('What will WI-W score after 6 overs?',
   'team_score_6', 'pre_match', 'WI-W', NULL::TEXT, 2,
   30, 'POWERPLAY_SCORE_30',
   NULL::TIMESTAMPTZ, '2026-06-24 17:30:00+00'::TIMESTAMPTZ),

  -- Q5: ENG-W Sixes  [TEAM_SIXES_10 — max 10 pts]
  ('How many sixes will ENG-W hit?',
   'total_sixes', 'pre_match', 'ENG-W', NULL::TEXT, 1,
   10, 'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-24 17:30:00+00'::TIMESTAMPTZ),

  -- Q6: WI-W Sixes  [TEAM_SIXES_10 — max 10 pts]
  ('How many sixes will WI-W hit?',
   'total_sixes', 'pre_match', 'WI-W', NULL::TEXT, 2,
   10, 'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-24 17:30:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- MATCH W2: India Women vs Bangladesh Women
--           Women's T20 World Cup 2026
--           25 June 2026  9:30 AM EST  →  13:30:00 UTC
-- ============================================================
WITH m_indw_banw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'IND-W vs BAN-W — WT20 WC 2026',
    'IND-W',
    'BAN-W',
    '2026-06-25 13:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'IND-W vs BAN-W — WT20 WC 2026'
  )
  RETURNING id
),
m_indw_banw_id AS (
  SELECT id FROM m_indw_banw
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'IND-W vs BAN-W — WT20 WC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_indw_banw)
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
FROM m_indw_banw_id mi
CROSS JOIN (VALUES

  -- Q1: IND-W Final Score  [TEAM_SCORE_50 — max 50 pts]
  ('What will IND-W final innings total be?',
   'team_final_score', 'pre_match', 'IND-W', NULL::TEXT, 1,
   50, 'TEAM_SCORE_50',
   NULL::TIMESTAMPTZ, '2026-06-25 13:30:00+00'::TIMESTAMPTZ),

  -- Q2: BAN-W Final Score  [TEAM_SCORE_50 — max 50 pts]
  ('What will BAN-W final innings total be?',
   'team_final_score', 'pre_match', 'BAN-W', NULL::TEXT, 2,
   50, 'TEAM_SCORE_50',
   NULL::TIMESTAMPTZ, '2026-06-25 13:30:00+00'::TIMESTAMPTZ),

  -- Q3: IND-W Powerplay  [POWERPLAY_SCORE_30 — max 30 pts]
  ('What will IND-W score after 6 overs?',
   'team_score_6', 'pre_match', 'IND-W', NULL::TEXT, 1,
   30, 'POWERPLAY_SCORE_30',
   NULL::TIMESTAMPTZ, '2026-06-25 13:30:00+00'::TIMESTAMPTZ),

  -- Q4: BAN-W Powerplay  [POWERPLAY_SCORE_30 — max 30 pts]
  ('What will BAN-W score after 6 overs?',
   'team_score_6', 'pre_match', 'BAN-W', NULL::TEXT, 2,
   30, 'POWERPLAY_SCORE_30',
   NULL::TIMESTAMPTZ, '2026-06-25 13:30:00+00'::TIMESTAMPTZ),

  -- Q5: IND-W Sixes  [TEAM_SIXES_10 — max 10 pts]
  ('How many sixes will IND-W hit?',
   'total_sixes', 'pre_match', 'IND-W', NULL::TEXT, 1,
   10, 'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-25 13:30:00+00'::TIMESTAMPTZ),

  -- Q6: BAN-W Sixes  [TEAM_SIXES_10 — max 10 pts]
  ('How many sixes will BAN-W hit?',
   'total_sixes', 'pre_match', 'BAN-W', NULL::TEXT, 2,
   10, 'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-25 13:30:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);


-- ============================================================
-- MATCH W3: England Women vs New Zealand Women
--           Women's T20 World Cup 2026
--           27 June 2026  1:30 PM EST  →  17:30:00 UTC
-- ============================================================
WITH m_engw_nzw AS (
  INSERT INTO closest_call_matches
    (match_title, team_1, team_2, match_date, status)
  SELECT
    'ENG-W vs NZ-W — WT20 WC 2026',
    'ENG-W',
    'NZ-W',
    '2026-06-27 17:30:00+00'::TIMESTAMPTZ,
    'open'
  WHERE NOT EXISTS (
    SELECT 1 FROM closest_call_matches
    WHERE  match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
  )
  RETURNING id
),
m_engw_nzw_id AS (
  SELECT id FROM m_engw_nzw
  UNION ALL
  SELECT id FROM closest_call_matches
  WHERE  match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
    AND  NOT EXISTS (SELECT 1 FROM m_engw_nzw)
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
FROM m_engw_nzw_id mi
CROSS JOIN (VALUES

  -- Q1: ENG-W Final Score  [TEAM_SCORE_50 — max 50 pts]
  ('What will ENG-W final innings total be?',
   'team_final_score', 'pre_match', 'ENG-W', NULL::TEXT, 1,
   50, 'TEAM_SCORE_50',
   NULL::TIMESTAMPTZ, '2026-06-27 17:30:00+00'::TIMESTAMPTZ),

  -- Q2: NZ-W Final Score  [TEAM_SCORE_50 — max 50 pts]
  ('What will NZ-W final innings total be?',
   'team_final_score', 'pre_match', 'NZ-W', NULL::TEXT, 2,
   50, 'TEAM_SCORE_50',
   NULL::TIMESTAMPTZ, '2026-06-27 17:30:00+00'::TIMESTAMPTZ),

  -- Q3: ENG-W Powerplay  [POWERPLAY_SCORE_30 — max 30 pts]
  ('What will ENG-W score after 6 overs?',
   'team_score_6', 'pre_match', 'ENG-W', NULL::TEXT, 1,
   30, 'POWERPLAY_SCORE_30',
   NULL::TIMESTAMPTZ, '2026-06-27 17:30:00+00'::TIMESTAMPTZ),

  -- Q4: NZ-W Powerplay  [POWERPLAY_SCORE_30 — max 30 pts]
  ('What will NZ-W score after 6 overs?',
   'team_score_6', 'pre_match', 'NZ-W', NULL::TEXT, 2,
   30, 'POWERPLAY_SCORE_30',
   NULL::TIMESTAMPTZ, '2026-06-27 17:30:00+00'::TIMESTAMPTZ),

  -- Q5: ENG-W Sixes  [TEAM_SIXES_10 — max 10 pts]
  ('How many sixes will ENG-W hit?',
   'total_sixes', 'pre_match', 'ENG-W', NULL::TEXT, 1,
   10, 'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-27 17:30:00+00'::TIMESTAMPTZ),

  -- Q6: NZ-W Sixes  [TEAM_SIXES_10 — max 10 pts]
  ('How many sixes will NZ-W hit?',
   'total_sixes', 'pre_match', 'NZ-W', NULL::TEXT, 2,
   10, 'TEAM_SIXES_10',
   NULL::TIMESTAMPTZ, '2026-06-27 17:30:00+00'::TIMESTAMPTZ)

) AS q(question_text, question_type, phase, team_code, player_name, innings_number,
       max_points, scoring_rule_code, open_time, lock_time)
WHERE NOT EXISTS (
  SELECT 1 FROM closest_call_questions WHERE closest_call_match_id = mi.id
);



-- ============================================================
-- TEST PREDICTIONS — MATCH W1: ENG-W vs WI-W
-- Predictions are varied realistic T20 guesses:
--   Finals typically 120–175, Powerplay 38–68, Sixes 3–12
-- ============================================================

-- ── kartik15 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 152 WHEN 'WI-W' THEN 148 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 55  WHEN 'WI-W' THEN 48  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 7   WHEN 'WI-W' THEN 6   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs WI-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yart_kuhli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 138 WHEN 'WI-W' THEN 142 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 48  WHEN 'WI-W' THEN 52  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 5   WHEN 'WI-W' THEN 8   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs WI-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yart_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── og_jalenbrunson ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 165 WHEN 'WI-W' THEN 132 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 60  WHEN 'WI-W' THEN 42  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 9   WHEN 'WI-W' THEN 4   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs WI-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'og_jalenbrunson'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 125 WHEN 'WI-W' THEN 155 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 44  WHEN 'WI-W' THEN 56  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 4   WHEN 'WI-W' THEN 9   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs WI-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── knicksrulz_17 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 148 WHEN 'WI-W' THEN 138 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 52  WHEN 'WI-W' THEN 46  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 6   WHEN 'WI-W' THEN 7   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs WI-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'knicksrulz_17'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- TEST PREDICTIONS — MATCH W2: IND-W vs BAN-W
-- ============================================================

-- ── kartik15 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'IND-W' THEN 165 WHEN 'BAN-W' THEN 110 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'IND-W' THEN 62  WHEN 'BAN-W' THEN 38  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'IND-W' THEN 9   WHEN 'BAN-W' THEN 3   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'IND-W vs BAN-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yart_kuhli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'IND-W' THEN 172 WHEN 'BAN-W' THEN 95  END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'IND-W' THEN 68  WHEN 'BAN-W' THEN 32  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'IND-W' THEN 11  WHEN 'BAN-W' THEN 2   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'IND-W vs BAN-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yart_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── og_jalenbrunson ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'IND-W' THEN 155 WHEN 'BAN-W' THEN 118 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'IND-W' THEN 58  WHEN 'BAN-W' THEN 44  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'IND-W' THEN 7   WHEN 'BAN-W' THEN 5   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'IND-W vs BAN-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'og_jalenbrunson'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'IND-W' THEN 180 WHEN 'BAN-W' THEN 105 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'IND-W' THEN 72  WHEN 'BAN-W' THEN 36  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'IND-W' THEN 12  WHEN 'BAN-W' THEN 4   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'IND-W vs BAN-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── knicksrulz_17 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'IND-W' THEN 162 WHEN 'BAN-W' THEN 112 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'IND-W' THEN 60  WHEN 'BAN-W' THEN 40  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'IND-W' THEN 8   WHEN 'BAN-W' THEN 3   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'IND-W vs BAN-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'knicksrulz_17'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- TEST PREDICTIONS — MATCH W3: ENG-W vs NZ-W
-- ============================================================

-- ── kartik15 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 145 WHEN 'NZ-W' THEN 158 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 52  WHEN 'NZ-W' THEN 56  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 6   WHEN 'NZ-W' THEN 8   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yart_kuhli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 160 WHEN 'NZ-W' THEN 145 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 58  WHEN 'NZ-W' THEN 50  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 8   WHEN 'NZ-W' THEN 6   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yart_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── og_jalenbrunson ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 130 WHEN 'NZ-W' THEN 167 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 46  WHEN 'NZ-W' THEN 62  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 4   WHEN 'NZ-W' THEN 10  END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'og_jalenbrunson'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 155 WHEN 'NZ-W' THEN 140 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 54  WHEN 'NZ-W' THEN 48  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 7   WHEN 'NZ-W' THEN 5   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── knicksrulz_17 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'ENG-W' THEN 140 WHEN 'NZ-W' THEN 162 END
    WHEN 'team_score_6'     THEN CASE q.team_code WHEN 'ENG-W' THEN 50  WHEN 'NZ-W' THEN 58  END
    WHEN 'total_sixes'      THEN CASE q.team_code WHEN 'ENG-W' THEN 5   WHEN 'NZ-W' THEN 9   END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'ENG-W vs NZ-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'knicksrulz_17'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- 1. Confirm all 3 matches exist with correct dates:
SELECT id, match_title, team_1, team_2, status,
       match_date AT TIME ZONE 'America/New_York' AS match_date_et
FROM   closest_call_matches
WHERE  match_title IN (
         'ENG-W vs WI-W — WT20 WC 2026',
         'IND-W vs BAN-W — WT20 WC 2026',
         'ENG-W vs NZ-W — WT20 WC 2026'
       )
ORDER  BY match_date;

-- 2. Confirm 6 questions per match, all pre_match:
SELECT
  ccm.match_title,
  COUNT(ccq.id)           AS question_count,
  SUM(ccq.max_points)     AS max_possible_pts,
  STRING_AGG(DISTINCT ccq.phase, ', ') AS phases,
  STRING_AGG(DISTINCT ccq.scoring_rule_code, ', ' ORDER BY ccq.scoring_rule_code) AS rules_used
FROM   closest_call_matches   ccm
LEFT   JOIN closest_call_questions ccq ON ccq.closest_call_match_id = ccm.id
WHERE  ccm.match_title IN (
         'ENG-W vs WI-W — WT20 WC 2026',
         'IND-W vs BAN-W — WT20 WC 2026',
         'ENG-W vs NZ-W — WT20 WC 2026'
       )
GROUP  BY ccm.match_title
ORDER  BY ccm.match_title;

-- Expected per match: 6 questions, 180 max pts, phase = pre_match only,
-- rules = POWERPLAY_SCORE_30, TEAM_SCORE_50, TEAM_SIXES_10

-- 3. Confirm 6 predictions per user per match:
SELECT
  u.user_name,
  m.match_title,
  COUNT(p.id) AS predictions
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  u.user_name LIKE 'wwc_test_user_%'
  AND  m.match_title IN (
         'ENG-W vs WI-W — WT20 WC 2026',
         'IND-W vs BAN-W — WT20 WC 2026',
         'ENG-W vs NZ-W — WT20 WC 2026'
       )
GROUP  BY u.user_name, m.match_title
ORDER  BY m.match_title, u.user_name;

-- Expected: 6 predictions per user per match (5 users × 3 matches = 15 rows)
