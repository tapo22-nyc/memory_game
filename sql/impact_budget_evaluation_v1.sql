-- ============================================================
-- FILE: impact_budget_evaluation_v1.sql
-- PURPOSE: Evaluate distribution of Impact Scores and Player
--          Budgets for all players using career stats.
--
-- RULES:
--   Impact score : always between 0 and 100
--   Player budget: always between $50,000 and $250,000
--   Team budget  : $1,000,000 for 11 players
--
-- NORMALIZATION METHOD: PERCENT_RANK() within each format.
--   - Higher stat = higher rank (0→1), multiplied by 100
--   - Economy rate is INVERTED (lower economy = better rank)
--
-- RUN ORDER:
--   Part A first  — schema inspection (confirm column names)
--   Part B second — normalized component scores (Query 1)
--   Part C third  — final impact + budget (Query 2)
--   Part D last   — distribution check (Query 3)
--
-- DO NOT UPDATE ANY TABLES — evaluation only.
-- ============================================================


-- ============================================================
-- PART A: SCHEMA INSPECTION
-- Run these first to confirm column names before anything else.
-- ============================================================

-- A1: All columns in the career stats master table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'player_career_stats_master'
ORDER BY ordinal_position;

-- A2: All columns in cricket_player_pool (SL/WI players + player_type)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'cricket_player_pool'
ORDER BY ordinal_position;

-- A3: All columns in cricapi_player_master (IPL players)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'cricapi_player_master'
ORDER BY ordinal_position;

-- A4: Quick sanity check — how many players per country + source in master table
SELECT country, player_pool_source, COUNT(*) AS players
FROM player_career_stats_master
GROUP BY country, player_pool_source
ORDER BY country;

-- A5: Check what player_type values exist in cricket_player_pool
SELECT player_type, COUNT(*) AS players
FROM cricket_player_pool
GROUP BY player_type;


-- ============================================================
-- PART B — QUERY 1: NORMALIZED COMPONENT SCORES
--
-- Unpivots the flat career stats table into one row per
-- (player, format), then applies PERCENT_RANK() within
-- each format to normalize every stat to 0–100.
--
-- Returns one row per player per format (3 rows per player).
-- ============================================================

WITH

-- ── Step 1: Resolve player_type for every player ─────────────
-- cricket_player_pool has player_type for SL/WI players.
-- cricapi_player_master may or may not — check A3 output first.
-- We fall back to NULL if neither has it.
player_roles AS (
  SELECT
    p.player_name,
    p.country,
    -- Normalise player_type labels to snake_case
    CASE COALESCE(cpp.player_type, ipm.player_type)
      WHEN 'Batsman'       THEN 'batter'
      WHEN 'Bowler'        THEN 'bowler'
      WHEN 'All Rounder'   THEN 'all_rounder'
      WHEN 'Wicketkeeper'  THEN 'wicket_keeper'
      ELSE 'unknown'
    END AS role
  FROM player_career_stats_master p
  -- SL/WI players: country stored as full name in master, short code in pool
  LEFT JOIN cricket_player_pool cpp
    ON LOWER(cpp.player_name) = LOWER(p.player_name)
   AND cpp.country = CASE p.country
         WHEN 'Sri Lanka'   THEN 'SL'
         WHEN 'West Indies' THEN 'WI'
         ELSE p.country
       END
  -- IPL players: country stored as full name in both tables
  LEFT JOIN cricapi_player_master ipm
    ON LOWER(ipm.player_name) = LOWER(p.player_name)
   AND LOWER(ipm.country) = LOWER(p.country)
   AND cpp.player_name IS NULL   -- only use ipl row if pool row didn't match
),

-- ── Step 2: Unpivot — one row per (player, format) ───────────
-- This gives us uniform columns regardless of format so we can
-- apply the same PERCENT_RANK() logic across all three formats.
unpivoted AS (

  -- T20
  SELECT
    p.player_name,
    p.country,
    p.player_pool_source,
    r.role,
    't20' AS format,
    -- batting stats
    COALESCE(p.t20_bat_matches, 0)      AS bat_matches,
    COALESCE(p.t20_bat_runs, 0)         AS bat_runs,
    COALESCE(p.t20_bat_avg, 0)          AS bat_avg,
    COALESCE(p.t20_bat_strike_rate, 0)  AS bat_sr,
    COALESCE(p.t20_bat_50s, 0)          AS bat_50s,
    COALESCE(p.t20_bat_100s, 0)         AS bat_100s,
    COALESCE(p.t20_bat_4s, 0)           AS bat_4s,
    COALESCE(p.t20_bat_6s, 0)           AS bat_6s,
    -- bowling stats
    COALESCE(p.t20_bowl_matches, 0)     AS bowl_matches,
    COALESCE(p.t20_bowl_wickets, 0)     AS bowl_wickets,
    COALESCE(p.t20_bowl_economy, 99)    AS bowl_economy,  -- 99 = no data (will rank last)
    COALESCE(p.t20_bowl_avg, 0)         AS bowl_avg,
    COALESCE(p.t20_bowl_5wi, 0)         AS bowl_5wi,
    0                                   AS bowl_10wi      -- T20 has no 10wi
  FROM player_career_stats_master p
  JOIN player_roles r USING (player_name, country)

  UNION ALL

  -- ODI
  SELECT
    p.player_name, p.country, p.player_pool_source, r.role,
    'odi' AS format,
    COALESCE(p.odi_bat_matches, 0),
    COALESCE(p.odi_bat_runs, 0),
    COALESCE(p.odi_bat_avg, 0),
    COALESCE(p.odi_bat_strike_rate, 0),
    COALESCE(p.odi_bat_50s, 0),
    COALESCE(p.odi_bat_100s, 0),
    COALESCE(p.odi_bat_4s, 0),
    COALESCE(p.odi_bat_6s, 0),
    COALESCE(p.odi_bowl_matches, 0),
    COALESCE(p.odi_bowl_wickets, 0),
    COALESCE(p.odi_bowl_economy, 99),
    COALESCE(p.odi_bowl_avg, 0),
    COALESCE(p.odi_bowl_5wi, 0),
    0
  FROM player_career_stats_master p
  JOIN player_roles r USING (player_name, country)

  UNION ALL

  -- Test
  SELECT
    p.player_name, p.country, p.player_pool_source, r.role,
    'test' AS format,
    COALESCE(p.test_bat_matches, 0),
    COALESCE(p.test_bat_runs, 0),
    COALESCE(p.test_bat_avg, 0),
    COALESCE(p.test_bat_strike_rate, 0),
    COALESCE(p.test_bat_50s, 0),
    COALESCE(p.test_bat_100s, 0),
    COALESCE(p.test_bat_4s, 0),
    COALESCE(p.test_bat_6s, 0),
    COALESCE(p.test_bowl_matches, 0),
    COALESCE(p.test_bowl_wickets, 0),
    COALESCE(p.test_bowl_economy, 99),
    COALESCE(p.test_bowl_avg, 0),
    COALESCE(p.test_bowl_5wi, 0),
    COALESCE(p.test_bowl_10wi, 0)
  FROM player_career_stats_master p
  JOIN player_roles r USING (player_name, country)
),

-- ── Step 3: Apply PERCENT_RANK within each format ────────────
-- All scores are 0–100. Economy is inverted (lower = better).
normalized AS (
  SELECT
    player_name,
    country,
    player_pool_source,
    role,
    format,

    -- raw values (kept for reference)
    bat_matches, bat_runs, bat_avg, bat_sr,
    bat_50s, bat_100s, bat_4s, bat_6s,
    bowl_matches, bowl_wickets, bowl_economy,
    bowl_5wi, bowl_10wi,

    -- batting normalized scores (0–100)
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_runs)        * 100, 1) AS runs_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_avg)         * 100, 1) AS batting_avg_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_sr)          * 100, 1) AS strike_rate_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_50s)         * 100, 1) AS fifties_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_100s)        * 100, 1) AS hundreds_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_4s)          * 100, 1) AS fours_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_6s)          * 100, 1) AS sixes_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_matches)     * 100, 1) AS bat_experience_score,

    -- combined boundary score (4s + weighted 6s)
    ROUND(PERCENT_RANK() OVER (
      PARTITION BY format
      ORDER BY (bat_4s + bat_6s * 1.5)
    ) * 100, 1) AS boundary_score,

    -- bowling normalized scores (0–100)
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_wickets)    * 100, 1) AS wickets_score,

    -- economy: INVERTED — lower economy ranks higher
    ROUND((1 - PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_economy)) * 100, 1) AS economy_score,

    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_5wi)        * 100, 1) AS five_wicket_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_10wi)       * 100, 1) AS ten_wicket_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_matches)    * 100, 1) AS bowl_experience_score

  FROM unpivoted
)

-- ── Final output of Query 1 ───────────────────────────────────
SELECT
  player_name,
  country,
  role,
  format,
  -- batting components
  bat_runs,        runs_score,
  bat_avg,         batting_avg_score,
  bat_sr,          strike_rate_score,
  bat_50s,         fifties_score,
  bat_100s,        hundreds_score,
                   boundary_score,
                   sixes_score,
  -- bowling components
  bowl_wickets,    wickets_score,
  bowl_economy,    economy_score,
  bowl_5wi,        five_wicket_score,
  bowl_10wi,       ten_wicket_score
FROM normalized
ORDER BY format, role, player_name;


-- ============================================================
-- PART C — QUERY 2: FINAL IMPACT SCORE + PLAYER BUDGET
--
-- Applies role-specific and format-specific weights to the
-- normalized scores from Part B.
--
-- impact_score : 0–100 (GREATEST/LEAST clamp)
-- player_budget: $50,000–$250,000 (rounded to nearest $5,000)
-- ============================================================

WITH

player_roles AS (
  SELECT
    p.player_name, p.country,
    CASE COALESCE(cpp.player_type, ipm.player_type)
      WHEN 'Batsman'       THEN 'batter'
      WHEN 'Bowler'        THEN 'bowler'
      WHEN 'All Rounder'   THEN 'all_rounder'
      WHEN 'Wicketkeeper'  THEN 'wicket_keeper'
      ELSE 'unknown'
    END AS role
  FROM player_career_stats_master p
  LEFT JOIN cricket_player_pool cpp
    ON LOWER(cpp.player_name) = LOWER(p.player_name)
   AND cpp.country = CASE p.country
         WHEN 'Sri Lanka' THEN 'SL' WHEN 'West Indies' THEN 'WI'
         ELSE p.country END
  LEFT JOIN cricapi_player_master ipm
    ON LOWER(ipm.player_name) = LOWER(p.player_name)
   AND LOWER(ipm.country) = LOWER(p.country)
   AND cpp.player_name IS NULL
),

unpivoted AS (
  SELECT p.player_name, p.country, p.player_pool_source, r.role, 't20' AS format,
    COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
    COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
    COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
    COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
    COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
    COALESCE(p.t20_bowl_economy,99) AS bowl_economy, COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
  FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  UNION ALL
  SELECT p.player_name, p.country, p.player_pool_source, r.role, 'odi' AS format,
    COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
    COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
    COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0),
    COALESCE(p.odi_bowl_matches,0), COALESCE(p.odi_bowl_wickets,0),
    COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
  FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  UNION ALL
  SELECT p.player_name, p.country, p.player_pool_source, r.role, 'test' AS format,
    COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
    COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
    COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0),
    COALESCE(p.test_bowl_matches,0), COALESCE(p.test_bowl_wickets,0),
    COALESCE(p.test_bowl_economy,99), COALESCE(p.test_bowl_5wi,0), COALESCE(p.test_bowl_10wi,0)
  FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
),

normalized AS (
  SELECT *,
    -- batting normalized (0–100)
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_runs)              * 100, 1) AS runs_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_avg)               * 100, 1) AS batting_avg_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_sr)                * 100, 1) AS strike_rate_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_50s)               * 100, 1) AS fifties_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_100s)              * 100, 1) AS hundreds_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY (bat_4s + bat_6s*1.5)) * 100, 1) AS boundary_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_6s)                * 100, 1) AS sixes_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_matches)           * 100, 1) AS bat_experience_score,
    -- bowling normalized (0–100)
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_wickets)          * 100, 1) AS wickets_score,
    ROUND((1 - PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_economy))    * 100, 1) AS economy_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_5wi)              * 100, 1) AS five_wicket_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_10wi)             * 100, 1) AS ten_wicket_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_matches)          * 100, 1) AS bowl_experience_score
  FROM unpivoted
),

-- ── Apply role + format specific weights ─────────────────────
scored AS (
  SELECT
    player_name, country, player_pool_source, role, format,

    -- ── BATTING IMPACT SCORE ─────────────────────────────────
    ROUND(CASE
      WHEN format = 't20' THEN
        -- T20 batter: SR and runs matter most, 6s add flair
        runs_score        * 0.30
        + strike_rate_score * 0.30
        + boundary_score    * 0.20
        + sixes_score       * 0.20
      WHEN format = 'odi' THEN
        -- ODI batter: avg and runs equally weighted, SR matters
        runs_score        * 0.40
        + batting_avg_score * 0.30
        + strike_rate_score * 0.30
      WHEN format = 'test' THEN
        -- Test batter: milestones (100s) are the premium signal
        hundreds_score    * 0.40
        + fifties_score     * 0.30
        + runs_score        * 0.30
    END, 1) AS batting_impact_score,

    -- ── BOWLING IMPACT SCORE ─────────────────────────────────
    ROUND(CASE
      WHEN format = 't20' THEN
        -- T20 bowler: economy is king in T20
        wickets_score     * 0.50
        + economy_score     * 0.50
      WHEN format = 'odi' THEN
        -- ODI bowler: wickets slightly more important than economy
        wickets_score     * 0.55
        + economy_score     * 0.45
      WHEN format = 'test' THEN
        -- Test bowler: wicket hauls (5wi, 10wi) signal quality
        wickets_score     * 0.40
        + five_wicket_score * 0.35
        + ten_wicket_score  * 0.25
    END, 1) AS bowling_impact_score,

    -- ── BATTING BUDGET SCORE ─────────────────────────────────
    ROUND(CASE
      WHEN format = 't20' THEN
        bat_experience_score * 0.20
        + batting_avg_score  * 0.30
        + strike_rate_score  * 0.30
        + fifties_score      * 0.20
      WHEN format = 'odi' THEN
        bat_experience_score * 0.20
        + batting_avg_score  * 0.40
        + fifties_score      * 0.20
        + hundreds_score     * 0.20
      WHEN format = 'test' THEN
        bat_experience_score * 0.20
        + batting_avg_score  * 0.30
        + fifties_score      * 0.25
        + hundreds_score     * 0.25
    END, 1) AS batting_budget_score,

    -- ── BOWLING BUDGET SCORE ─────────────────────────────────
    ROUND(CASE
      WHEN format = 't20' THEN
        bowl_experience_score * 0.20
        + wickets_score       * 0.40
        + economy_score       * 0.40
      WHEN format = 'odi' THEN
        bowl_experience_score * 0.20
        + wickets_score       * 0.40
        + economy_score       * 0.40
      WHEN format = 'test' THEN
        bowl_experience_score * 0.20
        + wickets_score       * 0.30
        + five_wicket_score   * 0.25
        + ten_wicket_score    * 0.25
    END, 1) AS bowling_budget_score

  FROM normalized
),

-- ── Combine batting + bowling by role ────────────────────────
combined AS (
  SELECT
    player_name, country, player_pool_source, role, format,
    batting_impact_score,
    bowling_impact_score,

    -- Final impact: role determines the split
    GREATEST(0, LEAST(100,
      ROUND(CASE
        WHEN role = 'batter'       THEN batting_impact_score
        WHEN role = 'wicket_keeper'THEN batting_impact_score
        WHEN role = 'bowler'       THEN bowling_impact_score
        WHEN role = 'all_rounder'  THEN batting_impact_score * 0.50 + bowling_impact_score * 0.50
        ELSE batting_impact_score  -- fallback
      END, 1)
    )) AS final_impact_score,

    -- Raw budget score (0–100)
    GREATEST(0, LEAST(100,
      ROUND(CASE
        WHEN role = 'batter'       THEN batting_budget_score
        WHEN role = 'wicket_keeper'THEN batting_budget_score
        WHEN role = 'bowler'       THEN bowling_budget_score
        WHEN role = 'all_rounder'  THEN batting_budget_score * 0.50 + bowling_budget_score * 0.50
        ELSE batting_budget_score
      END, 1)
    )) AS raw_budget_score

  FROM scored
),

-- ── Scale budget to $50,000–$250,000, round to $5,000 ────────
budgeted AS (
  SELECT
    player_name, country, player_pool_source, role, format,
    batting_impact_score,
    bowling_impact_score,
    final_impact_score,
    raw_budget_score,
    -- Linear scale: score 0 → $50k, score 100 → $250k
    -- Round to nearest $5,000
    ROUND(
      (50000 + (raw_budget_score / 100.0) * 200000) / 5000
    ) * 5000 AS final_player_budget
  FROM combined
)

-- ── Query 2 output ────────────────────────────────────────────
SELECT
  player_name,
  country,
  role,
  format,
  batting_impact_score,
  bowling_impact_score,
  final_impact_score,
  raw_budget_score,
  final_player_budget
FROM budgeted
ORDER BY format, role, final_impact_score DESC;


-- ============================================================
-- PART D — QUERY 3: DISTRIBUTION CHECK
--
-- Summarises the spread of impact scores and budgets by
-- format and role. Use this to validate that scores feel
-- sensible before committing to the formula.
--
-- KEY THINGS TO LOOK FOR:
--   - Median impact should be roughly 40–60 for most roles
--   - No role should have median budget near the floor ($50k)
--     or ceiling ($250k) — that signals weights need tuning
--   - P25–P75 range should be reasonably wide (not all bunched)
-- ============================================================

WITH
-- (paste the full CTE chain from Query 2 above here — all CTEs up to budgeted)
-- For convenience, the full self-contained version is below:

player_roles AS (
  SELECT p.player_name, p.country,
    CASE COALESCE(cpp.player_type, ipm.player_type)
      WHEN 'Batsman' THEN 'batter' WHEN 'Bowler' THEN 'bowler'
      WHEN 'All Rounder' THEN 'all_rounder' WHEN 'Wicketkeeper' THEN 'wicket_keeper'
      ELSE 'unknown' END AS role
  FROM player_career_stats_master p
  LEFT JOIN cricket_player_pool cpp
    ON LOWER(cpp.player_name) = LOWER(p.player_name)
   AND cpp.country = CASE p.country WHEN 'Sri Lanka' THEN 'SL' WHEN 'West Indies' THEN 'WI' ELSE p.country END
  LEFT JOIN cricapi_player_master ipm
    ON LOWER(ipm.player_name) = LOWER(p.player_name)
   AND LOWER(ipm.country) = LOWER(p.country) AND cpp.player_name IS NULL
),
unpivoted AS (
  SELECT p.player_name, p.country, p.player_pool_source, r.role, 't20' AS format,
    COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
    COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
    COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
    COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
    COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
    COALESCE(p.t20_bowl_economy,99) AS bowl_economy, COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
  FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  UNION ALL
  SELECT p.player_name, p.country, p.player_pool_source, r.role, 'odi',
    COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
    COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
    COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0), COALESCE(p.odi_bowl_matches,0),
    COALESCE(p.odi_bowl_wickets,0), COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
  FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  UNION ALL
  SELECT p.player_name, p.country, p.player_pool_source, r.role, 'test',
    COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
    COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
    COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0), COALESCE(p.test_bowl_matches,0),
    COALESCE(p.test_bowl_wickets,0), COALESCE(p.test_bowl_economy,99),
    COALESCE(p.test_bowl_5wi,0), COALESCE(p.test_bowl_10wi,0)
  FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
),
normalized AS (
  SELECT *,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_runs)              * 100,1) AS runs_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_avg)               * 100,1) AS batting_avg_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_sr)                * 100,1) AS strike_rate_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_50s)               * 100,1) AS fifties_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_100s)              * 100,1) AS hundreds_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY (bat_4s+bat_6s*1.5))  * 100,1) AS boundary_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_6s)                * 100,1) AS sixes_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_matches)           * 100,1) AS bat_experience_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_wickets)          * 100,1) AS wickets_score,
    ROUND((1-PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_economy))      * 100,1) AS economy_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_5wi)              * 100,1) AS five_wicket_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_10wi)             * 100,1) AS ten_wicket_score,
    ROUND(PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_matches)          * 100,1) AS bowl_experience_score
  FROM unpivoted
),
scored AS (
  SELECT player_name, country, player_pool_source, role, format,
    ROUND(CASE WHEN format='t20'  THEN runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20
               WHEN format='odi'  THEN runs_score*0.40+batting_avg_score*0.30+strike_rate_score*0.30
               WHEN format='test' THEN hundreds_score*0.40+fifties_score*0.30+runs_score*0.30 END,1) AS batting_impact_score,
    ROUND(CASE WHEN format='t20'  THEN wickets_score*0.50+economy_score*0.50
               WHEN format='odi'  THEN wickets_score*0.55+economy_score*0.45
               WHEN format='test' THEN wickets_score*0.40+five_wicket_score*0.35+ten_wicket_score*0.25 END,1) AS bowling_impact_score,
    ROUND(CASE WHEN format='t20'  THEN bat_experience_score*0.20+batting_avg_score*0.30+strike_rate_score*0.30+fifties_score*0.20
               WHEN format='odi'  THEN bat_experience_score*0.20+batting_avg_score*0.40+fifties_score*0.20+hundreds_score*0.20
               WHEN format='test' THEN bat_experience_score*0.20+batting_avg_score*0.30+fifties_score*0.25+hundreds_score*0.25 END,1) AS batting_budget_score,
    ROUND(CASE WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20+wickets_score*0.40+economy_score*0.40
               WHEN format='test' THEN bowl_experience_score*0.20+wickets_score*0.30+five_wicket_score*0.25+ten_wicket_score*0.25 END,1) AS bowling_budget_score
  FROM normalized
),
combined AS (
  SELECT player_name, country, role, format, batting_impact_score, bowling_impact_score,
    GREATEST(0,LEAST(100, ROUND(CASE
      WHEN role IN ('batter','wicket_keeper') THEN batting_impact_score
      WHEN role = 'bowler'      THEN bowling_impact_score
      WHEN role = 'all_rounder' THEN batting_impact_score*0.50+bowling_impact_score*0.50
      ELSE batting_impact_score END,1))) AS final_impact_score,
    GREATEST(0,LEAST(100, ROUND(CASE
      WHEN role IN ('batter','wicket_keeper') THEN batting_budget_score
      WHEN role = 'bowler'      THEN bowling_budget_score
      WHEN role = 'all_rounder' THEN batting_budget_score*0.50+bowling_budget_score*0.50
      ELSE batting_budget_score END,1))) AS raw_budget_score
  FROM scored
),
budgeted AS (
  SELECT *, ROUND((50000+(raw_budget_score/100.0)*200000)/5000)*5000 AS final_player_budget
  FROM combined
)

-- ── Query 3: Distribution summary ────────────────────────────
SELECT
  format,
  role,
  COUNT(*)                                                             AS player_count,
  -- Impact score distribution
  MIN(final_impact_score)                                             AS impact_min,
  ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1) AS impact_p25,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1) AS impact_median,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1) AS impact_p75,
  MAX(final_impact_score)                                             AS impact_max,
  -- Budget distribution
  MIN(final_player_budget)                                            AS budget_min,
  ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY final_player_budget)::numeric, -3) AS budget_p25,
  ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY final_player_budget)::numeric, -3) AS budget_median,
  ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY final_player_budget)::numeric, -3) AS budget_p75,
  MAX(final_player_budget)                                            AS budget_max
FROM budgeted
GROUP BY format, role
ORDER BY format, role;


-- ============================================================
-- TUNING NOTES
-- ============================================================
--
-- WHAT GOOD DISTRIBUTION LOOKS LIKE:
--   - Impact median around 45–55 per role/format
--   - Budget median around $130k–$150k (middle of $50k–$250k)
--   - P25 budget above $75k, P75 below $220k
--   - No role stuck at floor (0) or ceiling (100) for impact
--
-- COMMON FIXES IF DISTRIBUTION LOOKS WRONG:
--   - All batters scoring low in Test? → raise runs_score weight
--   - Bowlers bunched near top? → add bowl_experience_score weight
--   - Budgets all near $50k? → the raw_budget_score weights are
--     too conservative; raise the heavier stats' weights
--   - All-rounders dominating? → lower both batting+bowling weight
--     or add a mild penalty for role = all_rounder
--
-- ONCE HAPPY WITH DISTRIBUTION:
--   Next step is to wire these formulas into:
--   api/calculate-player-impact-budget.js
--   which saves the results to fantasy_player_impact_points
--   and updates the budget columns in the player tables.
-- ============================================================
