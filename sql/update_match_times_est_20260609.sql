-- ============================================================
-- MT Games — Add & Set Match Lock Times (EST / EDT)
-- File: sql/update_match_times_est_20260609.sql
--
-- RUN ORDER:
--   Step 1 — Add the match_start_time column (run once)
--   Step 2 — See your open match IDs
--   Step 3 — Set the times for your open matches
--   Step 4 — Verify
--
-- TIMEZONE NOTES:
--   Jun–Nov  → EDT = UTC-4  → use suffix  -04
--   Nov–Mar  → EST = UTC-5  → use suffix  -05
--
--   Example: 7:30 PM EDT  →  '2026-06-15 19:30:00-04'
--            2:00 PM EDT  →  '2026-06-15 14:00:00-04'
-- ============================================================


-- ============================================================
-- STEP 1 — Add the column (safe to re-run)
-- ============================================================

ALTER TABLE fantasy_matches
  ADD COLUMN IF NOT EXISTS match_start_time TIMESTAMPTZ;


-- ============================================================
-- STEP 2 — Find your open match IDs
-- ============================================================

SELECT
  id,
  match_title,
  team_1,
  team_2,
  match_format,
  match_start_time,
  status
FROM fantasy_matches
WHERE status = 'open'
ORDER BY id DESC;


-- ============================================================
-- STEP 3 — Set match_start_time for your open matches
--   Replace ??? with the match IDs from Step 2.
--   Replace the timestamps with your actual match times.
-- ============================================================

UPDATE fantasy_matches
SET match_start_time = CASE id
  WHEN ???  THEN '2026-06-12 19:30:00-04'::TIMESTAMPTZ
  WHEN ???  THEN '2026-06-14 14:00:00-04'::TIMESTAMPTZ
  WHEN ???  THEN '2026-06-15 10:00:00-04'::TIMESTAMPTZ
  WHEN ???  THEN '2026-06-18 19:30:00-04'::TIMESTAMPTZ
END
WHERE id IN (???, ???, ???, ???);

-- Single match version:
-- UPDATE fantasy_matches
-- SET match_start_time = '2026-06-15 19:30:00-04'::TIMESTAMPTZ
-- WHERE id = ???;


-- ============================================================
-- STEP 4 — Verify (times shown in both UTC and your local EDT)
-- ============================================================

SELECT
  id,
  match_title,
  match_format,
  match_start_time                                    AS stored_utc,
  match_start_time AT TIME ZONE 'America/New_York'    AS local_edt,
  status
FROM fantasy_matches
WHERE status = 'open'
ORDER BY match_start_time ASC NULLS LAST;


-- ============================================================
-- QUICK REFERENCE — Common EDT times
-- ============================================================
--   10:00 AM EDT  →  '... 10:00:00-04'
--   12:00 PM EDT  →  '... 12:00:00-04'
--    2:00 PM EDT  →  '... 14:00:00-04'
--    7:00 PM EDT  →  '... 19:00:00-04'
--    7:30 PM EDT  →  '... 19:30:00-04'
--    9:00 PM EDT  →  '... 21:00:00-04'
-- ============================================================
