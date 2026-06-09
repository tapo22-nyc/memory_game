-- ============================================================
-- FILE: sql/06_launch_ban_vs_aus.sql
-- PURPOSE: Step-by-step launch of Bangladesh vs Australia match.
--
-- IMPORTANT DIFFERENCES FROM YOUR OLD IPL FLOW:
--   OLD: insert ipl_matches → insert fantasy_matches (with ipl_match_id) → players from ipl_player_master
--   NEW: skip ipl_matches entirely → insert fantasy_matches directly → players from cricket_player_pool
--
-- RUN ORDER:
--   Step 1  — Check if BAN/AUS players already exist
--   Step 2  — Insert Bangladesh players into cricket_player_pool
--   Step 3  — Insert Australia players into cricket_player_pool
--   Step 4  — Create the fantasy match
--   Step 5  — Get the new match ID (copy it — you need it for steps below)
--   Step 6  — Link players to the match
--   Step 7  — Verify player count and setup
--   Step 8  — Add career stats (required for proper budget tiers)
--   Step 9  — Activate budget tiers (call refresh APIs in browser)
--
-- SAFE TO RE-RUN: all inserts use ON CONFLICT DO NOTHING.
-- ============================================================


-- ============================================================
-- STEP 1: CHECK IF BAN/AUS PLAYERS ALREADY EXIST
-- Run this first. If it returns rows, skip Steps 2 and/or 3.
-- ============================================================

SELECT country, COUNT(*) AS player_count
FROM cricket_player_pool
WHERE country IN ('BAN', 'AUS')
GROUP BY country
ORDER BY country;


-- ============================================================
-- STEP 2: INSERT BANGLADESH PLAYERS INTO cricket_player_pool
-- Skip this step if Step 1 already shows 12 BAN players.
-- player_cost_coins starts at 5 — overwritten by budget system.
-- ============================================================

INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Najmul Hossain Shanto', 'BAN', 'BAT',  'batsman',       5),
  ('Litton Das',            'BAN', 'WK',   'wicket-keeper', 5),
  ('Tanzid Hasan',          'BAN', 'BAT',  'batsman',       5),
  ('Towhid Hridoy',         'BAN', 'BAT',  'batsman',       5),
  ('Mahmudullah',           'BAN', 'AR',   'all-rounder',   5),
  ('Shakib Al Hasan',       'BAN', 'AR',   'all-rounder',   5),
  ('Afif Hossain',          'BAN', 'AR',   'all-rounder',   5),
  ('Jaker Ali',             'BAN', 'WK',   'wicket-keeper', 5),
  ('Taskin Ahmed',          'BAN', 'BOWL', 'bowler',        5),
  ('Mustafizur Rahman',     'BAN', 'BOWL', 'bowler',        5),
  ('Shoriful Islam',        'BAN', 'BOWL', 'bowler',        5),
  ('Rishad Hossain',        'BAN', 'BOWL', 'bowler',        5)
ON CONFLICT DO NOTHING;


-- ============================================================
-- STEP 3: INSERT AUSTRALIA PLAYERS INTO cricket_player_pool
-- Skip this step if Step 1 already shows 12 AUS players.
-- ============================================================

INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Mitchell Marsh',    'AUS', 'AR',   'all-rounder',   5),
  ('David Warner',      'AUS', 'BAT',  'batsman',       5),
  ('Travis Head',       'AUS', 'BAT',  'batsman',       5),
  ('Steve Smith',       'AUS', 'BAT',  'batsman',       5),
  ('Glenn Maxwell',     'AUS', 'AR',   'all-rounder',   5),
  ('Matthew Wade',      'AUS', 'WK',   'wicket-keeper', 5),
  ('Tim David',         'AUS', 'BAT',  'batsman',       5),
  ('Marcus Stoinis',    'AUS', 'AR',   'all-rounder',   5),
  ('Pat Cummins',       'AUS', 'BOWL', 'bowler',        5),
  ('Mitchell Starc',    'AUS', 'BOWL', 'bowler',        5),
  ('Adam Zampa',        'AUS', 'BOWL', 'bowler',        5),
  ('Josh Hazlewood',    'AUS', 'BOWL', 'bowler',        5)
ON CONFLICT DO NOTHING;

-- Verify both squads are in the pool
SELECT country, COUNT(*) AS players
FROM cricket_player_pool
WHERE country IN ('BAN', 'AUS')
GROUP BY country;


-- ============================================================
-- STEP 4: CREATE THE FANTASY MATCH
--
-- Change match_format to 'odi' or 'test' if needed.
-- Change match_title and match_date as required.
-- budget_coins = 1000000 = $1M team cap (do NOT change this).
-- NOTE: No ipl_matches insert needed for international games.
-- ============================================================

INSERT INTO fantasy_matches
  (match_title, team_1, team_2, status, budget_coins, match_format)
VALUES
  (
    'BAN vs AUS — T20I',   -- ← change title as needed
    'BAN',
    'AUS',
    'open',
    1000000,               -- $1M budget cap — do not change
    't20'                  -- ← change to 'odi' or 'test' if needed
  )
RETURNING id, match_title, team_1, team_2, status, budget_coins, match_format;


-- ============================================================
-- STEP 5: GET YOUR NEW MATCH ID
-- Copy the id number from the RETURNING result above.
-- You need it for Steps 6, 7, and 9.
-- Also run this to double-check:
-- ============================================================

SELECT id, match_title, team_1, team_2, status, budget_coins, match_format
FROM fantasy_matches
ORDER BY id DESC
LIMIT 5;


-- ============================================================
-- STEP 6: LINK PLAYERS TO THE MATCH
-- Replace 999 with the actual match id from Step 5.
-- This links all BAN + AUS players from cricket_player_pool.
-- player_source = 'cricket' tells the API to join cricket_player_pool.
-- ============================================================

INSERT INTO fantasy_match_players (fantasy_match_id, player_id, player_source)
SELECT
  999 AS fantasy_match_id,    -- ← replace 999 with your actual match ID
  id  AS player_id,
  'cricket' AS player_source
FROM cricket_player_pool
WHERE country IN ('BAN', 'AUS')
  AND is_active = TRUE
ON CONFLICT (fantasy_match_id, player_id)
DO NOTHING;


-- ============================================================
-- STEP 7: VERIFY PLAYER SETUP
-- Replace 999 with your actual match ID.
-- You should see 24 players (12 BAN + 12 AUS).
-- ============================================================

SELECT
  fmp.fantasy_match_id,
  cpp.player_name,
  cpp.country         AS team,
  cpp.player_type,
  cpp.player_tag      AS role,
  fmp.player_source,
  COALESCE(fmp.is_active, TRUE) AS is_active
FROM fantasy_match_players fmp
JOIN cricket_player_pool cpp
  ON cpp.id = fmp.player_id
WHERE fmp.fantasy_match_id = 999    -- ← replace 999 with your actual match ID
ORDER BY cpp.country, cpp.player_name;

-- Quick count check — should return BAN=12, AUS=12
SELECT cpp.country, COUNT(*) AS players
FROM fantasy_match_players fmp
JOIN cricket_player_pool cpp ON cpp.id = fmp.player_id
WHERE fmp.fantasy_match_id = 999    -- ← replace 999
GROUP BY cpp.country;


-- ============================================================
-- STEP 8: ADD CAREER STATS TO player_career_stats_master
--
-- This is required for proper budget tier calculation.
-- Without this, all players default to score=50 and get
-- assigned to mid tier at ~$125,000 each.
--
-- Stats below are T20I career approximations.
-- Update any values that are outdated or inaccurate.
-- ============================================================

-- ── Bangladesh players ──────────────────────────────────────

INSERT INTO player_career_stats_master
  (player_name, country, player_role, player_pool_source,
   t20_bat_matches, t20_bat_runs, t20_bat_avg, t20_bat_strike_rate,
   t20_bat_50s, t20_bat_100s, t20_bat_4s, t20_bat_6s,
   t20_bowl_matches, t20_bowl_wickets, t20_bowl_economy, t20_bowl_5wi,
   data_source, updated_at)
VALUES
  ('Najmul Hossain Shanto', 'Bangladesh', 'batter',        'cricket', 55,  1200, 26.0, 125.0, 6,  0, 120, 30,  0,  0,  99.0, 0, 'manual', NOW()),
  ('Litton Das',            'Bangladesh', 'wicket_keeper', 'cricket', 85,  1900, 28.0, 133.0, 10, 0, 190, 55,  0,  0,  99.0, 0, 'manual', NOW()),
  ('Tanzid Hasan',          'Bangladesh', 'batter',        'cricket', 30,   600, 22.0, 130.0, 2,  0,  60, 25,  0,  0,  99.0, 0, 'manual', NOW()),
  ('Towhid Hridoy',         'Bangladesh', 'batter',        'cricket', 50,  1100, 27.0, 128.0, 5,  0, 100, 30,  0,  0,  99.0, 0, 'manual', NOW()),
  ('Mahmudullah',           'Bangladesh', 'all_rounder',   'cricket', 115, 2100, 24.0, 122.0, 8,  0, 190, 75,  85, 35,   8.2, 0, 'manual', NOW()),
  ('Shakib Al Hasan',       'Bangladesh', 'all_rounder',   'cricket', 125, 2400, 23.0, 118.0, 10, 0, 220, 60, 120,140,   6.8, 1, 'manual', NOW()),
  ('Afif Hossain',          'Bangladesh', 'all_rounder',   'cricket', 50,   800, 22.0, 118.0, 2,  0,  75, 30,  35, 15,   8.0, 0, 'manual', NOW()),
  ('Jaker Ali',             'Bangladesh', 'wicket_keeper', 'cricket', 20,   300, 20.0, 120.0, 1,  0,  30,  8,   0,  0,  99.0, 0, 'manual', NOW()),
  ('Taskin Ahmed',          'Bangladesh', 'bowler',        'cricket', 90,    80, 10.0,  90.0, 0,  0,   8,  2,  90,100,   8.0, 0, 'manual', NOW()),
  ('Mustafizur Rahman',     'Bangladesh', 'bowler',        'cricket', 100,   90, 10.0,  88.0, 0,  0,   9,  2, 100,115,   7.3, 0, 'manual', NOW()),
  ('Shoriful Islam',        'Bangladesh', 'bowler',        'cricket', 40,    35,  9.0,  88.0, 0,  0,   4,  1,  40, 45,   8.5, 0, 'manual', NOW()),
  ('Rishad Hossain',        'Bangladesh', 'bowler',        'cricket', 35,    30,  9.0,  85.0, 0,  0,   3,  1,  35, 40,   7.8, 1, 'manual', NOW())
ON CONFLICT (player_name, country)
DO UPDATE SET
  player_role          = EXCLUDED.player_role,
  t20_bat_matches      = EXCLUDED.t20_bat_matches,
  t20_bat_runs         = EXCLUDED.t20_bat_runs,
  t20_bat_avg          = EXCLUDED.t20_bat_avg,
  t20_bat_strike_rate  = EXCLUDED.t20_bat_strike_rate,
  t20_bat_50s          = EXCLUDED.t20_bat_50s,
  t20_bat_4s           = EXCLUDED.t20_bat_4s,
  t20_bat_6s           = EXCLUDED.t20_bat_6s,
  t20_bowl_matches     = EXCLUDED.t20_bowl_matches,
  t20_bowl_wickets     = EXCLUDED.t20_bowl_wickets,
  t20_bowl_economy     = EXCLUDED.t20_bowl_economy,
  t20_bowl_5wi         = EXCLUDED.t20_bowl_5wi,
  data_source          = EXCLUDED.data_source,
  updated_at           = NOW();


-- ── Australia players ────────────────────────────────────────

INSERT INTO player_career_stats_master
  (player_name, country, player_role, player_pool_source,
   t20_bat_matches, t20_bat_runs, t20_bat_avg, t20_bat_strike_rate,
   t20_bat_50s, t20_bat_100s, t20_bat_4s, t20_bat_6s,
   t20_bowl_matches, t20_bowl_wickets, t20_bowl_economy, t20_bowl_5wi,
   data_source, updated_at)
VALUES
  ('Mitchell Marsh',  'Australia', 'all_rounder',   'cricket', 80,  1500, 26.0, 140.0, 7,  0, 140, 75,  55, 25,  8.5, 0, 'manual', NOW()),
  ('David Warner',    'Australia', 'batter',        'cricket', 100, 2900, 34.0, 143.0, 22, 1, 320, 80,   0,  0, 99.0, 0, 'manual', NOW()),
  ('Travis Head',     'Australia', 'batter',        'cricket', 50,  1400, 32.0, 155.0, 8,  0, 140, 60,   0,  0, 99.0, 0, 'manual', NOW()),
  ('Steve Smith',     'Australia', 'batter',        'cricket', 75,  1400, 25.0, 125.0, 8,  0, 140, 30,   0,  0, 99.0, 0, 'manual', NOW()),
  ('Glenn Maxwell',   'Australia', 'all_rounder',   'cricket', 105, 3200, 33.0, 158.0, 16, 0, 310,160,  90, 55,  7.5, 0, 'manual', NOW()),
  ('Matthew Wade',    'Australia', 'wicket_keeper', 'cricket', 80,  1300, 21.0, 130.0, 5,  0, 110, 55,   0,  0, 99.0, 0, 'manual', NOW()),
  ('Tim David',       'Australia', 'batter',        'cricket', 35,   800, 30.0, 153.0, 4,  0,  70, 55,   0,  0, 99.0, 0, 'manual', NOW()),
  ('Marcus Stoinis',  'Australia', 'all_rounder',   'cricket', 60,  1200, 25.0, 140.0, 5,  0, 110, 60,  45, 30,  8.8, 0, 'manual', NOW()),
  ('Pat Cummins',     'Australia', 'bowler',        'cricket', 55,   120, 12.0,  95.0, 0,  0,  10,  5,  55, 50,  8.3, 0, 'manual', NOW()),
  ('Mitchell Starc',  'Australia', 'bowler',        'cricket', 55,   110, 12.0,  92.0, 0,  0,  10,  5,  55, 55,  8.6, 0, 'manual', NOW()),
  ('Adam Zampa',      'Australia', 'bowler',        'cricket', 85,    60,  9.0,  80.0, 0,  0,   5,  2,  85, 95,  7.3, 1, 'manual', NOW()),
  ('Josh Hazlewood',  'Australia', 'bowler',        'cricket', 50,    50,  9.0,  80.0, 0,  0,   4,  1,  50, 60,  7.8, 0, 'manual', NOW())
ON CONFLICT (player_name, country)
DO UPDATE SET
  player_role          = EXCLUDED.player_role,
  t20_bat_matches      = EXCLUDED.t20_bat_matches,
  t20_bat_runs         = EXCLUDED.t20_bat_runs,
  t20_bat_avg          = EXCLUDED.t20_bat_avg,
  t20_bat_strike_rate  = EXCLUDED.t20_bat_strike_rate,
  t20_bat_50s          = EXCLUDED.t20_bat_50s,
  t20_bat_4s           = EXCLUDED.t20_bat_4s,
  t20_bat_6s           = EXCLUDED.t20_bat_6s,
  t20_bowl_matches     = EXCLUDED.t20_bowl_matches,
  t20_bowl_wickets     = EXCLUDED.t20_bowl_wickets,
  t20_bowl_economy     = EXCLUDED.t20_bowl_economy,
  t20_bowl_5wi         = EXCLUDED.t20_bowl_5wi,
  data_source          = EXCLUDED.data_source,
  updated_at           = NOW();

-- Verify career stats were added
SELECT player_name, country, player_role,
  t20_bat_runs, t20_bat_strike_rate, t20_bowl_wickets, t20_bowl_economy
FROM player_career_stats_master
WHERE country IN ('Bangladesh', 'Australia')
ORDER BY country, player_name;


-- ============================================================
-- STEP 9: ACTIVATE BUDGET TIERS
--
-- After running Steps 1–8, open these URLs in your browser
-- IN THIS ORDER:
--
-- 9a. Refresh global scores (picks up the new career stats):
--     https://www.playmtgames.com/api/refresh-player-format-scores
--     Wait for: { "success": true, "rows_inserted": ... }
--
-- 9b. Refresh match budgets (replace 999 with your match ID):
--     https://www.playmtgames.com/api/refresh-match-player-budgets?fantasy_match_id=999
--     Wait for: { "success": true, "rows_upserted": 24, "matches_refreshed": [999] }
--
-- After Step 9, open Create Team on the match and verify:
--   - 4 players show $200K–$250K  (premium)
--   - 8 players show $120K–$190K  (mid)
--   - 12 players show $50K–$120K  (value)
-- ============================================================


-- ============================================================
-- FULL VERIFICATION — run after Step 9 to confirm everything
-- Replace 999 with your actual match ID.
-- ============================================================

SELECT
  mpb.player_name,
  mpb.team_name,
  mpb.role,
  mpb.budget_tier,
  mpb.final_player_budget,
  mpb.final_impact_score
FROM match_player_budgets mpb
WHERE mpb.fantasy_match_id = 999    -- ← replace 999 with your actual match ID
ORDER BY mpb.final_player_budget DESC;

-- Tier count — should show premium=4, mid=8, value=12
SELECT budget_tier, COUNT(*) AS players
FROM match_player_budgets
WHERE fantasy_match_id = 999        -- ← replace 999
GROUP BY budget_tier
ORDER BY budget_tier;
