-- ============================================================
-- FILE: player_data_runbook.sql
-- PURPOSE: Quick reference for maintaining player career stats
--          and querying historical + recent form data.
--
-- SECTIONS:
--   1. Re-sync player career stats (refresh from CricAPI)
--   2. Verify data is fresh
--   3. Career stats spot checks
--   4. Last 5 matches form per player
--   5. Prompt for Claude — next session
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


-- ============================================================
-- SECTION 3: CAREER STATS SPOT CHECKS
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


-- ============================================================
-- SECTION 4: LAST 5 MATCHES FORM PER PLAYER
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
  COUNT(*)                                              AS innings,
  SUM(runs)                                            AS total_runs,
  ROUND(AVG(runs), 1)                                  AS avg_runs,
  ROUND(AVG(strike_rate), 1)                           AS avg_sr,
  SUM(sixes)                                           AS total_6s
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Rohit Sharma')  -- change name as needed
  AND match_format = 'T20'
  AND innings_type = 'batting'
ORDER BY match_date DESC
LIMIT 10;


-- ============================================================
-- SECTION 5: PROMPT FOR CLAUDE — NEXT SESSION
--
-- Copy and paste the prompt below to start the next session.
-- ============================================================

/*
PROMPT FOR CLAUDE:

I am building a cricket fantasy game at www.playmtgames.com.
The tech stack is: Next.js / Vercel, Neon PostgreSQL (serverless),
CricAPI for player data.

Key tables in our DB:
- player_career_stats_master   : flat career stats per player (ODI/T20/Test batting+bowling)
- cricket_player_pool          : SL/WI international players (columns: player_name, country [SL/WI], player_type, budget, is_active)
- cricapi_player_master        : IPL players (columns: player_name, country, cricapi_player_id, budget)
- fantasy_player_impact_points : stores impact_points per player per match (currently hardcoded at 100)
- fantasy_match_players        : links players to a fantasy match
- cricapi_player_match_history : match-by-match performance rows per player

We have just finished syncing career stats for all SL/WI and IPL players
into player_career_stats_master using CricAPI.

The next task is to calculate Impact Scores and Budget values for all
players in an upcoming match, using the career stats from
player_career_stats_master.

Impact Score formula idea (T20 focused):
- Batsman / Wicketkeeper : (t20_bat_avg × t20_bat_strike_rate / 100) + (t20_bat_6s × 0.3) + (t20_bat_50s × 1.5) + (t20_bat_100s × 4.0)
- Bowler                 : (t20_bowl_wickets / t20_bowl_matches × 15) + MAX(0, 9.0 - t20_bowl_economy) × 4 + (t20_bowl_5wi × 3.0)
- All Rounder            : batting_score × 0.6 + bowling_score × 0.4

Budget formula idea:
- Normalize impact score to a range of 7.0–12.0 across all players in the match pool
- Best player = 12.0, weakest = 7.0, everyone else scaled linearly

What I want to build:
1. A new API endpoint (api/calculate-player-impact-budget.js) that:
   - Takes a fantasy_match_id as input
   - Finds all players in that match via fantasy_match_players
   - Calculates impact score and budget for each player using the formula above
   - Saves impact score to fantasy_player_impact_points table
   - Saves budget back to cricket_player_pool.budget or cricapi_player_master.budget
   - Returns a summary of what was calculated

2. The formula weights should be easy to tweak at the top of the file

Please review the formula, suggest any improvements, then implement the API.
*/
