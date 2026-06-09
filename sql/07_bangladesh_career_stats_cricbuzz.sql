-- ============================================================
-- FILE: sql/07_bangladesh_career_stats_cricbuzz.sql
-- SOURCE: Historical_Data_Cricbuzz_20260608.csv
-- PURPOSE: Insert real Cricbuzz career stats for 15 Bangladesh
--          players into player_career_stats_master.
--          Also adds 7 new players to cricket_player_pool who
--          were not in the original FILE 6 squad insert.
--
-- PLAYERS INCLUDED (15 total):
--   Tanzid Hasan Tamim, Mehidy Hasan Miraz, Litton Das,
--   Soumya Sarkar, Najmul Hossain Shanto, Towhid Hridoy,
--   Mosaddek Hossain, Rishad Hossain, Taskin Ahmed,
--   Mustafizur Rahman, Shoriful Islam, Nahid Rana,
--   Tanvir Islam, Saif Hassan, Nurul Hasan
--
-- NOTE: Shakib Al Hasan, Mahmudullah, Afif Hossain, Jaker Ali
--       were NOT in the Cricbuzz file. Their stats remain as
--       previously inserted (approximate) in FILE 6.
--
-- RUN ORDER:
--   Step 1 — Add new players to cricket_player_pool
--   Step 2 — Upsert career stats for all 15 players
--   Step 3 — Verify
--   Step 4 — Call refresh APIs in browser
--
-- SAFE TO RE-RUN: all writes use ON CONFLICT DO UPDATE.
-- ============================================================


-- ============================================================
-- STEP 1: ADD NEW PLAYERS TO cricket_player_pool
-- These 7 players were not in the FILE 6 insert.
-- Skip for any player already in the pool.
-- ============================================================

INSERT INTO cricket_player_pool (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  ('Mehidy Hasan Miraz', 'BAN', 'AR',   'all-rounder',   5),
  ('Soumya Sarkar',      'BAN', 'BAT',  'batsman',       5),
  ('Mosaddek Hossain',   'BAN', 'AR',   'all-rounder',   5),
  ('Nahid Rana',         'BAN', 'BOWL', 'bowler',        5),
  ('Tanvir Islam',       'BAN', 'BOWL', 'bowler',        5),
  ('Saif Hassan',        'BAN', 'BAT',  'batsman',       5),
  ('Nurul Hasan',        'BAN', 'WK',   'wicket-keeper', 5)
ON CONFLICT DO NOTHING;

-- Verify total BAN player count (should be 15+ after this)
SELECT country, COUNT(*) AS players
FROM cricket_player_pool
WHERE country = 'BAN';


-- ============================================================
-- STEP 2: UPSERT CAREER STATS FOR ALL 15 PLAYERS
-- Real data from Cricbuzz. Replaces approximate data from
-- FILE 6 where applicable (ON CONFLICT DO UPDATE).
--
-- Economy = 99 where player has no bowling data (non-bowlers).
-- ============================================================

INSERT INTO player_career_stats_master (
  player_name, country, player_role, player_pool_source,

  -- Test Batting
  test_bat_matches, test_bat_innings, test_bat_not_outs,
  test_bat_runs, test_bat_highest, test_bat_avg, test_bat_balls_faced,
  test_bat_strike_rate, test_bat_50s, test_bat_100s, test_bat_4s, test_bat_6s,

  -- Test Bowling
  test_bowl_matches, test_bowl_innings, test_bowl_balls,
  test_bowl_runs, test_bowl_wickets, test_bowl_avg,
  test_bowl_economy, test_bowl_strike_rate, test_bowl_5wi, test_bowl_10wi,

  -- ODI Batting
  odi_bat_matches, odi_bat_innings, odi_bat_not_outs,
  odi_bat_runs, odi_bat_highest, odi_bat_avg, odi_bat_balls_faced,
  odi_bat_strike_rate, odi_bat_50s, odi_bat_100s, odi_bat_4s, odi_bat_6s,

  -- ODI Bowling
  odi_bowl_matches, odi_bowl_innings, odi_bowl_balls,
  odi_bowl_runs, odi_bowl_wickets, odi_bowl_avg,
  odi_bowl_economy, odi_bowl_strike_rate, odi_bowl_5wi,

  -- T20 Batting
  t20_bat_matches, t20_bat_innings, t20_bat_not_outs,
  t20_bat_runs, t20_bat_highest, t20_bat_avg, t20_bat_balls_faced,
  t20_bat_strike_rate, t20_bat_50s, t20_bat_100s, t20_bat_4s, t20_bat_6s,

  -- T20 Bowling
  t20_bowl_matches, t20_bowl_innings, t20_bowl_balls,
  t20_bowl_runs, t20_bowl_wickets, t20_bowl_avg,
  t20_bowl_economy, t20_bowl_strike_rate, t20_bowl_5wi,

  data_source, updated_at
)
VALUES

-- ── Tanzid Hasan Tamim (Batsman) ────────────────────────────
(
  'Tanzid Hasan Tamim', 'Bangladesh', 'batter', 'cricket',
  -- Test bat
  1,  2,  0,  30, '26',  15.00,   41,  73.18, 0, 0,  4, 0,
  -- Test bowl
  1,  0,  0,   0,   0,    0.00,  99.00,  0.00, 0, 0,
  -- ODI bat
  33, 33,  1, 812,'107', 25.38,  787, 103.18, 6, 1, 96, 32,
  -- ODI bowl
  33,  0,  0,   0,   0,    0.00,  99.00,  0.00, 0,
  -- T20 bat
  47, 47,  5,1146, '89', 27.29,  910, 125.94,11, 0,102, 52,
  -- T20 bowl
  47,  0,  0,   0,   0,    0.00,  99.00,  0.00, 0,
  'cricbuzz', NOW()
),

-- ── Mehidy Hasan Miraz (All-Rounder) ────────────────────────
(
  'Mehidy Hasan Miraz', 'Bangladesh', 'all_rounder', 'cricket',
  -- Test bat
  58,104, 10,2231,'104', 23.73, 4383,  50.91, 9, 2,257, 25,
  -- Test bowl
  58,102,13668,7051, 219,  32.20,   3.10, 62.41,14, 3,
  -- ODI bat
  120, 89, 12,1827,'112', 23.73, 2409,  75.85, 7, 2,150, 29,
  -- ODI bowl
  120,117, 5911,4651, 129,  36.05,   4.72, 45.82, 0,
  -- T20 bat
  34, 29,  4, 418, '46', 16.72,  358, 116.76, 0, 0, 37, 10,
  -- T20 bowl
  34, 31, 468, 667,  18,  37.06,   8.55, 26.00, 0,
  'cricbuzz', NOW()
),

-- ── Litton Das (Wicket-Keeper) ───────────────────────────────
(
  'Litton Das', 'Bangladesh', 'wicket_keeper', 'cricket',
  -- Test bat
  54, 94,  1,3356,'141', 36.09, 5571,  60.25,20, 6,401, 25,
  -- Test bowl (barely bowled — 12 balls in career)
  54,  1,  12,  13,   0,   0.00,  99.00,  0.00, 0, 0,
  -- ODI bat
  101,100,  7,2783,'176', 29.92, 3250,  85.64,13, 5,286, 49,
  -- ODI bowl
  101,  0,   0,   0,   0,   0.00,  99.00,  0.00, 0,
  -- T20 bat
  122,120,  5,2703, '83', 23.50, 2131, 126.85,16, 0,263, 83,
  -- T20 bowl
  122,  0,   0,   0,   0,   0.00,  99.00,  0.00, 0,
  'cricbuzz', NOW()
),

-- ── Soumya Sarkar (Batsman / part-time bowler) ───────────────
(
  'Soumya Sarkar', 'Bangladesh', 'batter', 'cricket',
  -- Test bat
  16, 30,  0, 831,'149', 27.70, 1442,  57.63, 4, 1,109,  9,
  -- Test bowl
  16, 12, 508, 336,   4,  84.00,   3.97,127.00, 0, 0,
  -- ODI bat
  81, 76,  3,2364,'169', 32.38, 2500,  94.56,14, 3,270, 58,
  -- ODI bowl
  81, 28, 582, 594,  17,  34.94,   6.12, 34.24, 0,
  -- T20 bat
  87, 86,  4,1462, '68', 17.83, 1197, 122.14, 5, 0,145, 55,
  -- T20 bowl
  87, 28, 288, 451,  12,  37.58,   9.40, 24.00, 0,
  'cricbuzz', NOW()
),

-- ── Najmul Hossain Shanto (Batsman) ─────────────────────────
(
  'Najmul Hossain Shanto', 'Bangladesh', 'batter', 'cricket',
  -- Test bat
  41, 77,  2,2530,'163', 33.73, 4688,  53.97, 6, 9,283, 32,
  -- Test bowl (rarely bowls)
  41, 11, 118,  86,   0,   0.00,   4.37,  0.00, 0, 0,
  -- ODI bat
  64, 63,  3,1914,'122', 31.90, 2450,  78.13,11, 4,199, 22,
  -- ODI bowl
  64, 10, 117, 125,   2,  62.50,   6.41, 58.50, 0,
  -- T20 bat
  50, 48,  5, 987, '71', 22.95,  905, 109.07, 4, 0, 89, 20,
  -- T20 bowl (3 innings only)
  50,  3,  18,  26,   0,   0.00,   8.67,  0.00, 0,
  'cricbuzz', NOW()
),

-- ── Towhid Hridoy (Batsman) ──────────────────────────────────
(
  'Towhid Hridoy', 'Bangladesh', 'batter', 'cricket',
  -- Test bat (no Tests played)
  0,  0,  0,   0,  NULL,  0.00,    0,   0.00, 0, 0,  0,  0,
  -- Test bowl
  0,  0,  0,   0,   0,   0.00,  99.00,  0.00, 0, 0,
  -- ODI bat
  50, 45,  6,1459,'100', 37.41, 1829,  79.78,12, 1, 92, 29,
  -- ODI bowl (1 ball bowled — not a bowler)
  50,  0,   0,   0,   0,   0.00,  99.00,  0.00, 0,
  -- T20 bat
  59, 53,  9,1261, '83', 28.66, 1004, 125.60, 6, 0, 81, 48,
  -- T20 bowl (1 ball only)
  59,  1,   2,   5,   0,   0.00,  99.00,  0.00, 0,
  'cricbuzz', NOW()
),

-- ── Mosaddek Hossain (All-Rounder) ───────────────────────────
(
  'Mosaddek Hossain', 'Bangladesh', 'all_rounder', 'cricket',
  -- Test bat
  4,  8,  2, 173, '75', 28.83,  375,  46.14, 1, 0, 13,  4,
  -- Test bowl
  4,  6, 162,  87,   0,   0.00,   3.22,  0.00, 0, 0,
  -- ODI bat
  43, 35, 10, 634, '52', 25.36,  762,  83.21, 3, 0, 58, 13,
  -- ODI bowl
  43, 41,1130, 969,  17,  57.00,   5.15, 66.47, 0,
  -- T20 bat
  33, 31, 10, 389, '48', 18.52,  341, 114.08, 0, 0, 26, 11,
  -- T20 bowl
  33, 26, 331, 398,  18,  22.11,   7.21, 18.39, 1,
  'cricbuzz', NOW()
),

-- ── Rishad Hossain (Bowler) ──────────────────────────────────
(
  'Rishad Hossain', 'Bangladesh', 'bowler', 'cricket',
  -- Test bat (no Tests)
  0,  0,  0,   0,  NULL,  0.00,    0,   0.00, 0, 0,  0,  0,
  -- Test bowl
  0,  0,  0,   0,   0,   0.00,  99.00,  0.00, 0, 0,
  -- ODI bat
  19, 15,  3, 182, '48', 15.17,  140, 130.00, 0, 0, 12, 13,
  -- ODI bowl
  19, 19, 934, 826,  29,  28.48,   5.31, 32.21, 1,
  -- T20 bat
  57, 34,  8, 218, '53',  8.38,  171, 127.49, 1, 0, 15, 15,
  -- T20 bowl
  57, 55,1140,1552,  73,  21.26,   8.17, 15.62, 0,
  'cricbuzz', NOW()
),

-- ── Taskin Ahmed (Bowler) ────────────────────────────────────
(
  'Taskin Ahmed', 'Bangladesh', 'bowler', 'cricket',
  -- Test bat
  19, 33,  5, 313, '75', 11.18,  615,  50.90, 1, 0, 33,  5,
  -- Test bowl
  19, 36,3482,2133,  55,  38.78,   3.68, 63.31, 1, 0,
  -- ODI bat
  88, 49, 14, 244, '21',  6.97,  434,  56.23, 0, 0, 16,  8,
  -- ODI bowl
  88, 86,4170,3727, 126,  29.58,   5.36, 33.10, 2,
  -- T20 bat
  86, 38, 16, 213, '31',  9.68,  216,  98.62, 0, 0, 19,  7,
  -- T20 bowl
  86, 84,1820,2354, 106,  22.21,   7.76, 17.17, 0,
  'cricbuzz', NOW()
),

-- ── Mustafizur Rahman (Bowler) ───────────────────────────────
(
  'Mustafizur Rahman', 'Bangladesh', 'bowler', 'cricket',
  -- Test bat
  15, 22,  7,  66, '16',  4.40,  162,  40.75, 0, 0,  3,  5,
  -- Test bowl
  15, 25,2145,1139,  31,  36.74,   3.19, 69.19, 0, 0,
  -- ODI bat
  120, 61, 37, 179, '20',  7.46,  359,  49.87, 0, 0, 18,  1,
  -- ODI bowl
  120,118,5745,4950, 187,  26.47,   5.17, 30.72, 6,
  -- T20 bat
  126, 37, 17, 112, '15',  5.60,  144,  77.78, 0, 0,  6,  5,
  -- T20 bowl
  126,125,2730,3313, 158,  20.97,   7.28, 17.28, 2,
  'cricbuzz', NOW()
),

-- ── Shoriful Islam (All-Rounder / Bowler) ────────────────────
(
  'Shoriful Islam', 'Bangladesh', 'all_rounder', 'cricket',
  -- Test bat
  13, 21,  3, 168, '26',  9.33,  245,  68.58, 0, 0, 20,  4,
  -- Test bowl
  13, 23,1884, 973,  27,  36.04,   3.10, 69.78, 0, 0,
  -- ODI bat
  43, 25, 10, 102, '16',  6.80,  123,  82.93, 0, 0,  8,  4,
  -- ODI bowl
  43, 43,2004,1788,  63,  28.38,   5.35, 31.81, 0,
  -- T20 bat
  61, 25,  9,  91, '16',  5.69,   79, 115.19, 0, 0,  9,  4,
  -- T20 bowl
  61, 59,1202,1623,  67,  24.22,   8.10, 17.94, 0,
  'cricbuzz', NOW()
),

-- ── Nahid Rana (Bowler) ──────────────────────────────────────
(
  'Nahid Rana', 'Bangladesh', 'bowler', 'cricket',
  -- Test bat
  12, 19, 11,  21, '11',  2.63,  120,  17.50, 0, 0,  3,  0,
  -- Test bowl
  12, 21,1833,1400,  38,  36.84,   4.58, 48.24, 2, 0,
  -- ODI bat
  11,  5,  5,   9,  '4',  0.00,   24,  37.50, 0, 0,  1,  0,
  -- ODI bowl
  11, 11, 606, 504,  21,  24.00,   4.99, 28.86, 2,
  -- T20 bat
  1,  0,  0,   0,  NULL,  0.00,    0,   0.00, 0, 0,  0,  0,
  -- T20 bowl (only 1 match, 24 balls)
  1,  1,  24,  50,   2,  25.00,  12.50, 12.00, 0,
  'cricbuzz', NOW()
),

-- ── Tanvir Islam (Bowler) ────────────────────────────────────
(
  'Tanvir Islam', 'Bangladesh', 'bowler', 'cricket',
  -- Test bat (no Tests)
  0,  0,  0,   0,  NULL,  0.00,    0,   0.00, 0, 0,  0,  0,
  -- Test bowl
  0,  0,  0,   0,   0,   0.00,  99.00,  0.00, 0, 0,
  -- ODI bat
  10,  8,  1,  42, '11',  6.00,   60,  70.00, 0, 0,  6,  2,
  -- ODI bowl
  10, 10, 588, 441,  16,  27.56,   4.50, 36.75, 1,
  -- T20 bat
  6,  3,  2,  12,  '8', 12.00,   16,  75.00, 0, 0,  1,  0,
  -- T20 bowl
  6,  6, 102, 136,   4,  34.00,   8.00, 25.50, 0,
  'cricbuzz', NOW()
),

-- ── Saif Hassan (Batsman) ────────────────────────────────────
(
  'Saif Hassan', 'Bangladesh', 'batter', 'cricket',
  -- Test bat
  6, 11,  0, 159, '43', 14.45,  307,  51.80, 0, 0, 27,  2,
  -- Test bowl (1 wicket in career)
  6,  2,  36,  27,   1,  27.00,   4.50, 36.00, 0, 0,
  -- ODI bat
  12, 12,  0, 297, '80', 24.75,  369,  80.49, 2, 0, 31, 12,
  -- ODI bowl
  12,  5,  91,  64,   4,  16.00,   4.22, 22.75, 0,
  -- T20 bat
  23, 22,  3, 476, '69', 25.05,  396, 120.21, 4, 0, 23, 33,
  -- T20 bowl
  23, 10, 103, 122,   2,  61.00,   7.11, 51.50, 0,
  'cricbuzz', NOW()
),

-- ── Nurul Hasan (Wicket-Keeper) ──────────────────────────────
(
  'Nurul Hasan', 'Bangladesh', 'wicket_keeper', 'cricket',
  -- Test bat
  11, 21,  1, 440, '64', 22.00,  694,  63.41, 3, 0, 57,  5,
  -- Test bowl (no bowling)
  11,  0,   0,   0,   0,   0.00,  99.00,  0.00, 0, 0,
  -- ODI bat
  13, 11,  4, 237, '45', 33.86,  256,  92.58, 0, 0, 20,  5,
  -- ODI bowl
  13,  0,   0,   0,   0,   0.00,  99.00,  0.00, 0,
  -- T20 bat
  55, 50, 19, 570, '42', 18.39,  477, 119.50, 0, 0, 31, 25,
  -- T20 bowl (no bowling)
  55,  0,   0,   0,   0,   0.00,  99.00,  0.00, 0,
  'cricbuzz', NOW()
)

ON CONFLICT (player_name, country)
DO UPDATE SET
  player_role            = EXCLUDED.player_role,
  -- Test bat
  test_bat_matches       = EXCLUDED.test_bat_matches,
  test_bat_innings       = EXCLUDED.test_bat_innings,
  test_bat_not_outs      = EXCLUDED.test_bat_not_outs,
  test_bat_runs          = EXCLUDED.test_bat_runs,
  test_bat_highest       = EXCLUDED.test_bat_highest,
  test_bat_avg           = EXCLUDED.test_bat_avg,
  test_bat_balls_faced   = EXCLUDED.test_bat_balls_faced,
  test_bat_strike_rate   = EXCLUDED.test_bat_strike_rate,
  test_bat_50s           = EXCLUDED.test_bat_50s,
  test_bat_100s          = EXCLUDED.test_bat_100s,
  test_bat_4s            = EXCLUDED.test_bat_4s,
  test_bat_6s            = EXCLUDED.test_bat_6s,
  -- Test bowl
  test_bowl_matches      = EXCLUDED.test_bowl_matches,
  test_bowl_innings      = EXCLUDED.test_bowl_innings,
  test_bowl_balls        = EXCLUDED.test_bowl_balls,
  test_bowl_runs         = EXCLUDED.test_bowl_runs,
  test_bowl_wickets      = EXCLUDED.test_bowl_wickets,
  test_bowl_avg          = EXCLUDED.test_bowl_avg,
  test_bowl_economy      = EXCLUDED.test_bowl_economy,
  test_bowl_strike_rate  = EXCLUDED.test_bowl_strike_rate,
  test_bowl_5wi          = EXCLUDED.test_bowl_5wi,
  test_bowl_10wi         = EXCLUDED.test_bowl_10wi,
  -- ODI bat
  odi_bat_matches        = EXCLUDED.odi_bat_matches,
  odi_bat_innings        = EXCLUDED.odi_bat_innings,
  odi_bat_not_outs       = EXCLUDED.odi_bat_not_outs,
  odi_bat_runs           = EXCLUDED.odi_bat_runs,
  odi_bat_highest        = EXCLUDED.odi_bat_highest,
  odi_bat_avg            = EXCLUDED.odi_bat_avg,
  odi_bat_balls_faced    = EXCLUDED.odi_bat_balls_faced,
  odi_bat_strike_rate    = EXCLUDED.odi_bat_strike_rate,
  odi_bat_50s            = EXCLUDED.odi_bat_50s,
  odi_bat_100s           = EXCLUDED.odi_bat_100s,
  odi_bat_4s             = EXCLUDED.odi_bat_4s,
  odi_bat_6s             = EXCLUDED.odi_bat_6s,
  -- ODI bowl
  odi_bowl_matches       = EXCLUDED.odi_bowl_matches,
  odi_bowl_innings       = EXCLUDED.odi_bowl_innings,
  odi_bowl_balls         = EXCLUDED.odi_bowl_balls,
  odi_bowl_runs          = EXCLUDED.odi_bowl_runs,
  odi_bowl_wickets       = EXCLUDED.odi_bowl_wickets,
  odi_bowl_avg           = EXCLUDED.odi_bowl_avg,
  odi_bowl_economy       = EXCLUDED.odi_bowl_economy,
  odi_bowl_strike_rate   = EXCLUDED.odi_bowl_strike_rate,
  odi_bowl_5wi           = EXCLUDED.odi_bowl_5wi,
  -- T20 bat
  t20_bat_matches        = EXCLUDED.t20_bat_matches,
  t20_bat_innings        = EXCLUDED.t20_bat_innings,
  t20_bat_not_outs       = EXCLUDED.t20_bat_not_outs,
  t20_bat_runs           = EXCLUDED.t20_bat_runs,
  t20_bat_highest        = EXCLUDED.t20_bat_highest,
  t20_bat_avg            = EXCLUDED.t20_bat_avg,
  t20_bat_balls_faced    = EXCLUDED.t20_bat_balls_faced,
  t20_bat_strike_rate    = EXCLUDED.t20_bat_strike_rate,
  t20_bat_50s            = EXCLUDED.t20_bat_50s,
  t20_bat_100s           = EXCLUDED.t20_bat_100s,
  t20_bat_4s             = EXCLUDED.t20_bat_4s,
  t20_bat_6s             = EXCLUDED.t20_bat_6s,
  -- T20 bowl
  t20_bowl_matches       = EXCLUDED.t20_bowl_matches,
  t20_bowl_innings       = EXCLUDED.t20_bowl_innings,
  t20_bowl_balls         = EXCLUDED.t20_bowl_balls,
  t20_bowl_runs          = EXCLUDED.t20_bowl_runs,
  t20_bowl_wickets       = EXCLUDED.t20_bowl_wickets,
  t20_bowl_avg           = EXCLUDED.t20_bowl_avg,
  t20_bowl_economy       = EXCLUDED.t20_bowl_economy,
  t20_bowl_strike_rate   = EXCLUDED.t20_bowl_strike_rate,
  t20_bowl_5wi           = EXCLUDED.t20_bowl_5wi,
  data_source            = EXCLUDED.data_source,
  updated_at             = NOW();


-- ============================================================
-- STEP 3: VERIFY
-- ============================================================

-- All 15 players should appear with data_source = 'cricbuzz'
SELECT
  player_name,
  player_role,
  t20_bat_runs,
  t20_bat_strike_rate,
  t20_bowl_wickets,
  t20_bowl_economy,
  data_source,
  updated_at
FROM player_career_stats_master
WHERE country = 'Bangladesh'
ORDER BY player_role, t20_bat_runs DESC;

-- Quick count
SELECT COUNT(*) AS bangladesh_players
FROM player_career_stats_master
WHERE country = 'Bangladesh';


-- ============================================================
-- STEP 4: CALL REFRESH APIS IN BROWSER (in this order)
--
-- 4a. Recompute global percentile scores:
--     https://www.playmtgames.com/api/refresh-player-format-scores
--     Wait for: { "success": true }
--
-- 4b. Recompute match budgets for the BAN vs AUS match
--     (replace 999 with your actual match ID from FILE 6):
--     https://www.playmtgames.com/api/refresh-match-player-budgets?fantasy_match_id=999
--     Wait for: { "success": true, "rows_upserted": 24 }
--
-- After Step 4, open Create Team and confirm Bangladesh
-- players now show proper tiered prices based on real stats.
-- ============================================================
