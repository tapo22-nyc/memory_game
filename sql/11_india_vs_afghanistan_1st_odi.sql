-- ============================================================
-- FILE: sql/11_india_vs_afghanistan_1st_odi.sql
-- PURPOSE: Fresh start for India vs Afghanistan 1st ODI.
--
-- RUN ORDER (top to bottom in Neon SQL Editor):
--
--   SECTION 1 — Safety check: preview what will be deleted.
--               READ THIS BEFORE running anything below it.
--
--   SECTION 2 — Delete all test game data and user entries.
--               Keeps player pool and career stats intact.
--
--   SECTION 3 — Ensure Afghanistan players are in cricket_player_pool.
--               Safe to re-run — uses ON CONFLICT DO NOTHING.
--
--   SECTION 4 — Add India players to cricket_player_pool.
--
--   SECTION 5 — Upsert India career stats into player_career_stats_master.
--               Source: Cricbuzz historical as of 2026-06-12.
--               Stats cover all 3 formats (ODI, T20, Test).
--
--   SECTION 6 — Create the India vs Afghanistan 1st ODI match
--               and link all players in one atomic transaction.
--
--   SECTION 7 — Run impact score + budget calculation.
--               Writes to: cricket_player_pool.player_cost_coins
--               and fantasy_player_impact_points.
--               This replaces the browser API calls from older files.
--
--   SECTION 8 — Full verification.
--
-- SAFE TO RE-RUN: all inserts use ON CONFLICT DO NOTHING/UPDATE.
--                 Section 2 (delete) is the only destructive step.
-- ============================================================


-- ============================================================
-- SECTION 1: SAFETY CHECK — READ BEFORE RUNNING SECTION 2
-- ============================================================
-- These are SELECT-only queries. Run them first to see exactly
-- what test data exists and will be removed by Section 2.
-- Nothing is deleted here.
-- ============================================================

-- Confirm the 5 target matches exist and look as expected
SELECT id, match_title, match_format, status, created_at
FROM fantasy_matches
WHERE id IN (78,79,80,81,82)
ORDER BY id;

-- How many user teams will be deleted (scoped to these 5 matches only)?
SELECT COUNT(*) AS user_teams_to_delete
FROM fantasy_user_teams
WHERE fantasy_match_id IN (78,79,80,81,82);

-- How many match-player links will be deleted?
SELECT COUNT(*) AS match_player_links_to_delete
FROM fantasy_match_players
WHERE fantasy_match_id IN (78,79,80,81,82);

-- How many budget rows exist for these specific matches?
SELECT COUNT(*) AS budget_rows_to_delete
FROM match_player_budgets
WHERE fantasy_match_id IN (78,79,80,81,82);

-- How many impact score rows exist for these specific matches?
SELECT COUNT(*) AS impact_rows_to_delete
FROM fantasy_player_impact_points
WHERE fantasy_match_id IN (78,79,80,81,82);

-- How many user teams exist for these specific matches?
SELECT COUNT(*) AS user_teams_to_delete
FROM fantasy_user_teams
WHERE fantasy_match_id IN (78,79,80,81,82);


-- ============================================================
-- SECTION 2: DELETE DATA FOR MATCHES 78, 79, 80, 81, 82 ONLY
-- ============================================================
-- Every DELETE is filtered to fantasy_match_id IN (78,79,80,81,82).
-- All other matches, user entries, and player data are untouched.
-- Deletes in dependency order: deepest child tables first.
-- ============================================================

BEGIN;

  -- 2a: Delete user team player selections for these matches only.
  --     fantasy_user_team_players references fantasy_user_teams,
  --     so we delete via a subquery on the parent table.
  DELETE FROM fantasy_user_team_players
  WHERE fantasy_user_team_id IN (
    SELECT id FROM fantasy_user_teams
    WHERE fantasy_match_id IN (78,79,80,81,82)
  );

  -- 2b: Delete user team entries for these matches only
  DELETE FROM fantasy_user_teams
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2c: Delete impact scores for these matches only
  DELETE FROM fantasy_player_impact_points
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2d: Delete budget/tier rows for these matches only
  DELETE FROM match_player_budgets
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2e: Delete player-to-match links for these matches only
  DELETE FROM fantasy_match_players
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2f: Delete clickstream events referencing these matches
  DELETE FROM user_clickstream_events
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2g: Delete coin ledger entries referencing these matches
  DELETE FROM fantasy_user_coin_ledger
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2h: Delete user booster entries referencing these matches
  DELETE FROM fantasy_user_boosters
  WHERE fantasy_match_id IN (78,79,80,81,82);

  -- 2i: Delete the matches themselves
  DELETE FROM fantasy_matches
  WHERE id IN (78,79,80,81,82);

COMMIT;

-- Confirm the 5 matches are gone and everything else still exists
SELECT COUNT(*) AS matches_remaining,
       MIN(id)  AS lowest_remaining_id,
       MAX(id)  AS highest_remaining_id
FROM fantasy_matches;

-- Confirm no orphan rows remain for those match IDs
SELECT 'fantasy_match_players'        AS tbl, COUNT(*) AS remaining
FROM fantasy_match_players        WHERE fantasy_match_id IN (78,79,80,81,82)
UNION ALL
SELECT 'fantasy_user_teams',          COUNT(*)
FROM fantasy_user_teams           WHERE fantasy_match_id IN (78,79,80,81,82)
UNION ALL
SELECT 'fantasy_player_impact_points',COUNT(*)
FROM fantasy_player_impact_points WHERE fantasy_match_id IN (78,79,80,81,82)
UNION ALL
SELECT 'match_player_budgets',        COUNT(*)
FROM match_player_budgets         WHERE fantasy_match_id IN (78,79,80,81,82);


-- ============================================================
-- SECTION 3: ENSURE AFGHANISTAN PLAYERS ARE IN cricket_player_pool
-- ============================================================
-- These were inserted by 10_afghanistan_india_series_setup.sql.
-- Repeating here with ON CONFLICT DO NOTHING is harmless — if
-- they already exist, this does nothing.
-- ============================================================

INSERT INTO cricket_player_pool
  (player_name, country, player_type, player_tag, player_cost_coins, is_active)
VALUES
  ('Hashmatullah Shahid', 'AFG', 'BAT',  'batsman',       5, TRUE),
  ('Ibrahim Zadran',      'AFG', 'BAT',  'batsman',       5, TRUE),
  ('Sediqullah Atal',     'AFG', 'BAT',  'batsman',       5, TRUE),
  ('Rahmat Shah',         'AFG', 'BAT',  'batsman',       5, TRUE),
  ('Darwish Rasooli',     'AFG', 'BAT',  'batsman',       5, TRUE),
  ('Ikram Alikhil',       'AFG', 'WK',   'wicket-keeper', 5, TRUE),
  ('Rahmanullah Gurbaz',  'AFG', 'WK',   'wicket-keeper', 5, TRUE),
  ('Azmatullah Omarzai',  'AFG', 'AR',   'all-rounder',   5, TRUE),
  ('Mohammad Nabi',       'AFG', 'AR',   'all-rounder',   5, TRUE),
  ('Rashid Khan',         'AFG', 'AR',   'all-rounder',   5, TRUE),
  ('Nangeyalia Kharoti',  'AFG', 'AR',   'all-rounder',   5, TRUE),
  ('AM Ghazanfar',        'AFG', 'BOWL', 'bowler',        5, TRUE),
  ('Bilal Sami',          'AFG', 'BOWL', 'bowler',        5, TRUE),
  ('Fareed Ahmad Malik',  'AFG', 'BOWL', 'bowler',        5, TRUE)
ON CONFLICT DO NOTHING;

SELECT country, COUNT(*) AS players
FROM cricket_player_pool
WHERE country = 'AFG';


-- ============================================================
-- SECTION 4: ADD INDIA PLAYERS TO cricket_player_pool
-- ============================================================
-- 14 players in the India ODI squad for this series.
-- Country code = 'IND' (short code convention in this table).
-- ============================================================

INSERT INTO cricket_player_pool
  (player_name, country, player_type, player_tag, player_cost_coins, is_active)
VALUES
  -- Batters
  ('Shubman Gill',       'IND', 'BAT',  'batsman',       5, TRUE),
  ('Rohit Sharma',       'IND', 'BAT',  'batsman',       5, TRUE),
  ('Yashasvi Jaiswal',   'IND', 'BAT',  'batsman',       5, TRUE),
  ('Shreyas Iyer',       'IND', 'BAT',  'batsman',       5, TRUE),
  -- Wicket-keepers
  ('KL Rahul',           'IND', 'WK',   'wicket-keeper', 5, TRUE),
  ('Ishan Kishan',       'IND', 'WK',   'wicket-keeper', 5, TRUE),
  -- All-rounders
  ('Washington Sundar',  'IND', 'AR',   'all-rounder',   5, TRUE),
  ('Nitish Kumar Reddy', 'IND', 'AR',   'all-rounder',   5, TRUE),
  -- Bowlers
  ('Kuldeep Yadav',      'IND', 'BOWL', 'bowler',        5, TRUE),
  ('Arshdeep Singh',     'IND', 'BOWL', 'bowler',        5, TRUE),
  ('Gurnoon Brar',       'IND', 'BOWL', 'bowler',        5, TRUE),
  ('Prasidh Krishna',    'IND', 'BOWL', 'bowler',        5, TRUE),
  ('Prince Yadav',       'IND', 'BOWL', 'bowler',        5, TRUE),
  ('Harsh Yadav',        'IND', 'BOWL', 'bowler',        5, TRUE)
ON CONFLICT DO NOTHING;

SELECT country, player_type, COUNT(*) AS players
FROM cricket_player_pool
WHERE country = 'IND'
GROUP BY country, player_type
ORDER BY player_type;


-- ============================================================
-- SECTION 5: UPSERT INDIA CAREER STATS
-- ============================================================
-- Source: Cricbuzz historical data, as of 2026-06-12.
-- country = 'India' (full name — matches the master table convention).
-- bowl_economy = 99 for batters/keepers with no bowling history.
-- bat_highest stored as TEXT.
--
-- Column value order per player:
--   identity(4) | odi_bat(12) | odi_bowl(9) | t20_bat(12)
--   | t20_bowl(9) | test_bat(12) | test_bowl(10) | source(1)
-- ============================================================

INSERT INTO player_career_stats_master (
  player_name, country, player_role, player_pool_source,
  odi_bat_matches, odi_bat_innings, odi_bat_not_outs,
  odi_bat_runs, odi_bat_highest, odi_bat_avg,
  odi_bat_balls_faced, odi_bat_strike_rate,
  odi_bat_100s, odi_bat_50s, odi_bat_4s, odi_bat_6s,
  odi_bowl_matches, odi_bowl_innings, odi_bowl_balls,
  odi_bowl_runs, odi_bowl_wickets, odi_bowl_avg,
  odi_bowl_economy, odi_bowl_strike_rate, odi_bowl_5wi,
  t20_bat_matches, t20_bat_innings, t20_bat_not_outs,
  t20_bat_runs, t20_bat_highest, t20_bat_avg,
  t20_bat_balls_faced, t20_bat_strike_rate,
  t20_bat_100s, t20_bat_50s, t20_bat_4s, t20_bat_6s,
  t20_bowl_matches, t20_bowl_innings, t20_bowl_balls,
  t20_bowl_runs, t20_bowl_wickets, t20_bowl_avg,
  t20_bowl_economy, t20_bowl_strike_rate, t20_bowl_5wi,
  test_bat_matches, test_bat_innings, test_bat_not_outs,
  test_bat_runs, test_bat_highest, test_bat_avg,
  test_bat_balls_faced, test_bat_strike_rate,
  test_bat_100s, test_bat_50s, test_bat_4s, test_bat_6s,
  test_bowl_matches, test_bowl_innings, test_bowl_balls,
  test_bowl_runs, test_bowl_wickets, test_bowl_avg,
  test_bowl_economy, test_bowl_strike_rate,
  test_bowl_5wi, test_bowl_10wi,
  data_source
)
VALUES

-- ── Shubman Gill (batter) — source: cricapi ──────────────────
('Shubman Gill','India','batter','ipl',
  48, 48,  7, 2415, '208', 58.9,  2384, 101.3,  6, 14, 274, 52,
  48,  2,  0,   25,    0,   0,    8.33,   0,    0,
  21, 21,  2,  578, '126', 30.42,  415, 139.28,  1,  3,  60, 22,
  21,  0,  0,    0,    0,   0,       0,   0,    0,
  32, 59,  5, 1893, '128', 35.06, 3159,  59.92,  5,  7, 210, 31,
  32,  1,  0,    1,    0,   0,    0.86,   0,    0,  0,
  'cricapi'),

-- ── KL Rahul (wicket-keeper) — source: cricapi ───────────────
('KL Rahul','India','wicket_keeper','ipl',
  79, 74, 14, 2863, '112', 47.72, 3279,  87.31,  7, 18, 227, 61,
  79,  0,  0,    0,    0,   0,       0,   0,    0,
  72, 68,  8, 2265, '110', 37.75, 1628, 139.13,  2, 22, 191, 99,
  72,  0,  0,    0,    0,   0,       0,   0,    0,
  58,101,  4, 3257, '199', 33.58, 6168,  52.8,   8, 17, 386, 26,
  58,  0,  0,    0,    0,   0,       0,   0,    0,  0,
  'cricapi'),

-- ── Rohit Sharma (batter) — source: cricapi ─────────────────
('Rohit Sharma','India','batter','ipl',
  267,259, 36,10987, '264', 49.27,11852,  92.7,  32, 57,1023,338,
  267, 40,  0,  533,    9,  59.22, 5.24,  67.78,  0,
  159,151, 16, 4231, '121', 31.34, 3003, 140.89,   5, 32, 383,205,
  159,  9,  0,  113,    1, 113,    9.97,  68,     0,
   67,116, 10, 4302, '212', 40.58, 7538,  57.07,  12, 18, 473, 88,
   67, 16,  0,  224,    2, 112,    3.51, 191.5,   0,  0,
  'cricapi'),

-- ── Yashasvi Jaiswal (batter) — source: cricapi ─────────────
('Yashasvi Jaiswal','India','batter','ipl',
   1,  1,  0,   15,  '15', 15,      22,  68.18,   0,  0,   3,  0,
   1,  0,  0,    0,    0,   0,       0,   0,    0,
  23, 22,  2,  723, '100', 36.15,  440, 164.32,   1,  5,  82, 38,
  23,  1,  0,   11,    0,   0,      11,   0,    0,
  19, 36,  2, 1798, '214', 52.88, 2738,  65.67,   4, 10, 207, 39,
  19,  1,  0,    6,    0,   0,       6,   0,    0,  0,
  'cricapi'),

-- ── Ishan Kishan (wicket-keeper) — source: cricapi ──────────
('Ishan Kishan','India','wicket_keeper','ipl',
  27, 24,  2,  933, '210', 42.41,  913, 102.19,   1,  7,  95, 33,
  27,  0,  0,    0,    0,   0,       0,   0,    0,
  32, 32,  1,  796,  '89', 25.68,  640, 124.38,   0,  6,  79, 36,
  32,  0,  0,    0,    0,   0,       0,   0,    0,
   2,  3,  2,   78,  '52', 78,      91,  85.71,   0,  1,   8,  2,
   2,  0,  0,    0,    0,   0,       0,   0,    0,  0,
  'cricapi'),

-- ── Shreyas Iyer (batter) — source: cricapi ─────────────────
('Shreyas Iyer','India','batter','ipl',
  64, 59,  6, 2524, '128', 47.62, 2475, 101.98,   5, 19, 238, 65,
  64,  5,  0,   39,    0,   0,    6.32,   0,    0,
  51, 47, 11, 1104,  '74', 30.67,  811, 136.13,   0,  8,  90, 44,
  51,  1,  0,    2,    0,   0,       0,   0,    0,
  14, 24,  2,  811, '105', 36.86, 1287,  63.01,   1,  5,  94, 16,
  14,  1,  0,    2,    0,   0,       2,   0,    0,  0,
  'cricapi'),

-- ── Washington Sundar (all-rounder) — source: cricapi ───────
('Washington Sundar','India','all_rounder','ipl',
  22, 14,  1,  315,  '51', 24.23,  380,  82.89,   0,  1,  23, 10,
  22, 19,  0,  626,   23,  27.22,  4.71, 34.7,    0,
  54, 22,  8,  193,  '50', 13.79,  159, 121.38,   0,  1,  16,  9,
  54, 52,  0, 1128,   48,  23.5,   6.94, 20.31,   0,
   9, 16,  5,  468,  '96', 42.55, 1020,  45.88,   0,  4,  44,  9,
   9, 16,  0,  641,   25,  25.64,  3.28, 46.92,   1,  1,
  'cricapi'),

-- ── Nitish Kumar Reddy (all-rounder) — source: cricapi ──────
('Nitish Kumar Reddy','India','all_rounder','ipl',
   1,  1,  1,   19,  '19',  0,      11, 172.73,   0,  0,   0,  2,
   1,  1,  0,   16,    0,   0,    7.38,   0,    0,
   4,  3,  1,   90,  '74', 45,      50, 180,      0,  1,   4,  8,
   4,  3,  0,   71,    3,  23.67,  7.89, 18,     0,
   5,  9,  1,  298, '114', 37.25,  464,  64.22,   1,  0,  30,  8,
   5,  9,  0,  190,    5,  38,     4.32, 52.8,    0,  0,
  'cricapi'),

-- ── Kuldeep Yadav (bowler) — source: cricapi ────────────────
('Kuldeep Yadav','India','bowler','ipl',
  107, 40, 19,  205,  '19',  9.76,  405,  50.62,  0,  0,  14,  0,
  107,104,  0, 4525,  173,  26.16,  5,    31.37,  2,
   40,  7,  3,   46,  '23', 11.5,   59,   77.97,  0,  0,   2,  0,
   40, 39,  0,  971,   69,  14.07,  6.77, 12.46,  2,
   13, 17,  2,  199,  '40', 13.27,  698,  28.51,  0,  0,  18,  1,
   13, 24,  0, 1241,   56,  22.16,  3.56, 37.38,  4,  0,
  'cricapi'),

-- ── Arshdeep Singh (bowler) — source: cricapi ───────────────
('Arshdeep Singh','India','bowler','ipl',
   8,  5,  1,   37,  '18',  9.25,   33, 112.12,  0,  0,   1,  3,
   8,  7,  0,  289,   12,  24.08,  5.06, 28.58,  1,
  63, 21, 13,   71,  '12',  8.88,   62, 116.13,  0,  0,   6,  3,
  63, 63,  0, 1812,   99,  18.3,   8.3,  13.23,  0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,  0,
  'cricapi'),

-- ── Gurnoon Brar (bowler) — not in dataset, all zeros ───────
('Gurnoon Brar','India','bowler','manual',
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,  0,
  'manual'),

-- ── Prasidh Krishna (bowler) — source: cricapi ──────────────
('Prasidh Krishna','India','bowler','ipl',
  17,  7,  5,    2,   '2',  1,      17,   11.76,  0,  0,   0,  0,
  17, 17,  0,  742,   29,  25.59,  5.61,  27.38,  0,
   5,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   5,  5,  0,  220,    8,  27.5,   11,    15,     0,
   3,  5,  3,    4,   '3',  2,      27,   14.81,  0,  0,   0,  0,
   3,  5,  0,  237,    8,  29.62,  4.31,  41.25,  0,  0,
  'cricapi'),

-- ── Prince Yadav (bowler) — no career stats yet ─────────────
('Prince Yadav','India','bowler','ipl',
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,  0,
  'cricapi'),

-- ── Harsh Yadav (bowler) — not in dataset, all zeros ────────
('Harsh Yadav','India','bowler','manual',
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,
   0,  0,  0,    0,   '0',  0,       0,    0,    0,  0,   0,  0,
   0,  0,  0,    0,    0,   0,       0,    0,    0,  0,
  'manual')

ON CONFLICT (player_name, country) DO UPDATE SET
  player_role          = EXCLUDED.player_role,
  player_pool_source   = EXCLUDED.player_pool_source,
  odi_bat_matches      = EXCLUDED.odi_bat_matches,
  odi_bat_innings      = EXCLUDED.odi_bat_innings,
  odi_bat_not_outs     = EXCLUDED.odi_bat_not_outs,
  odi_bat_runs         = EXCLUDED.odi_bat_runs,
  odi_bat_highest      = EXCLUDED.odi_bat_highest,
  odi_bat_avg          = EXCLUDED.odi_bat_avg,
  odi_bat_balls_faced  = EXCLUDED.odi_bat_balls_faced,
  odi_bat_strike_rate  = EXCLUDED.odi_bat_strike_rate,
  odi_bat_100s         = EXCLUDED.odi_bat_100s,
  odi_bat_50s          = EXCLUDED.odi_bat_50s,
  odi_bat_4s           = EXCLUDED.odi_bat_4s,
  odi_bat_6s           = EXCLUDED.odi_bat_6s,
  odi_bowl_matches     = EXCLUDED.odi_bowl_matches,
  odi_bowl_innings     = EXCLUDED.odi_bowl_innings,
  odi_bowl_balls       = EXCLUDED.odi_bowl_balls,
  odi_bowl_runs        = EXCLUDED.odi_bowl_runs,
  odi_bowl_wickets     = EXCLUDED.odi_bowl_wickets,
  odi_bowl_avg         = EXCLUDED.odi_bowl_avg,
  odi_bowl_economy     = EXCLUDED.odi_bowl_economy,
  odi_bowl_strike_rate = EXCLUDED.odi_bowl_strike_rate,
  odi_bowl_5wi         = EXCLUDED.odi_bowl_5wi,
  t20_bat_matches      = EXCLUDED.t20_bat_matches,
  t20_bat_innings      = EXCLUDED.t20_bat_innings,
  t20_bat_not_outs     = EXCLUDED.t20_bat_not_outs,
  t20_bat_runs         = EXCLUDED.t20_bat_runs,
  t20_bat_highest      = EXCLUDED.t20_bat_highest,
  t20_bat_avg          = EXCLUDED.t20_bat_avg,
  t20_bat_balls_faced  = EXCLUDED.t20_bat_balls_faced,
  t20_bat_strike_rate  = EXCLUDED.t20_bat_strike_rate,
  t20_bat_100s         = EXCLUDED.t20_bat_100s,
  t20_bat_50s          = EXCLUDED.t20_bat_50s,
  t20_bat_4s           = EXCLUDED.t20_bat_4s,
  t20_bat_6s           = EXCLUDED.t20_bat_6s,
  t20_bowl_matches     = EXCLUDED.t20_bowl_matches,
  t20_bowl_innings     = EXCLUDED.t20_bowl_innings,
  t20_bowl_balls       = EXCLUDED.t20_bowl_balls,
  t20_bowl_runs        = EXCLUDED.t20_bowl_runs,
  t20_bowl_wickets     = EXCLUDED.t20_bowl_wickets,
  t20_bowl_avg         = EXCLUDED.t20_bowl_avg,
  t20_bowl_economy     = EXCLUDED.t20_bowl_economy,
  t20_bowl_strike_rate = EXCLUDED.t20_bowl_strike_rate,
  t20_bowl_5wi         = EXCLUDED.t20_bowl_5wi,
  test_bat_matches     = EXCLUDED.test_bat_matches,
  test_bat_innings     = EXCLUDED.test_bat_innings,
  test_bat_not_outs    = EXCLUDED.test_bat_not_outs,
  test_bat_runs        = EXCLUDED.test_bat_runs,
  test_bat_highest     = EXCLUDED.test_bat_highest,
  test_bat_avg         = EXCLUDED.test_bat_avg,
  test_bat_balls_faced = EXCLUDED.test_bat_balls_faced,
  test_bat_strike_rate = EXCLUDED.test_bat_strike_rate,
  test_bat_100s        = EXCLUDED.test_bat_100s,
  test_bat_50s         = EXCLUDED.test_bat_50s,
  test_bat_4s          = EXCLUDED.test_bat_4s,
  test_bat_6s          = EXCLUDED.test_bat_6s,
  test_bowl_matches    = EXCLUDED.test_bowl_matches,
  test_bowl_innings    = EXCLUDED.test_bowl_innings,
  test_bowl_balls      = EXCLUDED.test_bowl_balls,
  test_bowl_runs       = EXCLUDED.test_bowl_runs,
  test_bowl_wickets    = EXCLUDED.test_bowl_wickets,
  test_bowl_avg        = EXCLUDED.test_bowl_avg,
  test_bowl_economy    = EXCLUDED.test_bowl_economy,
  test_bowl_strike_rate= EXCLUDED.test_bowl_strike_rate,
  test_bowl_5wi        = EXCLUDED.test_bowl_5wi,
  test_bowl_10wi       = EXCLUDED.test_bowl_10wi,
  data_source          = EXCLUDED.data_source,
  updated_at           = NOW();

-- Confirm 14 India rows exist in the master table
SELECT player_name, player_role,
  odi_bat_runs, odi_bat_avg, odi_bat_strike_rate,
  odi_bowl_wickets, odi_bowl_economy
FROM player_career_stats_master
WHERE country = 'India'
ORDER BY player_role, odi_bat_runs DESC;


-- ============================================================
-- SECTION 6: CREATE MATCH + LINK PLAYERS (single transaction)
-- ============================================================
-- Creates the India vs Afghanistan 1st ODI and links all 28
-- players (14 IND + 14 AFG) in one atomic block.
--
-- fantasy_team_size = 8 players per the 8-player non-IPL rule
-- (see migration_8player_nonipl_20260609.sql).
-- min 3 / max 5 players per team.
-- ============================================================

WITH new_match AS (
  INSERT INTO fantasy_matches
    (match_title, team_1, team_2, status, budget_coins,
     match_format, fantasy_team_size, min_players_per_team, max_players_per_team,
     match_start_time)
  VALUES
    ('IND vs AFG — 1st ODI', 'IND', 'AFG', 'open', 1000000,
     'odi', 8, 3, 5,
     '2026-06-13 04:00:00-04'::TIMESTAMPTZ)
  RETURNING id
),
all_players AS (
  SELECT id AS player_id
  FROM cricket_player_pool
  WHERE country IN ('IND', 'AFG')
    AND is_active = TRUE
)
INSERT INTO fantasy_match_players (fantasy_match_id, player_id, player_source)
SELECT nm.id, ap.player_id, 'cricket'
FROM new_match nm
CROSS JOIN all_players ap
ON CONFLICT DO NOTHING;

-- Show the newly created match
SELECT id, match_title, match_format, fantasy_team_size,
       min_players_per_team, max_players_per_team, budget_coins, status
FROM fantasy_matches
ORDER BY id DESC
LIMIT 1;

-- Show player count linked to it (expect 28: 14 IND + 14 AFG)
SELECT cpp.country, COUNT(*) AS players
FROM fantasy_match_players fmp
JOIN cricket_player_pool cpp ON cpp.id = fmp.player_id
JOIN fantasy_matches fm ON fm.id = fmp.fantasy_match_id
WHERE fm.match_title = 'IND vs AFG — 1st ODI'
GROUP BY cpp.country
ORDER BY cpp.country;


-- ============================================================
-- SECTION 7: IMPACT SCORE + BUDGET CALCULATION
-- ============================================================
-- The API has been fixed to handle all countries (IND, AFG, BAN,
-- etc.) correctly. Two fixes applied to
-- api/refresh-player-format-scores.js:
--   1. Role normalisation: 'wicketkeeper' → 'wicket_keeper', etc.
--   2. Economy = 0 now treated as 99 (player has no bowling history)
--      instead of ranking them as the best bowler in the dataset.
--
-- DO NOT RUN ANY SQL HERE.
-- Instead, open these two URLs in your browser (in order):
--
--   STEP 1 — Rebuild global format scores (all players, all formats):
--   https://playmtgames.com/api/refresh-player-format-scores
--
--   STEP 2 — Calculate budgets for this match only:
--   https://playmtgames.com/api/refresh-match-player-budgets?fantasy_match_id=<NEW_MATCH_ID>
--
--   Replace <NEW_MATCH_ID> with the id returned by Section 6
--   (check the "Show the newly created match" SELECT above).
--
-- This is the same workflow as all previous match files.
-- ============================================================


-- (No SQL to run here — see Section 7 comment above for the two API URLs.)

/*
WITH
  player_roles AS (
  unpivoted AS (
    -- ODI format only — this is an ODI match
    SELECT p.player_name, p.country, r.role, 'odi' AS format,
      COALESCE(p.odi_bat_matches,0)      AS bat_matches,
      COALESCE(p.odi_bat_runs,0)         AS bat_runs,
      COALESCE(p.odi_bat_avg,0)          AS bat_avg,
      COALESCE(p.odi_bat_strike_rate,0)  AS bat_sr,
      COALESCE(p.odi_bat_50s,0)          AS bat_50s,
      COALESCE(p.odi_bat_100s,0)         AS bat_100s,
      COALESCE(p.odi_bat_4s,0)           AS bat_4s,
      COALESCE(p.odi_bat_6s,0)           AS bat_6s,
      COALESCE(p.odi_bowl_matches,0)     AS bowl_matches,
      COALESCE(p.odi_bowl_wickets,0)     AS bowl_wickets,
      -- treat 0 economy as 99 (no bowling history) so economy_score ranks correctly
      CASE WHEN COALESCE(p.odi_bowl_economy,0) = 0 THEN 99
           ELSE p.odi_bowl_economy END   AS bowl_economy,
      COALESCE(p.odi_bowl_5wi,0)         AS bowl_5wi,
      0                                  AS bowl_10wi
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)
  ),
  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_runs)                * 100)::numeric,1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_avg)                 * 100)::numeric,1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_sr)                  * 100)::numeric,1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_50s)                 * 100)::numeric,1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_100s)                * 100)::numeric,1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY (bat_4s + bat_6s*1.5))   * 100)::numeric,1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_6s)                  * 100)::numeric,1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_matches)             * 100)::numeric,1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_wickets)            * 100)::numeric,1) AS wickets_score,
      -- Lower economy = better, so invert the rank
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_economy))      * 100)::numeric,1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_5wi)                * 100)::numeric,1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_matches)            * 100)::numeric,1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role,
      -- ODI batting impact: runs 40%, avg 30%, SR 30%
      ROUND(runs_score*0.40 + batting_avg_score*0.30 + strike_rate_score*0.30, 1) AS batting_impact,
      -- ODI bowling impact: wickets 55%, economy 45%
      ROUND(wickets_score*0.55 + economy_score*0.45, 1)                           AS bowling_impact,
      -- ODI batting budget: experience 20%, avg 40%, fifties 20%, hundreds 20%
      ROUND(bat_experience_score*0.20 + batting_avg_score*0.40 + fifties_score*0.20 + hundreds_score*0.20, 1) AS batting_budget,
      -- ODI bowling budget: experience 20%, wickets 40%, economy 40%
      ROUND(bowl_experience_score*0.20 + wickets_score*0.40 + economy_score*0.40, 1) AS bowling_budget
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country, role,
      GREATEST(0, LEAST(100, ROUND(
        CASE
          WHEN role IN ('batter','wicket_keeper') THEN batting_impact
          WHEN role = 'bowler'                    THEN bowling_impact
          WHEN role = 'all_rounder'               THEN batting_impact*0.50 + bowling_impact*0.50
          ELSE (batting_impact + bowling_impact) / 2
        END, 1))) AS final_impact_score,
      GREATEST(0, LEAST(100, ROUND(
        CASE
          WHEN role IN ('batter','wicket_keeper') THEN batting_budget
          WHEN role = 'bowler'                    THEN bowling_budget
          WHEN role = 'all_rounder'               THEN batting_budget*0.50 + bowling_budget*0.50
          ELSE (batting_budget + bowling_budget) / 2
        END, 1))) AS raw_budget_score
    FROM scored
  )
UPDATE cricket_player_pool cpp
SET player_cost_coins =
      ROUND((50000 + (c.raw_budget_score / 100.0) * 200000) / 5000) * 5000
FROM combined c
WHERE LOWER(cpp.player_name) = LOWER(c.player_name)
  AND cpp.country = CASE c.country
                      WHEN 'India'       THEN 'IND'
                      WHEN 'Afghanistan' THEN 'AFG'
                    END;

-- Preview updated costs
SELECT cpp.player_name, cpp.country, cpp.player_type, cpp.player_cost_coins
FROM cricket_player_pool cpp
WHERE cpp.country IN ('IND', 'AFG')
ORDER BY cpp.country, cpp.player_cost_coins DESC;


-- ── STEP 7b: Upsert impact scores into fantasy_player_impact_points ─

WITH
  player_roles AS (
    SELECT p.player_name, p.country,
      COALESCE(p.player_role, 'unknown') AS role
    FROM player_career_stats_master p
    WHERE p.country IN ('India', 'Afghanistan')
  ),
  unpivoted AS (
    SELECT p.player_name, p.country, r.role,
      COALESCE(p.odi_bat_matches,0)      AS bat_matches,
      COALESCE(p.odi_bat_runs,0)         AS bat_runs,
      COALESCE(p.odi_bat_avg,0)          AS bat_avg,
      COALESCE(p.odi_bat_strike_rate,0)  AS bat_sr,
      COALESCE(p.odi_bat_50s,0)          AS bat_50s,
      COALESCE(p.odi_bat_100s,0)         AS bat_100s,
      COALESCE(p.odi_bat_4s,0)           AS bat_4s,
      COALESCE(p.odi_bat_6s,0)           AS bat_6s,
      COALESCE(p.odi_bowl_matches,0)     AS bowl_matches,
      COALESCE(p.odi_bowl_wickets,0)     AS bowl_wickets,
      CASE WHEN COALESCE(p.odi_bowl_economy,0) = 0 THEN 99
           ELSE p.odi_bowl_economy END   AS bowl_economy,
      COALESCE(p.odi_bowl_5wi,0)         AS bowl_5wi
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)
  ),
  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_runs)               * 100)::numeric,1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_avg)                * 100)::numeric,1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_sr)                 * 100)::numeric,1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_50s)                * 100)::numeric,1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_100s)               * 100)::numeric,1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric,1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_6s)                 * 100)::numeric,1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bat_matches)            * 100)::numeric,1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_wickets)           * 100)::numeric,1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_economy))     * 100)::numeric,1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_5wi)               * 100)::numeric,1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY role ORDER BY bowl_matches)           * 100)::numeric,1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role,
      ROUND(runs_score*0.40 + batting_avg_score*0.30 + strike_rate_score*0.30, 1) AS batting_impact,
      ROUND(wickets_score*0.55 + economy_score*0.45, 1)                           AS bowling_impact
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country,
      GREATEST(0, LEAST(100, ROUND(
        CASE
          WHEN role IN ('batter','wicket_keeper') THEN batting_impact
          WHEN role = 'bowler'                    THEN bowling_impact
          WHEN role = 'all_rounder'               THEN batting_impact*0.50 + bowling_impact*0.50
          ELSE (batting_impact + bowling_impact) / 2
        END, 1))) AS final_impact_score
    FROM scored
  )
INSERT INTO fantasy_player_impact_points
  (fantasy_player_id, fantasy_match_id, impact_points, source, updated_at)
SELECT
  cpp.id                     AS fantasy_player_id,
  fm.id                      AS fantasy_match_id,
  c.final_impact_score,
  'calculated_v3',
  NOW()
FROM combined c
JOIN cricket_player_pool cpp
  ON LOWER(cpp.player_name) = LOWER(c.player_name)
 AND cpp.country = CASE c.country
                     WHEN 'India'       THEN 'IND'
                     WHEN 'Afghanistan' THEN 'AFG'
                   END
JOIN fantasy_matches fm
  ON fm.match_title = 'IND vs AFG — 1st ODI'
JOIN fantasy_match_players fmp
  ON fmp.fantasy_match_id = fm.id
 AND fmp.player_id = cpp.id
ON CONFLICT (fantasy_player_id, fantasy_match_id)
DO UPDATE SET
  impact_points = EXCLUDED.impact_points,
  source        = EXCLUDED.source,
  updated_at    = NOW();
*/


-- ============================================================
-- SECTION 8: FULL VERIFICATION
-- ============================================================

-- 8a: Match summary
SELECT id, match_title, match_format, fantasy_team_size,
       min_players_per_team, max_players_per_team,
       budget_coins, status
FROM fantasy_matches
WHERE match_title = 'IND vs AFG — 1st ODI';

-- 8b: Player count per team linked to the match (expect IND=14, AFG=14)
SELECT cpp.country, COUNT(*) AS players
FROM fantasy_match_players fmp
JOIN cricket_player_pool cpp ON cpp.id = fmp.player_id
JOIN fantasy_matches fm      ON fm.id  = fmp.fantasy_match_id
WHERE fm.match_title = 'IND vs AFG — 1st ODI'
GROUP BY cpp.country
ORDER BY cpp.country;

-- 8c: Impact scores per player — ranked from highest to lowest.
--     Rohit Sharma, Rashid Khan, Kuldeep Yadav should be near the top.
SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  ip.impact_points,
  cpp.player_cost_coins   AS budget_usd
FROM fantasy_player_impact_points ip
JOIN cricket_player_pool cpp  ON cpp.id = ip.fantasy_player_id
JOIN fantasy_matches fm        ON fm.id = ip.fantasy_match_id
WHERE fm.match_title = 'IND vs AFG — 1st ODI'
ORDER BY ip.impact_points DESC;

-- 8d: Budget tier distribution.
--     With 28 players the tiers will be approx: premium ~5, mid ~9, value ~14.
--     Adjust thresholds in your API if needed.
SELECT
  CASE
    WHEN cpp.player_cost_coins >= 200000 THEN 'premium  ($200K+)'
    WHEN cpp.player_cost_coins >= 120000 THEN 'mid      ($120K–$199K)'
    ELSE                                      'value    (under $120K)'
  END AS tier,
  COUNT(*) AS players,
  MIN(cpp.player_cost_coins) AS min_budget,
  MAX(cpp.player_cost_coins) AS max_budget
FROM fantasy_player_impact_points ip
JOIN cricket_player_pool cpp ON cpp.id = ip.fantasy_player_id
JOIN fantasy_matches fm       ON fm.id = ip.fantasy_match_id
WHERE fm.match_title = 'IND vs AFG — 1st ODI'
GROUP BY tier
ORDER BY min_budget DESC;

-- 8e: Quick sanity check — anyone stuck at $50K (role='unknown')?
--     This should return 0 rows if player_role is set for everyone.
SELECT cpp.player_name, cpp.country, cpp.player_cost_coins
FROM fantasy_player_impact_points ip
JOIN cricket_player_pool cpp ON cpp.id = ip.fantasy_player_id
JOIN fantasy_matches fm       ON fm.id = ip.fantasy_match_id
WHERE fm.match_title = 'IND vs AFG — 1st ODI'
  AND cpp.player_cost_coins = 50000
ORDER BY cpp.country;

-- ============================================================
-- ALL DONE.
-- The match is live. Users can now go to Create Team,
-- pick 8 players (3–5 per side) within the $1M budget.
-- ============================================================
