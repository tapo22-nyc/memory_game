-- ============================================================
-- FILE: sql/test_nzw_saw_game_03_enter_actual_values_and_score.sql
-- PURPOSE: Set actual values on all 8 questions and compute
--          difference + points_awarded on every prediction,
--          replicating what update-closest-call-actuals.js does.
--
-- PREREQUISITE: Run files 01 and 02 first.
--
-- ACTUAL VALUES USED:
--   NZ Women final total   : 145
--   NZ Women powerplay     :  48
--   Sophie Devine runs     :  38
--   NZ Women sixes         :   6
--   SA Women final total   : 138
--   SA Women powerplay     :  42
--   Nadine de Klerk runs   :  25
--   SA Women sixes         :   4
--
-- SAFE TO RE-RUN: Updates overwrite with the same values.
-- ============================================================


-- ── STEP 1: Set actual_value + status = 'scored' on all 8 questions ──────────

UPDATE closest_call_questions q
SET    actual_value = CASE
         WHEN q.question_type = 'team_final_score' AND q.team_code = 'NZ-W'          THEN 145
         WHEN q.question_type = 'team_score_6'     AND q.team_code = 'NZ-W'          THEN 48
         WHEN q.question_type = 'batter_runs'      AND q.player_name = 'Sophie Devine'    THEN 38
         WHEN q.question_type = 'total_sixes'      AND q.team_code = 'NZ-W'          THEN 6
         WHEN q.question_type = 'team_final_score' AND q.team_code = 'SA-W'          THEN 138
         WHEN q.question_type = 'team_score_6'     AND q.team_code = 'SA-W'          THEN 42
         WHEN q.question_type = 'batter_runs'      AND q.player_name = 'Nadine de Klerk'  THEN 25
         WHEN q.question_type = 'total_sixes'      AND q.team_code = 'SA-W'          THEN 4
       END,
       status     = 'scored',
       updated_at = NOW()
FROM   closest_call_matches m
WHERE  q.closest_call_match_id = m.id
  AND  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026';


-- ── STEP 2: Compute difference + points_awarded on all predictions ────────────
-- Mirrors the computePointsCode() logic in update-closest-call-actuals.js.
-- Uses q.actual_value set in step 1 above.

UPDATE closest_call_predictions p
SET    difference     = ABS(p.predicted_value - q.actual_value),
       points_awarded = CASE q.scoring_rule_code
         WHEN 'TEAM_SCORE_50'
           THEN CASE WHEN ABS(p.predicted_value - q.actual_value) > 40 THEN 0
                     ELSE 50 - ABS(p.predicted_value - q.actual_value) END
         WHEN 'POWERPLAY_SCORE_30'
           THEN CASE WHEN ABS(p.predicted_value - q.actual_value) > 20 THEN 0
                     ELSE 30 - ABS(p.predicted_value - q.actual_value) END
         WHEN 'BATTER_SCORE_20'
           THEN CASE WHEN ABS(p.predicted_value - q.actual_value) > 20 THEN 0
                     ELSE 20 - ABS(p.predicted_value - q.actual_value) END
         WHEN 'TEAM_SIXES_10'
           THEN CASE WHEN ABS(p.predicted_value - q.actual_value) > 5  THEN 0
                     ELSE 10 - ABS(p.predicted_value - q.actual_value) END
         ELSE 0
       END,
       updated_at = NOW()
FROM   closest_call_questions  q
JOIN   closest_call_matches    m ON m.id = q.closest_call_match_id
WHERE  p.question_id = q.id
  AND  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
  AND  q.status = 'scored';


-- ── STEP 3: Close the match ───────────────────────────────────────────────────

UPDATE closest_call_matches
SET    status     = 'closed',
       updated_at = NOW()
WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026';


-- ── Preview: scoring result per prediction ────────────────────────────────────
-- Run to confirm difference and points_awarded were written correctly.

SELECT
  u.user_name,
  q.question_type,
  q.team_code,
  q.player_name,
  q.scoring_rule_code,
  q.actual_value,
  p.predicted_value,
  p.difference,
  p.points_awarded
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
ORDER  BY u.user_name, q.id;
