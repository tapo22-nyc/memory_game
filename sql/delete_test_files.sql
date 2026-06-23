-- ============================================================
-- FILE: sql/delete_test_files.sql
-- PURPOSE: Permanently remove all data for the two QA test
--          matches from every table that touched them.
--
-- TEST GAME 1: [TEST] IND-W vs PAK-W — WT20 WC
-- TEST GAME 2: [TEST] TSK vs MI New York — MLC 2026
--
-- DELETION ORDER (respects foreign-key dependencies):
--   1. closest_call_predictions  ← references match + question
--   2. closest_call_questions    ← references match
--   3. closest_call_matches      ← root record
--
-- NOTE: The leaderboard is computed at query time from the
--       tables above — no separate leaderboard table exists.
--       Deleting the rows above removes them from all
--       leaderboard views automatically.
--
-- NOTE: Click-tracking events (track_click table) store
--       event_metadata as JSON and carry no FK to match rows,
--       so they are intentionally excluded here.  They are
--       low-value audit logs and not worth risking a broad
--       JSON-search delete against unrelated data.
--
-- SAFE TO RE-RUN: All deletes are scoped to match_title
--   LIKE '[TEST]%', which does not affect real match data.
-- ============================================================


-- ============================================================
-- STEP 0: Preview — confirm what will be deleted before running
-- ============================================================
SELECT
  ccm.id            AS match_id,
  ccm.match_title,
  ccm.status        AS match_status,
  COUNT(DISTINCT ccq.id)  AS questions,
  COUNT(DISTINCT ccp.id)  AS predictions
FROM  closest_call_matches ccm
LEFT  JOIN closest_call_questions   ccq ON ccq.closest_call_match_id = ccm.id
LEFT  JOIN closest_call_predictions ccp ON ccp.closest_call_match_id = ccm.id
WHERE ccm.match_title LIKE '[TEST]%'
GROUP BY ccm.id, ccm.match_title, ccm.status
ORDER BY ccm.id;


-- ============================================================
-- STEP 1: Delete all user predictions for the test matches
--         (closest_call_predictions references both
--          closest_call_match_id and question_id — delete first)
-- ============================================================
DELETE FROM closest_call_predictions
WHERE  closest_call_match_id IN (
  SELECT id
  FROM   closest_call_matches
  WHERE  match_title LIKE '[TEST]%'
);


-- ============================================================
-- STEP 2: Delete all questions for the test matches
--         (closest_call_questions references closest_call_match_id)
-- ============================================================
DELETE FROM closest_call_questions
WHERE  closest_call_match_id IN (
  SELECT id
  FROM   closest_call_matches
  WHERE  match_title LIKE '[TEST]%'
);


-- ============================================================
-- STEP 3: Delete the test match records themselves
-- ============================================================
DELETE FROM closest_call_matches
WHERE  match_title LIKE '[TEST]%';


-- ============================================================
-- STEP 4: Verification — all three queries should return 0 rows
-- ============================================================

-- 4a. Confirm no test matches remain:
SELECT id, match_title, status
FROM   closest_call_matches
WHERE  match_title LIKE '[TEST]%';

-- 4b. Confirm no orphaned questions remain:
SELECT COUNT(*) AS orphaned_questions
FROM   closest_call_questions ccq
WHERE  NOT EXISTS (
  SELECT 1 FROM closest_call_matches ccm
  WHERE  ccm.id = ccq.closest_call_match_id
);

-- 4c. Confirm no orphaned predictions remain:
SELECT COUNT(*) AS orphaned_predictions
FROM   closest_call_predictions ccp
WHERE  NOT EXISTS (
  SELECT 1 FROM closest_call_matches ccm
  WHERE  ccm.id = ccp.closest_call_match_id
);
