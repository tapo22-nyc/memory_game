-- ============================================================
-- FILE: impact_and_budget_formula_ideas.sql
-- PURPOSE: Ideas and test queries for calculating Impact Points
--          and Budget for each player in the fantasy team picker.
--
-- These are NOT deployed anywhere yet. Run in Neon SQL editor
-- to test and tune the weights before wiring into the app.
--
-- TWO METRICS:
--   Impact Points  — composite score reflecting fantasy value
--   Budget         — normalized price derived from impact (7.0–12.0)
--
-- FORMULA LOGIC BY PLAYER TYPE:
--   Batsman / Wicketkeeper → batting score only
--   Bowler                 → bowling score only
--   All Rounder            → 60% batting + 40% bowling
--
-- TUNABLE WEIGHTS (adjust these based on what feels right):
--   t20_bat_6s    × 0.3   — boundary hitting bonus
--   t20_bat_50s   × 1.5   — half-century bonus
--   t20_bat_100s  × 4.0   — century bonus
--   wickets/match × 15    — wicket-taking contribution
--   economy bonus × 4     — reward for economy below 9.0
--   t20_bowl_5wi  × 3.0   — 5-wicket haul bonus
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- STEP 1: Raw batting + bowling scores
-- Run this first to see the base numbers before role weighting.
-- ────────────────────────────────────────────────────────────

SELECT
  player_name,
  country,
  player_pool_source,

  -- T20 batting score: avg × (SR/100) + boundary/milestone bonuses
  ROUND(
    COALESCE(t20_bat_avg, 0) * COALESCE(t20_bat_strike_rate, 0) / 100
    + COALESCE(t20_bat_6s, 0) * 0.3
    + COALESCE(t20_bat_50s, 0) * 1.5
    + COALESCE(t20_bat_100s, 0) * 4.0
  , 2) AS t20_bat_score,

  -- T20 bowling score: wickets-per-match contribution + economy bonus
  -- Economy bonus: every run below 9.0 economy earns 4 points
  ROUND(
    (COALESCE(t20_bowl_wickets, 0)::numeric / NULLIF(t20_bowl_matches, 0)) * 15
    + GREATEST(0, (9.0 - COALESCE(t20_bowl_economy, 9.0))) * 4
    + COALESCE(t20_bowl_5wi, 0) * 3.0
  , 2) AS t20_bowl_score

FROM player_career_stats_master
WHERE country IN ('Sri Lanka', 'West Indies')
ORDER BY t20_bat_score DESC;


-- ────────────────────────────────────────────────────────────
-- STEP 2: Final impact score weighted by player role
-- Joins cricket_player_pool to get player_type (Batsman /
-- Bowler / All Rounder / Wicketkeeper).
-- ────────────────────────────────────────────────────────────

WITH scores AS (
  SELECT
    p.player_name,
    p.country,
    cpp.player_type,

    -- batting score
    COALESCE(t20_bat_avg, 0) * COALESCE(t20_bat_strike_rate, 0) / 100
    + COALESCE(t20_bat_6s, 0) * 0.3
    + COALESCE(t20_bat_50s, 0) * 1.5
    + COALESCE(t20_bat_100s, 0) * 4.0  AS bat_score,

    -- bowling score
    (COALESCE(t20_bowl_wickets, 0)::numeric / NULLIF(t20_bowl_matches, 0)) * 15
    + GREATEST(0, (9.0 - COALESCE(t20_bowl_economy, 9.0))) * 4
    + COALESCE(t20_bowl_5wi, 0) * 3.0  AS bowl_score

  FROM player_career_stats_master p
  JOIN cricket_player_pool cpp
    ON LOWER(cpp.player_name) = LOWER(p.player_name)
   AND cpp.country = CASE p.country
       WHEN 'Sri Lanka'   THEN 'SL'
       WHEN 'West Indies' THEN 'WI'
       ELSE p.country
     END
  WHERE p.country IN ('Sri Lanka', 'West Indies')
)
SELECT
  player_name,
  country,
  player_type,
  ROUND(CASE
    WHEN player_type = 'Batsman'        THEN bat_score
    WHEN player_type = 'Wicketkeeper'   THEN bat_score
    WHEN player_type = 'Bowler'         THEN bowl_score
    WHEN player_type = 'All Rounder'    THEN (bat_score * 0.6) + (bowl_score * 0.4)
    ELSE bat_score
  END, 2) AS impact_score
FROM scores
ORDER BY impact_score DESC;


-- ────────────────────────────────────────────────────────────
-- STEP 3: Normalize impact into a budget range of 7.0 → 12.0
-- Best player in pool gets 12.0, weakest gets 7.0.
-- Everyone else is scaled linearly between those.
-- ────────────────────────────────────────────────────────────

WITH scores AS (
  SELECT
    p.player_name,
    p.country,
    cpp.player_type,

    COALESCE(t20_bat_avg, 0) * COALESCE(t20_bat_strike_rate, 0) / 100
    + COALESCE(t20_bat_6s, 0) * 0.3
    + COALESCE(t20_bat_50s, 0) * 1.5
    + COALESCE(t20_bat_100s, 0) * 4.0  AS bat_score,

    (COALESCE(t20_bowl_wickets, 0)::numeric / NULLIF(t20_bowl_matches, 0)) * 15
    + GREATEST(0, (9.0 - COALESCE(t20_bowl_economy, 9.0))) * 4
    + COALESCE(t20_bowl_5wi, 0) * 3.0  AS bowl_score

  FROM player_career_stats_master p
  JOIN cricket_player_pool cpp
    ON LOWER(cpp.player_name) = LOWER(p.player_name)
   AND cpp.country = CASE p.country
       WHEN 'Sri Lanka'   THEN 'SL'
       WHEN 'West Indies' THEN 'WI'
       ELSE p.country
     END
  WHERE p.country IN ('Sri Lanka', 'West Indies')
),
impact AS (
  SELECT *,
    CASE
      WHEN player_type = 'Batsman'      THEN bat_score
      WHEN player_type = 'Wicketkeeper' THEN bat_score
      WHEN player_type = 'Bowler'       THEN bowl_score
      WHEN player_type = 'All Rounder'  THEN (bat_score * 0.6) + (bowl_score * 0.4)
      ELSE bat_score
    END AS impact_score
  FROM scores
),
minmax AS (
  SELECT MIN(impact_score) AS min_s, MAX(impact_score) AS max_s FROM impact
)
SELECT
  i.player_name,
  i.country,
  i.player_type,
  ROUND(i.impact_score, 1)  AS impact_score,
  -- scale linearly: 7.0 at min, 12.0 at max
  ROUND(
    7.0 + (i.impact_score - m.min_s) / NULLIF(m.max_s - m.min_s, 0) * 5.0
  , 1) AS suggested_budget
FROM impact i, minmax m
ORDER BY suggested_budget DESC;


-- ────────────────────────────────────────────────────────────
-- NOTES FOR TUNING
-- ────────────────────────────────────────────────────────────
--
-- After running Step 2, check these players as sanity checks:
--   Wanindu Hasaranga (WI) → should rank high on bowling
--   Nicholas Pooran (WI)   → should rank high on batting
--   Kusal Mendis (SL)      → should rank high on batting
--   Dasun Shanaka (SL)     → mid-range all-rounder
--
-- If scores feel off, adjust the multipliers at the top of
-- this file and re-run. Common tweaks:
--   - Economy bonus too high? Lower 4 → 2
--   - Batsmen dominating bowlers? Raise wickets/match × 15 → 20
--   - Budget range too compressed? Change 7.0–12.0 to 6.0–13.0
--
-- Once happy with the weights, the next step is to store
-- the calculated values in fantasy_player_impact_points and
-- a new budget column (or update the existing budget column
-- in the player pool tables).
-- ============================================================
