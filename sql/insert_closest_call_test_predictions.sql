-- ============================================================
-- FILE: sql/insert_closest_call_test_predictions.sql
-- PURPOSE: Insert test predictions for five dummy users across
--          both test matches created by insert_closest_call_test_games.sql.
--
--   Test users: mannu_09, kartik15, akshat_rr, yrat_kuhli, chiknichameli
--   Test matches:
--     [TEST] IND-W vs PAK-W — WT20 WC
--     [TEST] TSK vs MI New York — MLC 2026
--
-- PREREQUISITES:
--   Run insert_closest_call_test_games.sql first so the test
--   matches and questions exist.
--
-- WHAT THIS TESTS:
--   • Users spread across different score guesses → varied
--     leaderboard positions after actuals are entered
--   • All question types covered: batter_runs, bowler_wickets,
--     total_sixes, team_score_6, team_score_12, team_final_score
--   • Some users skip in-game questions (only answered pre-match)
--   • Tie-breaking between close scores visible on leaderboard
--
-- SAFE TO RE-RUN: Uses ON CONFLICT (user_id, question_id) DO NOTHING
--   on closest_call_predictions — re-running changes nothing.
--
-- TO SCORE AFTER QA:
--   Call /api/update-closest-call-actuals with real (or fake)
--   actual values, then the scoring engine computes differences
--   and awards points.
-- ============================================================


-- ============================================================
-- STEP 1: Ensure test users exist in ipl_users
--         (100 starting coins each, ON CONFLICT = no-op)
-- ============================================================
INSERT INTO ipl_users (user_name, total_points)
VALUES
  ('mannu_09', 100),
  ('kartik15', 100),
  ('akshat_rr', 100),
  ('yrat_kuhli', 100),
  ('chiknichameli', 100)
ON CONFLICT (user_name) DO NOTHING;


-- ============================================================
-- STEP 2: Predictions — TEST GAME 1
--         [TEST] IND-W vs PAK-W — WT20 WC
--
-- Simulated actual values for scoring reference (NOT inserted
-- here — use update-closest-call-actuals API to score):
--   Smriti Mandhana runs       : 42
--   Shafali Verma runs         : 28
--   Bismah Maroof runs         : 15
--   Deepti Sharma wickets      : 2
--   Total sixes                : 8
--   IND-W 6-over score         : 52
--   IND-W 12-over score        : 98
--   IND-W final total          : 147
--   PAK-W 6-over score         : 35
--   PAK-W 12-over score        : 72
--   PAK-W final total          : 112
-- ============================================================

-- ── mannu_09: good across the board, slightly off on scores ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs'      THEN
      CASE q.player_name
        WHEN 'Smriti Mandhana' THEN 40   -- diff 2  (very close)
        WHEN 'Shafali Verma'   THEN 30   -- diff 2
        WHEN 'Bismah Maroof'   THEN 18   -- diff 3
        ELSE NULL
      END
    WHEN 'bowler_wickets'   THEN 2       -- diff 0  (exact)
    WHEN 'total_sixes'      THEN 7       -- diff 1
    WHEN 'team_score_6'     THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 50            -- diff 2
        WHEN 'PAK-W' THEN 33            -- diff 2
      END
    WHEN 'team_score_12'    THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 95            -- diff 3
        WHEN 'PAK-W' THEN 70            -- diff 2
      END
    WHEN 'team_final_score' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 145           -- diff 2
        WHEN 'PAK-W' THEN 110           -- diff 2
      END
  END AS predicted_value
  
FROM ipl_users u
JOIN closest_call_matches m     ON m.match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
JOIN closest_call_questions q   ON q.closest_call_match_id = m.id
WHERE u.user_name = 'mannu_09'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── kartik15: overestimates scores, accurate on player stats ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Smriti Mandhana' THEN 55
        WHEN 'Shafali Verma' THEN 40
        WHEN 'Bismah Maroof' THEN 25
        ELSE NULL
      END
    WHEN 'bowler_wickets' THEN 3
    WHEN 'total_sixes' THEN 10
    WHEN 'team_score_6' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 60
        WHEN 'PAK-W' THEN 42
      END
    WHEN 'team_score_12' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 110
        WHEN 'PAK-W' THEN 80
      END
    WHEN 'team_final_score' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 162
        WHEN 'PAK-W' THEN 125
      END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;



-- ── akshat_rr: underestimates scores, misses on wickets ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Smriti Mandhana' THEN 25
        WHEN 'Shafali Verma' THEN 15
        WHEN 'Bismah Maroof' THEN 8
        ELSE NULL
      END
    WHEN 'bowler_wickets' THEN 0
    WHEN 'total_sixes' THEN 5
    WHEN 'team_score_6' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 44
        WHEN 'PAK-W' THEN 28
      END
    WHEN 'team_score_12' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 82
        WHEN 'PAK-W' THEN 60
      END
    WHEN 'team_final_score' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 128
        WHEN 'PAK-W' THEN 95
      END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── yrat_kuhli: pre-match only (skipped in-game questions) ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Smriti Mandhana' THEN 38
        WHEN 'Shafali Verma' THEN 22
        WHEN 'Bismah Maroof' THEN 20
        ELSE NULL
      END
    WHEN 'bowler_wickets' THEN 1
    WHEN 'total_sixes' THEN 9
    ELSE NULL
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
  AND q.phase = 'pre_match'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── chiknichameli: exact hit on total (edge-case test), wider misses elsewhere ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Smriti Mandhana' THEN 42
        WHEN 'Shafali Verma' THEN 50
        WHEN 'Bismah Maroof' THEN 35
        ELSE NULL
      END
    WHEN 'bowler_wickets' THEN 4
    WHEN 'total_sixes' THEN 8
    WHEN 'team_score_6' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 65
        WHEN 'PAK-W' THEN 48
      END
    WHEN 'team_score_12' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 120
        WHEN 'PAK-W' THEN 90
      END
    WHEN 'team_final_score' THEN
      CASE q.team_code
        WHEN 'IND-W' THEN 175
        WHEN 'PAK-W' THEN 138
      END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;



-- ============================================================
-- STEP 3: Predictions — TEST GAME 2
--         [TEST] TSK vs MI New York — MLC 2026
--
-- Simulated actual values for scoring reference:
--   Devon Conway runs          : 38
--   Tim David runs             : 55
--   Romario Shepherd runs      : 22
--   Mitchell Santner wickets   : 1
--   Rashid Khan wickets        : 3
--   Total sixes                : 14
--   TSK 6-over score           : 48
--   TSK 12-over score          : 92
--   TSK final total            : 158
--   MINY 6-over score          : 54
--   MINY 12-over score         : 105
--   MINY final total           : 162
-- ============================================================

-- ── mannu_09: accurate overall ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN CASE q.player_name
      WHEN 'Devon Conway' THEN 35
      WHEN 'Tim David' THEN 52
      WHEN 'Romario Shepherd' THEN 20
      ELSE NULL END
    WHEN 'bowler_wickets' THEN CASE q.player_name
      WHEN 'Mitchell Santner' THEN 1
      WHEN 'Rashid Khan' THEN 3
      ELSE NULL END
    WHEN 'total_sixes' THEN 13
    WHEN 'team_score_6' THEN CASE q.team_code WHEN 'TSK' THEN 46 WHEN 'MINY' THEN 52 END
    WHEN 'team_score_12' THEN CASE q.team_code WHEN 'TSK' THEN 90 WHEN 'MINY' THEN 103 END
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'TSK' THEN 155 WHEN 'MINY' THEN 160 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] TSK vs MI New York — MLC 2026'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'mannu_09'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── kartik15: high guesses ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN CASE q.player_name
      WHEN 'Devon Conway' THEN 55
      WHEN 'Tim David' THEN 70
      WHEN 'Romario Shepherd' THEN 40
      ELSE NULL END
    WHEN 'bowler_wickets' THEN CASE q.player_name
      WHEN 'Mitchell Santner' THEN 3
      WHEN 'Rashid Khan' THEN 5
      ELSE NULL END
    WHEN 'total_sixes' THEN 20
    WHEN 'team_score_6' THEN CASE q.team_code WHEN 'TSK' THEN 60 WHEN 'MINY' THEN 65 END
    WHEN 'team_score_12' THEN CASE q.team_code WHEN 'TSK' THEN 112 WHEN 'MINY' THEN 120 END
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'TSK' THEN 180 WHEN 'MINY' THEN 185 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] TSK vs MI New York — MLC 2026'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── akshat_rr: low guesses ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN CASE q.player_name
      WHEN 'Devon Conway' THEN 20
      WHEN 'Tim David' THEN 35
      WHEN 'Romario Shepherd' THEN 10
      ELSE NULL END
    WHEN 'bowler_wickets' THEN CASE q.player_name
      WHEN 'Mitchell Santner' THEN 0
      WHEN 'Rashid Khan' THEN 1
      ELSE NULL END
    WHEN 'total_sixes' THEN 8
    WHEN 'team_score_6' THEN CASE q.team_code WHEN 'TSK' THEN 36 WHEN 'MINY' THEN 40 END
    WHEN 'team_score_12' THEN CASE q.team_code WHEN 'TSK' THEN 70 WHEN 'MINY' THEN 82 END
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'TSK' THEN 130 WHEN 'MINY' THEN 135 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] TSK vs MI New York — MLC 2026'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── yrat_kuhli: pre-match only ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN CASE q.player_name
      WHEN 'Devon Conway' THEN 40
      WHEN 'Tim David' THEN 58
      WHEN 'Romario Shepherd' THEN 25
      ELSE NULL END
    WHEN 'bowler_wickets' THEN CASE q.player_name
      WHEN 'Mitchell Santner' THEN 2
      WHEN 'Rashid Khan' THEN 2
      ELSE NULL END
    WHEN 'total_sixes' THEN 12
    ELSE NULL
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] TSK vs MI New York — MLC 2026'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
  AND q.phase = 'pre_match'
ON CONFLICT (user_id, question_id) DO NOTHING;

-- ── chiknichameli: two exact hits, big misses on totals ──
INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'batter_runs' THEN CASE q.player_name
      WHEN 'Devon Conway' THEN 38
      WHEN 'Tim David' THEN 55
      WHEN 'Romario Shepherd' THEN 45
      ELSE NULL END
    WHEN 'bowler_wickets' THEN CASE q.player_name
      WHEN 'Mitchell Santner' THEN 0
      WHEN 'Rashid Khan' THEN 5
      ELSE NULL END
    WHEN 'total_sixes' THEN 6
    WHEN 'team_score_6' THEN CASE q.team_code WHEN 'TSK' THEN 70 WHEN 'MINY' THEN 75 END
    WHEN 'team_score_12' THEN CASE q.team_code WHEN 'TSK' THEN 130 WHEN 'MINY' THEN 140 END
    WHEN 'team_final_score' THEN CASE q.team_code WHEN 'TSK' THEN 200 WHEN 'MINY' THEN 205 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches m ON m.match_title = '[TEST] TSK vs MI New York — MLC 2026'
JOIN closest_call_questions q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- 1. Count predictions per user per match:
SELECT
  u.user_name,
  m.match_title,
  COUNT(p.id) AS prediction_count
FROM   closest_call_predictions p
JOIN   ipl_users                u ON u.id = p.user_id
JOIN   closest_call_matches     m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('mannu_09','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  m.match_title LIKE '[TEST]%'
GROUP  BY u.user_name, m.match_title
ORDER  BY m.match_title, u.user_name;

-- 2. Preview predictions with question text (helpful for QA):
/*
SELECT
  u.user_name,
  q.phase,
  q.question_type,
  q.question_text,
  p.predicted_value
FROM   closest_call_predictions p
JOIN   ipl_users                u ON u.id = p.user_id
JOIN   closest_call_questions   q ON q.id = p.question_id
JOIN   closest_call_matches     m ON m.id = p.closest_call_match_id
WHERE  u.user_name IN ('mannu_09','kartik15','akshat_rr','yrat_kuhli','chiknichameli')
  AND  m.match_title = '[TEST] IND-W vs PAK-W — WT20 WC'
ORDER  BY q.id, u.user_name;
*/

-- ============================================================
-- HOW TO SCORE TEST PREDICTIONS (for leaderboard QA):
--
-- Call /api/update-closest-call-actuals via POST with:
-- {
--   "closest_call_match_id": <id from step 1 above>,
--   "question_updates": [
--     { "question_id": <id>, "actual_value": 42 },
--     ...
--   ]
-- }
--
-- Then close the match:
-- UPDATE closest_call_matches
--   SET status = 'closed'
-- WHERE match_title = '[TEST] IND-W vs PAK-W — WT20 WC';
-- ============================================================
