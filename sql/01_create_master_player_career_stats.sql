-- ============================================================
-- FILE: sql/01_create_master_player_career_stats.sql
-- PURPOSE: Ensure player_career_stats_master is the single
--          source of truth for all player career stats.
--
-- WHAT THIS DOES:
--   Step 1 — CREATE TABLE IF NOT EXISTS (full schema)
--   Step 2 — ALTER TABLE to add missing columns safely
--   Step 3 — Backfill player_role from source tables
--   Step 4 — Add/verify indexes
--   Step 5 — Sample UPDATE (manual stat correction)
--   Step 6 — Sample UPSERT (add/refresh one player)
--
-- SAFE TO RE-RUN: all statements are idempotent.
-- ============================================================


-- ============================================================
-- STEP 1: CREATE TABLE (skips silently if already exists)
-- ============================================================

CREATE TABLE IF NOT EXISTS player_career_stats_master (

  id                    SERIAL PRIMARY KEY,

  -- ── Player identity ──────────────────────────────────────
  player_name           TEXT        NOT NULL,
  country               TEXT        NOT NULL,   -- full name: 'India', 'Sri Lanka', 'West Indies'
  player_role           TEXT,                   -- 'batter','bowler','all_rounder','wicket_keeper','unknown'
  cricapi_player_id     TEXT,                   -- CricAPI reference id (null if not yet linked)
  player_pool_source    TEXT        NOT NULL DEFAULT 'cricket',
                                                -- 'ipl'     → from cricapi_player_master / ipl_player_master
                                                -- 'cricket' → from cricket_player_pool (SL/WI etc.)

  -- ── ODI Batting ──────────────────────────────────────────
  odi_bat_matches       INTEGER     DEFAULT 0,
  odi_bat_innings       INTEGER     DEFAULT 0,
  odi_bat_not_outs      INTEGER     DEFAULT 0,
  odi_bat_runs          INTEGER     DEFAULT 0,
  odi_bat_highest       TEXT,
  odi_bat_avg           NUMERIC(7,2),
  odi_bat_balls_faced   INTEGER     DEFAULT 0,
  odi_bat_strike_rate   NUMERIC(7,2),
  odi_bat_100s          INTEGER     DEFAULT 0,
  odi_bat_50s           INTEGER     DEFAULT 0,
  odi_bat_4s            INTEGER     DEFAULT 0,
  odi_bat_6s            INTEGER     DEFAULT 0,

  -- ── ODI Bowling ──────────────────────────────────────────
  odi_bowl_matches      INTEGER     DEFAULT 0,
  odi_bowl_innings      INTEGER     DEFAULT 0,
  odi_bowl_balls        INTEGER     DEFAULT 0,
  odi_bowl_runs         INTEGER     DEFAULT 0,
  odi_bowl_wickets      INTEGER     DEFAULT 0,
  odi_bowl_avg          NUMERIC(7,2),
  odi_bowl_economy      NUMERIC(5,2),
  odi_bowl_strike_rate  NUMERIC(7,2),
  odi_bowl_5wi          INTEGER     DEFAULT 0,

  -- ── T20I Batting ─────────────────────────────────────────
  t20_bat_matches       INTEGER     DEFAULT 0,
  t20_bat_innings       INTEGER     DEFAULT 0,
  t20_bat_not_outs      INTEGER     DEFAULT 0,
  t20_bat_runs          INTEGER     DEFAULT 0,
  t20_bat_highest       TEXT,
  t20_bat_avg           NUMERIC(7,2),
  t20_bat_balls_faced   INTEGER     DEFAULT 0,
  t20_bat_strike_rate   NUMERIC(7,2),
  t20_bat_100s          INTEGER     DEFAULT 0,
  t20_bat_50s           INTEGER     DEFAULT 0,
  t20_bat_4s            INTEGER     DEFAULT 0,
  t20_bat_6s            INTEGER     DEFAULT 0,

  -- ── T20I Bowling ─────────────────────────────────────────
  t20_bowl_matches      INTEGER     DEFAULT 0,
  t20_bowl_innings      INTEGER     DEFAULT 0,
  t20_bowl_balls        INTEGER     DEFAULT 0,
  t20_bowl_runs         INTEGER     DEFAULT 0,
  t20_bowl_wickets      INTEGER     DEFAULT 0,
  t20_bowl_avg          NUMERIC(7,2),
  t20_bowl_economy      NUMERIC(5,2),
  t20_bowl_strike_rate  NUMERIC(7,2),
  t20_bowl_5wi          INTEGER     DEFAULT 0,

  -- ── Test Batting ─────────────────────────────────────────
  test_bat_matches      INTEGER     DEFAULT 0,
  test_bat_innings      INTEGER     DEFAULT 0,
  test_bat_not_outs     INTEGER     DEFAULT 0,
  test_bat_runs         INTEGER     DEFAULT 0,
  test_bat_highest      TEXT,
  test_bat_avg          NUMERIC(7,2),
  test_bat_balls_faced  INTEGER     DEFAULT 0,
  test_bat_strike_rate  NUMERIC(7,2),
  test_bat_100s         INTEGER     DEFAULT 0,
  test_bat_50s          INTEGER     DEFAULT 0,
  test_bat_4s           INTEGER     DEFAULT 0,
  test_bat_6s           INTEGER     DEFAULT 0,

  -- ── Test Bowling ─────────────────────────────────────────
  test_bowl_matches     INTEGER     DEFAULT 0,
  test_bowl_innings     INTEGER     DEFAULT 0,
  test_bowl_balls       INTEGER     DEFAULT 0,
  test_bowl_runs        INTEGER     DEFAULT 0,
  test_bowl_wickets     INTEGER     DEFAULT 0,
  test_bowl_avg         NUMERIC(7,2),
  test_bowl_economy     NUMERIC(5,2),
  test_bowl_strike_rate NUMERIC(7,2),
  test_bowl_5wi         INTEGER     DEFAULT 0,
  test_bowl_10wi        INTEGER     DEFAULT 0,

  -- ── Metadata ─────────────────────────────────────────────
  data_source           TEXT        DEFAULT 'cricapi',
  created_at            TIMESTAMP   DEFAULT NOW(),
  last_synced_at        TIMESTAMP   DEFAULT NOW(),
  updated_at            TIMESTAMP   DEFAULT NOW(),

  UNIQUE (player_name, country)
);


-- ============================================================
-- STEP 2: ADD MISSING COLUMNS (safe if table already exists)
-- Each ALTER runs independently — none will fail if the column
-- already exists.
-- ============================================================

ALTER TABLE player_career_stats_master
  ADD COLUMN IF NOT EXISTS player_role  TEXT;

ALTER TABLE player_career_stats_master
  ADD COLUMN IF NOT EXISTS created_at   TIMESTAMP DEFAULT NOW();


-- ============================================================
-- STEP 3: BACKFILL player_role FROM SOURCE TABLES
-- Populates player_role where it is currently NULL.
-- Priority: cricket_player_pool first (SL/WI), then
-- cricapi_player_master (all other players).
-- Only updates rows where player_role IS NULL — safe to re-run.
-- ============================================================

UPDATE player_career_stats_master p
SET
  player_role = CASE COALESCE(src.player_type, 'unknown')
    WHEN 'Batsman'      THEN 'batter'
    WHEN 'Bowler'       THEN 'bowler'
    WHEN 'All Rounder'  THEN 'all_rounder'
    WHEN 'Wicketkeeper' THEN 'wicket_keeper'
    ELSE 'unknown'
  END,
  updated_at = NOW()
FROM (
  SELECT DISTINCT ON (p2.player_name, p2.country)
    p2.player_name,
    p2.country,
    COALESCE(cpp2.player_type, ipm2.player_type) AS player_type
  FROM player_career_stats_master p2
  LEFT JOIN cricket_player_pool cpp2
    ON  LOWER(cpp2.player_name) = LOWER(p2.player_name)
    AND cpp2.country = CASE p2.country
          WHEN 'Sri Lanka'   THEN 'SL'
          WHEN 'West Indies' THEN 'WI'
          ELSE NULL END
  LEFT JOIN cricapi_player_master ipm2
    ON  LOWER(ipm2.player_name) = LOWER(p2.player_name)
    AND LOWER(ipm2.country)     = LOWER(p2.country)
  WHERE p2.player_role IS NULL
  ORDER BY p2.player_name, p2.country
) src
WHERE p.player_name = src.player_name
  AND p.country     = src.country;

-- Verify: how many rows still have NULL role (should be 0 or very few)
SELECT COUNT(*) AS players_with_null_role
FROM player_career_stats_master
WHERE player_role IS NULL;

-- Verify: role distribution
SELECT player_role, COUNT(*) AS player_count
FROM player_career_stats_master
GROUP BY player_role
ORDER BY player_count DESC;


-- ============================================================
-- STEP 4: INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_pcsm_country
  ON player_career_stats_master (country);

CREATE INDEX IF NOT EXISTS idx_pcsm_player_role
  ON player_career_stats_master (player_role);

CREATE INDEX IF NOT EXISTS idx_pcsm_cricapi_id
  ON player_career_stats_master (cricapi_player_id)
  WHERE cricapi_player_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pcsm_pool_source
  ON player_career_stats_master (player_pool_source);


-- ============================================================
-- STEP 5: SAMPLE — MANUALLY UPDATE ONE PLAYER'S STATS
-- Uncomment and fill in values as needed.
-- ============================================================

/*
UPDATE player_career_stats_master
SET
  player_role         = 'batter',            -- batter / bowler / all_rounder / wicket_keeper
  -- T20 batting
  t20_bat_matches     = 95,
  t20_bat_runs        = 3400,
  t20_bat_avg         = 42.50,
  t20_bat_strike_rate = 148.20,
  t20_bat_50s         = 24,
  t20_bat_100s        = 1,
  t20_bat_4s          = 320,
  t20_bat_6s          = 105,
  t20_bowl_wickets    = 0,
  t20_bowl_economy    = 99,
  -- ODI batting
  odi_bat_matches     = 280,
  odi_bat_runs        = 13000,
  odi_bat_avg         = 58.00,
  odi_bat_strike_rate = 93.50,
  odi_bat_50s         = 65,
  odi_bat_100s        = 46,
  -- Test batting
  test_bat_matches    = 120,
  test_bat_runs       = 9000,
  test_bat_avg        = 49.50,
  test_bat_50s        = 28,
  test_bat_100s       = 30,
  updated_at          = NOW()
WHERE player_name = 'Virat Kohli'
  AND country     = 'India';
*/


-- ============================================================
-- STEP 6: SAMPLE — SAFE UPSERT (add or refresh one player)
-- Uncomment and fill in values as needed.
-- ============================================================

/*
INSERT INTO player_career_stats_master (
  player_name, country, player_role, cricapi_player_id, player_pool_source,
  -- T20
  t20_bat_matches, t20_bat_runs, t20_bat_avg, t20_bat_strike_rate,
  t20_bat_50s, t20_bat_100s, t20_bat_4s, t20_bat_6s,
  t20_bowl_matches, t20_bowl_wickets, t20_bowl_economy, t20_bowl_5wi,
  -- ODI
  odi_bat_matches, odi_bat_runs, odi_bat_avg, odi_bat_strike_rate,
  odi_bat_50s, odi_bat_100s,
  odi_bowl_matches, odi_bowl_wickets, odi_bowl_economy, odi_bowl_5wi,
  -- Test
  test_bat_matches, test_bat_runs, test_bat_avg, test_bat_50s, test_bat_100s,
  test_bowl_matches, test_bowl_wickets, test_bowl_economy, test_bowl_5wi, test_bowl_10wi,
  data_source, updated_at
)
VALUES (
  'Player Name', 'Sri Lanka', 'batter', NULL, 'cricket',
  50, 1400, 35.0, 138.0, 10, 0, 120, 45,
  0, 0, 99, 0,
  80, 2800, 42.0, 85.0, 18, 4,
  5, 3, 7.2, 0,
  20, 900, 31.0, 8, 2,
  3, 5, 3.8, 0, 0,
  'manual', NOW()
)
ON CONFLICT (player_name, country)
DO UPDATE SET
  player_role         = EXCLUDED.player_role,
  t20_bat_matches     = EXCLUDED.t20_bat_matches,
  t20_bat_runs        = EXCLUDED.t20_bat_runs,
  t20_bat_avg         = EXCLUDED.t20_bat_avg,
  t20_bat_strike_rate = EXCLUDED.t20_bat_strike_rate,
  t20_bat_50s         = EXCLUDED.t20_bat_50s,
  t20_bat_100s        = EXCLUDED.t20_bat_100s,
  t20_bat_4s          = EXCLUDED.t20_bat_4s,
  t20_bat_6s          = EXCLUDED.t20_bat_6s,
  t20_bowl_matches    = EXCLUDED.t20_bowl_matches,
  t20_bowl_wickets    = EXCLUDED.t20_bowl_wickets,
  t20_bowl_economy    = EXCLUDED.t20_bowl_economy,
  t20_bowl_5wi        = EXCLUDED.t20_bowl_5wi,
  odi_bat_matches     = EXCLUDED.odi_bat_matches,
  odi_bat_runs        = EXCLUDED.odi_bat_runs,
  odi_bat_avg         = EXCLUDED.odi_bat_avg,
  odi_bat_strike_rate = EXCLUDED.odi_bat_strike_rate,
  odi_bat_50s         = EXCLUDED.odi_bat_50s,
  odi_bat_100s        = EXCLUDED.odi_bat_100s,
  odi_bowl_matches    = EXCLUDED.odi_bowl_matches,
  odi_bowl_wickets    = EXCLUDED.odi_bowl_wickets,
  odi_bowl_economy    = EXCLUDED.odi_bowl_economy,
  odi_bowl_5wi        = EXCLUDED.odi_bowl_5wi,
  test_bat_matches    = EXCLUDED.test_bat_matches,
  test_bat_runs       = EXCLUDED.test_bat_runs,
  test_bat_avg        = EXCLUDED.test_bat_avg,
  test_bat_50s        = EXCLUDED.test_bat_50s,
  test_bat_100s       = EXCLUDED.test_bat_100s,
  test_bowl_matches   = EXCLUDED.test_bowl_matches,
  test_bowl_wickets   = EXCLUDED.test_bowl_wickets,
  test_bowl_economy   = EXCLUDED.test_bowl_economy,
  test_bowl_5wi       = EXCLUDED.test_bowl_5wi,
  test_bowl_10wi      = EXCLUDED.test_bowl_10wi,
  data_source         = EXCLUDED.data_source,
  updated_at          = NOW();
*/
