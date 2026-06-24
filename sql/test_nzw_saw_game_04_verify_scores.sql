-- ============================================================
-- FILE: sql/test_nzw_saw_game_04_verify_scores.sql
-- PURPOSE: Verify that scoring produced the expected point totals
--          for all 5 test users after running file 03.
--
-- EXPECTED TOTALS:
--   test_nzw_saw_user_1  →  220 pts  (all exact)
--   test_nzw_saw_user_2  →  192 pts  (small diffs: 2–5 off each)
--   test_nzw_saw_user_5  →  139 pts  (mixed bag)
--   test_nzw_saw_user_3  →   52 pts  (at boundary / cutoff edge)
--   test_nzw_saw_user_4  →    0 pts  (every prediction outside cutoff)
-- ============================================================


-- ── CHECK 1: Total points per user (leaderboard view) ────────────────────────

SELECT
  u.user_name,
  SUM(p.points_awarded)   AS total_pts,
  COUNT(p.id)             AS predictions_scored
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
  AND  u.user_name LIKE 'test_nzw_saw_user_%'
  AND  q.status = 'scored'
GROUP  BY u.user_name
ORDER  BY total_pts DESC;

/*  Expected result:
    user_name               | total_pts | predictions_scored
    ------------------------+-----------+-------------------
    test_nzw_saw_user_1     |       220 |  8
    test_nzw_saw_user_2     |       192 |  8
    test_nzw_saw_user_5     |       139 |  8
    test_nzw_saw_user_3     |        52 |  8
    test_nzw_saw_user_4     |         0 |  8
*/


-- ── CHECK 2: Per-question breakdown for each user ────────────────────────────
-- Useful to trace exactly which prediction earned what.

SELECT
  u.user_name,
  q.scoring_rule_code,
  q.question_type,
  q.team_code,
  q.player_name,
  q.actual_value,
  p.predicted_value,
  p.difference,
  p.points_awarded,
  q.max_points
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
  AND  u.user_name LIKE 'test_nzw_saw_user_%'
ORDER  BY u.user_name, q.id;

/*  Expected per-question points (ordered by question ID):
    ─────────────────────────────────────────────────────────────────────────
    Q (type / team / player)      | rule              | actual | u1  u2  u3  u4  u5
    ──────────────────────────────────────────────────────────────────────────
    batter_runs / NZ-W / Sophie   | BATTER_SCORE_20   |  38    | 20  15   1   0  10
    total_sixes / NZ-W            | TEAM_SIXES_10     |   6    | 10   8   5   0   7
    batter_runs / SA-W / Nadine   | BATTER_SCORE_20   |  25    | 20  15   0   0   5
    total_sixes / SA-W            | TEAM_SIXES_10     |   4    | 10   8   5   0   7
    team_score_6 / NZ-W           | POWERPLAY_SCORE_30|  48    | 30  27  10   0  20
    team_final_score / NZ-W       | TEAM_SCORE_50     | 145    | 50  48  10   0  45
    team_score_6 / SA-W           | POWERPLAY_SCORE_30|  42    | 30  26  10   0  17
    team_final_score / SA-W       | TEAM_SCORE_50     | 138    | 50  45  11   0  28
    ──────────────────────────────────────────────────────────────────────────
    TOTAL                         |                   |        |220 192  52   0 139
*/


-- ── CHECK 3: Confirm no negative points were awarded ─────────────────────────

SELECT COUNT(*) AS negative_points_count
FROM   closest_call_predictions p
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
  AND  p.points_awarded < 0;

-- Expected: 0


-- ── CHECK 4: Confirm all 8 questions are scored ───────────────────────────────

SELECT
  COUNT(*)                                                AS total_questions,
  SUM(CASE WHEN status = 'scored' THEN 1 ELSE 0 END)     AS scored,
  SUM(CASE WHEN actual_value IS NOT NULL THEN 1 ELSE 0 END) AS has_actual_value
FROM   closest_call_questions q
JOIN   closest_call_matches   m ON m.id = q.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026';

-- Expected: 8 / 8 / 8


-- ── CHECK 5: User 3 boundary edge cases ──────────────────────────────────────
-- Specifically validates that diff = cutoff earns min points, not 0.
-- NZ final diff 40 → 10 pts (not 0: rule is > 40, not >= 40)
-- NZ powerplay diff 20 → 10 pts (not 0: rule is > 20, not >= 20)
-- Nadine de Klerk diff 20 → 0 pts (20 - 20 = 0, which is correct)
-- SA sixes diff 5 → 5 pts (not 0: rule is > 5, not >= 5)

SELECT
  q.question_type,
  q.team_code,
  q.player_name,
  q.scoring_rule_code,
  p.difference,
  p.points_awarded
FROM   closest_call_predictions p
JOIN   ipl_users               u ON u.id = p.user_id
JOIN   closest_call_questions  q ON q.id = p.question_id
JOIN   closest_call_matches    m ON m.id = p.closest_call_match_id
WHERE  m.match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
  AND  u.user_name = 'test_nzw_saw_user_3'
ORDER  BY q.id;

/*  Expected:
    question_type    | team_code | player_name      | rule               | diff | pts
    -----------------+-----------+------------------+--------------------+------+----
    batter_runs      | NZ-W      | Sophie Devine    | BATTER_SCORE_20    |  19  |   1
    total_sixes      | NZ-W      |                  | TEAM_SIXES_10      |   5  |   5
    batter_runs      | SA-W      | Nadine de Klerk  | BATTER_SCORE_20    |  20  |   0
    total_sixes      | SA-W      |                  | TEAM_SIXES_10      |   5  |   5
    team_score_6     | NZ-W      |                  | POWERPLAY_SCORE_30 |  20  |  10
    team_final_score | NZ-W      |                  | TEAM_SCORE_50      |  40  |  10
    team_score_6     | SA-W      |                  | POWERPLAY_SCORE_30 |  20  |  10
    team_final_score | SA-W      |                  | TEAM_SCORE_50      |  39  |  11
*/
