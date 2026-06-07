-- ============================================================
-- FILE: impact_points_setup.sql
-- PURPOSE: Set up the fantasy_player_impact_points table and
--          seed every player with a default impact score of 100.
--
-- BACKGROUND:
--   The player selection screen was redesigned to show an
--   "Impact Points" column next to Budget for each player.
--   Impact Points will eventually be calculated from real
--   historical match stats (runs, wickets, catches, etc.).
--   For now, every player gets a hardcoded value of 100 so
--   the column is populated and the UI works end-to-end.
--
-- WHEN TO RE-RUN:
--   - After adding new players to a fantasy match
--   - After adding a new fantasy match
--   - The ON CONFLICT clause makes it safe to re-run anytime;
--     it will not create duplicates.
--
-- NEON INSTRUCTIONS:
--   Open your Neon project > SQL Editor, paste this entire
--   file and click Run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- STEP 1: Create the impact points table
--
-- One row per (player, match) combination.
-- fantasy_match_id is nullable so this can later support
-- career/global impact scores that are not match-specific.
-- The UNIQUE constraint prevents duplicate rows for the same
-- player + match pair.
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fantasy_player_impact_points (
  id                SERIAL PRIMARY KEY,
  fantasy_player_id INTEGER  NOT NULL,          -- references the player id used in fantasy_match_players
  fantasy_match_id  INTEGER,                    -- which match this score applies to (nullable for global scores)
  impact_points     NUMERIC  DEFAULT 100,       -- the actual score; 100 is the hardcoded default for now
  source            TEXT     DEFAULT 'default_hardcoded', -- tracks how the score was set; change to 'calculated' later
  created_at        TIMESTAMP DEFAULT NOW(),
  updated_at        TIMESTAMP DEFAULT NOW(),
  UNIQUE (fantasy_player_id, fantasy_match_id)  -- prevents duplicate rows per player+match
);


-- ────────────────────────────────────────────────────────────
-- STEP 2: Seed default impact points for all existing players
--
-- This reads every row in fantasy_match_players (the table
-- that links players to their specific fantasy matches) and
-- inserts a corresponding row in fantasy_player_impact_points
-- with impact_points = 100.
--
-- ON CONFLICT: if a row already exists for that player+match,
-- it just updates the score and timestamp — safe to re-run.
--
-- Source table used: fantasy_match_players
--   Columns used: player_id (the player), fantasy_match_id
-- ────────────────────────────────────────────────────────────

INSERT INTO fantasy_player_impact_points (
  fantasy_player_id,
  fantasy_match_id,
  impact_points,
  source,
  created_at,
  updated_at
)
SELECT
  fmp.player_id       AS fantasy_player_id,
  fmp.fantasy_match_id,
  100                 AS impact_points,
  'default_hardcoded' AS source,
  NOW()               AS created_at,
  NOW()               AS updated_at
FROM fantasy_match_players fmp
ON CONFLICT (fantasy_player_id, fantasy_match_id)
DO UPDATE SET
  impact_points = EXCLUDED.impact_points,
  updated_at    = NOW();


-- ────────────────────────────────────────────────────────────
-- VERIFICATION (optional — run separately to check the data)
--
-- Shows how many impact point rows exist per match:
--   SELECT fantasy_match_id, COUNT(*) AS player_count
--   FROM fantasy_player_impact_points
--   GROUP BY fantasy_match_id
--   ORDER BY fantasy_match_id;
--
-- Shows all rows for a specific match (replace 1 with your id):
--   SELECT * FROM fantasy_player_impact_points
--   WHERE fantasy_match_id = 1;
-- ────────────────────────────────────────────────────────────


-- ────────────────────────────────────────────────────────────
-- FUTURE: When real impact points are calculated
--
-- Update individual rows like this:
--   UPDATE fantasy_player_impact_points
--   SET impact_points = <calculated_value>,
--       source        = 'calculated',
--       updated_at    = NOW()
--   WHERE fantasy_player_id = <player_id>
--     AND fantasy_match_id  = <match_id>;
--
-- Or bulk-update from a stats table:
--   UPDATE fantasy_player_impact_points ip
--   SET impact_points = stats.score,
--       source        = 'calculated',
--       updated_at    = NOW()
--   FROM <your_stats_table> stats
--   WHERE ip.fantasy_player_id = stats.player_id
--     AND ip.fantasy_match_id  = stats.match_id;
-- ────────────────────────────────────────────────────────────
