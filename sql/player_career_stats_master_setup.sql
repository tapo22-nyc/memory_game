-- ============================================================
-- FILE: player_career_stats_master_setup.sql
-- PURPOSE: Create the player_career_stats_master table — a
--          clean, flat, queryable table that stores career
--          batting and bowling totals for every player across
--          all three formats (ODI, T20, Test).
--
-- WHY A NEW TABLE?
--   cricapi_player_career_stats (existing) stores stats as raw
--   JSON blobs. You cannot easily query "all players with
--   ODI avg > 40" without JSON parsing. This new table stores
--   every stat as a proper numeric column so you can sort,
--   filter, and display directly.
--
-- WHO WRITES TO THIS TABLE?
--   api/sync-selected-player-career-stats.js  (covers all players)
--   api/update-player-career-after-match.js   (post-match refresh)
--
-- SAFE TO RE-RUN: CREATE TABLE IF NOT EXISTS is idempotent.
-- ============================================================

CREATE TABLE IF NOT EXISTS player_career_stats_master (

  id                    SERIAL PRIMARY KEY,

  -- ── Player identity ────────────────────────────────────────
  player_name           TEXT        NOT NULL,
  country               TEXT        NOT NULL,  -- e.g. 'SL', 'WI', 'IND'
  cricapi_player_id     TEXT,                   -- null for players with no CricAPI ID yet
  player_pool_source    TEXT        NOT NULL DEFAULT 'cricket',
                                                -- 'ipl'     → from cricapi_player_master
                                                -- 'cricket' → from cricket_player_pool

  -- ── ODI Batting ────────────────────────────────────────────
  odi_bat_matches       INTEGER     DEFAULT 0,
  odi_bat_innings       INTEGER     DEFAULT 0,
  odi_bat_not_outs      INTEGER     DEFAULT 0,
  odi_bat_runs          INTEGER     DEFAULT 0,
  odi_bat_highest       TEXT,                   -- stored as text e.g. "183*" (not out marker)
  odi_bat_avg           NUMERIC(7,2),
  odi_bat_balls_faced   INTEGER     DEFAULT 0,
  odi_bat_strike_rate   NUMERIC(7,2),
  odi_bat_100s          INTEGER     DEFAULT 0,
  odi_bat_50s           INTEGER     DEFAULT 0,
  odi_bat_4s            INTEGER     DEFAULT 0,
  odi_bat_6s            INTEGER     DEFAULT 0,

  -- ── ODI Bowling ────────────────────────────────────────────
  odi_bowl_matches      INTEGER     DEFAULT 0,
  odi_bowl_innings      INTEGER     DEFAULT 0,
  odi_bowl_balls        INTEGER     DEFAULT 0,
  odi_bowl_runs         INTEGER     DEFAULT 0,
  odi_bowl_wickets      INTEGER     DEFAULT 0,
  odi_bowl_avg          NUMERIC(7,2),
  odi_bowl_economy      NUMERIC(5,2),
  odi_bowl_strike_rate  NUMERIC(7,2),
  odi_bowl_5wi          INTEGER     DEFAULT 0,  -- 5-wicket hauls

  -- ── T20I Batting ───────────────────────────────────────────
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

  -- ── T20I Bowling ───────────────────────────────────────────
  t20_bowl_matches      INTEGER     DEFAULT 0,
  t20_bowl_innings      INTEGER     DEFAULT 0,
  t20_bowl_balls        INTEGER     DEFAULT 0,
  t20_bowl_runs         INTEGER     DEFAULT 0,
  t20_bowl_wickets      INTEGER     DEFAULT 0,
  t20_bowl_avg          NUMERIC(7,2),
  t20_bowl_economy      NUMERIC(5,2),
  t20_bowl_strike_rate  NUMERIC(7,2),
  t20_bowl_5wi          INTEGER     DEFAULT 0,

  -- ── Test Batting ───────────────────────────────────────────
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

  -- ── Test Bowling ───────────────────────────────────────────
  test_bowl_matches     INTEGER     DEFAULT 0,
  test_bowl_innings     INTEGER     DEFAULT 0,
  test_bowl_balls       INTEGER     DEFAULT 0,
  test_bowl_runs        INTEGER     DEFAULT 0,
  test_bowl_wickets     INTEGER     DEFAULT 0,
  test_bowl_avg         NUMERIC(7,2),
  test_bowl_economy     NUMERIC(5,2),
  test_bowl_strike_rate NUMERIC(7,2),
  test_bowl_5wi         INTEGER     DEFAULT 0,
  test_bowl_10wi        INTEGER     DEFAULT 0, -- 10-wicket match hauls

  -- ── Metadata ───────────────────────────────────────────────
  data_source           TEXT        DEFAULT 'cricapi',
                                                -- 'cricapi'  → fetched from CricAPI players_info
                                                -- 'computed' → calculated from cricapi_player_match_history rows
  last_synced_at        TIMESTAMP   DEFAULT NOW(),
  updated_at            TIMESTAMP   DEFAULT NOW(),

  UNIQUE (player_name, country)
                                                -- one row per player per country
                                                -- ON CONFLICT DO UPDATE refreshes stats in place
);


-- ── Useful indexes for fast lookups ──────────────────────────

CREATE INDEX IF NOT EXISTS idx_pcsm_country
  ON player_career_stats_master (country);

CREATE INDEX IF NOT EXISTS idx_pcsm_cricapi_id
  ON player_career_stats_master (cricapi_player_id)
  WHERE cricapi_player_id IS NOT NULL;


-- ============================================================
-- VERIFICATION QUERIES (run after the sync API has populated data)
-- ============================================================

-- Check how many players have been synced per country:
-- SELECT country, player_pool_source, COUNT(*) AS players, MAX(last_synced_at) AS last_sync
-- FROM player_career_stats_master
-- GROUP BY country, player_pool_source
-- ORDER BY country;

-- Full career card for one player:
-- SELECT
--   player_name, country,
--   odi_bat_matches, odi_bat_runs, odi_bat_avg, odi_bat_strike_rate,
--   odi_bat_50s, odi_bat_100s, odi_bat_4s, odi_bat_6s,
--   odi_bowl_wickets, odi_bowl_avg, odi_bowl_economy,
--   t20_bat_matches, t20_bat_runs, t20_bat_avg, t20_bat_strike_rate,
--   t20_bat_50s, t20_bat_6s,
--   t20_bowl_wickets, t20_bowl_economy
-- FROM player_career_stats_master
-- WHERE LOWER(player_name) = LOWER('Kusal Mendis');

-- Top ODI run scorers among SL + WI players:
-- SELECT player_name, country, odi_bat_matches, odi_bat_runs, odi_bat_avg, odi_bat_100s, odi_bat_50s
-- FROM player_career_stats_master
-- WHERE country IN ('SL', 'WI')
-- ORDER BY odi_bat_runs DESC NULLS LAST;

-- Top T20 wicket takers:
-- SELECT player_name, country, t20_bowl_matches, t20_bowl_wickets, t20_bowl_avg, t20_bowl_economy
-- FROM player_career_stats_master
-- WHERE country IN ('SL', 'WI')
-- ORDER BY t20_bowl_wickets DESC NULLS LAST;
