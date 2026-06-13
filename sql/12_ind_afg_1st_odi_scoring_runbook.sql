-- ============================================================
-- FILE: sql/12_ind_afg_1st_odi_scoring_runbook.sql
-- PURPOSE: Step-by-step scoring setup for Match 84
--          IND vs AFG — 1st ODI (2026-06-13)
-- Fantasy Match ID: 84
--
-- RUN ORDER:
--   Step 1 — Find the CricAPI match ID
--   Step 2 — Insert cricapi_match_mapping (match ID link)
--   Step 3 — Insert cricapi_player_mapping (player name mapping)
--   Step 4 — (Optional) Enable auto-sync via cron
--   Step 5 — Run scoring APIs (browser URLs, in order)
--   Step 6 — Verify scoring results
-- ============================================================


-- ============================================================
-- STEP 1: FIND THE CRICAPI MATCH ID
-- ============================================================
-- Open this URL in your browser to see live/upcoming matches:
--   https://api.cricapi.com/v1/cricScore?apikey=YOUR_API_KEY
--
-- Look for the match: "India vs Afghanistan" or "IND vs AFG"
-- You'll see an entry like:
--   {
--     "id": "some-uuid-string-here",
--     "name": "India vs Afghanistan, 1st ODI",
--     ...
--   }
--
-- Copy the "id" value (it's a UUID like "abc12345-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
-- You'll use it in Step 2 below.
-- ============================================================


-- ============================================================
-- STEP 2: INSERT cricapi_match_mapping
-- Replace 'PASTE_CRICAPI_MATCH_UUID_HERE' with the UUID from Step 1.
-- Run this once before the match starts.
-- ============================================================

INSERT INTO cricapi_match_mapping (fantasy_match_id, cricapi_match_id)
VALUES (84, 'PASTE_CRICAPI_MATCH_UUID_HERE')
ON CONFLICT (fantasy_match_id) DO UPDATE
  SET cricapi_match_id = EXCLUDED.cricapi_match_id,
      updated_at = NOW();

-- Verify:
SELECT * FROM cricapi_match_mapping WHERE fantasy_match_id = 84;


-- ============================================================
-- STEP 3: INSERT cricapi_player_mapping
-- Maps each of the 28 players (14 IND + 14 AFG) to their
-- CricAPI name (the exact name string in the scorecard).
--
-- IMPORTANT: CricAPI names sometimes differ from our DB names.
-- The names below are best guesses — run Step 5A first and
-- check the "unmapped players" output to catch any mismatches.
-- Correct any wrong names and re-run just those rows.
-- ============================================================

INSERT INTO cricapi_player_mapping (fantasy_match_id, player_id, cricapi_player_name)
VALUES

  -- ---- INDIA (14 players) ----
  -- Batters
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Shubman Gill'       AND country = 'IND'), 'Shubman Gill'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rohit Sharma'       AND country = 'IND'), 'Rohit Sharma'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Yashasvi Jaiswal'   AND country = 'IND'), 'Yashasvi Jaiswal'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Shreyas Iyer'       AND country = 'IND'), 'Shreyas Iyer'),
  -- Wicket-keepers
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'KL Rahul'           AND country = 'IND'), 'KL Rahul'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ishan Kishan'       AND country = 'IND'), 'Ishan Kishan'),
  -- All-rounders
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Washington Sundar'  AND country = 'IND'), 'Washington Sundar'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Nitish Kumar Reddy' AND country = 'IND'), 'Nitish Kumar Reddy'),
  -- Bowlers
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Kuldeep Yadav'      AND country = 'IND'), 'Kuldeep Yadav'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Arshdeep Singh'     AND country = 'IND'), 'Arshdeep Singh'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Gurnoon Brar'       AND country = 'IND'), 'Gurnoon Brar'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Prasidh Krishna'    AND country = 'IND'), 'Prasidh Krishna'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Prince Yadav'       AND country = 'IND'), 'Prince Yadav'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Harsh Yadav'        AND country = 'IND'), 'Harsh Yadav'),

  -- ---- AFGHANISTAN (14 players) ----
  -- Batters
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Hashmatullah Shahid' AND country = 'AFG'), 'Hashmatullah Shahidi'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rahmanullah Gurbaz'  AND country = 'AFG'), 'Rahmanullah Gurbaz'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ibrahim Zadran'      AND country = 'AFG'), 'Ibrahim Zadran'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Sediqullah Atal'     AND country = 'AFG'), 'Sediqullah Atal'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rahmat Shah'         AND country = 'AFG'), 'Rahmat Shah'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Darwish Rasooli'     AND country = 'AFG'), 'Darwish Rasooli'),
  -- Wicket-keeper
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Ikram Alikhil'       AND country = 'AFG'), 'Ikram Alikhil'),
  -- All-rounders
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Azmatullah Omarzai'  AND country = 'AFG'), 'Azmatullah Omarzai'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Mohammad Nabi'       AND country = 'AFG'), 'Mohammad Nabi'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Rashid Khan'         AND country = 'AFG'), 'Rashid Khan'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Nangeyalia Kharoti'  AND country = 'AFG'), 'Nangeyalia Kharoti'),
  -- Bowlers
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'AM Ghazanfar'        AND country = 'AFG'), 'AM Ghazanfar'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Bilal Sami'          AND country = 'AFG'), 'Bilal Sami'),
  (84, (SELECT id FROM cricket_player_pool WHERE player_name = 'Fareed Ahmad Malik'  AND country = 'AFG'), 'Fareed Ahmad Malik')

ON CONFLICT (fantasy_match_id, player_id) DO UPDATE
  SET cricapi_player_name = EXCLUDED.cricapi_player_name;

-- Verify all 28 rows inserted:
SELECT
  cpm.player_id,
  cpp.player_name AS db_name,
  cpp.country,
  cpm.cricapi_player_name
FROM cricapi_player_mapping cpm
JOIN cricket_player_pool cpp ON cpp.id = cpm.player_id
WHERE cpm.fantasy_match_id = 84
ORDER BY cpp.country, cpp.player_name;


-- ============================================================
-- STEP 4: (OPTIONAL) ENABLE AUTO-SYNC VIA CRON
-- If you want the scoring APIs to run automatically every few
-- minutes during the match, insert a row into the sync control
-- table. Set is_auto_sync_enabled=FALSE to stop auto-sync.
-- ============================================================

-- Enable auto-sync for match 84:
INSERT INTO fantasy_score_sync_control (fantasy_match_id, is_auto_sync_enabled)
VALUES (84, TRUE)
ON CONFLICT (fantasy_match_id) DO UPDATE
  SET is_auto_sync_enabled = TRUE, updated_at = NOW();

-- To stop auto-sync after the match is done:
-- UPDATE fantasy_score_sync_control SET is_auto_sync_enabled = FALSE WHERE fantasy_match_id = 84;

-- Verify:
SELECT * FROM fantasy_score_sync_control WHERE fantasy_match_id = 84;


-- ============================================================
-- STEP 5: RUN SCORING APIs IN BROWSER
-- Hit these 3 URLs in order after the match is in progress
-- or after it finishes. You can re-run them as many times as
-- you want — they are safe to repeat.
--
-- 5A — Sync raw player stats from CricAPI scorecard:
--      https://playmtgames.com/api/sync-cricapi-score?fantasy_match_id=84
--
--      After running 5A, check the "unmapped players" section
--      in the JSON response. If any players show up there,
--      their CricAPI name doesn't match what's in
--      cricapi_player_mapping. Fix Step 3 for those players
--      and re-run 5A.
--
-- 5B — Recalculate user fantasy scores (captain/VC multipliers):
--      https://playmtgames.com/api/recalculate-fantasy-user-scores?fantasy_match_id=84
--
-- 5C — Update the score ticker shown on the match card:
--      https://playmtgames.com/api/sync-match-score-note?fantasy_match_id=84
--
-- Run order: 5A → 5B → 5C
-- ============================================================


-- ============================================================
-- STEP 6: VERIFY SCORING RESULTS
-- Run these queries after Step 5 to check everything worked.
-- ============================================================

-- 6A: Raw player stats synced from CricAPI
SELECT
  fps.player_name,
  fps.team,
  fps.runs_scored,
  fps.balls_faced,
  fps.fours,
  fps.sixes,
  fps.wickets_taken,
  fps.economy_rate,
  fps.catches,
  fps.stumpings,
  fps.fantasy_points,
  fps.is_captain,
  fps.is_vice_captain
FROM fantasy_player_match_stats fps
WHERE fps.fantasy_match_id = 84
ORDER BY fps.fantasy_points DESC;

-- 6B: User team scores (leaderboard)
SELECT
  fums.user_id,
  fums.team_name,
  fums.total_fantasy_points,
  fums.captain_name,
  fums.vice_captain_name,
  fums.rank
FROM fantasy_user_match_scores fums
WHERE fums.fantasy_match_id = 84
ORDER BY fums.total_fantasy_points DESC;

-- 6C: Check match status + score note
SELECT
  id,
  match_title,
  status,
  score_update_note,
  match_start_time
FROM fantasy_matches
WHERE id = 84;

-- 6D: Check for any unmapped players (got 0 points from scoring)
-- These are players in the match who played but weren't found in cricapi_player_mapping
SELECT
  fps.player_name,
  fps.team,
  fps.fantasy_points
FROM fantasy_player_match_stats fps
WHERE fps.fantasy_match_id = 84
  AND fps.fantasy_points = 0
  AND (fps.runs_scored > 0 OR fps.wickets_taken > 0)
ORDER BY fps.player_name;
