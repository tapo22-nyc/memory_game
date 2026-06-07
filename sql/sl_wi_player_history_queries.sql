-- ============================================================
-- FILE: sl_wi_player_history_queries.sql
-- PURPOSE: Inspect historical data for Sri Lanka (SL) and
--          West Indies (WI) players, and manually insert or
--          correct match records when data is missing.
--
-- TABLES USED:
--   cricket_player_pool          — master list of SL/WI players
--   cricapi_player_match_history — one row per player per innings
--   cricapi_player_career_stats  — aggregated career stats (JSON)
--   cricsheet_player_mapping     — player ID mappings
--
-- HOW TO USE:
--   Open Neon SQL Editor, copy the section you need, and Run.
--   Each section is self-contained and safe to run on its own.
-- ============================================================


-- ============================================================
-- SECTION 1: WHICH SL/WI PLAYERS DO WE HAVE IN OUR POOL?
-- Shows every player we registered, their role, and cost.
-- Run this first to confirm names before using in other queries.
-- ============================================================

SELECT
  id             AS pool_id,
  player_name,
  country,
  player_type,   -- BAT, BOWL, WK, AR
  player_tag,
  player_cost_coins,
  is_active
FROM cricket_player_pool
WHERE country IN ('SL', 'WI')
ORDER BY country, player_type, player_name;


-- ============================================================
-- SECTION 2: ARE THEY MAPPED TO CRICSHEET / CRICAPI IDs?
-- If mapping_status is not 'mapped', historical data cannot
-- be synced automatically for that player.
-- ============================================================

SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  cpm.cricsheet_player_id,
  cpm.cricapi_player_id,
  cpm.mapping_status,
  CASE
    WHEN cpm.cricsheet_player_id IS NOT NULL THEN 'YES'
    ELSE 'NO — needs manual mapping'
  END AS has_cricsheet_id
FROM cricket_player_pool cpp
LEFT JOIN cricsheet_player_mapping cpm
       ON LOWER(cpm.player_name) = LOWER(cpp.player_name)
WHERE cpp.country IN ('SL', 'WI')
  AND cpp.is_active = TRUE
ORDER BY cpp.country, has_cricsheet_id, cpp.player_name;


-- ============================================================
-- SECTION 3: HOW MANY MATCHES OF HISTORY DO WE HAVE?
-- Shows match counts per player broken down by format (Test,
-- ODI, T20). A zero means we have no data for that format.
-- ============================================================

SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  COUNT(DISTINCT CASE WHEN LOWER(h.match_type) = 'test' THEN h.source_match_id END) AS test_matches,
  COUNT(DISTINCT CASE WHEN LOWER(h.match_type) = 'odi'  THEN h.source_match_id END) AS odi_matches,
  COUNT(DISTINCT CASE WHEN LOWER(h.match_type) IN ('t20','t20i') THEN h.source_match_id END) AS t20_matches,
  COUNT(DISTINCT h.source_match_id) AS total_matches
FROM cricket_player_pool cpp
LEFT JOIN cricapi_player_match_history h
       ON LOWER(h.player_name) = LOWER(cpp.player_name)
WHERE cpp.country IN ('SL', 'WI')
  AND cpp.is_active = TRUE
GROUP BY cpp.player_name, cpp.country, cpp.player_type
ORDER BY cpp.country, total_matches DESC, cpp.player_name;


-- ============================================================
-- SECTION 4: CAREER STATS SUMMARY (from cricapi_player_career_stats)
-- These are aggregated lifetime stats stored as JSON columns.
-- batting_odi / batting_test / batting_t20 each contain a JSON
-- object with keys like: inns, runs, avg, sr, 50s, 100s, etc.
-- bowling_* columns contain: inns, wkts, avg, econ, 5wi, etc.
-- ============================================================

SELECT
  player_name,
  country,
  batting_odi    AS batting_career_odi,
  batting_test   AS batting_career_test,
  batting_t20    AS batting_career_t20,
  bowling_odi    AS bowling_career_odi,
  bowling_test   AS bowling_career_test,
  bowling_t20    AS bowling_career_t20,
  updated_at
FROM cricapi_player_career_stats
WHERE LOWER(country) IN ('sri lanka', 'west indies', 'sl', 'wi')
   OR player_name IN (
        SELECT player_name FROM cricket_player_pool
        WHERE country IN ('SL', 'WI') AND is_active = TRUE
      )
ORDER BY country, player_name;


-- ============================================================
-- SECTION 5: LAST 5 GAMES — ODI (all SL + WI players)
-- Each row = one innings of one player in one match.
-- A batsman who did not bowl will have overs = 0 (normal).
-- ============================================================

SELECT
  player_name,
  country,
  match_date,
  match_name,
  opponent,
  venue,
  innings_number,
  -- Batting
  runs,
  balls,
  fours,
  sixes,
  ROUND(strike_rate::numeric, 1)  AS strike_rate,
  dismissal_type,
  is_out,
  -- Bowling
  overs,
  runs_conceded,
  wickets,
  ROUND(economy::numeric, 2)      AS economy
FROM cricapi_player_match_history
WHERE LOWER(match_type) = 'odi'
  AND player_name IN (
        SELECT player_name FROM cricket_player_pool
        WHERE country IN ('SL', 'WI') AND is_active = TRUE
      )
ORDER BY player_name, match_date DESC, innings_number ASC
LIMIT 200;  -- adjust limit if you have more players


-- ============================================================
-- SECTION 6: LAST 5 GAMES — T20 (all SL + WI players)
-- ============================================================

SELECT
  player_name,
  country,
  match_date,
  match_name,
  opponent,
  venue,
  innings_number,
  runs,
  balls,
  fours,
  sixes,
  ROUND(strike_rate::numeric, 1)  AS strike_rate,
  dismissal_type,
  is_out,
  overs,
  runs_conceded,
  wickets,
  ROUND(economy::numeric, 2)      AS economy
FROM cricapi_player_match_history
WHERE LOWER(match_type) IN ('t20', 't20i')
  AND player_name IN (
        SELECT player_name FROM cricket_player_pool
        WHERE country IN ('SL', 'WI') AND is_active = TRUE
      )
ORDER BY player_name, match_date DESC, innings_number ASC
LIMIT 200;


-- ============================================================
-- SECTION 7: LAST 5 GAMES — TEST (all SL + WI players)
-- ============================================================

SELECT
  player_name,
  country,
  match_date,
  match_name,
  opponent,
  venue,
  innings_number,
  runs,
  balls,
  fours,
  sixes,
  ROUND(strike_rate::numeric, 1)  AS strike_rate,
  dismissal_type,
  is_out,
  overs,
  runs_conceded,
  wickets,
  ROUND(economy::numeric, 2)      AS economy
FROM cricapi_player_match_history
WHERE LOWER(match_type) = 'test'
  AND player_name IN (
        SELECT player_name FROM cricket_player_pool
        WHERE country IN ('SL', 'WI') AND is_active = TRUE
      )
ORDER BY player_name, match_date DESC, innings_number ASC
LIMIT 200;


-- ============================================================
-- SECTION 8: PER-PLAYER DEEP DIVE (one player at a time)
-- Replace 'Kusal Mendis' with any player name.
-- Shows all formats and all innings sorted newest first.
-- Useful to audit a specific player's complete history.
-- ============================================================

SELECT
  match_type,
  match_date,
  match_name,
  opponent,
  venue,
  innings_number,
  runs,
  balls,
  fours,
  sixes,
  ROUND(strike_rate::numeric, 1)  AS strike_rate,
  dismissal_type,
  is_out,
  overs,
  runs_conceded,
  wickets,
  ROUND(economy::numeric, 2)      AS economy,
  data_source,
  source_match_id
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Kusal Mendis')  -- << change this name
ORDER BY match_date DESC, innings_number ASC;


-- ============================================================
-- SECTION 9: COMPUTED BATTING AVERAGES PER PLAYER PER FORMAT
-- Calculates batting average and strike rate from raw rows.
-- Only includes innings where the player faced at least 1 ball.
-- ============================================================

SELECT
  player_name,
  country,
  match_type,
  COUNT(DISTINCT source_match_id)                                AS matches,
  COUNT(*)                                                       AS innings,
  SUM(runs)                                                      AS total_runs,
  MAX(runs)                                                      AS highest_score,
  ROUND(
    SUM(runs)::numeric / NULLIF(SUM(CASE WHEN is_out THEN 1 ELSE 0 END), 0), 2
  )                                                              AS batting_avg,
  ROUND(AVG(NULLIF(strike_rate, 0))::numeric, 1)                 AS avg_strike_rate,
  SUM(fours)                                                     AS total_fours,
  SUM(sixes)                                                     AS total_sixes
FROM cricapi_player_match_history
WHERE balls > 0
  AND player_name IN (
        SELECT player_name FROM cricket_player_pool
        WHERE country IN ('SL', 'WI') AND is_active = TRUE
      )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- ============================================================
-- SECTION 10: COMPUTED BOWLING AVERAGES PER PLAYER PER FORMAT
-- Only includes innings where the player actually bowled.
-- ============================================================

SELECT
  player_name,
  country,
  match_type,
  COUNT(DISTINCT source_match_id)                                AS matches,
  COUNT(*)                                                       AS bowling_innings,
  SUM(wickets)                                                   AS total_wickets,
  SUM(runs_conceded)                                             AS total_runs_conceded,
  ROUND(AVG(NULLIF(economy, 0))::numeric, 2)                     AS avg_economy,
  ROUND(
    SUM(runs_conceded)::numeric / NULLIF(SUM(wickets), 0), 2
  )                                                              AS bowling_avg,
  MAX(wickets)                                                   AS best_innings_wickets
FROM cricapi_player_match_history
WHERE overs > 0
  AND player_name IN (
        SELECT player_name FROM cricket_player_pool
        WHERE country IN ('SL', 'WI') AND is_active = TRUE
      )
GROUP BY player_name, country, match_type
ORDER BY player_name, match_type;


-- ============================================================
-- SECTION 11: PLAYERS WITH ZERO HISTORY (data gaps)
-- Use this to identify exactly who has no data at all, so
-- you know who needs manual inserts (see Section 12 below).
-- ============================================================

SELECT
  cpp.player_name,
  cpp.country,
  cpp.player_type,
  'NO HISTORY' AS status
FROM cricket_player_pool cpp
WHERE cpp.country IN ('SL', 'WI')
  AND cpp.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1
    FROM cricapi_player_match_history h
    WHERE LOWER(h.player_name) = LOWER(cpp.player_name)
  )
ORDER BY cpp.country, cpp.player_name;


-- ============================================================
-- ============================================================
-- MANUAL INSERT SECTION
-- Use the templates below to add or correct match data.
-- ============================================================
-- ============================================================


-- ============================================================
-- SECTION 12: INSERT A MATCH RECORD FOR ONE PLAYER
--
-- HOW THE UNIQUE KEY WORKS:
--   The cricapi_match_id column is used as a unique key.
--   For manually inserted rows use this format so it never
--   collides with auto-synced rows:
--     'manual*<match_identifier>*<innings_number>*<format>'
--   Example: 'manual*SL_WI_ODI_2025_01_15*1*odi'
--
-- ON CONFLICT: if you re-run with the same cricapi_match_id +
--   player_name, it will UPDATE the existing row (safe to fix).
--
-- REQUIRED fields are marked with <<FILL>>.
-- Optional fields you don't know: leave as NULL or 0.
-- ============================================================

INSERT INTO cricapi_player_match_history (
  cricapi_match_id,       -- unique row key — use the manual* format above
  source_match_id,        -- same value as cricapi_match_id is fine for manual rows
  data_source,            -- always 'manual' for rows you insert yourself
  cricapi_player_id,      -- leave NULL if you don't know the cricapi ID
  cricsheet_player_id,    -- leave NULL if you don't know the cricsheet ID
  player_name,            -- must match exactly the name in cricket_player_pool
  country,                -- 'SL' or 'WI'
  match_name,             -- descriptive, e.g. 'SL vs WI ODI 1st Match'
  match_date,             -- format: 'YYYY-MM-DD'
  match_type,             -- 'odi', 't20', 't20i', or 'test'
  team,                   -- player's own team code, e.g. 'SL'
  opponent,               -- opposing team, e.g. 'WI'
  venue,                  -- ground name
  innings_number,         -- 1 or 2 (which innings of the match)
  batting_team,           -- team that batted in this innings, e.g. 'SL'
  bowling_team,           -- team that bowled in this innings, e.g. 'WI'
  -- BATTING stats (set to 0 if player did not bat)
  runs,
  balls,
  fours,
  sixes,
  strike_rate,            -- runs/balls*100, or NULL if not batting
  dismissal_type,         -- e.g. 'caught', 'bowled', 'run out', or NULL if not out
  dismissed_by_bowler,    -- bowler name or NULL
  dismissed_by_fielder,   -- fielder name or NULL
  is_out,                 -- TRUE if dismissed, FALSE if not out / did not bat
  -- BOWLING stats (set to 0 if player did not bowl)
  overs,
  runs_conceded,
  wickets,
  economy,                -- runs_conceded / overs, or NULL if did not bowl
  updated_at
)
VALUES (
  'manual*<<MATCH_ID>>*<<INNINGS_NUMBER>>*<<FORMAT>>',  -- <<FILL>> e.g. 'manual*SL_WI_ODI_2025_06_01*1*odi'
  'manual*<<MATCH_ID>>*<<INNINGS_NUMBER>>*<<FORMAT>>',  -- same as above
  'manual',
  NULL,                        -- cricapi_player_id  (NULL is fine)
  NULL,                        -- cricsheet_player_id (NULL is fine)
  '<<PLAYER NAME>>',           -- <<FILL>> exact name e.g. 'Kusal Mendis'
  '<<SL or WI>>',              -- <<FILL>>
  '<<MATCH NAME>>',            -- <<FILL>> e.g. 'SL vs WI ODI 1st Match'
  '<<YYYY-MM-DD>>',            -- <<FILL>> e.g. '2025-06-01'
  '<<FORMAT>>',                -- <<FILL>> 'odi', 't20', or 'test'
  '<<PLAYER TEAM>>',           -- <<FILL>> e.g. 'SL'
  '<<OPPONENT>>',              -- <<FILL>> e.g. 'WI'
  '<<VENUE>>',                 -- <<FILL>> e.g. 'R. Premadasa Stadium, Colombo'
  <<INNINGS_NUMBER>>,          -- <<FILL>> 1 or 2
  '<<BATTING TEAM>>',          -- <<FILL>> team batting in this innings
  '<<BOWLING TEAM>>',          -- <<FILL>> team bowling in this innings
  -- Batting
  <<RUNS>>,                    -- <<FILL>> e.g. 54
  <<BALLS>>,                   -- <<FILL>> e.g. 60
  <<FOURS>>,                   -- <<FILL>> e.g. 6
  <<SIXES>>,                   -- <<FILL>> e.g. 1
  <<STRIKE_RATE>>,             -- <<FILL>> e.g. 90.0, or NULL
  '<<DISMISSAL TYPE>>',        -- <<FILL>> or NULL if not out
  '<<DISMISSED BY BOWLER>>',   -- <<FILL>> or NULL
  '<<DISMISSED BY FIELDER>>',  -- <<FILL>> or NULL
  <<IS_OUT>>,                  -- <<FILL>> TRUE or FALSE
  -- Bowling
  <<OVERS>>,                   -- <<FILL>> e.g. 9.0, or 0 if did not bowl
  <<RUNS_CONCEDED>>,           -- <<FILL>> e.g. 42, or 0
  <<WICKETS>>,                 -- <<FILL>> e.g. 2, or 0
  <<ECONOMY>>,                 -- <<FILL>> e.g. 4.67, or NULL
  NOW()
)
ON CONFLICT (cricapi_match_id, cricapi_player_id)
DO UPDATE SET
  player_name          = EXCLUDED.player_name,
  match_name           = EXCLUDED.match_name,
  match_date           = EXCLUDED.match_date,
  match_type           = EXCLUDED.match_type,
  team                 = EXCLUDED.team,
  opponent             = EXCLUDED.opponent,
  venue                = EXCLUDED.venue,
  innings_number       = EXCLUDED.innings_number,
  batting_team         = EXCLUDED.batting_team,
  bowling_team         = EXCLUDED.bowling_team,
  runs                 = EXCLUDED.runs,
  balls                = EXCLUDED.balls,
  fours                = EXCLUDED.fours,
  sixes                = EXCLUDED.sixes,
  strike_rate          = EXCLUDED.strike_rate,
  dismissal_type       = EXCLUDED.dismissal_type,
  dismissed_by_bowler  = EXCLUDED.dismissed_by_bowler,
  dismissed_by_fielder = EXCLUDED.dismissed_by_fielder,
  is_out               = EXCLUDED.is_out,
  overs                = EXCLUDED.overs,
  runs_conceded        = EXCLUDED.runs_conceded,
  wickets              = EXCLUDED.wickets,
  economy              = EXCLUDED.economy,
  updated_at           = NOW();


-- ============================================================
-- SECTION 13: WORKED EXAMPLE — Kusal Mendis, SL vs WI ODI
--
-- This is a real filled-in example you can copy and adapt.
-- Kusal Mendis scored 72 off 85 balls (7 fours, 2 sixes),
-- was caught out. Did not bowl (overs = 0).
-- ============================================================

/*  -- Remove the slash-star and star-slash to run this block

INSERT INTO cricapi_player_match_history (
  cricapi_match_id, source_match_id, data_source,
  cricapi_player_id, cricsheet_player_id,
  player_name, country, match_name, match_date, match_type,
  team, opponent, venue, innings_number, batting_team, bowling_team,
  runs, balls, fours, sixes, strike_rate,
  dismissal_type, dismissed_by_bowler, dismissed_by_fielder, is_out,
  overs, runs_conceded, wickets, economy, updated_at
)
VALUES (
  'manual*SL_WI_ODI_2025_06_01*1*odi',
  'manual*SL_WI_ODI_2025_06_01*1*odi',
  'manual',
  NULL, NULL,
  'Kusal Mendis', 'SL', 'SL vs WI ODI — 1st Match', '2025-06-01', 'odi',
  'SL', 'WI', 'R. Premadasa Stadium, Colombo', 1, 'SL', 'WI',
  72, 85, 7, 2, 84.7,
  'caught', 'Alzarri Joseph', 'Nicholas Pooran', TRUE,
  0, 0, 0, NULL, NOW()
)
ON CONFLICT (cricapi_match_id, cricapi_player_id)
DO UPDATE SET
  runs = EXCLUDED.runs, balls = EXCLUDED.balls,
  fours = EXCLUDED.fours, sixes = EXCLUDED.sixes,
  strike_rate = EXCLUDED.strike_rate,
  dismissal_type = EXCLUDED.dismissal_type,
  dismissed_by_bowler = EXCLUDED.dismissed_by_bowler,
  is_out = EXCLUDED.is_out, updated_at = NOW();

*/  -- end of example block


-- ============================================================
-- SECTION 14: WORKED EXAMPLE — All-rounder with BOTH bat + bowl
--
-- Wanindu Hasaranga scored 34 off 28 (3 fours, 2 sixes),
-- AND also bowled 10 overs, 2 wickets, 48 runs conceded.
-- For all-rounders you need TWO ROWS — one for batting
-- (batting_team = their own team) and one for bowling
-- (bowling_team = their own team, overs > 0).
-- The two rows differ by innings_number or batting/bowling team.
-- ============================================================

/*  -- Remove the slash-star and star-slash to run this block

-- ROW 1: batting innings
INSERT INTO cricapi_player_match_history (
  cricapi_match_id, source_match_id, data_source,
  cricapi_player_id, cricsheet_player_id,
  player_name, country, match_name, match_date, match_type,
  team, opponent, venue, innings_number, batting_team, bowling_team,
  runs, balls, fours, sixes, strike_rate,
  dismissal_type, dismissed_by_bowler, dismissed_by_fielder, is_out,
  overs, runs_conceded, wickets, economy, updated_at
)
VALUES (
  'manual*SL_WI_ODI_2025_06_01_bat*1*odi',
  'manual*SL_WI_ODI_2025_06_01_bat*1*odi',
  'manual', NULL, NULL,
  'Wanindu Hasaranga', 'SL', 'SL vs WI ODI — 1st Match', '2025-06-01', 'odi',
  'SL', 'WI', 'R. Premadasa Stadium, Colombo', 1, 'SL', 'WI',
  34, 28, 3, 2, 121.4,
  'bowled', 'Alzarri Joseph', NULL, TRUE,
  0, 0, 0, NULL, NOW()
)
ON CONFLICT (cricapi_match_id, cricapi_player_id) DO UPDATE SET runs = EXCLUDED.runs, updated_at = NOW();

-- ROW 2: bowling innings
INSERT INTO cricapi_player_match_history (
  cricapi_match_id, source_match_id, data_source,
  cricapi_player_id, cricsheet_player_id,
  player_name, country, match_name, match_date, match_type,
  team, opponent, venue, innings_number, batting_team, bowling_team,
  runs, balls, fours, sixes, strike_rate,
  dismissal_type, dismissed_by_bowler, dismissed_by_fielder, is_out,
  overs, runs_conceded, wickets, economy, updated_at
)
VALUES (
  'manual*SL_WI_ODI_2025_06_01_bowl*2*odi',
  'manual*SL_WI_ODI_2025_06_01_bowl*2*odi',
  'manual', NULL, NULL,
  'Wanindu Hasaranga', 'SL', 'SL vs WI ODI — 1st Match', '2025-06-01', 'odi',
  'SL', 'WI', 'R. Premadasa Stadium, Colombo', 2, 'WI', 'SL',
  0, 0, 0, 0, NULL,
  NULL, NULL, NULL, FALSE,
  10, 48, 2, 4.8, NOW()
)
ON CONFLICT (cricapi_match_id, cricapi_player_id) DO UPDATE SET wickets = EXCLUDED.wickets, updated_at = NOW();

*/  -- end of example block


-- ============================================================
-- SECTION 15: CORRECT AN EXISTING RECORD
-- Use this when a row already exists but has wrong stats.
-- Replace all <<>> placeholders with real values.
-- ============================================================

UPDATE cricapi_player_match_history
SET
  runs                 = <<CORRECTED_RUNS>>,
  balls                = <<CORRECTED_BALLS>>,
  fours                = <<CORRECTED_FOURS>>,
  sixes                = <<CORRECTED_SIXES>>,
  strike_rate          = <<CORRECTED_SR>>,
  dismissal_type       = '<<CORRECTED_DISMISSAL>>',
  is_out               = <<TRUE_OR_FALSE>>,
  wickets              = <<CORRECTED_WICKETS>>,
  overs                = <<CORRECTED_OVERS>>,
  runs_conceded        = <<CORRECTED_RUNS_CONCEDED>>,
  economy              = <<CORRECTED_ECONOMY>>,
  updated_at           = NOW()
WHERE LOWER(player_name) = LOWER('<<PLAYER NAME>>')
  AND source_match_id    = '<<SOURCE_MATCH_ID>>'   -- from Section 8 query
  AND innings_number     = <<INNINGS_NUMBER>>;

-- BEFORE running the UPDATE, always verify what you're about
-- to change by running this SELECT first:
--
-- SELECT * FROM cricapi_player_match_history
-- WHERE LOWER(player_name) = LOWER('Kusal Mendis')
--   AND source_match_id = 'manual*SL_WI_ODI_2025_06_01*1*odi';


-- ============================================================
-- SECTION 16: VERIFY YOUR INSERTS WORKED
-- Run after any Section 12–15 insert/update to confirm.
-- Replace 'Kusal Mendis' with the player you just edited.
-- ============================================================

SELECT
  player_name,
  match_type,
  match_date,
  match_name,
  opponent,
  innings_number,
  runs, balls, fours, sixes,
  ROUND(strike_rate::numeric, 1) AS sr,
  dismissal_type,
  is_out,
  overs, runs_conceded, wickets,
  ROUND(economy::numeric, 2) AS econ,
  data_source,
  updated_at
FROM cricapi_player_match_history
WHERE LOWER(player_name) = LOWER('Kusal Mendis')  -- << change this
ORDER BY match_date DESC, innings_number ASC;
