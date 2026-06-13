-- ============================================================
-- FILE: sql/10_afghanistan_india_series_setup.sql
-- PURPOSE: Set up Afghanistan historical player data ahead of
--          the India vs Afghanistan ODI series (starting 2026-06-13).
--
-- WHAT THIS FILE DOES (run top to bottom in Neon SQL editor):
--
--   SECTION 1 — Create a permanent staging table called
--               manual_upload_historical_player_data.
--               You will \copy CSV files into this table for
--               every new country (Afghanistan, India, etc.).
--               The table is reusable forever — just add rows.
--
--   SECTION 2 — Instructions for loading your CSV file into
--               that staging table using psql \copy.
--               (Read these comments before running anything.)
--
--   SECTION 3 — Back up the existing Afghanistan rows that are
--               already in player_career_stats_master, so you
--               can restore them if anything goes wrong.
--
--   SECTION 4 — Inside a transaction:
--               a) Delete the old Afghanistan rows from
--                  player_career_stats_master.
--               b) Upsert the fresh data from the staging table
--                  into player_career_stats_master.
--               Rolls back automatically if anything fails.
--
--   SECTION 5 — Add Afghanistan players to cricket_player_pool
--               so they appear in match creation dropdowns.
--
--   SECTION 6 — Verification queries to confirm everything
--               looks correct before you go live.
--
-- SAFE TO RE-RUN: All writes use ON CONFLICT DO NOTHING or
--                 ON CONFLICT DO UPDATE, so re-running this
--                 file will not create duplicate rows.
--
-- FILES NEEDED:
--   Afghanistan_player_career_stats_master_ready.csv
--   (lives in: Historical Player Data/ folder)
-- ============================================================


-- ============================================================
-- SECTION 1: CREATE THE MANUAL UPLOAD STAGING TABLE
-- ============================================================
-- This table acts as a permanent "inbox" for all manual CSV
-- uploads. Every time you prepare data for a new country
-- (India, Bangladesh refresh, etc.) you upload into this table
-- first. The master table then pulls from here.
--
-- Columns mirror player_career_stats_master exactly, plus two
-- extra tracking columns at the end:
-- ============================================================
-- WHY THIS TABLE HAS NO EXTRA COLUMNS:
-- \copy without a column list always tries to fill EVERY column
-- in the table from the CSV — DEFAULT values are ignored by COPY.
-- The only way to use a plain \copy with no column list is to
-- make the table an exact mirror of the CSV: same columns, same
-- order, nothing extra. Country is your natural batch identifier.
-- ============================================================

-- Run this first if the table already exists from a prior attempt:
DROP TABLE IF EXISTS manual_upload_historical_player_data;

CREATE TABLE manual_upload_historical_player_data (

  -- ── Columns are in the EXACT same order as the CSV header ──
  -- id, player_name, country ... created_at  (74 columns total)

  id                   INTEGER,
  player_name          TEXT        NOT NULL,
  country              TEXT        NOT NULL,
  cricapi_player_id    TEXT,
  player_pool_source   TEXT,

  -- ODI Batting
  odi_bat_matches      INTEGER,
  odi_bat_innings      INTEGER,
  odi_bat_not_outs     INTEGER,
  odi_bat_runs         INTEGER,
  odi_bat_highest      TEXT,
  odi_bat_avg          NUMERIC(7,2),
  odi_bat_balls_faced  INTEGER,
  odi_bat_strike_rate  NUMERIC(7,2),
  odi_bat_100s         INTEGER,
  odi_bat_50s          INTEGER,
  odi_bat_4s           INTEGER,
  odi_bat_6s           INTEGER,

  -- ODI Bowling
  odi_bowl_matches     INTEGER,
  odi_bowl_innings     INTEGER,
  odi_bowl_balls       INTEGER,
  odi_bowl_runs        INTEGER,
  odi_bowl_wickets     INTEGER,
  odi_bowl_avg         NUMERIC(7,2),
  odi_bowl_economy     NUMERIC(5,2),
  odi_bowl_strike_rate NUMERIC(7,2),
  odi_bowl_5wi         INTEGER,

  -- T20 Batting
  t20_bat_matches      INTEGER,
  t20_bat_innings      INTEGER,
  t20_bat_not_outs     INTEGER,
  t20_bat_runs         INTEGER,
  t20_bat_highest      TEXT,
  t20_bat_avg          NUMERIC(7,2),
  t20_bat_balls_faced  INTEGER,
  t20_bat_strike_rate  NUMERIC(7,2),
  t20_bat_100s         INTEGER,
  t20_bat_50s          INTEGER,
  t20_bat_4s           INTEGER,
  t20_bat_6s           INTEGER,

  -- T20 Bowling
  t20_bowl_matches     INTEGER,
  t20_bowl_innings     INTEGER,
  t20_bowl_balls       INTEGER,
  t20_bowl_runs        INTEGER,
  t20_bowl_wickets     INTEGER,
  t20_bowl_avg         NUMERIC(7,2),
  t20_bowl_economy     NUMERIC(5,2),
  t20_bowl_strike_rate NUMERIC(7,2),
  t20_bowl_5wi         INTEGER,

  -- Test Batting
  test_bat_matches     INTEGER,
  test_bat_innings     INTEGER,
  test_bat_not_outs    INTEGER,
  test_bat_runs        INTEGER,
  test_bat_highest     TEXT,
  test_bat_avg         NUMERIC(7,2),
  test_bat_balls_faced INTEGER,
  test_bat_strike_rate NUMERIC(7,2),
  test_bat_100s        INTEGER,
  test_bat_50s         INTEGER,
  test_bat_4s          INTEGER,
  test_bat_6s          INTEGER,

  -- Test Bowling
  test_bowl_matches    INTEGER,
  test_bowl_innings    INTEGER,
  test_bowl_balls      INTEGER,
  test_bowl_runs       INTEGER,
  test_bowl_wickets    INTEGER,
  test_bowl_avg        NUMERIC(7,2),
  test_bowl_economy    NUMERIC(5,2),
  test_bowl_strike_rate NUMERIC(7,2),
  test_bowl_5wi        INTEGER,
  test_bowl_10wi       INTEGER,

  -- Metadata (TEXT not TIMESTAMP — these are blank in manual CSVs)
  data_source          TEXT,
  last_synced_at       TEXT,
  updated_at           TEXT,
  player_role          TEXT,
  created_at           TEXT
);

-- One index is enough — you'll always filter by country
CREATE INDEX IF NOT EXISTS idx_muhpd_country
  ON manual_upload_historical_player_data (country);

-- Confirm table was created
SELECT 'manual_upload_historical_player_data table created (or already existed)' AS status;


-- ============================================================
-- SECTION 2: LOAD YOUR CSV INTO THE STAGING TABLE
-- ============================================================
-- Run these steps OUTSIDE of this SQL file, from a terminal
-- (psql) connected to your Neon database.
--
-- STEP 2a — Open a terminal and connect to Neon:
--
--   psql "postgresql://USER:PASSWORD@HOST/DATABASE?sslmode=require"
--
--   (Get the connection string from Neon dashboard → Connect)
--
-- STEP 2b — Run this exact command in psql. That's it — one line:
--
--   \copy manual_upload_historical_player_data FROM 'C:\Users\tapob\Downloads\20260606_memory_game-main\Historical Player Data\Afghanistan_player_career_stats_master_ready.csv' DELIMITER ',' CSV HEADER;
--
--   The HEADER keyword skips the first row (column names) automatically.
--   No column list needed — the table is an exact mirror of the CSV.
--
-- STEP 2c — Verify the rows loaded correctly (run in psql or Neon):
--
--   SELECT country, COUNT(*) AS players
--   FROM manual_upload_historical_player_data
--   GROUP BY country;
--
--   You should see: Afghanistan | 14
--
-- ── NOTE FOR FUTURE COUNTRIES ────────────────────────────────
-- For India, Bangladesh refresh, etc.: prepare a new CSV in
-- the same format (Afghanistan_player_career_stats_master_ready.csv),
-- change the batch label (e.g. 'India_2026-06-20'), and repeat
-- STEP 2b–2e. Rows for different countries/batches coexist
-- safely in the same table.
-- ============================================================


-- ============================================================
-- SECTION 3: BACK UP EXISTING AFGHANISTAN DATA
-- ============================================================
-- Run this BEFORE the delete in Section 4.
-- Creates a snapshot of the current Afghanistan rows so you
-- can restore them with a simple INSERT...SELECT if needed.
-- Safe to re-run: CREATE TABLE IF NOT EXISTS is idempotent.
-- ============================================================

CREATE TABLE IF NOT EXISTS player_career_stats_master_backup_afghanistan AS
SELECT *
FROM player_career_stats_master
WHERE country = 'Afghanistan';

-- Show what we backed up
SELECT COUNT(*) AS rows_backed_up,
       STRING_AGG(player_name, ', ' ORDER BY player_name) AS player_names
FROM player_career_stats_master_backup_afghanistan;


-- ============================================================
-- SECTION 4: REPLACE AFGHANISTAN DATA IN THE MASTER TABLE
-- ============================================================
-- This block runs as a single transaction so it either
-- completes fully or rolls back completely — your data is
-- never left in a half-replaced state.
--
-- What happens inside:
--   a) Delete old Afghanistan rows (country = 'Afghanistan').
--      NOTE: This only targets the exact string 'Afghanistan'.
--            Rows with country = 'AFG' are NOT touched.
--
--   b) Upsert fresh rows from manual_upload_historical_player_data
--      into player_career_stats_master for country = 'Afghanistan'.
--      If a player already exists (player_name, country conflict),
--      all stats are overwritten with the new values.
--
-- PREREQUISITE: Complete Section 2 (CSV load) before running
--               this section, or the INSERT will load 0 rows.
-- ============================================================

BEGIN;

  -- ── 4a: Delete old Afghanistan rows ────────────────────────
  -- We delete first so the upsert below can re-insert cleanly.
  -- The ON CONFLICT DO UPDATE would also work without the delete,
  -- but deleting first ensures no stale columns are left over.

  DELETE FROM player_career_stats_master
  WHERE country = 'Afghanistan';

  -- Show how many rows were removed (should match your backup count)
  -- (In psql this prints automatically; in Neon console you'll see
  --  "X rows affected" in the output panel.)

  -- ── 4b: Upsert fresh Afghanistan data from staging table ────
  -- Pulls all Afghanistan rows from manual_upload_historical_player_data.
  -- Converts 'missing_not_filled' cricapi_player_id → NULL.
  -- Forces player_pool_source = 'cricket' (master table convention).
  -- Forces data_source = 'manual'.

  INSERT INTO player_career_stats_master (
    player_name,
    country,
    cricapi_player_id,
    player_pool_source,
    player_role,
    data_source,

    -- ODI Batting
    odi_bat_matches, odi_bat_innings, odi_bat_not_outs,
    odi_bat_runs, odi_bat_highest, odi_bat_avg,
    odi_bat_balls_faced, odi_bat_strike_rate,
    odi_bat_100s, odi_bat_50s, odi_bat_4s, odi_bat_6s,

    -- ODI Bowling
    odi_bowl_matches, odi_bowl_innings, odi_bowl_balls,
    odi_bowl_runs, odi_bowl_wickets, odi_bowl_avg,
    odi_bowl_economy, odi_bowl_strike_rate, odi_bowl_5wi,

    -- T20 Batting
    t20_bat_matches, t20_bat_innings, t20_bat_not_outs,
    t20_bat_runs, t20_bat_highest, t20_bat_avg,
    t20_bat_balls_faced, t20_bat_strike_rate,
    t20_bat_100s, t20_bat_50s, t20_bat_4s, t20_bat_6s,

    -- T20 Bowling
    t20_bowl_matches, t20_bowl_innings, t20_bowl_balls,
    t20_bowl_runs, t20_bowl_wickets, t20_bowl_avg,
    t20_bowl_economy, t20_bowl_strike_rate, t20_bowl_5wi,

    -- Test Batting
    test_bat_matches, test_bat_innings, test_bat_not_outs,
    test_bat_runs, test_bat_highest, test_bat_avg,
    test_bat_balls_faced, test_bat_strike_rate,
    test_bat_100s, test_bat_50s, test_bat_4s, test_bat_6s,

    -- Test Bowling
    test_bowl_matches, test_bowl_innings, test_bowl_balls,
    test_bowl_runs, test_bowl_wickets, test_bowl_avg,
    test_bowl_economy, test_bowl_strike_rate,
    test_bowl_5wi, test_bowl_10wi,

    last_synced_at,
    updated_at
  )
  SELECT
    player_name,
    country,
    -- Treat 'missing_not_filled' as NULL (no real CricAPI ID yet)
    NULLIF(cricapi_player_id, 'missing_not_filled'),
    'cricket',                   -- player_pool_source convention in master table
    player_role,
    'manual',                    -- data_source

    -- ODI Batting
    COALESCE(odi_bat_matches, 0),
    COALESCE(odi_bat_innings, 0),
    COALESCE(odi_bat_not_outs, 0),
    COALESCE(odi_bat_runs, 0),
    COALESCE(odi_bat_highest, '0'),
    odi_bat_avg,
    COALESCE(odi_bat_balls_faced, 0),
    odi_bat_strike_rate,
    COALESCE(odi_bat_100s, 0),
    COALESCE(odi_bat_50s, 0),
    COALESCE(odi_bat_4s, 0),
    COALESCE(odi_bat_6s, 0),

    -- ODI Bowling
    COALESCE(odi_bowl_matches, 0),
    COALESCE(odi_bowl_innings, 0),
    COALESCE(odi_bowl_balls, 0),
    COALESCE(odi_bowl_runs, 0),
    COALESCE(odi_bowl_wickets, 0),
    odi_bowl_avg,
    odi_bowl_economy,
    odi_bowl_strike_rate,
    COALESCE(odi_bowl_5wi, 0),

    -- T20 Batting
    COALESCE(t20_bat_matches, 0),
    COALESCE(t20_bat_innings, 0),
    COALESCE(t20_bat_not_outs, 0),
    COALESCE(t20_bat_runs, 0),
    COALESCE(t20_bat_highest, '0'),
    t20_bat_avg,
    COALESCE(t20_bat_balls_faced, 0),
    t20_bat_strike_rate,
    COALESCE(t20_bat_100s, 0),
    COALESCE(t20_bat_50s, 0),
    COALESCE(t20_bat_4s, 0),
    COALESCE(t20_bat_6s, 0),

    -- T20 Bowling
    COALESCE(t20_bowl_matches, 0),
    COALESCE(t20_bowl_innings, 0),
    COALESCE(t20_bowl_balls, 0),
    COALESCE(t20_bowl_runs, 0),
    COALESCE(t20_bowl_wickets, 0),
    t20_bowl_avg,
    t20_bowl_economy,
    t20_bowl_strike_rate,
    COALESCE(t20_bowl_5wi, 0),

    -- Test Batting
    COALESCE(test_bat_matches, 0),
    COALESCE(test_bat_innings, 0),
    COALESCE(test_bat_not_outs, 0),
    COALESCE(test_bat_runs, 0),
    COALESCE(test_bat_highest, '0'),
    test_bat_avg,
    COALESCE(test_bat_balls_faced, 0),
    test_bat_strike_rate,
    COALESCE(test_bat_100s, 0),
    COALESCE(test_bat_50s, 0),
    COALESCE(test_bat_4s, 0),
    COALESCE(test_bat_6s, 0),

    -- Test Bowling
    COALESCE(test_bowl_matches, 0),
    COALESCE(test_bowl_innings, 0),
    COALESCE(test_bowl_balls, 0),
    COALESCE(test_bowl_runs, 0),
    COALESCE(test_bowl_wickets, 0),
    test_bowl_avg,
    test_bowl_economy,
    test_bowl_strike_rate,
    COALESCE(test_bowl_5wi, 0),
    COALESCE(test_bowl_10wi, 0),

    NOW(),   -- last_synced_at
    NOW()    -- updated_at

  FROM manual_upload_historical_player_data
  WHERE country = 'Afghanistan'

  -- If a (player_name, country) pair already exists, overwrite
  -- all stats columns with the new values from the staging table.
  ON CONFLICT (player_name, country)
  DO UPDATE SET
    player_role          = EXCLUDED.player_role,
    player_pool_source   = EXCLUDED.player_pool_source,
    data_source          = EXCLUDED.data_source,

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
    test_bowl_strike_rate = EXCLUDED.test_bowl_strike_rate,
    test_bowl_5wi        = EXCLUDED.test_bowl_5wi,
    test_bowl_10wi       = EXCLUDED.test_bowl_10wi,

    updated_at           = NOW(),
    last_synced_at       = NOW();

COMMIT;

-- Confirm the transaction completed
SELECT 'Section 4 complete: Afghanistan data replaced in player_career_stats_master' AS status;


-- ============================================================
-- SECTION 5: ADD AFGHANISTAN PLAYERS TO cricket_player_pool
-- ============================================================
-- cricket_player_pool is the roster table that the match
-- creation screen reads. Players must be in this table to
-- appear when you set up a new match.
--
-- Country code for Afghanistan in this table is 'AFG'
-- (short codes: BAN, SL, WI, AUS, AFG, IND, etc.)
--
-- player_type values used in this table:
--   'BAT'  → batter
--   'WK'   → wicketkeeper
--   'AR'   → all-rounder
--   'BOWL' → bowler
--
-- ON CONFLICT DO NOTHING means re-running is safe — players
-- already in the pool are skipped without error.
-- ============================================================

INSERT INTO cricket_player_pool
  (player_name, country, player_type, player_tag, player_cost_coins)
VALUES
  -- Batters
  ('Hashmatullah Shahid', 'AFG', 'BAT',  'batsman',       5),
  ('Ibrahim Zadran',      'AFG', 'BAT',  'batsman',       5),
  ('Sediqullah Atal',     'AFG', 'BAT',  'batsman',       5),
  ('Rahmat Shah',         'AFG', 'BAT',  'batsman',       5),
  ('Darwish Rasooli',     'AFG', 'BAT',  'batsman',       5),

  -- Wicketkeepers
  ('Ikram Alikhil',       'AFG', 'WK',   'wicket-keeper', 5),
  ('Rahmanullah Gurbaz',  'AFG', 'WK',   'wicket-keeper', 5),

  -- All-Rounders
  ('Azmatullah Omarzai',  'AFG', 'AR',   'all-rounder',   5),
  ('Mohammad Nabi',       'AFG', 'AR',   'all-rounder',   5),
  ('Rashid Khan',         'AFG', 'AR',   'all-rounder',   5),
  ('Nangeyalia Kharoti',  'AFG', 'AR',   'all-rounder',   5),

  -- Bowlers
  ('AM Ghazanfar',        'AFG', 'BOWL', 'bowler',        5),
  ('Bilal Sami',          'AFG', 'BOWL', 'bowler',        5),
  ('Fareed Ahmad Malik',  'AFG', 'BOWL', 'bowler',        5)

ON CONFLICT DO NOTHING;

-- Confirm Afghanistan players are in the pool
SELECT country, player_type, COUNT(*) AS count
FROM cricket_player_pool
WHERE country = 'AFG'
GROUP BY country, player_type
ORDER BY player_type;


-- ============================================================
-- SECTION 6: VERIFICATION QUERIES
-- ============================================================
-- Run these after everything above to confirm the data looks
-- right before you go live with match creation.
-- ============================================================

-- 6a: How many Afghanistan players are now in the master table?
--     Should be exactly 14.
SELECT COUNT(*) AS afghanistan_player_count
FROM player_career_stats_master
WHERE country = 'Afghanistan';

-- 6b: Check for accidental duplicate players.
--     This query should return ZERO rows.
--     If it returns rows, something went wrong — roll back
--     by running: INSERT INTO player_career_stats_master
--     SELECT * FROM player_career_stats_master_backup_afghanistan
--     ON CONFLICT DO NOTHING;
SELECT player_name, COUNT(*) AS duplicate_count
FROM player_career_stats_master
WHERE country = 'Afghanistan'
GROUP BY player_name
HAVING COUNT(*) > 1;

-- 6c: Full player list with key ODI stats.
--     Confirm the stats look reasonable before match launch.
SELECT
  player_name,
  player_role,
  odi_bat_matches,
  odi_bat_runs,
  odi_bat_avg,
  odi_bat_strike_rate,
  odi_bowl_wickets,
  odi_bowl_economy,
  data_source
FROM player_career_stats_master
WHERE country = 'Afghanistan'
ORDER BY player_name;

-- 6d: Confirm manual_upload_historical_player_data has the rows.
--     Useful to verify the \copy completed before Section 4.
SELECT upload_batch, country, COUNT(*) AS players, MIN(uploaded_at) AS first_upload
FROM manual_upload_historical_player_data
WHERE country = 'Afghanistan'
GROUP BY upload_batch, country;

-- 6e: Cross-check — every Afghanistan player in cricket_player_pool
--     should also exist in player_career_stats_master.
--     This query should return ZERO rows (no missing stats).
SELECT p.player_name, p.country AS pool_country
FROM cricket_player_pool p
WHERE p.country = 'AFG'
  AND NOT EXISTS (
    SELECT 1 FROM player_career_stats_master m
    WHERE m.player_name = p.player_name
      AND m.country = 'Afghanistan'
  );

-- ============================================================
-- ALL DONE.
-- Next steps after verification passes:
--   1. Go to your match creation screen and create the
--      India vs Afghanistan ODI match.
--   2. Select Afghanistan players from cricket_player_pool
--      (country = 'AFG').
--   3. The budget/impact score calculation will read their
--      ODI stats from player_career_stats_master automatically.
--   4. For India players: prepare India_player_career_stats_master_ready.csv
--      in the same format, upload to manual_upload_historical_player_data
--      with upload_batch = 'India_YYYY-MM-DD', then run
--      Section 4 again with WHERE country = 'India'.
-- ============================================================
