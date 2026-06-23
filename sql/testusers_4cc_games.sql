-- ============================================================
-- FILE: sql/testusers_4cc_games.sql
-- PURPOSE: Insert test predictions for 5 users across all 4
--          upcoming Closest Call games.
--
-- PREREQUISITE: Run questions_4cc_games.sql first so the 6
--   new questions per match exist with their final IDs.
--
-- USERS (5):
--   ami_kolkata    — balanced / accurate guesses (new user)
--   kartik15       — higher-scoring guesses
--   akshat_rr      — lower-scoring guesses
--   yrat_kuhli     — mixed but reasonable guesses
--   chiknichameli  — aggressive / edge-case guesses
--
-- QUESTION TYPES PER GAME (6 total, all pre_match):
--   team_final_score  SL-W / IRE-W / AUS-W / PAK-W / SFU / TSK / WF / SEO
--   team_score_6      (powerplay)
--   total_sixes       (per team, distinguished by team_code)
--
-- EXPECTED TOTALS:
--   5 users × 4 games × 6 questions = 120 predictions
--   Each user: 24 predictions total (6 per game × 4 games)
--
-- SAFE TO RE-RUN: ON CONFLICT (user_id, question_id) DO NOTHING
--   means re-running this file leaves existing predictions intact.
--
-- NOTE: No status column is referenced — closest_call_predictions
--   does not have one.  Only user_id, closest_call_match_id,
--   question_id, and predicted_value are inserted.
--   All CASE expressions are fully exhaustive: no NULL
--   predicted_value rows will be inserted.
-- ============================================================


-- ============================================================
-- STEP 1: Ensure all 5 test users exist in ipl_users
-- ============================================================
INSERT INTO ipl_users (user_name, total_points)
VALUES
  ('ami_kolkata',    100),
  ('kartik15',       100),
  ('akshat_rr',      100),
  ('yrat_kuhli',     100),
  ('chiknichameli',  100)
ON CONFLICT (user_name) DO NOTHING;


-- ============================================================
-- SIMULATED ACTUALS (for reference — these are set in
-- score_4cc_games.sql, not here):
--
--   W1 SL-W vs IRE-W:
--     SL-W  final=138, powerplay=48, sixes=4
--     IRE-W final=112, powerplay=38, sixes=3
--
--   W2 AUS-W vs PAK-W:
--     AUS-W final=152, powerplay=52, sixes=6
--     PAK-W final=118, powerplay=40, sixes=3
--
--   M1 SF Unicorns vs TSK:
--     SFU   final=162, powerplay=54, sixes=8
--     TSK   final=158, powerplay=50, sixes=7
--
--   M2 Washington Freedom vs Seattle Orcas:
--     WF    final=168, powerplay=58, sixes=9
--     SEO   final=145, powerplay=48, sixes=6
-- ============================================================


-- ============================================================
-- STEP 2: Predictions — W1 (SL-W vs IRE-W — WT20 WC 2026)
-- ============================================================

-- ── ami_kolkata: balanced/accurate (close to actuals) ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SL-W'  THEN 135
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'IRE-W' THEN 110
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SL-W'  THEN 46
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'IRE-W' THEN 37
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SL-W'  THEN 4
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'IRE-W' THEN 3
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'ami_kolkata'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── kartik15: high-scoring guesses ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SL-W'  THEN 150
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'IRE-W' THEN 130
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SL-W'  THEN 55
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'IRE-W' THEN 48
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SL-W'  THEN 7
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'IRE-W' THEN 6
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr: low-scoring guesses ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SL-W'  THEN 115
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'IRE-W' THEN 92
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SL-W'  THEN 38
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'IRE-W' THEN 28
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SL-W'  THEN 2
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'IRE-W' THEN 1
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yrat_kuhli: mixed/reasonable ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SL-W'  THEN 128
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'IRE-W' THEN 118
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SL-W'  THEN 44
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'IRE-W' THEN 42
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SL-W'  THEN 3
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'IRE-W' THEN 4
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── chiknichameli: aggressive/edge-case ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SL-W'  THEN 175
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'IRE-W' THEN 145
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SL-W'  THEN 68
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'IRE-W' THEN 58
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SL-W'  THEN 10
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'IRE-W' THEN 8
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SL-W vs IRE-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- STEP 3: Predictions — W2 (AUS-W vs PAK-W — WT20 WC 2026)
-- ============================================================

-- ── ami_kolkata ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'AUS-W' THEN 150
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'PAK-W' THEN 120
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'AUS-W' THEN 50
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'PAK-W' THEN 42
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'AUS-W' THEN 6
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'PAK-W' THEN 3
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'ami_kolkata'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── kartik15 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'AUS-W' THEN 168
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'PAK-W' THEN 140
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'AUS-W' THEN 62
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'PAK-W' THEN 52
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'AUS-W' THEN 9
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'PAK-W' THEN 7
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'AUS-W' THEN 128
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'PAK-W' THEN 98
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'AUS-W' THEN 42
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'PAK-W' THEN 32
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'AUS-W' THEN 3
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'PAK-W' THEN 1
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yrat_kuhli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'AUS-W' THEN 145
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'PAK-W' THEN 125
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'AUS-W' THEN 48
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'PAK-W' THEN 45
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'AUS-W' THEN 5
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'PAK-W' THEN 4
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── chiknichameli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'AUS-W' THEN 182
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'PAK-W' THEN 160
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'AUS-W' THEN 72
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'PAK-W' THEN 60
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'AUS-W' THEN 12
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'PAK-W' THEN 9
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'AUS-W vs PAK-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- STEP 4: Predictions — M1 (SF Unicorns vs Texas Super Kings — MLC 2026)
-- ============================================================

-- ── ami_kolkata ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SFU' THEN 160
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'TSK' THEN 155
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SFU' THEN 52
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'TSK' THEN 48
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SFU' THEN 8
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'TSK' THEN 7
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'ami_kolkata'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── kartik15 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SFU' THEN 178
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'TSK' THEN 175
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SFU' THEN 65
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'TSK' THEN 62
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SFU' THEN 12
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'TSK' THEN 11
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SFU' THEN 135
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'TSK' THEN 130
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SFU' THEN 40
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'TSK' THEN 38
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SFU' THEN 4
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'TSK' THEN 4
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yrat_kuhli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SFU' THEN 168
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'TSK' THEN 152
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SFU' THEN 57
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'TSK' THEN 53
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SFU' THEN 7
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'TSK' THEN 9
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── chiknichameli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SFU' THEN 200
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'TSK' THEN 195
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SFU' THEN 80
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'TSK' THEN 75
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SFU' THEN 15
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'TSK' THEN 14
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'SF Unicorns vs Texas Super Kings — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- STEP 5: Predictions — M2 (Washington Freedom vs Seattle Orcas — MLC 2026)
-- ============================================================

-- ── ami_kolkata ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'WF'  THEN 165
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SEO' THEN 148
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'WF'  THEN 56
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SEO' THEN 47
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'WF'  THEN 9
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SEO' THEN 6
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'ami_kolkata'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── kartik15 ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'WF'  THEN 185
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SEO' THEN 165
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'WF'  THEN 68
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SEO' THEN 58
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'WF'  THEN 13
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SEO' THEN 10
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'WF'  THEN 140
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SEO' THEN 120
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'WF'  THEN 44
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SEO' THEN 36
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'WF'  THEN 5
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SEO' THEN 3
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yrat_kuhli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'WF'  THEN 155
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SEO' THEN 152
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'WF'  THEN 52
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SEO' THEN 52
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'WF'  THEN 7
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SEO' THEN 8
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── chiknichameli ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'WF'  THEN 205
    WHEN q.question_type = 'team_final_score' AND q.team_code = 'SEO' THEN 188
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'WF'  THEN 78
    WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SEO' THEN 68
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'WF'  THEN 14
    WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SEO' THEN 12
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = 'Washington Freedom vs Seattle Orcas — MLC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- VERIFICATION
-- ============================================================

-- 1. Prediction count per user per match (expect 6 each)
SELECT
  u.user_name,
  m.match_title,
  COUNT(p.id) AS prediction_count
FROM   closest_call_predictions p
JOIN   ipl_users             u ON u.id = p.user_id
JOIN   closest_call_matches  m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('ami_kolkata','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  m.match_title IN (
         'SL-W vs IRE-W — WT20 WC 2026',
         'AUS-W vs PAK-W — WT20 WC 2026',
         'SF Unicorns vs Texas Super Kings — MLC 2026',
         'Washington Freedom vs Seattle Orcas — MLC 2026'
       )
GROUP  BY u.user_name, m.match_title
ORDER  BY m.match_title, u.user_name;

-- 2. Total predictions per user (expect 24 each) and grand total (expect 120)
SELECT
  u.user_name,
  COUNT(p.id) AS total_predictions
FROM   closest_call_predictions p
JOIN   ipl_users             u ON u.id = p.user_id
JOIN   closest_call_matches  m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('ami_kolkata','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  m.match_title IN (
         'SL-W vs IRE-W — WT20 WC 2026',
         'AUS-W vs PAK-W — WT20 WC 2026',
         'SF Unicorns vs Texas Super Kings — MLC 2026',
         'Washington Freedom vs Seattle Orcas — MLC 2026'
       )
GROUP  BY u.user_name

UNION ALL

SELECT 'GRAND TOTAL', COUNT(p.id)
FROM   closest_call_predictions p
JOIN   ipl_users             u ON u.id = p.user_id
JOIN   closest_call_matches  m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('ami_kolkata','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  m.match_title IN (
         'SL-W vs IRE-W — WT20 WC 2026',
         'AUS-W vs PAK-W — WT20 WC 2026',
         'SF Unicorns vs Texas Super Kings — MLC 2026',
         'Washington Freedom vs Seattle Orcas — MLC 2026'
       )

ORDER  BY user_name;

-- 3. Confirm no NULL predicted_value rows were inserted
SELECT COUNT(*) AS null_predicted_value_count
FROM   closest_call_predictions p
JOIN   ipl_users             u ON u.id = p.user_id
JOIN   closest_call_matches  m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('ami_kolkata','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  m.match_title IN (
         'SL-W vs IRE-W — WT20 WC 2026',
         'AUS-W vs PAK-W — WT20 WC 2026',
         'SF Unicorns vs Texas Super Kings — MLC 2026',
         'Washington Freedom vs Seattle Orcas — MLC 2026'
       )
  AND  p.predicted_value IS NULL;
