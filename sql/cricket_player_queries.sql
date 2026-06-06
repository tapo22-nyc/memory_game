-- ============================================================
-- MT Games — Cricket Player & History Diagnostic Queries
-- ============================================================


-- ============================================================
-- SECTION 1: PLAYER POOL — ROLES & TYPES
-- ============================================================

-- All players in cricket_player_pool with their type/role
SELECT
  id,
  player_name,
  country,
  player_type,
  player_tag,
  player_cost_coins,
  is_active
FROM cricket_player_pool
ORDER BY country, player_type, player_name;


-- Count by country and player type
SELECT
  country,
  player_type,
  COUNT(*) AS player_count
FROM cricket_player_pool
WHERE is_active = TRUE
GROUP BY country, player_type
ORDER BY country, player_type;


-- Players linked to each fantasy match (with type)
SELECT
  fm.id            AS fantasy_match_id,
  fm.match_title,
  fm.match_format,
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  cpp.player_tag,
  cpp.player_cost_coins
FROM fantasy_match_players fmp
JOIN cricket_player_pool cpp ON cpp.id = fmp.player_id
JOIN fantasy_matches fm      ON fm.id  = fmp.fantasy_match_id
WHERE fmp.player_source = 'cricket'
ORDER BY fm.id, cpp.country, cpp.player_type, cpp.player_name;


-- ============================================================
-- SECTION 2: CRICSHEET MAPPING STATUS
-- ============================================================

-- Full mapping status for all international players
SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  cpm.cricsheet_player_id,
  cpm.cricapi_player_id,
  cpm.mapping_status
FROM cricket_player_pool cpp
LEFT JOIN cricsheet_player_mapping cpm
  ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
 AND cpm.country IN (cpp.country, 'England', 'New Zealand', 'Sri Lanka', 'West Indies')
WHERE cpp.is_active = TRUE
ORDER BY cpp.country, cpm.mapping_status, cpp.player_name;


-- Players still not mapped (no Cricsheet ID yet)
SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type
FROM cricket_player_pool cpp
LEFT JOIN cricsheet_player_mapping cpm
  ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
WHERE cpp.is_active = TRUE
  AND (cpm.cricsheet_player_id IS NULL OR cpm.mapping_status != 'mapped')
ORDER BY cpp.country, cpp.player_name;


-- ============================================================
-- SECTION 3: HISTORICAL DATA AVAILABILITY
-- ============================================================

-- How many history rows each player has, broken down by format
SELECT
  player_name,
  country,
  match_type,
  COUNT(DISTINCT source_match_id) AS matches,
  COUNT(*) AS total_innings_rows
FROM cricapi_player_match_history
WHERE LOWER(country) IN ('england','new zealand','sri lanka','west indies')
   OR player_name IN (
      SELECT player_name FROM cricket_player_pool WHERE is_active = TRUE
   )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- Quick summary: total matches available per player (all formats)
SELECT
  player_name,
  country,
  COUNT(DISTINCT source_match_id || match_type) AS total_matches,
  COUNT(DISTINCT CASE WHEN match_type = 'test' THEN source_match_id END) AS test_matches,
  COUNT(DISTINCT CASE WHEN match_type = 'odi'  THEN source_match_id END) AS odi_matches,
  COUNT(DISTINCT CASE WHEN match_type = 't20'  THEN source_match_id END) AS t20_matches
FROM cricapi_player_match_history
WHERE player_name IN (
  SELECT player_name FROM cricket_player_pool WHERE is_active = TRUE
)
GROUP BY player_name, country
ORDER BY player_name;


-- ============================================================
-- SECTION 4: PLAYER HISTORY DETAIL — BATTING
-- ============================================================

-- Last 10 batting innings for a specific player
-- Replace 'Shai Hope' with any player name
SELECT
  player_name,
  match_type,
  match_date,
  match_name,
  opponent,
  venue,
  innings_number,
  batting_team,
  runs,
  balls,
  fours,
  sixes,
  strike_rate,
  dismissal_type,
  dismissed_by_bowler,
  is_out
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Shai Hope')
  AND balls > 0
ORDER BY match_date DESC, innings_number ASC
LIMIT 10;


-- ============================================================
-- SECTION 5: PLAYER HISTORY DETAIL — BOWLING
-- ============================================================

-- Last 10 bowling innings for a specific player
-- Replace 'Kyle Jamieson' with any player name
SELECT
  player_name,
  match_type,
  match_date,
  match_name,
  opponent,
  venue,
  innings_number,
  bowling_team,
  overs,
  runs_conceded,
  wickets,
  economy
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Kyle Jamieson')
  AND overs > 0
ORDER BY match_date DESC, innings_number ASC
LIMIT 10;


-- ============================================================
-- SECTION 6: CAREER AVERAGES (from historical data)
-- ============================================================

-- Batting averages per player per format
SELECT
  player_name,
  country,
  match_type,
  COUNT(DISTINCT source_match_id)                             AS matches,
  SUM(runs)                                                   AS total_runs,
  SUM(balls)                                                  AS total_balls,
  ROUND(AVG(NULLIF(strike_rate, 0))::numeric, 1)              AS avg_strike_rate,
  ROUND(
    SUM(runs)::numeric / NULLIF(SUM(CASE WHEN is_out THEN 1 ELSE 0 END), 0),
    2
  )                                                           AS batting_avg,
  SUM(fours)                                                  AS total_fours,
  SUM(sixes)                                                  AS total_sixes,
  MAX(runs)                                                   AS highest_score
FROM cricapi_player_match_history
WHERE balls > 0
  AND player_name IN (
    SELECT player_name FROM cricket_player_pool WHERE is_active = TRUE
  )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- Bowling averages per player per format
SELECT
  player_name,
  country,
  match_type,
  COUNT(DISTINCT source_match_id)                             AS matches,
  SUM(wickets)                                                AS total_wickets,
  SUM(runs_conceded)                                          AS total_runs_conceded,
  ROUND(AVG(NULLIF(economy, 0))::numeric, 2)                  AS avg_economy,
  ROUND(
    SUM(runs_conceded)::numeric / NULLIF(SUM(wickets), 0),
    2
  )                                                           AS bowling_avg,
  MAX(wickets)                                                AS best_innings_wickets
FROM cricapi_player_match_history
WHERE overs > 0
  AND player_name IN (
    SELECT player_name FROM cricket_player_pool WHERE is_active = TRUE
  )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- ============================================================
-- SECTION 7: FULL PLAYER PROFILE — one player at a glance
-- ============================================================

-- Replace 'Kane Williamson' with any player name
SELECT
  match_type,
  match_date,
  match_name,
  opponent,
  innings_number,
  runs,
  balls,
  strike_rate,
  dismissal_type,
  overs,
  runs_conceded,
  wickets,
  economy
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Kane Williamson')
ORDER BY match_date DESC, innings_number ASC
LIMIT 20;
