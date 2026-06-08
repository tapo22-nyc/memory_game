-- ============================================================
-- FILE: player_selection_active.sql
-- PURPOSE: Control which players appear in the "Select Players"
--          modal in create-team.html.
--
-- Players are sourced from fantasy_match_players. Adding an
-- is_active flag here lets you hide specific players per match
-- without deleting them from the pool.
--
-- RUN ORDER:
--   Step 1 — Add is_active column (run once)
--   Step 2 — View all players for a match/team
--   Step 3 — Set players active or inactive
-- ============================================================


-- ============================================================
-- STEP 1: ADD is_active COLUMN TO fantasy_match_players
-- Run once. Defaults all existing players to active (TRUE).
-- ============================================================

ALTER TABLE fantasy_match_players
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;


-- ============================================================
-- STEP 2: VIEW ALL PLAYERS FOR A MATCH, WITH ACTIVE STATUS
--
-- Replace fantasy_match_id = 1 with your actual match ID.
-- Optional: also filter by team_name (see commented WHERE).
-- ============================================================

SELECT
  fmp.fantasy_match_id,
  fmp.player_id,
  fmp.player_source,
  fmp.is_active,
  COALESCE(ipm.player_name, cpp.player_name)             AS player_name,
  COALESCE(ipm.team_code,   cpp.country)                 AS team_name,
  COALESCE(ipm.player_type, cpp.player_type)             AS player_type,
  COALESCE(ipm.player_cost_coins, cpp.player_cost_coins) AS price
FROM fantasy_match_players fmp
LEFT JOIN ipl_player_master ipm
  ON ipm.id = fmp.player_id
  AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
LEFT JOIN cricket_player_pool cpp
  ON cpp.id = fmp.player_id
  AND fmp.player_source = 'cricket'
WHERE fmp.fantasy_match_id = 80          -- ← change to your match ID
  -- AND COALESCE(ipm.team_code, cpp.country) = 'MI'  -- ← optionally filter by team
ORDER BY team_name, player_name;


-- ============================================================
-- STEP 3A: DEACTIVATE specific players (hide from modal)
--
-- Replace fantasy_match_id and player names as needed.
-- ============================================================

UPDATE fantasy_match_players fmp
SET is_active = FALSE
FROM (
  SELECT fmp2.player_id, fmp2.player_source
  FROM fantasy_match_players fmp2
  LEFT JOIN ipl_player_master ipm
    ON ipm.id = fmp2.player_id
    AND COALESCE(fmp2.player_source, 'ipl') = 'ipl'
  LEFT JOIN cricket_player_pool cpp
    ON cpp.id = fmp2.player_id
    AND fmp2.player_source = 'cricket'
  WHERE fmp2.fantasy_match_id = 1       -- ← change to your match ID
    AND COALESCE(ipm.player_name, cpp.player_name) IN (
      'Player Name 1',                  -- ← replace with actual names
      'Player Name 2',
      'Player Name 3'
    )
) sub
WHERE fmp.player_id    = sub.player_id
  AND fmp.player_source IS NOT DISTINCT FROM sub.player_source
  AND fmp.fantasy_match_id = 80;         -- ← same match ID as above


-- ============================================================
-- STEP 3B: REACTIVATE specific players (show in modal again)
-- Same pattern as 3A, just sets is_active = TRUE.
-- ============================================================

UPDATE fantasy_match_players fmp
SET is_active = TRUE
FROM (
  SELECT fmp2.player_id, fmp2.player_source
  FROM fantasy_match_players fmp2
  LEFT JOIN ipl_player_master ipm
    ON ipm.id = fmp2.player_id
    AND COALESCE(fmp2.player_source, 'ipl') = 'ipl'
  LEFT JOIN cricket_player_pool cpp
    ON cpp.id = fmp2.player_id
    AND fmp2.player_source = 'cricket'
  WHERE fmp2.fantasy_match_id = 80       -- ← change to your match ID
    AND COALESCE(ipm.player_name, cpp.player_name) IN (
      'Player Name 1',                  -- ← replace with actual names
      'Player Name 2'
    )
) sub
WHERE fmp.player_id    = sub.player_id
  AND fmp.player_source IS NOT DISTINCT FROM sub.player_source
  AND fmp.fantasy_match_id = 80;         -- ← same match ID as above


-- ============================================================
-- STEP 3C: DEACTIVATE AN ENTIRE TEAM for a match
-- Useful when a team is not playing (e.g., only 2 of 4 teams play).
-- ============================================================

UPDATE fantasy_match_players fmp
SET is_active = FALSE
FROM (
  SELECT fmp2.player_id, fmp2.player_source
  FROM fantasy_match_players fmp2
  LEFT JOIN ipl_player_master ipm
    ON ipm.id = fmp2.player_id
    AND COALESCE(fmp2.player_source, 'ipl') = 'ipl'
  LEFT JOIN cricket_player_pool cpp
    ON cpp.id = fmp2.player_id
    AND fmp2.player_source = 'cricket'
  WHERE fmp2.fantasy_match_id = 80       -- ← change to your match ID
    AND COALESCE(ipm.team_code, cpp.country) = 'MI' -- ← team code/country to deactivate
) sub
WHERE fmp.player_id    = sub.player_id
  AND fmp.player_source IS NOT DISTINCT FROM sub.player_source
  AND fmp.fantasy_match_id = 80;         -- ← same match ID as above


-- ============================================================
-- VERIFY: Count active vs inactive per team for a match
-- ============================================================

SELECT
  COALESCE(ipm.team_code, cpp.country) AS team,
  COUNT(*) FILTER (WHERE fmp.is_active = TRUE)  AS active,
  COUNT(*) FILTER (WHERE fmp.is_active = FALSE) AS inactive,
  COUNT(*)                                       AS total
FROM fantasy_match_players fmp
LEFT JOIN ipl_player_master ipm
  ON ipm.id = fmp.player_id
  AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
LEFT JOIN cricket_player_pool cpp
  ON cpp.id = fmp.player_id
  AND fmp.player_source = 'cricket'
WHERE fmp.fantasy_match_id = 1          -- ← change to your match ID
GROUP BY team
ORDER BY team;
