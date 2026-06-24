-- ============================================================
-- FILE: sql/test_nzw_saw_game_05_cleanup.sql
-- PURPOSE: Remove all test data created by files 01–02 for the
--          NZ-W vs SA-W test match.  Run after QA is complete.
--
-- WHAT IS DELETED:
--   • closest_call_predictions  — for test users in test match
--   • closest_call_questions    — for test match
--   • closest_call_matches      — the test match itself
--   • ipl_users rows            — test_nzw_saw_user_1 through _5
--                                  (only if they have no other predictions)
--
-- SAFE TO RE-RUN: DELETEs are idempotent — re-running after data
--   is already removed completes without error.
-- ============================================================


-- ── STEP 1: Remove predictions for this test match ────────────────────────────

DELETE FROM closest_call_predictions
WHERE  closest_call_match_id IN (
         SELECT id FROM closest_call_matches
         WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
       );


-- ── STEP 2: Remove questions for this test match ──────────────────────────────

DELETE FROM closest_call_questions
WHERE  closest_call_match_id IN (
         SELECT id FROM closest_call_matches
         WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'
       );


-- ── STEP 3: Remove the test match itself ─────────────────────────────────────

DELETE FROM closest_call_matches
WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026';


-- ── STEP 4: Remove test users (only if they have no other predictions) ────────
-- Guard prevents deleting users that somehow made real predictions.

DELETE FROM ipl_users
WHERE  user_name IN (
         'test_nzw_saw_user_1',
         'test_nzw_saw_user_2',
         'test_nzw_saw_user_3',
         'test_nzw_saw_user_4',
         'test_nzw_saw_user_5'
       )
  AND  id NOT IN (
         SELECT DISTINCT user_id FROM closest_call_predictions
       );


-- ── Verify cleanup ────────────────────────────────────────────────────────────

SELECT 'matches remaining' AS check_target,
       COUNT(*) AS remaining_rows
FROM   closest_call_matches
WHERE  match_title = '[TEST] NZ-W vs SA-W — WT20 WC 2026'

UNION ALL

SELECT 'test users remaining',
       COUNT(*)
FROM   ipl_users
WHERE  user_name LIKE 'test_nzw_saw_user_%';

-- Expected: both rows show 0
