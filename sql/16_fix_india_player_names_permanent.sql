-- ============================================================
-- FILE: sql/16_fix_india_player_names_permanent.sql
-- PURPOSE: Permanently correct two India player names that
--          don't match what CricAPI returns in scorecards.
--
-- THE PROBLEM:
--   When sync-cricapi-score runs, it looks up each scorecard
--   name in cricapi_player_mapping.cricapi_player_name.
--   If the name doesn't match exactly, the player gets 0 pts.
--
--   Two names were wrong in our database vs CricAPI:
--     DB: 'Gurnoon Brar'  →  CricAPI: 'Gurnoor Brar'
--     DB: 'Harsh Yadav'   →  CricAPI: 'Harsh Dubey'
--
--   (Hashmatullah Shahid vs Shahidi was already handled
--    manually in the match 84 runbook — fixed here too
--    so future AFG matches don't need a manual override.)
--
-- WHY THIS IS SAFE:
--   cricket_player_pool and player_career_stats_master are
--   referenced everywhere by numeric player_id, NOT by name.
--   Renaming a player here only affects what the UI displays
--   and how the cricapi_player_mapping template reads — no
--   scores, teams, or budgets are affected.
--
-- RUN ORDER:
--   STEP 1 — Preview what will change (SELECT only, safe)
--   STEP 2 — Fix cricket_player_pool
--   STEP 3 — Fix player_career_stats_master
--   STEP 4 — Verify all three fixes
--   STEP 5 — Correct template for matches 85 & 86 runbooks
-- ============================================================


-- ============================================================
-- STEP 1: PREVIEW — see current names before changing anything
-- ============================================================

SELECT 'cricket_player_pool' AS table_name, player_name, country
FROM cricket_player_pool
WHERE player_name IN ('Gurnoon Brar', 'Harsh Yadav', 'Hashmatullah Shahid')

UNION ALL

SELECT 'player_career_stats_master', player_name, country
FROM player_career_stats_master
WHERE player_name IN ('Gurnoon Brar', 'Harsh Yadav', 'Hashmatullah Shahid');

-- Expected: 4 rows (2 in pool, 2 in master — Hashmatullah
-- may or may not appear depending on how file 10 ran)


-- ============================================================
-- STEP 2: FIX cricket_player_pool
-- ============================================================
-- These are the names shown on the create-team screen and
-- stored in cricapi_player_mapping. Correcting them here means
-- every future match runbook picks up the right names
-- automatically when it does:
--   SELECT id FROM cricket_player_pool WHERE player_name = '...'
-- ============================================================

UPDATE cricket_player_pool
SET player_name = 'Gurnoor Brar'
WHERE player_name = 'Gurnoon Brar'
  AND country = 'IND';

UPDATE cricket_player_pool
SET player_name = 'Harsh Dubey'
WHERE player_name = 'Harsh Yadav'
  AND country = 'IND';

UPDATE cricket_player_pool
SET player_name = 'Hashmatullah Shahidi'
WHERE player_name = 'Hashmatullah Shahid'
  AND country = 'AFG';

-- Confirm 3 rows updated (1 per statement = 3 total)
SELECT player_name, country, player_type
FROM cricket_player_pool
WHERE player_name IN ('Gurnoor Brar', 'Harsh Dubey', 'Hashmatullah Shahidi')
ORDER BY country, player_name;


-- ============================================================
-- STEP 3: FIX player_career_stats_master
-- ============================================================
-- This table drives the budget/impact score calculation.
-- The name must match cricket_player_pool exactly or the
-- cross-join in the budget API finds no stats for the player.
-- ============================================================

UPDATE player_career_stats_master
SET player_name = 'Gurnoor Brar'
WHERE player_name = 'Gurnoon Brar'
  AND country = 'India';

UPDATE player_career_stats_master
SET player_name = 'Harsh Dubey'
WHERE player_name = 'Harsh Yadav'
  AND country = 'India';

UPDATE player_career_stats_master
SET player_name = 'Hashmatullah Shahidi'
WHERE player_name = 'Hashmatullah Shahid'
  AND country = 'Afghanistan';

-- Confirm rows updated
SELECT player_name, country, player_role, data_source
FROM player_career_stats_master
WHERE player_name IN ('Gurnoor Brar', 'Harsh Dubey', 'Hashmatullah Shahidi')
ORDER BY country, player_name;


-- ============================================================
-- STEP 4: FIX cricapi_player_mapping FOR MATCH 84
-- ============================================================
-- Match 84 is already live — the mapping rows that were
-- inserted by file 12 used the old wrong names. Update them
-- to match CricAPI exactly so re-syncing works cleanly.
-- ============================================================

UPDATE cricapi_player_mapping
SET cricapi_player_name = 'Gurnoor Brar'
WHERE fantasy_match_id = 84
  AND player_id = (
    SELECT id FROM cricket_player_pool
    WHERE player_name = 'Gurnoor Brar' AND country = 'IND'
  );

UPDATE cricapi_player_mapping
SET cricapi_player_name = 'Harsh Dubey'
WHERE fantasy_match_id = 84
  AND player_id = (
    SELECT id FROM cricket_player_pool
    WHERE player_name = 'Harsh Dubey' AND country = 'IND'
  );

UPDATE cricapi_player_mapping
SET cricapi_player_name = 'Hashmatullah Shahidi'
WHERE fantasy_match_id = 84
  AND player_id = (
    SELECT id FROM cricket_player_pool
    WHERE player_name = 'Hashmatullah Shahidi' AND country = 'AFG'
  );


-- ============================================================
-- STEP 5: FULL VERIFICATION
-- ============================================================

-- 5A: All 3 names fixed in cricket_player_pool?
--     Should return exactly 3 rows.
SELECT player_name, country, player_type
FROM cricket_player_pool
WHERE player_name IN ('Gurnoor Brar', 'Harsh Dubey', 'Hashmatullah Shahidi');

-- 5B: Old wrong names are gone?
--     Should return 0 rows. If any row appears, the UPDATE missed.
SELECT player_name, country
FROM cricket_player_pool
WHERE player_name IN ('Gurnoon Brar', 'Harsh Yadav', 'Hashmatullah Shahid');

-- 5C: player_career_stats_master updated?
--     Should return 3 rows (or 2 if Hashmatullah wasn't in master).
SELECT player_name, country, player_role
FROM player_career_stats_master
WHERE player_name IN ('Gurnoor Brar', 'Harsh Dubey', 'Hashmatullah Shahidi');

-- 5D: Match 84 cricapi_player_mapping — all 28 rows correct?
--     The 3 fixed names should now match their CricAPI names exactly.
SELECT
  cpp.player_name   AS db_name,
  cpm.cricapi_player_name,
  CASE
    WHEN cpp.player_name = cpm.cricapi_player_name THEN 'EXACT MATCH'
    ELSE 'DIFFERENT — manual override in place'
  END AS status
FROM cricapi_player_mapping cpm
JOIN cricket_player_pool cpp ON cpp.id = cpm.player_id
WHERE cpm.fantasy_match_id = 84
ORDER BY cpp.country, cpp.player_name;


-- ============================================================
-- STEP 6: CORRECT cricapi_player_mapping TEMPLATE
--         FOR MATCHES 85 AND 86
-- ============================================================
-- Copy this block into your match 85 and 86 runbook files
-- (replacing the equivalent STEP 3 section from file 12).
-- Replace 85 with 86 for the third ODI runbook.
--
-- Key changes vs file 12:
--   'Gurnoon Brar'        → 'Gurnoor Brar'     (spelling)
--   'Harsh Yadav'         → 'Harsh Dubey'       (actual player)
--   'Hashmatullah Shahid' → 'Hashmatullah Shahidi' (trailing i)
-- ============================================================

/*
INSERT INTO cricapi_player_mapping (fantasy_match_id, player_id, cricapi_player_name)
VALUES

  -- ---- INDIA (14 players) ----
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Shubman Gill'        AND country = 'IND'), 'Shubman Gill'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rohit Sharma'        AND country = 'IND'), 'Rohit Sharma'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Yashasvi Jaiswal'    AND country = 'IND'), 'Yashasvi Jaiswal'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Shreyas Iyer'        AND country = 'IND'), 'Shreyas Iyer'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'KL Rahul'            AND country = 'IND'), 'KL Rahul'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ishan Kishan'        AND country = 'IND'), 'Ishan Kishan'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Washington Sundar'   AND country = 'IND'), 'Washington Sundar'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Nitish Kumar Reddy'  AND country = 'IND'), 'Nitish Kumar Reddy'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Kuldeep Yadav'       AND country = 'IND'), 'Kuldeep Yadav'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Arshdeep Singh'      AND country = 'IND'), 'Arshdeep Singh'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Gurnoor Brar'        AND country = 'IND'), 'Gurnoor Brar'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Prasidh Krishna'     AND country = 'IND'), 'Prasidh Krishna'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Prince Yadav'        AND country = 'IND'), 'Prince Yadav'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Harsh Dubey'         AND country = 'IND'), 'Harsh Dubey'),

  -- ---- AFGHANISTAN (14 players) ----
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Hashmatullah Shahidi' AND country = 'AFG'), 'Hashmatullah Shahidi'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rahmanullah Gurbaz'   AND country = 'AFG'), 'Rahmanullah Gurbaz'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ibrahim Zadran'       AND country = 'AFG'), 'Ibrahim Zadran'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Sediqullah Atal'      AND country = 'AFG'), 'Sediqullah Atal'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rahmat Shah'          AND country = 'AFG'), 'Rahmat Shah'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Darwish Rasooli'      AND country = 'AFG'), 'Darwish Rasooli'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ikram Alikhil'        AND country = 'AFG'), 'Ikram Alikhil'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Azmatullah Omarzai'   AND country = 'AFG'), 'Azmatullah Omarzai'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Mohammad Nabi'        AND country = 'AFG'), 'Mohammad Nabi'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rashid Khan'          AND country = 'AFG'), 'Rashid Khan'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Nangeyalia Kharoti'   AND country = 'AFG'), 'Nangeyalia Kharoti'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'AM Ghazanfar'         AND country = 'AFG'), 'AM Ghazanfar'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Bilal Sami'           AND country = 'AFG'), 'Bilal Sami'),
  (85, (SELECT id FROM cricket_player_pool WHERE player_name = 'Fareed Ahmad Malik'   AND country = 'AFG'), 'Fareed Ahmad Malik')

ON CONFLICT (fantasy_match_id, player_id) DO UPDATE
  SET cricapi_player_name = EXCLUDED.cricapi_player_name;
*/

-- ============================================================
-- REMINDER FOR MATCHES 85 & 86:
--
-- After each match, if sync-cricapi-score still returns any
-- unmapped_players, those are squad changes (new call-ups).
-- Fix them the same way:
--   1. Add the new player to cricket_player_pool
--   2. Add career stats to player_career_stats_master
--   3. Add a cricapi_player_mapping row with the exact
--      CricAPI scorecard name
--   4. Re-run sync-cricapi-score
-- ============================================================
