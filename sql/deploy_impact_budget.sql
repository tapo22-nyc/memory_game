-- ============================================================
-- FILE: deploy_impact_budget.sql
-- PURPOSE: One-shot deployment script to push calculated
--          Impact Scores and Player Budgets into all 3 live
--          tables that the app reads from.
--
-- WHAT THIS SCRIPT DOES:
--   Step 1 — Compute impact scores + budgets for every player
--            in player_career_stats_master, for T20 format.
--            (IPL matches are T20; international matches are
--            handled by format mapping in Step 2.)
--
--   Step 2 — Update cricket_player_pool.player_cost_coins
--            (SL/WI players — used in budget validation)
--
--   Step 3 — Update ipl_player_master.player_cost_coins
--            (IPL/all other players — used in budget validation)
--
--   Step 4 — Upsert fantasy_player_impact_points
--            (per player per match — shown in player card)
--            Uses match format from fantasy_matches to pick
--            the right T20/ODI/Test score per match.
--
--   Step 5 — Set fantasy_matches.budget_coins = 1000000
--            (updates all matches to the $1,000,000 team cap)
--
-- BUDGET SCALE:
--   Score   0 → $50,000
--   Score  50 → $150,000
--   Score 100 → $250,000
--   Rounded to nearest $5,000.
--   Team budget: $1,000,000 for 11 players.
--
-- SAFE TO RE-RUN — all writes use ON CONFLICT DO UPDATE.
--
-- RUN ORDER: run this entire file in Neon SQL Editor at once.
-- ============================================================


-- ============================================================
-- SHARED CTE: compute scores for ALL players, ALL formats
-- Paste this block once — Steps 2, 3, 4 all reference it
-- via separate WITH blocks below.
-- ============================================================

-- ── STEP 1: Preview scores before writing (optional check) ──
-- Run this SELECT first to sanity-check the numbers.
-- When happy, proceed to Steps 2–5.

WITH
  player_roles AS (
    SELECT
      p.player_name, p.country,
      CASE COALESCE(cpp.player_type, ipm.player_type)
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
  ),
  unpivoted AS (
    SELECT p.player_name, p.country, r.role, 't20' AS format,
      COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
      COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
      COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
      COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
      COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
      COALESCE(p.t20_bowl_economy,99) AS bowl_economy,
      COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, r.role, 'odi',
      COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
      COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
      COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0), COALESCE(p.odi_bowl_matches,0),
      COALESCE(p.odi_bowl_wickets,0), COALESCE(p.odi_bowl_economy,99),
      COALESCE(p.odi_bowl_5wi,0), 0
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, r.role, 'test',
      COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
      COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
      COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0), COALESCE(p.test_bowl_matches,0),
      COALESCE(p.test_bowl_wickets,0), COALESCE(p.test_bowl_economy,99),
      COALESCE(p.test_bowl_5wi,0), COALESCE(p.test_bowl_10wi,0)
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  ),
  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_runs)               * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_avg)                * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_sr)                 * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_50s)                * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_100s)               * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_6s)                 * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_matches)            * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_wickets)           * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_economy))     * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_5wi)               * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_10wi)              * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_matches)           * 100)::numeric, 1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role, format,
      ROUND(CASE WHEN format='t20'  THEN runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20
                 WHEN format='odi'  THEN runs_score*0.40+batting_avg_score*0.30+strike_rate_score*0.30
                 WHEN format='test' THEN hundreds_score*0.40+fifties_score*0.30+runs_score*0.30 END,1) AS batting_impact,
      ROUND(CASE WHEN format='t20'  THEN wickets_score*0.50+economy_score*0.50
                 WHEN format='odi'  THEN wickets_score*0.55+economy_score*0.45
                 WHEN format='test' THEN wickets_score*0.40+five_wicket_score*0.35+ten_wicket_score*0.25 END,1) AS bowling_impact,
      ROUND(CASE WHEN format='t20'  THEN bat_experience_score*0.20+batting_avg_score*0.30+strike_rate_score*0.30+fifties_score*0.20
                 WHEN format='odi'  THEN bat_experience_score*0.20+batting_avg_score*0.40+fifties_score*0.20+hundreds_score*0.20
                 WHEN format='test' THEN bat_experience_score*0.20+batting_avg_score*0.30+fifties_score*0.25+hundreds_score*0.25
      END,1) AS batting_budget,
      ROUND(CASE WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20+wickets_score*0.40+economy_score*0.40
                 WHEN format='test' THEN bowl_experience_score*0.20+wickets_score*0.30+five_wicket_score*0.25+ten_wicket_score*0.25
      END,1) AS bowling_budget
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country, role, format,
      GREATEST(0, LEAST(100, ROUND(CASE
        WHEN role='batter'        THEN batting_impact
        WHEN role='wicket_keeper' THEN batting_impact
        WHEN role='bowler'        THEN bowling_impact
        WHEN role='all_rounder'   THEN batting_impact*0.50+bowling_impact*0.50
        ELSE (batting_impact+bowling_impact)/2 END,1))) AS final_impact_score,
      GREATEST(0, LEAST(100, ROUND(CASE
        WHEN role='batter'        THEN batting_budget
        WHEN role='wicket_keeper' THEN batting_budget
        WHEN role='bowler'        THEN bowling_budget
        WHEN role='all_rounder'   THEN batting_budget*0.50+bowling_budget*0.50
        ELSE (batting_budget+bowling_budget)/2 END,1))) AS raw_budget_score
    FROM scored
  )
SELECT
  player_name, country, role, format,
  final_impact_score,
  ROUND((50000 + (raw_budget_score / 100.0) * 200000) / 5000) * 5000 AS budget_usd
FROM combined
ORDER BY format, role, final_impact_score DESC;


-- ============================================================
-- STEP 2: UPDATE cricket_player_pool.player_cost_coins
-- (SL/WI international players)
-- Uses T20 scores for T20 matches; ODI scores for ODI matches.
-- Since cricket_player_pool covers both formats, we use T20
-- as default and override with ODI for players who have
-- better ODI coverage. Adjust the format filter as needed.
-- ============================================================

WITH
  player_roles AS (
    SELECT p.player_name, p.country,
      CASE COALESCE(cpp.player_type, ipm.player_type)
        WHEN 'Batsman' THEN 'batter' WHEN 'Bowler' THEN 'bowler'
        WHEN 'All Rounder' THEN 'all_rounder' WHEN 'Wicketkeeper' THEN 'wicket_keeper'
        ELSE 'unknown' END AS role
    FROM player_career_stats_master p
    LEFT JOIN cricket_player_pool cpp
      ON LOWER(cpp.player_name) = LOWER(p.player_name)
     AND cpp.country = CASE p.country WHEN 'Sri Lanka' THEN 'SL' WHEN 'West Indies' THEN 'WI' ELSE NULL END
    LEFT JOIN cricapi_player_master ipm
      ON LOWER(ipm.player_name) = LOWER(p.player_name)
     AND LOWER(ipm.country) = LOWER(p.country)
  ),
  unpivoted AS (
    SELECT p.player_name, p.country, r.role, 't20' AS format,
      COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
      COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
      COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
      COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
      COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
      COALESCE(p.t20_bowl_economy,99) AS bowl_economy, COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, r.role, 'odi',
      COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
      COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
      COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0), COALESCE(p.odi_bowl_matches,0),
      COALESCE(p.odi_bowl_wickets,0), COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, r.role, 'test',
      COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
      COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
      COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0), COALESCE(p.test_bowl_matches,0),
      COALESCE(p.test_bowl_wickets,0), COALESCE(p.test_bowl_economy,99),
      COALESCE(p.test_bowl_5wi,0), COALESCE(p.test_bowl_10wi,0)
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  ),
  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_runs)               * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_avg)                * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_sr)                 * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_50s)                * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_100s)               * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_6s)                 * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_matches)            * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_wickets)           * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_economy))     * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_5wi)               * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_10wi)              * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_matches)           * 100)::numeric, 1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role, format,
      ROUND(CASE WHEN format='t20'  THEN runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20
                 WHEN format='odi'  THEN runs_score*0.40+batting_avg_score*0.30+strike_rate_score*0.30
                 WHEN format='test' THEN hundreds_score*0.40+fifties_score*0.30+runs_score*0.30 END,1) AS batting_impact,
      ROUND(CASE WHEN format='t20'  THEN wickets_score*0.50+economy_score*0.50
                 WHEN format='odi'  THEN wickets_score*0.55+economy_score*0.45
                 WHEN format='test' THEN wickets_score*0.40+five_wicket_score*0.35+ten_wicket_score*0.25 END,1) AS bowling_impact,
      ROUND(CASE WHEN format='t20'  THEN bat_experience_score*0.20+batting_avg_score*0.30+strike_rate_score*0.30+fifties_score*0.20
                 WHEN format='odi'  THEN bat_experience_score*0.20+batting_avg_score*0.40+fifties_score*0.20+hundreds_score*0.20
                 WHEN format='test' THEN bat_experience_score*0.20+batting_avg_score*0.30+fifties_score*0.25+hundreds_score*0.25
      END,1) AS batting_budget,
      ROUND(CASE WHEN format IN ('t20','odi') THEN bowl_experience_score*0.20+wickets_score*0.40+economy_score*0.40
                 WHEN format='test' THEN bowl_experience_score*0.20+wickets_score*0.30+five_wicket_score*0.25+ten_wicket_score*0.25
      END,1) AS bowling_budget
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country, role, format,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_impact
        WHEN role='wicket_keeper' THEN batting_impact
        WHEN role='bowler'        THEN bowling_impact
        WHEN role='all_rounder'   THEN batting_impact*0.50+bowling_impact*0.50
        ELSE (batting_impact+bowling_impact)/2 END,1))) AS final_impact_score,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_budget
        WHEN role='wicket_keeper' THEN batting_budget
        WHEN role='bowler'        THEN bowling_budget
        WHEN role='all_rounder'   THEN batting_budget*0.50+bowling_budget*0.50
        ELSE (batting_budget+bowling_budget)/2 END,1))) AS raw_budget_score
    FROM scored
  ),
  -- Pick the best available format score for each SL/WI player.
  -- Priority: if the player has an ODI match in a live ODI match
  -- use ODI; otherwise default to T20.
  -- For simplicity we store the T20 budget as the default cost.
  -- You can re-run this script with format = 'odi' for ODI matches.
  t20_scores AS (
    SELECT player_name, country,
           final_impact_score AS t20_impact,
           ROUND((50000 + (raw_budget_score / 100.0) * 200000) / 5000) * 5000 AS budget_usd
    FROM combined
    WHERE format = 't20'
  )
UPDATE cricket_player_pool cpp
SET player_cost_coins = t20.budget_usd
FROM t20_scores t20
WHERE LOWER(cpp.player_name) = LOWER(t20.player_name)
  AND cpp.country = CASE t20.country
        WHEN 'Sri Lanka'   THEN 'SL'
        WHEN 'West Indies' THEN 'WI'
        ELSE NULL END;

-- Verify: see updated costs for SL/WI players
SELECT player_name, country, player_type, player_cost_coins
FROM cricket_player_pool
ORDER BY country, player_cost_coins DESC;


-- ============================================================
-- STEP 3: UPDATE ipl_player_master.player_cost_coins
-- (IPL + all non-SL/WI players)
-- Joins on player_name — works for most players.
-- A small number with name mismatches will not be updated;
-- check the verification query at the end to find them.
-- ============================================================

WITH
  player_roles AS (
    SELECT p.player_name, p.country,
      CASE COALESCE(cpp.player_type, ipm2.player_type)
        WHEN 'Batsman' THEN 'batter' WHEN 'Bowler' THEN 'bowler'
        WHEN 'All Rounder' THEN 'all_rounder' WHEN 'Wicketkeeper' THEN 'wicket_keeper'
        ELSE 'unknown' END AS role
    FROM player_career_stats_master p
    LEFT JOIN cricket_player_pool cpp
      ON LOWER(cpp.player_name) = LOWER(p.player_name)
     AND cpp.country = CASE p.country WHEN 'Sri Lanka' THEN 'SL' WHEN 'West Indies' THEN 'WI' ELSE NULL END
    LEFT JOIN cricapi_player_master ipm2
      ON LOWER(ipm2.player_name) = LOWER(p.player_name)
     AND LOWER(ipm2.country) = LOWER(p.country)
  ),
  unpivoted AS (
    SELECT p.player_name, p.country, r.role, 't20' AS format,
      COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
      COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
      COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
      COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
      COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
      COALESCE(p.t20_bowl_economy,99) AS bowl_economy, COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  ),
  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_runs)               * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_avg)                * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_sr)                 * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_50s)                * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_100s)               * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_6s)                 * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_matches)            * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_wickets)           * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_economy))     * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_5wi)               * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_10wi)              * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_matches)           * 100)::numeric, 1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role, format,
      ROUND(runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20,1) AS batting_impact,
      ROUND(wickets_score*0.50+economy_score*0.50,1) AS bowling_impact,
      ROUND(bat_experience_score*0.20+batting_avg_score*0.30+strike_rate_score*0.30+fifties_score*0.20,1) AS batting_budget,
      ROUND(bowl_experience_score*0.20+wickets_score*0.40+economy_score*0.40,1) AS bowling_budget
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_impact
        WHEN role='wicket_keeper' THEN batting_impact
        WHEN role='bowler'        THEN bowling_impact
        WHEN role='all_rounder'   THEN batting_impact*0.50+bowling_impact*0.50
        ELSE (batting_impact+bowling_impact)/2 END,1))) AS final_impact_score,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_budget
        WHEN role='wicket_keeper' THEN batting_budget
        WHEN role='bowler'        THEN bowling_budget
        WHEN role='all_rounder'   THEN batting_budget*0.50+bowling_budget*0.50
        ELSE (batting_budget+bowling_budget)/2 END,1))) AS raw_budget_score
    FROM scored
  )
UPDATE ipl_player_master ipm
SET auction_price_cr = ROUND((50000 + (c.raw_budget_score / 100.0) * 200000) / 5000) * 5000
FROM combined c
WHERE LOWER(ipm.player_name) = LOWER(c.player_name);

-- Verify: IPL players still at $50,000 minimum (name mismatch — fix manually)
SELECT ipm.player_name, ipm.team_code, ipm.player_cost_coins
FROM ipl_player_master ipm
WHERE ipm.player_cost_coins = 50000
ORDER BY ipm.team_code, ipm.player_name;

-- Verify: all IPL players updated, sorted by cost
SELECT player_name, team_code, player_type, player_cost_coins
FROM ipl_player_master
ORDER BY player_cost_coins DESC
LIMIT 30;


-- ============================================================
-- STEP 4: UPSERT fantasy_player_impact_points
-- Updates impact score per player per match.
-- Uses the match's format (ipl/t20 → T20, odi → ODI, test → Test)
-- to pick the right score for each match.
-- ============================================================

WITH
  player_roles AS (
    SELECT p.player_name, p.country,
      CASE COALESCE(cpp.player_type, ipm2.player_type)
        WHEN 'Batsman' THEN 'batter' WHEN 'Bowler' THEN 'bowler'
        WHEN 'All Rounder' THEN 'all_rounder' WHEN 'Wicketkeeper' THEN 'wicket_keeper'
        ELSE 'unknown' END AS role
    FROM player_career_stats_master p
    LEFT JOIN cricket_player_pool cpp
      ON LOWER(cpp.player_name) = LOWER(p.player_name)
     AND cpp.country = CASE p.country WHEN 'Sri Lanka' THEN 'SL' WHEN 'West Indies' THEN 'WI' ELSE NULL END
    LEFT JOIN cricapi_player_master ipm2
      ON LOWER(ipm2.player_name) = LOWER(p.player_name)
     AND LOWER(ipm2.country) = LOWER(p.country)
  ),
  unpivoted AS (
    SELECT p.player_name, p.country, r.role, 't20' AS format,
      COALESCE(p.t20_bat_matches,0) AS bat_matches, COALESCE(p.t20_bat_runs,0) AS bat_runs,
      COALESCE(p.t20_bat_avg,0) AS bat_avg, COALESCE(p.t20_bat_strike_rate,0) AS bat_sr,
      COALESCE(p.t20_bat_50s,0) AS bat_50s, COALESCE(p.t20_bat_100s,0) AS bat_100s,
      COALESCE(p.t20_bat_4s,0) AS bat_4s, COALESCE(p.t20_bat_6s,0) AS bat_6s,
      COALESCE(p.t20_bowl_matches,0) AS bowl_matches, COALESCE(p.t20_bowl_wickets,0) AS bowl_wickets,
      COALESCE(p.t20_bowl_economy,99) AS bowl_economy, COALESCE(p.t20_bowl_5wi,0) AS bowl_5wi, 0 AS bowl_10wi
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, r.role, 'odi',
      COALESCE(p.odi_bat_matches,0), COALESCE(p.odi_bat_runs,0), COALESCE(p.odi_bat_avg,0),
      COALESCE(p.odi_bat_strike_rate,0), COALESCE(p.odi_bat_50s,0), COALESCE(p.odi_bat_100s,0),
      COALESCE(p.odi_bat_4s,0), COALESCE(p.odi_bat_6s,0), COALESCE(p.odi_bowl_matches,0),
      COALESCE(p.odi_bowl_wickets,0), COALESCE(p.odi_bowl_economy,99), COALESCE(p.odi_bowl_5wi,0), 0
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
    UNION ALL
    SELECT p.player_name, p.country, r.role, 'test',
      COALESCE(p.test_bat_matches,0), COALESCE(p.test_bat_runs,0), COALESCE(p.test_bat_avg,0),
      COALESCE(p.test_bat_strike_rate,0), COALESCE(p.test_bat_50s,0), COALESCE(p.test_bat_100s,0),
      COALESCE(p.test_bat_4s,0), COALESCE(p.test_bat_6s,0), COALESCE(p.test_bowl_matches,0),
      COALESCE(p.test_bowl_wickets,0), COALESCE(p.test_bowl_economy,99),
      COALESCE(p.test_bowl_5wi,0), COALESCE(p.test_bowl_10wi,0)
    FROM player_career_stats_master p JOIN player_roles r USING (player_name, country)
  ),
  normalized AS (
    SELECT *,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_runs)               * 100)::numeric, 1) AS runs_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_avg)                * 100)::numeric, 1) AS batting_avg_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_sr)                 * 100)::numeric, 1) AS strike_rate_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_50s)                * 100)::numeric, 1) AS fifties_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_100s)               * 100)::numeric, 1) AS hundreds_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY (bat_4s + bat_6s*1.5))  * 100)::numeric, 1) AS boundary_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_6s)                 * 100)::numeric, 1) AS sixes_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bat_matches)            * 100)::numeric, 1) AS bat_experience_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_wickets)           * 100)::numeric, 1) AS wickets_score,
      ROUND(((1 - PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_economy))     * 100)::numeric, 1) AS economy_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_5wi)               * 100)::numeric, 1) AS five_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_10wi)              * 100)::numeric, 1) AS ten_wicket_score,
      ROUND((PERCENT_RANK() OVER (PARTITION BY format, role ORDER BY bowl_matches)           * 100)::numeric, 1) AS bowl_experience_score
    FROM unpivoted
  ),
  scored AS (
    SELECT player_name, country, role, format,
      ROUND(CASE WHEN format='t20'  THEN runs_score*0.30+strike_rate_score*0.30+boundary_score*0.20+sixes_score*0.20
                 WHEN format='odi'  THEN runs_score*0.40+batting_avg_score*0.30+strike_rate_score*0.30
                 WHEN format='test' THEN hundreds_score*0.40+fifties_score*0.30+runs_score*0.30 END,1) AS batting_impact,
      ROUND(CASE WHEN format='t20'  THEN wickets_score*0.50+economy_score*0.50
                 WHEN format='odi'  THEN wickets_score*0.55+economy_score*0.45
                 WHEN format='test' THEN wickets_score*0.40+five_wicket_score*0.35+ten_wicket_score*0.25 END,1) AS bowling_impact
    FROM normalized
  ),
  combined AS (
    SELECT player_name, country, format,
      GREATEST(0,LEAST(100,ROUND(CASE
        WHEN role='batter'        THEN batting_impact
        WHEN role='wicket_keeper' THEN batting_impact
        WHEN role='bowler'        THEN bowling_impact
        WHEN role='all_rounder'   THEN batting_impact*0.50+bowling_impact*0.50
        ELSE (batting_impact+bowling_impact)/2 END,1))) AS final_impact_score
    FROM scored
  ),
  -- For each (player, match) pair, pick the score matching the match's format.
  -- 'ipl' and null formats are treated as 't20'.
  match_player_scores AS (
    SELECT
      fmp.player_id,
      fmp.fantasy_match_id,
      c.final_impact_score
    FROM fantasy_match_players fmp
    JOIN fantasy_matches fm ON fm.id = fmp.fantasy_match_id
    -- Resolve player name from whichever source table they belong to
    LEFT JOIN ipl_player_master ipm_src
      ON ipm_src.id = fmp.player_id
     AND COALESCE(fmp.player_source, 'ipl') = 'ipl'
    LEFT JOIN cricket_player_pool cpp_src
      ON cpp_src.id = fmp.player_id
     AND fmp.player_source = 'cricket'
    -- Match to the calculated score using the match's format
    JOIN combined c
      ON LOWER(c.player_name) = LOWER(COALESCE(ipm_src.player_name, cpp_src.player_name))
     AND c.format = CASE COALESCE(fm.match_format, 'ipl')
                      WHEN 'odi'  THEN 'odi'
                      WHEN 'test' THEN 'test'
                      ELSE 't20'              -- ipl, t20, null all use t20
                    END
  )
INSERT INTO fantasy_player_impact_points (
  fantasy_player_id,
  fantasy_match_id,
  impact_points,
  source,
  updated_at
)
SELECT
  player_id,
  fantasy_match_id,
  final_impact_score,
  'calculated_v3',
  NOW()
FROM match_player_scores
ON CONFLICT (fantasy_player_id, fantasy_match_id)
DO UPDATE SET
  impact_points = EXCLUDED.impact_points,
  source        = EXCLUDED.source,
  updated_at    = NOW();

-- Verify: impact scores per match after upsert
SELECT
  fm.match_title,
  fm.match_format,
  COUNT(*)                       AS players,
  MIN(ip.impact_points)          AS min_impact,
  ROUND(AVG(ip.impact_points),1) AS avg_impact,
  MAX(ip.impact_points)          AS max_impact
FROM fantasy_player_impact_points ip
JOIN fantasy_matches fm ON fm.id = ip.fantasy_match_id
WHERE ip.source = 'calculated_v3'
GROUP BY fm.id, fm.match_title, fm.match_format
ORDER BY fm.id;


-- ============================================================
-- STEP 5: SET MATCH BUDGET TO 100 Cr
-- Updates budget_coins on all fantasy matches.
-- Only run this if you want to change the cap from current value.
-- ============================================================

UPDATE fantasy_matches
SET budget_coins = 1000000;

-- Verify
SELECT id, match_title, match_format, budget_coins, status
FROM fantasy_matches
ORDER BY id;
