-- ============================================================
-- FILE: sql/test_nzw_saw_game_02_insert_test_predictions.sql
-- PURPOSE: Insert predictions for 5 test users across all 8
--          questions in the NZ-W vs SA-W test match.
--
-- PREREQUISITE: Run test_nzw_saw_game_01_create_game_questions.sql first.
--
-- TEST USERS (created here if they don't exist):
--   kartik15  — all exact predictions        → 220 pts
--   yrat_kuhli  — small diffs (2–5 off)        → 192 pts
--   og_jalenbrunson  — at boundary (diff = cutoff)  →  52 pts
--   akshat_rr  — just outside every cutoff    →   0 pts
--   chiknichameli  — mixed: some good, some wide  → 139 pts
--
-- ACTUAL VALUES (for reference — entered in file 03):
--   NZ Women final total   : 145
--   NZ Women powerplay     :  48
--   Sophie Devine runs     :  38
--   NZ Women sixes         :   6
--   SA Women final total   : 138
--   SA Women powerplay     :  42
--   Nadine de Klerk runs   :  25
--   SA Women sixes         :   4
--
-- SAFE TO RE-RUN: ON CONFLICT (user_id, question_id) DO NOTHING
-- ============================================================


-- ── Ensure test users exist ───────────────────────────────────────────────────

INSERT INTO ipl_users (user_name, total_points)
VALUES
  ('kartik15', 0),
  ('yrat_kuhli', 0),
  ('og_jalenbrunson', 0),
  ('akshat_rr', 0),
  ('chiknichameli', 0)
ON CONFLICT (user_name) DO NOTHING;


-- ── User 1: All exact — expected 220 pts ─────────────────────────────────────
-- Every prediction matches the actual value precisely.
-- Tests the maximum score for each rule:
--   TEAM_SCORE_50 exact (×2) → 50+50
--   POWERPLAY_SCORE_30 exact (×2) → 30+30
--   BATTER_SCORE_20 exact (×2) → 20+20
--   TEAM_SIXES_10 exact (×2) → 10+10

INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 145 WHEN 'SA-W' THEN 138 END
    WHEN 'team_score_6' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 48 WHEN 'SA-W' THEN 42 END
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Sophie Devine'    THEN 38
        WHEN 'Nadine de Klerk'  THEN 25
      END
    WHEN 'total_sixes' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 6 WHEN 'SA-W' THEN 4 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'kartik15'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── User 2: Small diffs — expected 192 pts ───────────────────────────────────
-- Predictions slightly off; stays well inside every cutoff.
--
-- Predictions vs actuals → diff → pts:
--   NZ final:      147 vs 145 → diff 2  → 48 pts  (TEAM_SCORE_50)
--   NZ powerplay:   51 vs 48  → diff 3  → 27 pts  (POWERPLAY_SCORE_30)
--   Sophie Devine:  33 vs 38  → diff 5  → 15 pts  (BATTER_SCORE_20)
--   NZ sixes:        8 vs 6   → diff 2  →  8 pts  (TEAM_SIXES_10)
--   SA final:      143 vs 138 → diff 5  → 45 pts  (TEAM_SCORE_50)
--   SA powerplay:   46 vs 42  → diff 4  → 26 pts  (POWERPLAY_SCORE_30)
--   Nadine:         20 vs 25  → diff 5  → 15 pts  (BATTER_SCORE_20)
--   SA sixes:        6 vs 4   → diff 2  →  8 pts  (TEAM_SIXES_10)
--   Total: 48+27+15+8+45+26+15+8 = 192 pts

INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 147 WHEN 'SA-W' THEN 143 END
    WHEN 'team_score_6' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 51 WHEN 'SA-W' THEN 46 END
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Sophie Devine'    THEN 33
        WHEN 'Nadine de Klerk'  THEN 20
      END
    WHEN 'total_sixes' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 8 WHEN 'SA-W' THEN 6 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'yrat_kuhli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── User 3: Boundary / at cutoff — expected 52 pts ───────────────────────────
-- Predictions land exactly AT the cutoff boundary (last point scoring value)
-- or just inside — tests the CASE WHEN > threshold boundary precisely.
--
-- Predictions vs actuals → diff → pts:
--   NZ final:      185 vs 145 → diff 40 → 10 pts  (50-40; cutoff is >40 = 0)
--   NZ powerplay:   68 vs 48  → diff 20 → 10 pts  (30-20; cutoff is >20 = 0)
--   Sophie Devine:  57 vs 38  → diff 19 →  1 pts  (20-19; one inside cutoff)
--   NZ sixes:       11 vs 6   → diff 5  →  5 pts  (10-5;  cutoff is >5 = 0)
--   SA final:      177 vs 138 → diff 39 → 11 pts  (50-39; inside cutoff)
--   SA powerplay:   62 vs 42  → diff 20 → 10 pts  (30-20; at boundary)
--   Nadine:         45 vs 25  → diff 20 →  0 pts  (20-20 = 0; boundary is 0)
--   SA sixes:        9 vs 4   → diff 5  →  5 pts  (10-5;  at boundary)
--   Total: 10+10+1+5+11+10+0+5 = 52 pts

INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 185 WHEN 'SA-W' THEN 177 END
    WHEN 'team_score_6' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 68 WHEN 'SA-W' THEN 62 END
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Sophie Devine'    THEN 57
        WHEN 'Nadine de Klerk'  THEN 45
      END
    WHEN 'total_sixes' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 11 WHEN 'SA-W' THEN 9 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'og_jalenbrunson'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── User 4: All outside cutoff — expected 0 pts ──────────────────────────────
-- Every prediction is 1 step beyond the zero-points threshold.
-- Tests that each rule correctly returns 0 and not a negative number.
--
-- Predictions vs actuals → diff → pts:
--   NZ final:      186 vs 145 → diff 41 → 0 pts  (41 > 40)
--   NZ powerplay:   69 vs 48  → diff 21 → 0 pts  (21 > 20)
--   Sophie Devine:  59 vs 38  → diff 21 → 0 pts  (21 > 20)
--   NZ sixes:       12 vs 6   → diff 6  → 0 pts  ( 6 > 5 )
--   SA final:      179 vs 138 → diff 41 → 0 pts  (41 > 40)
--   SA powerplay:   63 vs 42  → diff 21 → 0 pts  (21 > 20)
--   Nadine:         46 vs 25  → diff 21 → 0 pts  (21 > 20)
--   SA sixes:       10 vs 4   → diff 6  → 0 pts  ( 6 > 5 )
--   Total: 0 pts

INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 186 WHEN 'SA-W' THEN 179 END
    WHEN 'team_score_6' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 69 WHEN 'SA-W' THEN 63 END
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Sophie Devine'    THEN 59
        WHEN 'Nadine de Klerk'  THEN 46
      END
    WHEN 'total_sixes' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 12 WHEN 'SA-W' THEN 10 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'akshat_rr'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── User 5: Mixed — expected 139 pts ─────────────────────────────────────────
-- Some questions are close (inside cutoff), one exceeds the TEAM_SCORE_50 cutoff.
--
-- Predictions vs actuals → diff → pts:
--   NZ final:      150 vs 145 → diff 5  → 45 pts  (50-5)
--   NZ powerplay:   38 vs 48  → diff 10 → 20 pts  (30-10)
--   Sophie Devine:  28 vs 38  → diff 10 → 10 pts  (20-10)
--   NZ sixes:        9 vs 6   → diff 3  →  7 pts  (10-3)
--   SA final:      160 vs 138 → diff 22 → 28 pts  (50-22)
--   SA powerplay:   55 vs 42  → diff 13 → 17 pts  (30-13)
--   Nadine:         40 vs 25  → diff 15 →  5 pts  (20-15)
--   SA sixes:        7 vs 4   → diff 3  →  7 pts  (10-3)
--   Total: 45+20+10+7+28+17+5+7 = 139 pts

INSERT INTO closest_call_predictions
  (user_id, closest_call_match_id, question_id, predicted_value)
SELECT u.id, m.id, q.id,
  CASE q.question_type
    WHEN 'team_final_score' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 150 WHEN 'SA-W' THEN 160 END
    WHEN 'team_score_6' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 38 WHEN 'SA-W' THEN 55 END
    WHEN 'batter_runs' THEN
      CASE q.player_name
        WHEN 'Sophie Devine'    THEN 28
        WHEN 'Nadine de Klerk'  THEN 40
      END
    WHEN 'total_sixes' THEN
      CASE q.team_code WHEN 'NZ-W' THEN 9 WHEN 'SA-W' THEN 7 END
  END AS predicted_value
FROM ipl_users u
JOIN closest_call_matches    m ON m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
JOIN closest_call_questions  q ON q.closest_call_match_id = m.id
WHERE u.user_name = 'chiknichameli'
ON CONFLICT (user_id, question_id) DO NOTHING;


-- ── Verify predictions inserted ───────────────────────────────────────────────

SELECT
  u.user_name,
  COUNT(p.id)              AS predictions_inserted,
  STRING_AGG(p.predicted_value::TEXT, ', ' ORDER BY q.id) AS predicted_values
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
GROUP  BY u.user_name
ORDER  BY u.user_name;

-- Expected: 8 predictions per user, 5 users
