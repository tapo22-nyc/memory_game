-- ============================================================
-- FILE: v2_player_data_runbook.sql
-- PURPOSE: Quick reference for maintaining player career stats,
--          adding missing players, and querying historical +
--          recent form data.
--
-- SECTIONS:
--   1. Re-sync player career stats (refresh from CricAPI)
--   2. Verify data is fresh
--   3. Add missing players (e.g. Matthew Short, Josh Inglis)
--   4. Career stats spot checks
--   5. Last 5 matches form per player
--   6. Prompt for Claude — next session
-- ============================================================


-- ============================================================
-- SECTION 1: RE-SYNC PLAYER CAREER STATS
-- Run these two URLs in your browser whenever you want to
-- refresh career stats from CricAPI (e.g. once a month).
-- Run pool first, then ipl. Each takes ~30 seconds.
-- ============================================================

-- Step 1: Refresh SL + WI players
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=pool

-- Step 2: Refresh IPL + all other players
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=ipl

-- Optional: refresh a single player only
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=all&player=Kusal%20Mendis


-- ============================================================
-- SECTION 2: VERIFY DATA IS FRESH
-- Run after every sync to confirm timestamps updated.
-- ============================================================

-- Check last sync time per source
SELECT
  player_pool_source,
  COUNT(*)            AS total_players,
  MAX(last_synced_at) AS last_synced
FROM player_career_stats_master
GROUP BY player_pool_source;

-- Check SL + WI players specifically
SELECT
  country,
  COUNT(*)            AS players,
  MAX(last_synced_at) AS last_synced
FROM player_career_stats_master
WHERE country IN ('Sri Lanka', 'West Indies')
GROUP BY country;

-- Find players in cricapi_player_master who have NO career stats yet
-- (these are the "missing" players you need to fix)
SELECT ipm.player_name, ipm.country, ipm.cricapi_player_id
FROM cricapi_player_master ipm
LEFT JOIN player_career_stats_master pcsm
  ON LOWER(ipm.player_name) = LOWER(pcsm.player_name)
 AND ipm.country = pcsm.country
WHERE pcsm.player_name IS NULL
ORDER BY ipm.country, ipm.player_name;


-- ============================================================
-- SECTION 3: HOW TO ADD MISSING PLAYERS
--
-- Use this section when players exist in your game but their
-- historical career stats are missing from player_career_stats_master.
--
-- Example missing players: Matthew Short, Josh Inglis,
-- Cameron Green, Matt Renshaw, Cooper Connolly (Australia)
--
-- THERE ARE TWO POSSIBLE REASONS DATA IS MISSING:
--   A. Player is in cricapi_player_master but has no cricapi_player_id
--   B. Player is not in cricapi_player_master at all
--
-- Follow the steps below to diagnose and fix.
-- ============================================================

-- STEP 3a: Check if the player exists and has a CricAPI ID
SELECT player_name, country, cricapi_player_id
FROM cricapi_player_master
WHERE player_name IN (
  'Matthew Short',
  'Josh Inglis',
  'Cameron Green',
  'Matt Renshaw',
  'Cooper Connolly'
);
-- If cricapi_player_id is NULL → go to Step 3b
-- If the player row is missing entirely → go to Step 3c

-- ─────────────────────────────────────────────────────────
-- STEP 3b: Player exists but has no CricAPI ID
-- Find their CricAPI ID manually, then UPDATE it.
--
-- To find the ID:
--   1. Go to: https://www.cricapi.com/
--   2. Use the /v1/players?search=<name> endpoint with your API key:
--      https://api.cricapi.com/v1/players?apikey=YOUR_KEY&search=Matthew%20Short
--   3. Find the correct player in the results (check country field)
--   4. Copy their "id" value (looks like a UUID)
--   5. Run the UPDATE below
-- ─────────────────────────────────────────────────────────

UPDATE cricapi_player_master
SET cricapi_player_id = 'PASTE-UUID-HERE'   -- replace with actual CricAPI ID
WHERE player_name = 'Matthew Short'
  AND country = 'Australia';

-- Repeat for each missing player:
-- UPDATE cricapi_player_master SET cricapi_player_id = 'UUID' WHERE player_name = 'Josh Inglis' AND country = 'Australia';
-- UPDATE cricapi_player_master SET cricapi_player_id = 'UUID' WHERE player_name = 'Cameron Green' AND country = 'Australia';
-- UPDATE cricapi_player_master SET cricapi_player_id = 'UUID' WHERE player_name = 'Matt Renshaw' AND country = 'Australia';
-- UPDATE cricapi_player_master SET cricapi_player_id = 'UUID' WHERE player_name = 'Cooper Connolly' AND country = 'Australia';

-- ─────────────────────────────────────────────────────────
-- STEP 3c: Player is not in cricapi_player_master at all
-- INSERT them first, then go back to Step 3b to add the ID.
-- ─────────────────────────────────────────────────────────

INSERT INTO cricapi_player_master (player_name, country, cricapi_player_id)
VALUES
  ('Matthew Short',    'Australia', NULL),
  ('Josh Inglis',      'Australia', NULL),
  ('Cameron Green',    'Australia', NULL),
  ('Matt Renshaw',     'Australia', NULL),
  ('Cooper Connolly',  'Australia', NULL)
ON CONFLICT (player_name, country) DO NOTHING;
-- After inserting, go back to Step 3b to fill in the UUIDs.

-- ─────────────────────────────────────────────────────────
-- STEP 3d: Sync career stats for just these players
-- Once cricapi_player_id is filled in, call the API for each
-- player individually. Do NOT re-run the full ipl sync just
-- for a handful of players — it uses too many API credits.
--
-- Run each URL one at a time in your browser:
-- ─────────────────────────────────────────────────────────

-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=ipl&player=Matthew%20Short
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=ipl&player=Josh%20Inglis
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=ipl&player=Cameron%20Green
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=ipl&player=Matt%20Renshaw
-- https://www.playmtgames.com/api/sync-selected-player-career-stats?source=ipl&player=Cooper%20Connolly

-- ─────────────────────────────────────────────────────────
-- STEP 3e: Verify the new data landed correctly
-- ─────────────────────────────────────────────────────────

SELECT player_name, country, t20_bat_matches, t20_bat_runs, t20_bat_avg, last_synced_at
FROM player_career_stats_master
WHERE player_name IN (
  'Matthew Short',
  'Josh Inglis',
  'Cameron Green',
  'Matt Renshaw',
  'Cooper Connolly'
);


-- ============================================================
-- SECTION 4: CAREER STATS SPOT CHECKS
-- ============================================================

-- Full batting + bowling card for one player
SELECT
  player_name, country,
  odi_bat_matches, odi_bat_runs, odi_bat_avg, odi_bat_strike_rate,
  odi_bat_50s, odi_bat_100s, odi_bat_4s, odi_bat_6s,
  odi_bowl_wickets, odi_bowl_avg, odi_bowl_economy,
  t20_bat_matches, t20_bat_runs, t20_bat_avg, t20_bat_strike_rate,
  t20_bat_50s, t20_bat_6s,
  t20_bowl_wickets, t20_bowl_economy,
  test_bat_matches, test_bat_runs, test_bat_avg,
  test_bowl_wickets, test_bowl_avg
FROM player_career_stats_master
WHERE LOWER(player_name) = LOWER('Kusal Mendis');  -- change name as needed

-- Top T20 run scorers (SL + WI)
SELECT player_name, country, t20_bat_matches, t20_bat_runs, t20_bat_avg, t20_bat_strike_rate, t20_bat_6s
FROM player_career_stats_master
WHERE country IN ('Sri Lanka', 'West Indies')
ORDER BY t20_bat_runs DESC NULLS LAST
LIMIT 10;

-- Top T20 wicket takers (SL + WI)
SELECT player_name, country, t20_bowl_matches, t20_bowl_wickets, t20_bowl_avg, t20_bowl_economy
FROM player_career_stats_master
WHERE country IN ('Sri Lanka', 'West Indies')
ORDER BY t20_bowl_wickets DESC NULLS LAST
LIMIT 10;

-- Top ODI run scorers (SL + WI)
SELECT player_name, country, odi_bat_matches, odi_bat_runs, odi_bat_avg, odi_bat_100s, odi_bat_50s
FROM player_career_stats_master
WHERE country IN ('Sri Lanka', 'West Indies')
ORDER BY odi_bat_runs DESC NULLS LAST
LIMIT 10;

-- All players with missing career stats (runs = 0 or null across all formats)
-- Useful for finding players who synced but returned empty data from CricAPI
SELECT player_name, country, player_pool_source, last_synced_at
FROM player_career_stats_master
WHERE COALESCE(t20_bat_runs, 0) = 0
  AND COALESCE(odi_bat_runs, 0) = 0
  AND COALESCE(t20_bowl_wickets, 0) = 0
ORDER BY country, player_name;


-- ============================================================
-- SECTION 5: LAST 5 MATCHES FORM PER PLAYER
-- Reads from cricapi_player_match_history (match-by-match rows).
-- NOTE: SL/WI players may have no rows here if the Cricsheet
-- backfill was never run. This works well for IPL players.
-- ============================================================

-- Last 5 T20 batting innings for a player
SELECT
  player_name,
  match_date,
  match_id,
  runs,
  balls_faced,
  fours,
  sixes,
  is_out,
  strike_rate
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Virat Kohli')  -- change name as needed
  AND match_format = 'T20'
  AND innings_type = 'batting'
ORDER BY match_date DESC
LIMIT 5;

-- Last 5 T20 bowling innings for a player
SELECT
  player_name,
  match_date,
  match_id,
  overs_bowled,
  runs_conceded,
  wickets,
  economy_rate
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Wanindu Hasaranga')  -- change name as needed
  AND match_format = 'T20'
  AND innings_type = 'bowling'
ORDER BY match_date DESC
LIMIT 5;

-- Recent form summary: avg runs + strike rate over last 10 T20 innings
SELECT
  player_name,
  COUNT(*)                   AS innings,
  SUM(runs)                  AS total_runs,
  ROUND(AVG(runs), 1)        AS avg_runs,
  ROUND(AVG(strike_rate), 1) AS avg_sr,
  SUM(sixes)                 AS total_6s
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Rohit Sharma')  -- change name as needed
  AND match_format = 'T20'
  AND innings_type = 'batting'
ORDER BY match_date DESC
LIMIT 10;


-- ============================================================
-- SECTION 6: PROMPT FOR CLAUDE — NEXT SESSION
--
-- Copy and paste the entire prompt below into a new Claude
-- conversation to pick up exactly where we left off.
-- ============================================================

/*
PROMPT FOR CLAUDE:

I am building a cricket fantasy game at www.playmtgames.com.
The tech stack is: Next.js / Vercel, Neon PostgreSQL (serverless),
CricAPI for player data, deployed on Vercel via GitHub.

Key tables in our DB:
- player_career_stats_master   : flat career stats per player (ODI/T20/Test
                                  batting + bowling). country column stores
                                  full names e.g. 'Sri Lanka', 'West Indies',
                                  'Australia'. Unique on (player_name, country).
- cricket_player_pool          : SL/WI international players. Columns include
                                  player_name, country (short code: SL/WI),
                                  player_type (Batsman/Bowler/All Rounder/
                                  Wicketkeeper), budget, is_active.
- cricapi_player_master        : IPL + other international players. Columns
                                  include player_name, country (full name),
                                  cricapi_player_id, budget.
- fantasy_player_impact_points : stores impact_points per player per match.
                                  Currently hardcoded at 100 for all players.
                                  Columns: fantasy_player_id, fantasy_match_id,
                                  impact_points, source.
- fantasy_match_players        : links players to a fantasy match. Columns:
                                  player_id, fantasy_match_id,
                                  player_source ('ipl' or 'cricket').
- cricapi_player_match_history : match-by-match performance rows per player.

We have finished syncing career stats for all SL/WI and IPL players into
player_career_stats_master using CricAPI. The data is clean and verified.

THE NEXT TASK is to build an API that calculates Impact Scores and Budget
values for all players in an upcoming match, then saves them to the DB.

Impact Score formula (T20 focused, weights are tunable):
- Batsman / Wicketkeeper:
    (t20_bat_avg × t20_bat_strike_rate / 100)
    + (t20_bat_6s × 0.3)
    + (t20_bat_50s × 1.5)
    + (t20_bat_100s × 4.0)

- Bowler:
    (t20_bowl_wickets / t20_bowl_matches × 15)
    + MAX(0, 9.0 - t20_bowl_economy) × 4
    + (t20_bowl_5wi × 3.0)

- All Rounder:
    batting_score × 0.6 + bowling_score × 0.4

Budget formula:
- Normalize impact score to a 7.0–12.0 range across all players in the match
- Best player in the match pool = 12.0, weakest = 7.0, linear scale

What I want you to build:
1. A new API: api/calculate-player-impact-budget.js that:
   - Takes ?fantasy_match_id=<id> as input
   - Finds all players in that match via fantasy_match_players
   - Joins player_career_stats_master for career stats
   - Joins cricket_player_pool or cricapi_player_master for player_type
   - Calculates impact score per player using the formula above
   - Normalizes impact scores into budget values (7.0–12.0)
   - Saves impact_points to fantasy_player_impact_points
     (ON CONFLICT DO UPDATE)
   - Saves budget back to cricket_player_pool.budget (for SL/WI players)
     and cricapi_player_master.budget (for IPL players)
   - Supports ?dryRun=true to preview without writing
   - Returns full breakdown of every player's score

2. All formula weights should be defined as constants at the top of
   the file so they are easy to tune without touching the logic.

Please review the formula first, suggest any improvements if needed,
then implement the API.
*/
