-- ============================================================
-- FILE: sql/08_aus_ban_series_launch.sql
-- PURPOSE: Launch AUS vs BAN series — Test, ODI, T20
--          22 players total (8 BAN + 14 AUS)
-- Last updated: 2026-06-08
--
-- RUN ORDER:
--   Step 1 — Delete existing AUS/BAN career stats
--   Step 2 — Insert/update players in cricket_player_pool
--   Step 3 — Insert career stats (all 3 formats, all 22 players)
--   Step 4 — Create 3 fantasy matches + link all players
--   Step 5 — Verify player counts per match
--   Step 6 — Call refresh APIs (browser URLs)
-- ============================================================


-- ============================================================
-- STEP 1: DELETE EXISTING AUS/BAN CAREER STATS
-- Wipes stale data so only the Cricbuzz stats below are used.
-- ============================================================

DELETE FROM player_career_stats_master
WHERE country IN ('AUS', 'BAN');

-- Confirm 0 rows remain
SELECT COUNT(*) AS remaining_rows
FROM player_career_stats_master
WHERE country IN ('AUS', 'BAN');


-- ============================================================
-- STEP 2: INSERT PLAYERS INTO cricket_player_pool
-- 8 Bangladesh + 14 Australia = 22 players
-- Columns: player_type (BAT/WK/AR/BOWL), player_tag (display label)
-- Litton Das, Josh Inglis, Alex Carey → WK
-- player_cost_coins = 5 placeholder (budget system overrides this)
-- ============================================================

INSERT INTO cricket_player_pool
  (player_name, country, player_type, player_tag, player_cost_coins, is_active)
VALUES
  -- Bangladesh
  ('Tanzid Hasan Tamim',    'BAN', 'BAT',  'batsman',        5, TRUE),
  ('Mehidy Hasan Miraz',    'BAN', 'AR',   'all-rounder',    5, TRUE),
  ('Litton Das',            'BAN', 'WK',   'wicket-keeper',  5, TRUE),
  ('Soumya Sarkar',         'BAN', 'BAT',  'batsman',        5, TRUE),
  ('Najmul Hossain Shanto', 'BAN', 'BAT',  'batsman',        5, TRUE),
  ('Towhid Hridoy',         'BAN', 'BAT',  'batsman',        5, TRUE),
  ('Mosaddek Hossain',      'BAN', 'AR',   'all-rounder',    5, TRUE),
  ('Rishad Hossain',        'BAN', 'BOWL', 'bowler',         5, TRUE),
  -- Australia
  ('Josh Inglis',           'AUS', 'WK',   'wicket-keeper',  5, TRUE),
  ('Alex Carey',            'AUS', 'WK',   'wicket-keeper',  5, TRUE),
  ('Marnus Labuschagne',    'AUS', 'BAT',  'batsman',        5, TRUE),
  ('Matt Renshaw',          'AUS', 'BAT',  'batsman',        5, TRUE),
  ('Cameron Green',         'AUS', 'AR',   'all-rounder',    5, TRUE),
  ('Cooper Connolly',       'AUS', 'AR',   'all-rounder',    5, TRUE),
  ('Matthew Kuhnemann',     'AUS', 'BOWL', 'bowler',         5, TRUE),
  ('Xavier Bartlett',       'AUS', 'BOWL', 'bowler',         5, TRUE),
  ('Nathan Ellis',          'AUS', 'BOWL', 'bowler',         5, TRUE),
  ('Adam Zampa',            'AUS', 'BOWL', 'bowler',         5, TRUE),
  ('Matthew Short',         'AUS', 'BAT',  'batsman',        5, TRUE),
  ('Ben Dwarshuis',         'AUS', 'BOWL', 'bowler',         5, TRUE),
  ('Todd Murphy',           'AUS', 'BOWL', 'bowler',         5, TRUE),
  ('Oliver Peake',          'AUS', 'AR',   'all-rounder',    5, TRUE)
ON CONFLICT DO NOTHING;

-- Confirm 22 rows
SELECT player_name, country, player_role
FROM cricket_player_pool
WHERE country IN ('AUS', 'BAN') AND is_active = TRUE
ORDER BY country, player_name;


-- ============================================================
-- STEP 3: INSERT CAREER STATS
-- Source: Cricbuzz historical data 2026-06-08
-- Wide-format: ONE row per player, all 3 formats in columns.
-- Column naming: {format}_{bat|bowl}_{stat}
-- Rules applied:
--   bowl_economy = 99 wherever the raw value is 0
--   bat_highest stored as TEXT (column type in table)
--   Columns not in table (ducks, maidens, 4w) are omitted
-- ============================================================

INSERT INTO player_career_stats_master (
  player_name, country, player_role, player_pool_source,
  -- ODI batting
  odi_bat_matches, odi_bat_innings, odi_bat_not_outs, odi_bat_runs, odi_bat_highest,
  odi_bat_avg, odi_bat_balls_faced, odi_bat_strike_rate, odi_bat_100s, odi_bat_50s,
  odi_bat_4s, odi_bat_6s,
  -- ODI bowling
  odi_bowl_matches, odi_bowl_innings, odi_bowl_balls, odi_bowl_runs,
  odi_bowl_wickets, odi_bowl_avg, odi_bowl_economy, odi_bowl_strike_rate, odi_bowl_5wi,
  -- T20 batting
  t20_bat_matches, t20_bat_innings, t20_bat_not_outs, t20_bat_runs, t20_bat_highest,
  t20_bat_avg, t20_bat_balls_faced, t20_bat_strike_rate, t20_bat_100s, t20_bat_50s,
  t20_bat_4s, t20_bat_6s,
  -- T20 bowling
  t20_bowl_matches, t20_bowl_innings, t20_bowl_balls, t20_bowl_runs,
  t20_bowl_wickets, t20_bowl_avg, t20_bowl_economy, t20_bowl_strike_rate, t20_bowl_5wi,
  -- Test batting
  test_bat_matches, test_bat_innings, test_bat_not_outs, test_bat_runs, test_bat_highest,
  test_bat_avg, test_bat_balls_faced, test_bat_strike_rate, test_bat_100s, test_bat_50s,
  test_bat_4s, test_bat_6s,
  -- Test bowling
  test_bowl_matches, test_bowl_innings, test_bowl_balls, test_bowl_runs,
  test_bowl_wickets, test_bowl_avg, test_bowl_economy, test_bowl_strike_rate,
  test_bowl_5wi, test_bowl_10wi,
  data_source
)
VALUES

-- ── BANGLADESH ──────────────────────────────────────────────
-- Value order per player:
--   identity(4) | odi_bat(12) | odi_bowl(9) | t20_bat(12) | t20_bowl(9) | test_bat(12) | test_bowl(10) | source(1)

-- Tanzid Hasan Tamim
('Tanzid Hasan Tamim','BAN','batter','cricket',
  33,33,1,812,'107', 25.38,787,103.18, 1,6,96,32,
  33,0,0,0, 0,0,99,0,0,
  47,47,5,1146,'89', 27.29,910,125.94, 0,11,102,52,
  47,0,0,0, 0,0,99,0,0,
  1,2,0,30,'26', 15,41,73.18, 0,0,4,0,
  1,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Mehidy Hasan Miraz
('Mehidy Hasan Miraz','BAN','all_rounder','cricket',
  120,89,12,1827,'112', 23.73,2409,75.85, 2,7,150,29,
  120,117,5911,4651, 129,36.05,4.72,45.82,0,
  34,29,4,418,'46', 16.72,358,116.76, 0,0,37,10,
  34,31,468,667, 18,37.06,8.55,26,0,
  58,104,10,2231,'104', 23.73,4383,50.91, 2,9,257,25,
  58,102,13668,7051, 219,32.2,3.1,62.41, 14,0,
  'manual'),

-- Litton Das (wicket_keeper — Cricbuzz lists as Batsman)
('Litton Das','BAN','wicket_keeper','cricket',
  101,100,7,2783,'176', 29.92,3250,85.64, 5,13,286,49,
  101,0,0,0, 0,0,99,0,0,
  122,120,5,2703,'83', 23.5,2131,126.85, 0,16,263,83,
  122,0,0,0, 0,0,99,0,0,
  54,94,1,3356,'141', 36.09,5571,60.25, 6,20,401,25,
  54,1,12,13, 0,0,6.5,0, 0,0,
  'manual'),

-- Soumya Sarkar
('Soumya Sarkar','BAN','batter','cricket',
  81,76,3,2364,'169', 32.38,2500,94.56, 3,14,270,58,
  81,28,582,594, 17,34.94,6.12,34.24,0,
  87,86,4,1462,'68', 17.83,1197,122.14, 0,5,145,55,
  87,28,288,451, 12,37.58,9.4,24,0,
  16,30,0,831,'149', 27.7,1442,57.63, 1,4,109,9,
  16,12,508,336, 4,84,3.97,127, 0,0,
  'manual'),

-- Najmul Hossain Shanto
('Najmul Hossain Shanto','BAN','batter','cricket',
  64,63,3,1914,'122', 31.9,2450,78.13, 4,11,199,22,
  64,10,117,125, 2,62.5,6.41,58.5,0,
  50,48,5,987,'71', 22.95,905,109.07, 0,4,89,20,
  50,3,18,26, 0,0,8.67,0,0,
  41,77,2,2530,'163', 33.73,4688,53.97, 9,6,283,32,
  41,11,118,86, 0,0,4.37,0, 0,0,
  'manual'),

-- Towhid Hridoy (0 Test caps)
('Towhid Hridoy','BAN','batter','cricket',
  50,45,6,1459,'100', 37.41,1829,79.78, 1,12,92,29,
  50,0,0,0, 0,0,99,0,0,
  59,53,9,1261,'83', 28.66,1004,125.6, 0,6,81,48,
  59,1,2,5, 0,0,99,0,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Mosaddek Hossain
('Mosaddek Hossain','BAN','all_rounder','cricket',
  43,35,10,634,'52', 25.36,762,83.21, 0,3,58,13,
  43,41,1130,969, 17,57,5.15,66.47,0,
  33,31,10,389,'48', 18.52,341,114.08, 0,0,26,11,
  33,26,331,398, 18,22.11,7.21,18.39,1,
  4,8,2,173,'75', 28.83,375,46.14, 0,1,13,4,
  4,6,162,87, 0,0,3.22,0, 0,0,
  'manual'),

-- Rishad Hossain (0 Test caps)
('Rishad Hossain','BAN','bowler','cricket',
  19,15,3,182,'48', 15.17,140,130, 0,0,12,13,
  19,19,934,826, 29,28.48,5.31,32.21,1,
  57,34,8,218,'53', 8.38,171,127.49, 0,1,15,15,
  57,55,1140,1552, 73,21.26,8.17,15.62,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- ── AUSTRALIA ───────────────────────────────────────────────

-- Josh Inglis (wicket_keeper — Cricbuzz lists as Batsman)
('Josh Inglis','AUS','wicket_keeper','cricket',
  36,32,3,895,'120', 30.86,887,100.91, 1,6,91,23,
  36,0,0,0, 0,0,99,0,0,
  46,43,7,1000,'110', 27.78,627,159.49, 2,2,104,39,
  46,0,0,0, 0,0,99,0,0,
  5,7,0,184,'102', 26.29,228,80.71, 1,0,18,1,
  5,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Alex Carey (wicket_keeper — Cricbuzz lists as Batsman)
('Alex Carey','AUS','wicket_keeper','cricket',
  88,80,13,2283,'106', 34.07,2533,90.14, 1,13,217,24,
  88,0,0,0, 0,0,99,0,0,
  42,29,5,267,'37', 11.13,243,109.88, 0,0,23,7,
  42,0,0,0, 0,0,99,0,0,
  48,73,8,2333,'156', 35.89,3581,65.15, 3,13,248,17,
  48,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Marnus Labuschagne (1 T20 cap only)
('Marnus Labuschagne','AUS','batter','cricket',
  69,61,4,1895,'124', 33.25,2292,82.68, 2,12,157,10,
  69,18,344,377, 11,34.27,6.58,31.27,0,
  1,1,0,2,'2', 2,4,50, 0,0,0,0,
  1,0,0,0, 0,0,99,0,0,
  63,114,9,4694,'215', 44.7,8987,52.24, 11,25,524,15,
  63,50,1316,834, 14,59.57,3.8,94, 0,0,
  'manual'),

-- Matt Renshaw
('Matt Renshaw','AUS','batter','cricket',
  6,6,1,215,'61', 43,231,93.08, 0,2,12,3,
  6,3,60,47, 1,47,4.7,60,0,
  6,5,0,120,'65', 24,99,121.22, 0,1,8,2,
  6,0,0,0, 0,0,99,0,0,
  14,24,2,645,'184', 29.32,1524,42.33, 1,3,78,3,
  14,3,30,20, 0,0,4,0, 0,0,
  'manual'),

-- Cameron Green
('Cameron Green','AUS','all_rounder','cricket',
  34,30,8,842,'118', 38.27,983,85.66, 1,3,65,22,
  34,27,832,811, 20,40.55,5.85,41.6,1,
  28,26,4,638,'62', 29,420,151.91, 0,6,49,36,
  28,16,231,350, 14,25,9.09,16.5,0,
  37,59,6,1736,'174', 32.75,3512,49.44, 2,7,196,14,
  37,53,2561,1519, 39,38.95,3.56,65.67, 1,0,
  'manual'),

-- Cooper Connolly
('Cooper Connolly','AUS','all_rounder','cricket',
  9,6,1,97,'61', 19.4,140,69.29, 0,1,7,1,
  9,5,156,137, 6,22.83,5.27,26,1,
  11,7,1,28,'13', 4.67,30,93.34, 0,0,1,2,
  11,9,150,231, 3,77,9.24,50,0,
  1,1,0,4,'4', 4,6,66.67, 0,0,1,0,
  1,2,30,21, 0,0,4.2,0, 0,0,
  'manual'),

-- Matthew Kuhnemann
('Matthew Kuhnemann','AUS','bowler','cricket',
  8,5,1,54,'24', 13.5,95,56.85, 0,0,5,0,
  8,8,432,325, 13,25,4.51,33.23,0,
  8,3,0,7,'5', 2.33,13,53.85, 0,0,0,0,
  8,8,162,220, 3,73.33,8.15,54,0,
  5,6,2,18,'6', 4.5,67,26.87, 0,0,2,0,
  5,9,1026,555, 25,22.2,3.25,41.04, 2,0,
  'manual'),

-- Xavier Bartlett (0 Test caps)
('Xavier Bartlett','AUS','bowler','cricket',
  5,2,0,11,'8', 5.5,15,73.34, 0,0,0,1,
  5,5,247,167, 15,11.13,4.06,16.47,0,
  21,11,4,73,'34', 10.43,70,104.29, 0,0,7,3,
  21,20,399,529, 24,22.04,7.95,16.63,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Nathan Ellis (0 Test caps)
('Nathan Ellis','AUS','bowler','cricket',
  20,15,4,120,'18', 10.91,140,85.72, 0,0,8,6,
  20,20,987,897, 25,35.88,5.45,39.48,0,
  36,11,6,39,'12', 7.8,61,63.94, 0,0,2,1,
  36,36,753,978, 55,17.78,7.79,13.69,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Adam Zampa (0 Test caps)
('Adam Zampa','AUS','bowler','cricket',
  118,61,22,388,'36', 9.95,597,65, 0,0,32,2,
  118,118,6159,5673, 197,28.8,5.53,31.26,1,
  115,30,13,80,'13', 4.71,98,81.64, 0,0,7,0,
  115,112,2467,3034, 147,20.64,7.38,16.78,1,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Matthew Short (0 Test caps)
('Matthew Short','AUS','batter','cricket',
  21,19,0,462,'74', 24.32,523,88.34, 0,4,46,11,
  21,18,444,393, 6,65.5,5.31,74,0,
  24,22,2,416,'66', 20.8,277,150.19, 0,1,40,20,
  24,10,108,206, 9,22.89,11.44,12,1,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Ben Dwarshuis (0 Test caps)
('Ben Dwarshuis','AUS','bowler','cricket',
  6,3,0,61,'33', 20.33,92,66.31, 0,0,4,2,
  6,6,294,270, 11,24.55,5.51,26.73,0,
  15,11,3,63,'17', 7.88,79,79.75, 0,0,2,1,
  15,15,342,536, 22,24.36,9.4,15.55,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
  'manual'),

-- Todd Murphy (Test only — 0 ODI/T20 caps)
('Todd Murphy','AUS','bowler','cricket',
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0,0,
  7,10,1,122,'41', 13.56,205,59.52, 0,0,15,3,
  7,12,1157,619, 22,28.14,3.21,52.59, 1,0,
  'manual'),

-- Oliver Peake (ODI only — 0 Test/T20 caps)
('Oliver Peake','AUS','all_rounder','cricket',
  3,3,0,45,'31', 15,61,73.78, 0,0,3,2,
  3,0,0,0, 0,0,99,0,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0,0,
  0,0,0,0,'0', 0,0,0, 0,0,0,0,
  0,0,0,0, 0,0,99,0, 0,0,
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

-- Confirm 22 rows (one per player)
SELECT country, COUNT(*) AS rows_inserted
FROM player_career_stats_master
WHERE country IN ('AUS', 'BAN')
GROUP BY country
ORDER BY country;


-- ============================================================
-- STEP 4: CREATE 3 FANTASY MATCHES + LINK ALL 22 PLAYERS
-- One CTE block does everything atomically.
-- All 22 active AUS/BAN players are added to every match.
-- ============================================================

WITH test_match AS (
  INSERT INTO fantasy_matches
    (match_title, team_1, team_2, status, budget_coins, match_format)
  VALUES ('AUS vs BAN — Test', 'AUS', 'BAN', 'open', 1000000, 'test')
  RETURNING id
),
odi_match AS (
  INSERT INTO fantasy_matches
    (match_title, team_1, team_2, status, budget_coins, match_format)
  VALUES ('AUS vs BAN — ODI', 'AUS', 'BAN', 'open', 1000000, 'odi')
  RETURNING id
),
t20_match AS (
  INSERT INTO fantasy_matches
    (match_title, team_1, team_2, status, budget_coins, match_format)
  VALUES ('AUS vs BAN — T20I', 'AUS', 'BAN', 'open', 1000000, 't20')
  RETURNING id
),
all_matches AS (
  SELECT id AS match_id FROM test_match
  UNION ALL SELECT id FROM odi_match
  UNION ALL SELECT id FROM t20_match
),
all_players AS (
  SELECT id AS player_id
  FROM cricket_player_pool
  WHERE country IN ('AUS', 'BAN') AND is_active = TRUE
)
INSERT INTO fantasy_match_players (fantasy_match_id, player_id, player_source)
SELECT am.match_id, ap.player_id, 'cricket'
FROM all_matches am
CROSS JOIN all_players ap
ON CONFLICT DO NOTHING;


-- ============================================================
-- STEP 5: VERIFY
-- Expect 3 rows, each with player_count = 22
-- ============================================================

SELECT
  fm.id            AS match_id,
  fm.match_title,
  fm.match_format,
  COUNT(fmp.player_id) AS player_count
FROM fantasy_matches fm
JOIN fantasy_match_players fmp ON fmp.fantasy_match_id = fm.id
WHERE fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
  AND fm.status = 'open'
GROUP BY fm.id, fm.match_title, fm.match_format
ORDER BY fm.id;

-- Also confirm tier distribution per match after refresh (run after Step 6)
SELECT
  fm.match_title,
  mpb.budget_tier,
  COUNT(*) AS players
FROM match_player_budgets mpb
JOIN fantasy_matches fm ON fm.id = mpb.fantasy_match_id
WHERE fm.team_1 IN ('AUS','BAN') AND fm.team_2 IN ('AUS','BAN')
GROUP BY fm.match_title, mpb.budget_tier
ORDER BY fm.match_title, mpb.budget_tier;


-- ============================================================
-- STEP 6: REFRESH BUDGETS (open in browser, in this order)
--
-- 1. Recompute global percentile scores:
--    https://www.playmtgames.com/api/refresh-player-format-scores
--    Wait for: { "success": true, "rows_inserted": N }
--
-- 2. Recompute match-level tier prices for all open matches:
--    https://www.playmtgames.com/api/refresh-match-player-budgets
--    Wait for: { "success": true, "rows_upserted": 66, ... }
--
-- NOTE: 22 players per match (not the usual 24) means the
-- value tier will have 10 players instead of 12. Premium (4)
-- and mid (8) tiers are unchanged. Min team cost will still
-- be well under $1M.
-- ============================================================
