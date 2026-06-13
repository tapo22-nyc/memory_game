-- ============================================================
-- FILE: sql/14_ind_afg_1st_odi_match_lock_setup.sql
-- PURPOSE: Instructions to set up auto-lock for Match 84
--          IND vs AFG — 1st ODI (2026-06-13 at 4:00 AM EDT)
--
-- There is no SQL to run here. Two code file changes are needed:
--   Change 1 — api/lock-fantasy-match.js   (match ID)
--   Change 2 — vercel.json                  (cron schedule)
-- ============================================================


-- ============================================================
-- CHANGE 1: api/lock-fantasy-match.js
-- Update the hardcoded match ID on line 13.
-- ============================================================
--
-- FIND (line 13):
--   const matchId = 73; // replace if different
--
-- REPLACE WITH:
--   const matchId = 84; // IND vs AFG 1st ODI


-- ============================================================
-- CHANGE 2: vercel.json
-- Update the cron schedule for /api/lock-fantasy-match.
-- 4:00 AM EDT = 08:00 UTC on June 13.
-- Vercel cron always runs in UTC.
-- ============================================================
--
-- FIND:
--   {
--     "path": "/api/lock-fantasy-match",
--     "schedule": "59 9 24 5 *"
--   }
--
-- REPLACE WITH:
--   {
--     "path": "/api/lock-fantasy-match",
--     "schedule": "0 8 13 6 *"
--   }
--
-- Cron field breakdown: minute hour day month weekday
--   0  → fire at :00
--   8  → 08:00 UTC = 4:00 AM EDT
--   13 → 13th of the month
--   6  → June
--   *  → any day of week


-- ============================================================
-- VERIFICATION QUERY
-- After deploying, confirm match 84 has the correct start time
-- and is still open before the lock fires.
-- ============================================================

SELECT
  id,
  match_title,
  status,
  match_start_time,
  match_start_time AT TIME ZONE 'America/New_York' AS start_time_edt
FROM fantasy_matches
WHERE id = 84;
