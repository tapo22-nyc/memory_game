-- ============================================================
-- FILE: impact_budget_evaluation_v2.sql
-- PURPOSE: Evaluate Impact Scores and Player Budgets for ALL
--          players across ALL countries and ALL formats.
--
-- KEY CHANGE FROM v1:
--   v1 filtered only SL + WI players. v2 covers the entire
--   player_career_stats_master table — every country, every
--   format. PERCENT_RANK normalization now runs across the
--   full player pool, so rankings are globally meaningful.
--
-- RULES:
--   Impact score : 0–100 (clamped with GREATEST/LEAST)
--   Player budget: $50,000–$250,000 (rounded to $5,000)
--   Team budget  : $1,000,000 for 11 players
--
-- NORMALIZATION:
--   PERCENT_RANK() within each format across ALL players.
--   Economy rate is inverted (lower economy = higher score).
--
-- IMPORTANT NOTE ON PLAYER ROLES:
--   - SL/WI players → role comes from cricket_player_pool
--   - IPL/other players → role comes from cricapi_player_master
--     IF that table has a player_type column (check Part A first).
--     If not, those players will show role = 'unknown'.
--   Run Part A (schema inspection) before anything else.
--
-- RUN ORDER:
--   Part A — schema inspection
--   Part B — Query 1: normalized component scores (all players)
--   Part C — Query 2: final impact + budget (all players)
--   Part D — Query 3: distribution by format + role
-- ============================================================


-- ============================================================
-- PART A: SCHEMA INSPECTION
-- Run these before the main queries to confirm column names.
-- ============================================================

-- A1: All columns in player_career_stats_master
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'player_career_stats_master'
ORDER BY ordinal_position;

-- A2: All columns in cricket_player_pool
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'cricket_player_pool'
ORDER BY ordinal_position;

-- A3: All columns in cricapi_player_master
-- Check if player_type column exists here for IPL players
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'cricapi_player_master'
ORDER BY ordinal_position;

-- A4: How many players per country + source in master table
SELECT country, player_pool_source, COUNT(*) AS players
FROM player_career_stats_master
GROUP BY country, player_pool_source
ORDER BY player_pool_source, country;

-- A5: What player_type values exist in cricket_player_pool
SELECT player_type, country, COUNT(*) AS players
FROM cricket_player_pool
GROUP BY player_type, country
ORDER BY player_type;

-- A6: cricapi_player_master has NO player_type column — confirmed.
-- IPL/non-SL-WI players will show role = 'unknown' until you add
-- a player_type column to cricapi_player_master (see note below).

-- A7: How many players in master have NO role resolved
-- (expected to be high for IPL players — see note at bottom of file)
SELECT COUNT(*) AS players_without_role
FROM player_career_stats_master p
LEFT JOIN cricket_player_pool cpp
  ON LOWER(cpp.player_name) = LOWER(p.player_name)
 AND cpp.country = CASE p.country
       WHEN 'Sri Lanka'   THEN 'SL'
       WHEN 'West Indies' THEN 'WI'
       ELSE NULL END
WHERE cpp.player_type IS NULL;


-- ============================================================
-- PART B — QUERY 1: NORMALIZED COMPONENT SCORES (ALL PLAYERS)
--
-- Returns one row per player per format (3 rows per player).
-- Each component score is 0–100 via PERCENT_RANK across ALL
-- players in that format.
-- ============================================================

 WITH

  player_roles AS (
    SELECT
      p.player_name,
      p.country,
      CASE cpp.player_type
        WHEN 'Batsman'      THEN 'batter'
        WHEN 'Bowler'       THEN 'bowler'
        WHEN 'All Rounder'  THEN 'all_rounder'
        WHEN 'Wicketkeeper' THEN 'wicket_keeper'
        ELSE 'unknown'
      END AS role
    FROM player_career_stats_master p
    LEFT JOIN cricket_player_pool cpp
      ON LOWER(cpp.player_name) = LOWER(p.player_name)
     AND cpp.country = CASE p.country
           WHEN 'Sri Lanka'   THEN 'SL'
           WHEN 'West Indies' THEN 'WI'
           ELSE NULL
         END
    LEFT JOIN cricapi_player_master ipm
      ON LOWER(ipm.player_name) = LOWER(p.player_name)
     AND LOWER(ipm.country) = LOWER(p.country)
     AND cpp.player_name IS NULL
  ),

  unpivoted AS (
    SELECT
      p.player_name, p.country, p.player_pool_source, r.role,
      't20' AS format,
      COALESCE(p.t20_bat_matches, 0)     AS bat_matches,
      COALESCE(p.t20_bat_runs, 0)        AS bat_runs,
      COALESCE(p.t20_bat_avg, 0)         AS bat_avg,
      COALESCE(p.t20_bat_strike_rate, 0) AS bat_sr,
      COALESCE(p.t20_bat_50s, 0)         AS bat_50s,
      COALESCE(p.t20_bat_100s, 0)        AS bat_100s,
      COALESCE(p.t20_bat_4s, 0)          AS bat_4s,
      COALESCE(p.t20_bat_6s, 0)          AS bat_6s,
      COALESCE(p.t20_bowl_matches, 0)    AS bowl_matches,
      COALESCE(p.t20_bowl_wickets, 0)    AS bowl_wickets,
      COALESCE(p.t20_bowl_economy, 99)   AS bowl_economy,
      COALESCE(p.t20_bowl_5wi, 0)        AS bowl_5wi,
      0                                  AS bowl_10wi
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)

    UNION ALL

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
      COALESCE(p.odi_bowl_5wi, 0),
      0
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)

    UNION ALL

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
      COALESCE(p.test_bowl_5wi, 0),
      COALESCE(p.test_bowl_10wi, 0)
    FROM player_career_stats_master p
    JOIN player_roles r USING (player_name, country)
  ),

  normalized AS (
    SELECT
      player_name, country, player_pool_source, role, format,
      bat_matches, bat_runs, bat_avg, bat_sr,
      bat_50s, bat_100s, bat_4s, bat_6s,
      bowl_matches, bowl_wickets, bowl_economy, bowl_5wi, bowl_10wi,

      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_runs)               * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_avg)                * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_sr)                 * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_50s)                * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_100s)               * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_6s)                 * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_matches)            * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_wickets)           * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_economy))     * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_5wi)               * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_10wi)              * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_matches)           * 100)::numeric, 1) AS bowl_experience_score

    FROM unpivoted
  )

  SELECT
    player_name,
    country,
    role,
    format,
    bat_runs,     runs_score,
    bat_avg,      batting_avg_score,
    bat_sr,       strike_rate_score,
    bat_50s,      fifties_score,
    bat_100s,     hundreds_score,
                  boundary_score,
                  sixes_score,
    bowl_wickets, wickets_score,
    bowl_economy, economy_score,
    bowl_5wi,     five_wicket_score,
    bowl_10wi,    ten_wicket_score
  FROM normalized
  ORDER BY format, country, player_name;

-- ============================================================
-- PART C — QUERY 2: FINAL IMPACT SCORE + PLAYER BUDGET
--          (ALL PLAYERS, ALL FORMATS)
-- ============================================================


  WITH

  player_roles AS (
    SELECT
      p.player_name, p.country,
      CASE cpp.player_type
        WHEN 'Batsman'      THEN 'batter'
        WHEN 'Bowler'       THEN 'bowler'
        WHEN 'All Rounder'  THEN 'all_rounder'
        WHEN 'Wicketkeeper' THEN 'wicket_keeper'
        ELSE 'unknown'
      END AS role
    FROM player_career_stats_master p
    LEFT JOIN cricket_player_pool cpp
      ON LOWER(cpp.player_name) = LOWER(p.player_name)
     AND cpp.country = CASE p.country
           WHEN 'Sri Lanka'   THEN 'SL'
           WHEN 'West Indies' THEN 'WI'
           ELSE NULL END
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
      COALESCE(p.t20_bowl_economy,99) AS bowl_economy,
      COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)

    UNION ALL

    SELECT p.player_name, p.country, p.player_pool_source, r.role, 'odi',
      COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
      COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
      COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0),
      COALESCE(p.odi_bowl_matches,0), COALESCE(p.odi_bowl_wickets,0),
      COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)

    UNION ALL

    SELECT p.player_name, p.country, p.player_pool_source, r.role, 'test',
      COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
      COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
      COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0),
      COALESCE(p.test_bowl_matches,0), COALESCE(p.test_bowl_wickets,0),
      COALESCE(p.test_bowl_economy,99), COALESCE(p.test_bowl_5wi,0),
      COALESCE(p.test_bowl_10wi,0)
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  ),

  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_runs)               * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_avg)                * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_sr)                 * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_50s)                * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_100s)               * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_6s)                 * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_matches)            * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_wickets)           * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_economy))     * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_5wi)               * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_10wi)              * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_matches)           * 100)::numeric, 1) AS bowl_experience_score
    FROM unpivoted
  ),

  scored AS (
    SELECT
      player_name, country, player_pool_source, role, format,
      ROUND(CASE
        WHEN format = 't20'  THEN runs_score*0.30 + strike_rate_score*0.30 + boundary_score*0.20 + sixes_score*0.20
        WHEN format = 'odi'  THEN runs_score*0.40 + batting_avg_score*0.30 + strike_rate_score*0.30
        WHEN format = 'test' THEN hundreds_score*0.40 + fifties_score*0.30 + runs_score*0.30
      END, 1) AS batting_impact_score,
      ROUND(CASE
        WHEN format = 't20'  THEN wickets_score*0.50 + economy_score*0.50
        WHEN format = 'odi'  THEN wickets_score*0.55 + economy_score*0.45
        WHEN format = 'test' THEN wickets_score*0.40 + five_wicket_score*0.35 + ten_wicket_score*0.25
      END, 1) AS bowling_impact_score,
      ROUND(CASE
        WHEN format = 't20'  THEN bat_experience_score*0.20 + batting_avg_score*0.30 + strike_rate_score*0.30 + fifties_score*0.20
        WHEN format = 'odi'  THEN bat_experience_score*0.20 + batting_avg_score*0.40 + fifties_score*0.20 + hundreds_score*0.20
        WHEN format = 'test' THEN bat_experience_score*0.20 + batting_avg_score*0.30 + fifties_score*0.25 + hundreds_score*0.25
      END, 1) AS batting_budget_score,
      ROUND(CASE
        WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20 + wickets_score*0.40 + economy_score*0.40
        WHEN format = 'test'        THEN bowl_experience_score*0.20 + wickets_score*0.30 + five_wicket_score*0.25 +
  ten_wicket_score*0.25
      END, 1) AS bowling_budget_score
    FROM normalized
  ),

  combined AS (
    SELECT
      player_name, country, player_pool_source, role, format,
      batting_impact_score, bowling_impact_score,
      GREATEST(0, LEAST(100, ROUND(CASE
        WHEN role = 'batter'        THEN batting_impact_score
        WHEN role = 'wicket_keeper' THEN batting_impact_score
        WHEN role = 'bowler'        THEN bowling_impact_score
        WHEN role = 'all_rounder'   THEN batting_impact_score*0.50 + bowling_impact_score*0.50
        ELSE (batting_impact_score + bowling_impact_score) / 2
      END, 1))) AS final_impact_score,
      GREATEST(0, LEAST(100, ROUND(CASE
        WHEN role = 'batter'        THEN batting_budget_score
        WHEN role = 'wicket_keeper' THEN batting_budget_score
        WHEN role = 'bowler'        THEN bowling_budget_score
        WHEN role = 'all_rounder'   THEN batting_budget_score*0.50 + bowling_budget_score*0.50
        ELSE (batting_budget_score + bowling_budget_score) / 2
      END, 1))) AS raw_budget_score
    FROM scored
  )

  SELECT
    player_name,
    country,
    role,
    format,
    batting_impact_score,
    bowling_impact_score,
    final_impact_score,
    raw_budget_score,
    ROUND((50000 + (raw_budget_score / 100.0) * 200000) / 5000) * 5000 AS final_player_budget
  FROM combined
  ORDER BY format, final_impact_score DESC;


-- ============================================================
-- PART D — QUERY 3: DISTRIBUTION CHECK (ALL PLAYERS)
--
-- Summarises impact + budget spread by format and role.
-- This is your validation step before wiring into the app.
--
-- WHAT TO LOOK FOR:
--   - Impact median should be 40–60 for each role/format
--   - Budget median should be $120k–$160k
--   - P25 budget ideally above $80k
--   - P75 budget ideally below $220k
--   - 'unknown' role count should be low (fix cricapi_player_master
--     player_type column if it's high)
-- ============================================================


  WITH
  player_roles AS (
    SELECT p.player_name, p.country,
      CASE cpp.player_type
        WHEN 'Batsman' THEN 'batter' WHEN 'Bowler' THEN 'bowler'
        WHEN 'All Rounder' THEN 'all_rounder' WHEN 'Wicketkeeper' THEN 'wicket_keeper'
        ELSE 'unknown' END AS role
    FROM player_career_stats_master p
    LEFT JOIN cricket_player_pool cpp
      ON LOWER(cpp.player_name) = LOWER(p.player_name)
     AND cpp.country = CASE p.country WHEN 'Sri Lanka' THEN 'SL' WHEN 'West Indies' THEN 'WI' ELSE NULL END
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
      COALESCE(p.t20_bowl_economy,99) AS bowl_economy,
      COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, p.player_pool_source, r.role, 'odi',
      COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
      COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
      COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0), COALESCE(p.odi_bowl_matches,0),
      COALESCE(p.odi_bowl_wickets,0), COALESCE(p.odi_bowl_economy,99),
      COALESCE(p.odi_bowl_5wi,0), 0
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
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_runs)             * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_avg)              * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_sr)               * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_50s)              * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_100s)             * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY (bat_4s+bat_6s*1.5)) * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_6s)               * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bat_matches)          * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_wickets)         * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_economy))   * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_5wi)             * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_10wi)            * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format ORDER BY bowl_matches)         * 100)::numeric, 1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role, format,
      ROUND(CASE WHEN format='t20'  THEN runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20
                 WHEN format='odi'  THEN runs_score*0.40+batting_avg_score*0.30+strike_rate_score*0.30
                 WHEN format='test' THEN hundreds_score*0.40+fifties_score*0.30+runs_score*0.30 END,1) AS batting_impact_score,
      ROUND(CASE WHEN format='t20'  THEN wickets_score*0.50+economy_score*0.50
                 WHEN format='odi'  THEN wickets_score*0.55+economy_score*0.45
                 WHEN format='test' THEN wickets_score*0.40+five_wicket_score*0.35+ten_wicket_score*0.25 END,1) AS
  bowling_impact_score,
      ROUND(CASE WHEN format='t20'  THEN bat_experience_score*0.20+batting_avg_score*0.30+strike_rate_score*0.30+fifties_score*0.20
                 WHEN format='odi'  THEN bat_experience_score*0.20+batting_avg_score*0.40+fifties_score*0.20+hundreds_score*0.20
                 WHEN format='test' THEN bat_experience_score*0.20+batting_avg_score*0.30+fifties_score*0.25+hundreds_score*0.25
  END,1) AS batting_budget_score,
      ROUND(CASE WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20+wickets_score*0.40+economy_score*0.40
                 WHEN format='test' THEN bowl_experience_score*0.20+wickets_score*0.30+five_wicket_score*0.25+ten_wicket_score*0.25
  END,1) AS bowling_budget_score
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country, role, format, batting_impact_score, bowling_impact_score,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_impact_score
        WHEN role='wicket_keeper' THEN batting_impact_score
        WHEN role='bowler'        THEN bowling_impact_score
        WHEN role='all_rounder'   THEN batting_impact_score*0.50+bowling_impact_score*0.50
        ELSE (batting_impact_score+bowling_impact_score)/2 END,1))) AS final_impact_score,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_budget_score
        WHEN role='wicket_keeper' THEN batting_budget_score
        WHEN role='bowler'        THEN bowling_budget_score
        WHEN role='all_rounder'   THEN batting_budget_score*0.50+bowling_budget_score*0.50
        ELSE (batting_budget_score+bowling_budget_score)/2 END,1))) AS raw_budget_score
    FROM scored
  ),
  budgeted AS (
    SELECT *, ROUND((50000+(raw_budget_score/100.0)*200000)/5000)*5000 AS final_player_budget
    FROM combined
  )

  SELECT
    format,
    role,
    COUNT(*)                                                                            AS player_count,
    MIN(final_impact_score)                                                             AS impact_min,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1) AS impact_p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1) AS impact_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY final_impact_score)::numeric, 1) AS impact_p75,
    MAX(final_impact_score)                                                             AS impact_max,
    MIN(final_player_budget)                                                            AS budget_min,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY final_player_budget)::numeric, -3) AS budget_p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY final_player_budget)::numeric, -3) AS budget_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY final_player_budget)::numeric, -3) AS budget_p75,
    MAX(final_player_budget)                                                            AS budget_max
  FROM budgeted
  GROUP BY format, role
  ORDER BY format, role;